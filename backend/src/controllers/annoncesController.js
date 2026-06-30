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
    // Construction de la requête avec filtres optionnels
    let countSql = "SELECT COUNT(*) as total FROM annonces WHERE 1=1";
    let sql = `
      SELECT 
        a.id, 
        a.titre,
        a.description,
        a.categorie,
        a.prix,
        a.ville, 
        a.type_paiement,
        a.urgent,
        a.urgent_until,
        a.statut,
        a.created_at,
        a.type_publication,
        a.budget_max,
        a.disponibilite,
        (SELECT url FROM annonce_photos WHERE annonce_id = a.id ORDER BY ordre ASC, id ASC LIMIT 1) AS premiere_photo,
        (SELECT COUNT(*) FROM annonce_photos WHERE annonce_id = a.id) AS nb_photos,
        (SELECT COUNT(*) FROM annonce_likes WHERE annonce_id = a.id) AS nb_likes,
        (SELECT COUNT(*) FROM commentaires WHERE annonce_id = a.id AND type != 'avis' AND type != 'reponse') AS nb_commentaires,
        (SELECT COUNT(*) FROM commentaires WHERE annonce_id = a.id AND type = 'avis') AS nb_avis,
        CONCAT(u.prenom, ' ', u.nom) AS nom_user,
        u.photo AS avatar_user,
        u.telephone AS tel_user
      FROM annonces a
      LEFT JOIN users u ON a.user_id = u.id
      WHERE 1=1
    `;

    const queryParams = [];
    const countParams = [];

    // Gestion du filtre 'mine' vs 'others'/'tous'
    if (filter === 'mine' && req.user) {
      // Pour "mes annonces", on affiche toutes les annonces (même en pause/expirée)
      sql += " AND a.user_id = ?";
      countSql += " AND user_id = ?";
      queryParams.push(req.user.id);
      countParams.push(req.user.id);
    } else {
      // Sinon on ne montre que les annonces actives
      sql += " AND a.statut = 'active'";
      countSql += " AND statut = 'active'";

      if (filter === 'others' && req.user) {
        sql += " AND a.user_id != ?";
        countSql += " AND user_id != ?";
        queryParams.push(req.user.id);
        countParams.push(req.user.id);
      }
    }

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

    sql += ` ORDER BY 
      (CASE WHEN a.urgent = 1 AND (a.urgent_until IS NULL OR a.urgent_until > NOW()) THEN 0 ELSE 1 END) ASC,
      a.created_at DESC 
      LIMIT ? OFFSET ?`;
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
    const { titre, description, categorie, prix, ville, photos, type_paiement, urgent, type_publication, budget_max, disponibilite } = req.body;

    if (!titre || !description) {
      return res.status(400).json({ success: false, message: 'Le titre et la description sont requis.' });
    }

    const pricingType = type_paiement || 'hourly';
    const isUrgent = urgent === true || urgent === 1 || urgent === '1';
    const finalPrix = pricingType === 'quote' ? null : (prix ?? null);

    // Insérer l'annonce
    const [result] = await db.query(
      `INSERT INTO annonces (user_id, titre, description, categorie, prix, ville, type_paiement, urgent, urgent_until, statut, type_publication, budget_max, disponibilite) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ${isUrgent ? 'DATE_ADD(NOW(), INTERVAL 3 DAY)' : 'NULL'}, 'active', ?, ?, ?)`,
      [req.user.id, titre, description, categorie || null, finalPrix, ville || null, pricingType, isUrgent ? 1 : 0, type_publication || 'offre', budget_max || null, disponibilite || null]
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
        a.id, a.user_id, a.titre, a.description, a.categorie, a.prix, a.ville, a.type_paiement, a.urgent, a.urgent_until, a.statut, a.created_at,
        a.type_publication, a.budget_max, a.disponibilite,
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
    // 3. Récupérer les commentaires (tous types : commentaire, avis, reponse)
    const [commentaires] = await db.query(
      `SELECT 
        c.id, c.user_id, c.contenu, c.type, c.note, c.parent_id, c.created_at,
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

    // Filtrer et séparer par type
    const currentUserId = req.user ? Number(req.user.id) : null;
    
    // Commentaires classiques privés (visibles seulement propriétaire + auteur)
    const filteredCommentaires = commentaires.filter(c => {
      const type = c.type || 'commentaire';
      if (type !== 'commentaire') return false;
      if (currentUserId === null) return false;
      return currentUserId === Number(annonce.user_id) || currentUserId === Number(c.user_id);
    });

    // Les avis (publics)
    const avis = commentaires.filter(c => c.type === 'avis');

    // Les réponses aux avis (publiques)
    const reponses = commentaires.filter(c => c.type === 'reponse');

    res.json({
      success: true,
      data: {
        ...annonce,
        is_owner,
        is_liked,
        photos,
        commentaires: filteredCommentaires,
        avis: avis,
        reponses: reponses,
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
    const { titre, description, categorie, prix, ville, statut, type_paiement, urgent, type_publication, budget_max, disponibilite } = req.body;

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

    const updates = [];
    const params = [];

    if (titre !== undefined) { updates.push('titre = ?'); params.push(titre); }
    if (description !== undefined) { updates.push('description = ?'); params.push(description); }
    if (categorie !== undefined) { updates.push('categorie = ?'); params.push(categorie); }
    if (ville !== undefined) { updates.push('ville = ?'); params.push(ville); }
    if (statut !== undefined) { updates.push('statut = ?'); params.push(statut); }

    if (type_paiement !== undefined) {
      updates.push('type_paiement = ?');
      params.push(type_paiement);
      if (type_paiement === 'quote') {
        updates.push('prix = NULL');
      } else if (prix !== undefined) {
        updates.push('prix = ?');
        params.push(prix);
      }
    } else if (prix !== undefined) {
      updates.push('prix = ?');
      params.push(prix);
    }

    if (type_publication !== undefined) { updates.push('type_publication = ?'); params.push(type_publication); }
    if (budget_max !== undefined) { updates.push('budget_max = ?'); params.push(budget_max); }
    if (disponibilite !== undefined) { updates.push('disponibilite = ?'); params.push(disponibilite); }

    if (urgent !== undefined) {
      const isUrgent = urgent === true || urgent === 1 || urgent === '1';
      if (isUrgent) {
        updates.push('urgent = 1', 'urgent_until = DATE_ADD(NOW(), INTERVAL 3 DAY)');
      } else {
        updates.push('urgent = 0', 'urgent_until = NULL');
      }
    }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'Aucun champ à modifier.' });
    }

    params.push(id);
    await db.query(`UPDATE annonces SET ${updates.join(', ')} WHERE id = ?`, params);

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

    const [countResult] = await db.query(
      "SELECT COUNT(*) AS cnt FROM annonce_photos WHERE annonce_id = ?",
      [id]
    );
    if (countResult[0].cnt >= 2) {
      return res.status(400).json({ success: false, message: 'Maximum 2 photos par annonce.' });
    }

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

// DELETE /api/annonces/:id/photos/:pid - Supprimer une photo (propriétaire uniquement)
exports.deletePhoto = async (req, res) => {
  try {
    const { id, pid } = req.params;

    const [annonces] = await db.query("SELECT user_id FROM annonces WHERE id = ?", [id]);
    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }

    if (annonces[0].user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Action non autorisée.' });
    }

    const [photos] = await db.query(
      "SELECT id FROM annonce_photos WHERE id = ? AND annonce_id = ?",
      [pid, id]
    );
    if (photos.length === 0) {
      return res.status(404).json({ success: false, message: 'Photo introuvable.' });
    }

    await db.query("DELETE FROM annonce_photos WHERE id = ?", [pid]);

    res.json({ success: true, message: 'Photo supprimée avec succès.' });
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
    const { contenu, type = 'commentaire', note, parent_id } = req.body;
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

    // Vérifications spéciales si c'est un avis ou une réponse
    if (type === 'commentaire' && Number(annonce.user_id) === Number(userId)) {
      return res.status(403).json({ success: false, message: 'Vous ne pouvez pas commenter votre propre annonce.' });
    }
if (type === 'avis') {
  const [existingAvis] = await db.query(
    "SELECT id FROM commentaires WHERE annonce_id = ? AND user_id = ? AND type = 'avis'",
    [id, userId]
  );
  if (existingAvis.length > 0) {
    return res.status(409).json({ success: false, message: 'Vous avez déjà laissé un avis sur cette offre.' });
  }
}
   if (type === 'reponse') {
     if (Number(annonce.user_id) !== Number(userId)) {
       return res.status(403).json({ success: false, message: 'Seul le propriétaire de l\'annonce peut répondre aux avis.' });
     }
     if (!parent_id) {
       return res.status(400).json({ success: false, message: 'ID de l\'avis parent requis pour répondre.' });
     }

     const [parentComment] = await db.query(
       "SELECT id, type FROM commentaires WHERE id = ? AND annonce_id = ?",
       [parent_id, id]
     );
     if (parentComment.length === 0 || parentComment[0].type !== 'avis') {
       return res.status(404).json({ success: false, message: 'Avis introuvable ou invalide.' });
     }

     const [existingReponse] = await db.query(
       "SELECT id FROM commentaires WHERE parent_id = ? AND type = 'reponse'",
       [parent_id]
     );
     if (existingReponse.length > 0) {
       return res.status(409).json({ success: false, message: 'Vous avez déjà répondu à cet avis.' });
     }
   }
    // 2. Insérer le commentaire
    const [result] = await db.query(
      "INSERT INTO commentaires (annonce_id, user_id, contenu, type, note, parent_id) VALUES (?, ?, ?, ?, ?, ?)",
      [id, userId, contenu, type, note || null, parent_id || null]
    );

    const commentId = result.insertId;

    // 3. Récupérer les informations du commentaire inséré pour la réponse
    const [newComments] = await db.query(
      `SELECT 
        c.id, c.user_id, c.contenu, c.type, c.note, c.parent_id, c.created_at,
        CONCAT(u.prenom, ' ', u.nom) AS nom_user,
        u.photo AS avatar_user,
        u.telephone AS tel_user
       FROM commentaires c
       LEFT JOIN users u ON c.user_id = u.id
       WHERE c.id = ?`,
      [commentId]
    );

    const insertedComment = newComments[0];

    // 4. Envoyer la notification Firebase au propriétaire si ce n'est pas lui qui écrit
    if (annonce.user_id !== userId) {
      try {
        const [owners] = await db.query("SELECT fcm_token FROM users WHERE id = ?", [annonce.user_id]);
        
        if (owners.length > 0 && owners[0].fcm_token) {
          const commenterName = insertedComment.nom_user || 'Un utilisateur';
          let notificationTitle = 'Nouveau commentaire 💬';
          if (type === 'avis') notificationTitle = 'Nouvel avis reçu ⭐';
          
          const notificationBody = `${commenterName} a écrit : "${contenu.length > 40 ? contenu.substring(0, 40) + '...' : contenu}"`;

          sendPushNotification(
            owners[0].fcm_token,
            notificationTitle,
            notificationBody,
            {
              type: type,
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
      message: 'Opération réussie.',
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
    const [commentaires] = await db.query("SELECT id, user_id, type FROM commentaires WHERE id = ? AND annonce_id = ?", [cid, id]);
    if (commentaires.length === 0) {
      return res.status(404).json({ success: false, message: 'Commentaire introuvable pour cette annonce.' });
    }

    const commentaire = commentaires[0];

// 3. Vérifier l'autorisation
  if (commentaire.type === 'avis') {
    // Seul l'auteur de l'avis peut le supprimer (pas le propriétaire de l'annonce)
    if (commentaire.user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Seul l\'auteur de l\'avis peut le supprimer.' });
    }
  } else if (commentaire.type === 'reponse') {
    return res.status(403).json({ success: false, message: 'Les réponses ne peuvent pas être supprimées, seulement modifiées.' });
  } else {
    // Pour les commentaires classiques : propriétaire de l'annonce OU auteur
    if (annonce.user_id !== req.user.id && commentaire.user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Action non autorisée.' });
    }
  }
    // 4. Supprimer le commentaire et les réponses enfants si c'est un avis
    if (commentaire.type === 'avis') {
      await db.query("DELETE FROM commentaires WHERE parent_id = ?", [cid]);
    }
    await db.query("DELETE FROM commentaires WHERE id = ?", [cid]);

    res.json({ success: true, message: 'Élément supprimé avec succès.' });

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

// PUT /api/annonces/:id/commentaires/:cid - Modifier une réponse (propriétaire de l'annonce uniquement)
exports.updateCommentaire = async (req, res) => {
  try {
    const { id, cid } = req.params;
    const { contenu } = req.body;

    if (!contenu || contenu.trim() === '') {
      return res.status(400).json({ success: false, message: 'Le contenu est requis.' });
    }

    const [annonces] = await db.query("SELECT user_id FROM annonces WHERE id = ?", [id]);
    if (annonces.length === 0) {
      return res.status(404).json({ success: false, message: 'Annonce introuvable.' });
    }
    const annonce = annonces[0];

    const [commentaires] = await db.query(
      "SELECT id, user_id, type FROM commentaires WHERE id = ? AND annonce_id = ?",
      [cid, id]
    );
    if (commentaires.length === 0) {
      return res.status(404).json({ success: false, message: 'Commentaire introuvable.' });
    }
    const commentaire = commentaires[0];

    if (commentaire.type !== 'reponse') {
      return res.status(403).json({ success: false, message: 'Seules les réponses peuvent être modifiées.' });
    }

    if (Number(annonce.user_id) !== Number(req.user.id) || Number(commentaire.user_id) !== Number(req.user.id)) {
      return res.status(403).json({ success: false, message: 'Action non autorisée.' });
    }

    await db.query("UPDATE commentaires SET contenu = ? WHERE id = ?", [contenu, cid]);

    res.json({ success: true, message: 'Réponse modifiée avec succès.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};