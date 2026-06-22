const db = require('../config/database');
const cloudinary = require('../config/cloudinary');
const { sendPushNotification } = require('../services/notificationService');

// Helper pour uploader un buffer de fichier vers Cloudinary
const uploadFromBuffer = (fileBuffer) => {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: 'annonces' },
      (error, result) => {
        if (result) resolve(result);
        else reject(error);
      }
    );
    stream.end(fileBuffer);
  });
};

// GET /api/annonces - Feed paginé
exports.getFeed = async (req, res) => {
  try {
    let { page = 1, limit = 10, categorie, ville, filter } = req.query;

    page = parseInt(page, 10);
    limit = parseInt(limit, 10);
    if (isNaN(page) || page < 1) page = 1;
    if (isNaN(limit) || limit < 1) limit = 10;

    const offset = (page - 1) * limit;

    // Construction de la requête avec filtres optionnels
    let countSql = "SELECT COUNT(*) as total FROM annonces WHERE statut = 'active'";
    let sql = `
      SELECT 
        a.id, 
        a.titre,
        a.description,
        a.categorie,
        a.prix,
        a.ville, 
        a.type_paiement,
        a.created_at,
        (SELECT url FROM annonce_photos WHERE annonce_id = a.id ORDER BY ordre ASC, id ASC LIMIT 1) AS premiere_photo,
        (SELECT COUNT(*) FROM annonce_likes WHERE annonce_id = a.id) AS nb_likes,
        (SELECT COUNT(*) FROM commentaires WHERE annonce_id = a.id) AS nb_commentaires,
        CONCAT(u.prenom, ' ', u.nom) AS nom_user,
        u.photo AS avatar_user,
        u.telephone AS tel_user
      FROM annonces a
      LEFT JOIN users u ON a.user_id = u.id
      WHERE a.statut = 'active'
    `;

    const queryParams = [];
    const countParams = [];

    if (categorie) {
      sql += " AND a.categorie = ?";
      countSql += " AND categorie = ?";
      queryParams.push(categorie);
      countParams.push(categorie);
    }

    if (ville) {
      sql += " AND a.ville = ?";
      countSql += " AND ville = ?";
      queryParams.push(ville);
      countParams.push(ville);
    }

    if (filter === 'mine' && req.user) {
      sql += " AND a.user_id = ?";
      countSql += " AND user_id = ?";
      queryParams.push(req.user.id);
      countParams.push(req.user.id);
    } else if (filter === 'others' && req.user) {
      sql += " AND a.user_id != ?";
      countSql += " AND user_id != ?";
      queryParams.push(req.user.id);
      countParams.push(req.user.id);
    }

    sql += " ORDER BY a.created_at DESC LIMIT ? OFFSET ?";
    queryParams.push(limit, offset);

    // Exécuter le comptage et la récupération
    const [countResult] = await db.query(countSql, countParams);
    const total = countResult[0].total;

    const [rows] = await db.query(sql, queryParams);

    res.json({
      success: true,
      page,
      limit,
      total,
      data: rows
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/annonces - Créer une annonce (authentifié)
exports.createAnnonce = async (req, res) => {
  try {
    const { titre, description, categorie, prix, ville, photos, type_paiement } = req.body;

    if (!titre || !description) {
      return res.status(400).json({ success: false, message: 'Le titre et la description sont requis.' });
    }

    // Insérer l'annonce
    const [result] = await db.query(
      `INSERT INTO annonces (user_id, titre, description, categorie, prix, ville, type_paiement, statut) 
       VALUES (?, ?, ?, ?, ?, ?, ?, 'active')`,
      [req.user.id, titre, description, categorie || null, prix || null, ville || null, type_paiement || 'Espèces']
    );

    const annonceId = result.insertId;

    // Insérer les photos si fournies sous forme d'URL
    if (photos && Array.isArray(photos)) {
      for (let i = 0; i < photos.length; i++) {
        await db.query(
          "INSERT INTO annonce_photos (annonce_id, url, ordre) VALUES (?, ?, ?)",
          [annonceId, photos[i], i]
        );
      }
    }

    res.status(201).json({
      success: true,
      message: 'Annonce créée avec succès',
      id: annonceId
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/annonces/:id - Détails d'une annonce
exports.getDetail = async (req, res) => {
  try {
    const { id } = req.params;

    // 1. Récupérer les infos principales de l'annonce
    const [annonces] = await db.query(
      `SELECT 
        a.id, a.user_id, a.titre, a.description, a.categorie, a.prix, a.ville, a.type_paiement, a.statut, a.created_at,
        CONCAT(u.prenom, ' ', u.nom) AS nom_user,
        u.photo AS avatar_user
       FROM annonces a
       LEFT JOIN users u ON a.user_id = u.id
       WHERE a.id = ?`,
      [id]
    );

    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }

    const annonce = annonces[0];

    // 2. Récupérer les photos de l'annonce
    const [photos] = await db.query(
      "SELECT id, url, ordre FROM annonce_photos WHERE annonce_id = ? ORDER BY ordre ASC, id ASC",
      [id]
    );

    // 3. Récupérer les commentaires
    const [commentaires] = await db.query(
      `SELECT 
        c.id, c.user_id, c.contenu, c.type, c.created_at,
        CONCAT(u.prenom, ' ', u.nom) AS nom_user,
        u.photo AS avatar_user,
        u.telephone AS tel_user
       FROM commentaires c
       LEFT JOIN users u ON c.user_id = u.id
       WHERE c.annonce_id = ?
       ORDER BY c.created_at ASC`,
      [id]
    );

    // 4. Récupérer les likes
    const [likes] = await db.query(
      `SELECT 
        l.user_id,
        CONCAT(u.prenom, ' ', u.nom) AS nom_user,
        u.photo AS avatar_user
       FROM annonce_likes l
       LEFT JOIN users u ON l.user_id = u.id
       WHERE l.annonce_id = ?`,
      [id]
    );

    // 5. Calculer le statut d'appartenance et de like de l'utilisateur connecté
    const is_owner = req.user ? (Number(req.user.id) === Number(annonce.user_id)) : false;
    const is_liked = req.user ? likes.some(l => Number(l.user_id) === Number(req.user.id)) : false;

    // Commentaires : visibles par le propriétaire + l'auteur de chaque commentaire
    const currentUserId = req.user ? Number(req.user.id) : null;
    const filteredCommentaires = commentaires.filter(c => {
      const type = c.type || 'commentaire';
      if (type !== 'commentaire') return false;
      if (currentUserId === null) return false;
      return currentUserId === Number(annonce.user_id) || currentUserId === Number(c.user_id);
    });

    res.json({
      success: true,
      data: {
        ...annonce,
        is_owner,
        is_liked,
        photos,
        commentaires: filteredCommentaires,
        likes_count: likes.length,
        likes
      }
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/annonces/:id - Modifier une annonce (propriétaire uniquement)
exports.updateAnnonce = async (req, res) => {
  try {
    const { id } = req.params;
    const { titre, description, categorie, prix, ville, statut, type_paiement } = req.body;

    // Vérifier l'annonce
    const [annonces] = await db.query("SELECT user_id FROM annonces WHERE id = ?", [id]);
    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }

    if (annonces[0].user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Action non autorisée.' });
    }

    // Validation du statut si fourni
    if (statut && !['active', 'pausee', 'expiree'].includes(statut)) {
      return res.status(400).json({ success: false, message: 'Statut invalide.' });
    }

    // Mise à jour
    await db.query(
      `UPDATE annonces SET
        titre = COALESCE(?, titre),
        description = COALESCE(?, description),
        categorie = COALESCE(?, categorie),
        prix = COALESCE(?, prix),
        ville = COALESCE(?, ville),
        type_paiement = COALESCE(?, type_paiement),
        statut = COALESCE(?, statut)
       WHERE id = ?`,
      [titre || null, description || null, categorie || null, prix || null, ville || null, type_paiement || null, statut || null, id]
    );

    res.json({ success: true, message: 'Annonce modifiée avec succès.' });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/annonces/:id - Supprimer une annonce (propriétaire uniquement)
exports.deleteAnnonce = async (req, res) => {
  try {
    const { id } = req.params;

    // Vérifier l'annonce
    const [annonces] = await db.query("SELECT user_id FROM annonces WHERE id = ?", [id]);
    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }

    if (annonces[0].user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Action non autorisée.' });
    }

    // Supprimer les données associées
    await db.query("DELETE FROM annonce_photos WHERE annonce_id = ?", [id]);
    await db.query("DELETE FROM annonce_likes WHERE annonce_id = ?", [id]);
    await db.query("DELETE FROM commentaires WHERE annonce_id = ?", [id]);
    await db.query("DELETE FROM annonces WHERE id = ?", [id]);

    res.json({ success: true, message: 'Annonce supprimée avec succès.' });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/annonces/:id/photos - Uploader une photo vers Cloudinary et l'ajouter à l'annonce
exports.uploadPhoto = async (req, res) => {
  try {
    const { id } = req.params;

    // 1. Vérifier l'annonce et l'autorisation
    const [annonces] = await db.query("SELECT user_id FROM annonces WHERE id = ?", [id]);
    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }

    if (annonces[0].user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Action non autorisée.' });
    }

    // 2. Vérifier si un fichier a été téléversé
    if (!req.files || Object.keys(req.files).length === 0) {
      return res.status(400).json({ success: false, message: 'Aucun fichier n\'a été fourni.' });
    }

    const file = req.files.photo || req.files.image || Object.values(req.files)[0];

    // 3. Téléverser vers Cloudinary
    let uploadResult;
    if (file.tempFilePath) {
      uploadResult = await cloudinary.uploader.upload(file.tempFilePath, { folder: 'annonces' });
    } else if (file.data) {
      uploadResult = await uploadFromBuffer(file.data);
    } else {
      return res.status(400).json({ success: false, message: 'Données de fichier invalides.' });
    }

    const photoUrl = uploadResult.secure_url;

    // 4. Calculer le prochain ordre de photo
    const [orderResult] = await db.query(
      "SELECT COALESCE(MAX(ordre), 0) + 1 AS next_ordre FROM annonce_photos WHERE annonce_id = ?",
      [id]
    );
    const nextOrdre = orderResult[0].next_ordre;

    // 5. Enregistrer dans la base de données
    const [insertResult] = await db.query(
      "INSERT INTO annonce_photos (annonce_id, url, ordre) VALUES (?, ?, ?)",
      [id, photoUrl, nextOrdre]
    );

    res.json({
      success: true,
      photo: {
        id: insertResult.insertId,
        url: photoUrl,
        ordre: nextOrdre
      }
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/annonces/:id/like - Liker / Unliker une annonce
exports.toggleLike = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Vérifier l'annonce
    const [annonces] = await db.query("SELECT id FROM annonces WHERE id = ?", [id]);
    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }

    // Vérifier si déjà liké
    const [likes] = await db.query(
      "SELECT id FROM annonce_likes WHERE annonce_id = ? AND user_id = ?",
      [id, userId]
    );

    if (likes.length > 0) {
      // Unliker
      await db.query("DELETE FROM annonce_likes WHERE id = ?", [likes[0].id]);
      return res.json({ success: true, message: 'Like retiré avec succès.', liked: false });
    } else {
      // Liker
      await db.query(
        "INSERT INTO annonce_likes (annonce_id, user_id) VALUES (?, ?)",
        [id, userId]
      );
      return res.json({ success: true, message: 'Annonce likée avec succès.', liked: true });
    }

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/annonces/:id/commentaires - Ajouter un commentaire et notifier le propriétaire
exports.addCommentaire = async (req, res) => {
  try {
    const { id } = req.params;
    const { contenu, type } = req.body;
    const userId = req.user.id;

    if (!contenu || contenu.trim() === '') {
      return res.status(400).json({ success: false, message: 'Le contenu du commentaire est requis.' });
    }

    // 1. Vérifier l'annonce et obtenir le titre et l'owner
    const [annonces] = await db.query(
      "SELECT user_id, titre FROM annonces WHERE id = ?",
      [id]
    );

    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }

    const annonce = annonces[0];

    if (Number(annonce.user_id) === Number(userId)) {
      return res.status(403).json({ success: false, message: 'Vous ne pouvez pas commenter votre propre annonce.' });
    }

    // 2. Insérer le commentaire (type commentaire uniquement)
    const [result] = await db.query(
      "INSERT INTO commentaires (annonce_id, user_id, contenu, type) VALUES (?, ?, ?, ?)",
      [id, userId, contenu, 'commentaire']
    );

    const commentId = result.insertId;

    // 3. Récupérer les informations du commentaire inséré pour la réponse
    const [newComments] = await db.query(
      `SELECT 
        c.id, c.user_id, c.contenu, c.type, c.created_at,
        CONCAT(u.prenom, ' ', u.nom) AS nom_user,
        u.photo AS avatar_user,
        u.telephone AS tel_user
       FROM commentaires c
       LEFT JOIN users u ON c.user_id = u.id
       WHERE c.id = ?`,
      [commentId]
    );

    const insertedComment = newComments[0];

    // 4. Envoyer la notification Firebase au propriétaire si ce n'est pas lui qui commente
    if (annonce.user_id !== userId) {
      try {
        // Obtenir le token FCM du propriétaire
        const [owners] = await db.query("SELECT fcm_token FROM users WHERE id = ?", [annonce.user_id]);
        
        if (owners.length > 0 && owners[0].fcm_token) {
          const commenterName = insertedComment.nom_user || 'Un utilisateur';
          const notificationTitle = 'Nouveau commentaire 💬';
          const notificationBody = `${commenterName} a écrit sur votre annonce "${annonce.titre}" : "${contenu.length > 40 ? contenu.substring(0, 40) + '...' : contenu}"`;

          // Appel asynchrone sans bloquer la requête HTTP principale
          sendPushNotification(
            owners[0].fcm_token,
            notificationTitle,
            notificationBody,
            {
              type: 'comment',
              annonceId: String(id),
              commentId: String(commentId)
            }
          );
        }
      } catch (notifErr) {
        console.error('⚠️ Échec de l\'envoi de la notification push (continué) :', notifErr.message);
      }
    }

    res.status(201).json({
      success: true,
      message: 'Commentaire ajouté avec succès.',
      data: insertedComment
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/annonces/:id/commentaires/:cid - Supprimer un commentaire (propriétaire de l'annonce)
exports.deleteCommentaire = async (req, res) => {
  try {
    const { id, cid } = req.params;

    // 1. Vérifier si l'annonce existe et récupérer son propriétaire
    const [annonces] = await db.query("SELECT user_id FROM annonces WHERE id = ?", [id]);
    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }

    const annonce = annonces[0];

    // 2. Vérifier si le commentaire existe
    const [commentaires] = await db.query("SELECT user_id FROM commentaires WHERE id = ? AND annonce_id = ?", [cid, id]);
    if (commentaires.length === 0) {
      return res.status(404).json({ success: false, message: 'Commentaire introuvable pour cette annonce.' });
    }

    // 3. Vérifier l'autorisation : seul le propriétaire de l'annonce peut supprimer
    if (annonce.user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Action non autorisée. Seul le propriétaire de l\'annonce peut supprimer les commentaires.' });
    }

    // 4. Supprimer le commentaire
    await db.query("DELETE FROM commentaires WHERE id = ?", [cid]);

    res.json({ success: true, message: 'Commentaire supprimé avec succès.' });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/annonces/:id/commentaires/:cid/contacter - Ouvrir un chat privé (Stub reporté)
exports.contacterCommentateur = async (req, res) => {
  try {
    const { id, cid } = req.params;

    // Vérifier l'annonce
    const [annonces] = await db.query("SELECT user_id, titre FROM annonces WHERE id = ?", [id]);
    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }

    const annonce = annonces[0];

    // Seul le propriétaire de l'annonce peut contacter le commentateur
    if (annonce.user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Action non autorisée.' });
    }

    // Récupérer le commentateur
    const [commentaires] = await db.query("SELECT user_id FROM commentaires WHERE id = ?", [cid]);
    if (commentaires.length === 0) {
      return res.status(404).json({ success: false, message: 'Commentaire introuvable.' });
    }

    const commentateurId = commentaires[0].user_id;

    // Stub de réponse pour la messagerie
    res.json({
      success: true,
      message: 'Messagerie privée non implémentée (reporté à plus tard).',
      data: {
        annonce_id: id,
        proprietaire_id: req.user.id,
        commentateur_id: commentateurId
      }
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
