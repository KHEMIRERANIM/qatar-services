const db = require('../config/database')
const bcrypt = require('bcrypt')
const jwt = require('jsonwebtoken')
const { v4: uuidv4 } = require('uuid')
const cloudinary = require('../config/cloudinary')

// ═══════════════════════════
// CREATE — INSCRIPTION
// ═══════════════════════════
exports.register = async (req, res) => {
  try {
const { prenom, nom, email,
        telephone, mot_de_passe,
        date_naissance, ville } = req.body

    // Validation champs obligatoires
    if (!prenom || !nom || !email || 
        !telephone || !mot_de_passe) {
      return res.status(400).json({
        message: 'Tous les champs sont obligatoires'
      })
    }

    // Validation mot de passe
    if (mot_de_passe.length < 8) {
      return res.status(400).json({
        message: 'Mot de passe minimum 8 caractères'
      })
    }

    // Vérifier email unique
    const [existingEmail] = await db.query(
      'SELECT id FROM users WHERE email = ?',
      [email]
    )
    if (existingEmail.length > 0) {
      return res.status(400).json({
        message: 'Email déjà utilisé'
      })
    }

    // Vérifier téléphone unique
    const [existingPhone] = await db.query(
      'SELECT id FROM users WHERE telephone = ?',
      [telephone]
    )
    if (existingPhone.length > 0) {
      return res.status(400).json({
        message: 'Téléphone déjà utilisé'
      })
    }

    // Hasher mot de passe
    const hashedPassword = await bcrypt.hash(mot_de_passe, 10)

    // Créer utilisateur
  const uuid = uuidv4()
      await db.query(
        `INSERT INTO users
         (uuid, prenom, nom, email, telephone, mot_de_passe, date_naissance, ville, statut)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'inactif')`,
        [uuid, prenom, nom, email, telephone, hashedPassword, date_naissance || null, ville || null, 'inactif']
      )

    res.status(201).json({
      message: 'Compte créé avec succès'
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// ═══════════════════════════
// READ — CONNEXION
// ═══════════════════════════
exports.login = async (req, res) => {
  try {
    const { email, mot_de_passe } = req.body

    if (!email || !mot_de_passe) {
      return res.status(400).json({
        message: 'Email et mot de passe obligatoires'
      })
    }

    // Vérifier email existe
    const [users] = await db.query(
      'SELECT * FROM users WHERE email = ? AND deleted_at IS NULL',
      [email]
    )
    if (users.length === 0) {
      return res.status(400).json({
        message: 'Email ou mot de passe incorrect'
      })
    }

    const user = users[0]

    // Vérifier si bloqué
    if (user.bloque_jusqua &&
        new Date() < new Date(user.bloque_jusqua)) {
      return res.status(400).json({
        message: 'Compte bloqué temporairement'
      })
    }

    // Vérifier mot de passe
    const validPassword = await bcrypt.compare(
      mot_de_passe,
      user.mot_de_passe
    )

    if (!validPassword) {
      await db.query(
        `UPDATE users SET
         tentatives_login = tentatives_login + 1
         WHERE id = ?`,
        [user.id]
      )

      if (user.tentatives_login >= 4) {
        const bloqueJusqua = new Date(
          Date.now() + 30 * 60 * 1000
        )
        await db.query(
          'UPDATE users SET bloque_jusqua = ? WHERE id = ?',
          [bloqueJusqua, user.id]
        )
        return res.status(400).json({
          message: 'Compte bloqué 30 minutes'
        })
      }

      return res.status(400).json({
        message: 'Email ou mot de passe incorrect'
      })
    }

    // Réinitialiser tentatives
    await db.query(
      `UPDATE users SET
       tentatives_login = 0,
       derniere_connexion = NOW()
       WHERE id = ?`,
      [user.id]
    )

    // Générer tokens
    const token = jwt.sign(
      { id: user.id, uuid: user.uuid },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE }
    )

    const refreshToken = jwt.sign(
      { id: user.id },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_REFRESH_EXPIRE }
    )

    // Sauvegarder token
    await db.query(
      `INSERT INTO tokens
       (user_id, token, refresh_token, expire_le)
       VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))`,
      [user.id, token, refreshToken]
    )

    res.json({
      message: 'Connexion réussie',
      token,
      refreshToken,
      user: {
        uuid: user.uuid,
        prenom: user.prenom,
        nom: user.nom,
        email: user.email,
        photo: user.photo
      }
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// ═══════════════════════════
// READ — PROFIL
// ═══════════════════════════
exports.profile = async (req, res) => {
  try {
    const [users] = await db.query(
      `SELECT uuid, prenom, nom, email,
       telephone, photo, date_naissance, ville, statut,
       created_at
       FROM users WHERE id = ?`,
      [req.user.id]
    )
    const [prestataires] = await db.query(
      'SELECT statut_verification, badge_verifie FROM prestataires WHERE user_id = ?',
      [req.user.id]
    )

    const user = users[0] || {}
    const isPro = prestataires.length > 0 && prestataires[0].badge_verifie === 1

    res.json({
      user: {
        ...user,
        role: isPro ? 'pro' : 'client',
        isPro,
        statut_verification: prestataires[0]?.statut_verification || 'non_demande',
      },
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// ═══════════════════════════
// UPDATE — MOT DE PASSE OUBLIÉ
// ═══════════════════════════
exports.forgotPassword = async (req, res) => {
  try {
    const { email } = req.body

    const [users] = await db.query(
      'SELECT id FROM users WHERE email = ?',
      [email]
    )

    if (users.length === 0) {
      return res.json({
        message: 'Email envoyé si le compte existe'
      })
    }

    const token = uuidv4()
    const expireAt = new Date(Date.now() + 15 * 60 * 1000)

    await db.query(
      `INSERT INTO reset_password
       (user_id, token, expire_le)
       VALUES (?, ?, ?)`,
      [users[0].id, token, expireAt]
    )

    // TODO: envoyer email

    res.json({
      message: 'Email envoyé si le compte existe'
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// ═══════════════════════════
// UPDATE — RESET MOT DE PASSE
// ═══════════════════════════
exports.resetPassword = async (req, res) => {
  try {
    const { token, nouveau_mot_de_passe } = req.body

    const [resets] = await db.query(
      `SELECT * FROM reset_password
       WHERE token = ?
       AND utilise = FALSE
       AND expire_le > NOW()`,
      [token]
    )

    if (resets.length === 0) {
      return res.status(400).json({
        message: 'Lien invalide ou expiré'
      })
    }

    const hashedPassword = await bcrypt.hash(
      nouveau_mot_de_passe, 10
    )

    await db.query(
      'UPDATE users SET mot_de_passe = ? WHERE id = ?',
      [hashedPassword, resets[0].user_id]
    )

    await db.query(
      'UPDATE reset_password SET utilise = TRUE WHERE token = ?',
      [token]
    )

    res.json({
      message: 'Mot de passe modifié avec succès'
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// ═══════════════════════════
// DELETE — DÉCONNEXION
// ═══════════════════════════
exports.logout = async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1]

    await db.query(
      'UPDATE tokens SET revoque = TRUE WHERE token = ?',
      [token]
    )

    res.json({ message: 'Déconnecté avec succès' })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// UPDATE — PROFIL
exports.updateProfile = async (req, res) => {
  try {
    const { prenom, nom, email, telephone, photo, date_naissance, ville } = req.body

    // Simple validations
    if (email) {
      // Check if email already used by another user
      const [existingEmail] = await db.query(
        'SELECT id FROM users WHERE email = ? AND id != ?',
        [email, req.user.id]
      )
      if (existingEmail.length > 0) {
        return res.status(400).json({
          message: 'Email déjà utilisé'
        })
      }
    }

    if (telephone) {
      // Check if phone already used by another user
      const [existingPhone] = await db.query(
        'SELECT id FROM users WHERE telephone = ? AND id != ?',
        [telephone, req.user.id]
      )
      if (existingPhone.length > 0) {
        return res.status(400).json({
          message: 'Téléphone déjà utilisé'
        })
      }
    }

    // Dynamic update query
    const fieldsToUpdate = []
    const params = []

    if (prenom !== undefined) { fieldsToUpdate.push('prenom = ?'); params.push(prenom); }
    if (nom !== undefined) { fieldsToUpdate.push('nom = ?'); params.push(nom); }
    if (email !== undefined) { fieldsToUpdate.push('email = ?'); params.push(email); }
    if (telephone !== undefined) { fieldsToUpdate.push('telephone = ?'); params.push(telephone); }
    if (photo !== undefined) { fieldsToUpdate.push('photo = ?'); params.push(photo); }
        if (date_naissance !== undefined) { fieldsToUpdate.push('date_naissance = ?'); params.push(date_naissance); }
        if (ville !== undefined) { fieldsToUpdate.push('ville = ?'); params.push(ville); }

        if (fieldsToUpdate.length === 0) {
      return res.status(400).json({ message: 'Aucun champ à modifier' })
    }

    params.push(req.user.id)

    await db.query(
      `UPDATE users SET ${fieldsToUpdate.join(', ')} WHERE id = ?`,
      params
    )

    // Return the updated user info
  const [users] = await db.query(
        'SELECT uuid, prenom, nom, email, telephone, photo, date_naissance, ville, statut FROM users WHERE id = ?',
        [req.user.id]
      )

    res.json({
      message: 'Profil mis à jour avec succès',
      user: users[0]
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// UPDATE — VERIFICATION EMAIL (STATUS ACTIVE)

exports.verifyEmail = async (req, res) => {
  try {
    await db.query(
      "UPDATE users SET statut = 'actif' WHERE id = ?",
      [req.user.id]
    )
    res.json({
      success: true,
      message: 'Email vérifié et statut mis à jour dans MySQL'
    })
  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}
// POST — SOCIAL LOGIN (GOOGLE / APPLE)
exports.socialLogin = async (req, res) => {
  try {
    const { email, prenom, nom, photo, uid } = req.body

    if (!email) {
      return res.status(400).json({ message: 'Email obligatoire' })
    }

    // Check if user exists
    let [users] = await db.query(
      'SELECT * FROM users WHERE email = ? AND deleted_at IS NULL',
      [email]
    )

    let user
    if (users.length === 0) {
      // Create user as active directly
      const uuid = uid || uuidv4()
      const placeholderPassword = await bcrypt.hash(uuid, 10)
      
      await db.query(
        `INSERT INTO users
         (uuid, prenom, nom, email, mot_de_passe, photo, statut)
         VALUES (?, ?, ?, ?, ?, ?, 'actif')`,
        [uuid, prenom || '', nom || '', email, placeholderPassword, photo || '', 'actif']
      )

      // Fetch the newly created user
      const [newUsers] = await db.query(
        'SELECT * FROM users WHERE email = ?',
        [email]
      )
      user = newUsers[0]
  } else {
    user = users[0]
    // Si pas de photo, utilise la photo Google
    if (!user.photo && photo) {
      await db.query(
        'UPDATE users SET photo = ? WHERE id = ?',
        [photo, user.id]
      )
      user.photo = photo
    }
    if (user.statut !== 'actif') {
      await db.query(
        "UPDATE users SET statut = 'actif' WHERE id = ?",
        [user.id]
      )
      user.statut = 'actif'
    }
  }
    // Generate backend JWT tokens
    const token = jwt.sign(
      { id: user.id, uuid: user.uuid },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE }
    )

    const refreshToken = jwt.sign(
      { id: user.id },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_REFRESH_EXPIRE }
    )

    await db.query(
      `INSERT INTO tokens
       (user_id, token, refresh_token, expire_le)
       VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))`,
      [user.id, token, refreshToken]
    )

    res.json({
      message: 'Connexion réussie',
      token,
      refreshToken,
      user: {
        uuid: user.uuid,
        prenom: user.prenom,
        nom: user.nom,
        email: user.email,
        photo: user.photo,
        telephone: user.telephone,
        statut: user.statut
      }
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// POST — SYNC PASSWORD (Firebase -> MySQL after reset)
exports.syncPassword = async (req, res) => {
  try {
    const { email, password, idToken } = req.body

    if (!email || !password || !idToken) {
      return res.status(400).json({ message: 'Données manquantes' })
    }

    const apiKey = process.env.FIREBASE_API_KEY;
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken })
      }
    )

    if (!response.ok) {
      return res.status(401).json({ message: 'Token de vérification invalide' })
    }

    const data = await response.json()
    if (!data.users || data.users.length === 0) {
      return res.status(401).json({ message: 'Utilisateur introuvable dans Firebase' })
    }

    const firebaseUser = data.users[0]
    if (firebaseUser.email.toLowerCase() !== email.toLowerCase()) {
      return res.status(403).json({ message: 'Non autorisé' })
    }

    // Mettre à jour le mot de passe dans MySQL
    const hashedPassword = await bcrypt.hash(password, 10)
    await db.query(
      'UPDATE users SET mot_de_passe = ? WHERE email = ?',
      [hashedPassword, email]
    )

    res.json({ success: true, message: 'Mot de passe synchronisé avec succès' })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// POST — CHECK PHONE (Check if phone exists in MySQL)
exports.checkPhone = async (req, res) => {
  try {
    let { telephone } = req.body

    if (!telephone) {
      return res.status(400).json({ message: 'Téléphone obligatoire' })
    }

    // Exact query on users
    const [users] = await db.query(
      'SELECT id FROM users WHERE telephone = ? AND deleted_at IS NULL',
      [telephone]
    )

    if (users.length === 0) {
      return res.status(404).json({
        exists: false,
        message: 'Numéro non reconnu'
      })
    }

    res.json({
      exists: true,
      message: 'Numéro de téléphone trouvé'
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// POST — LOGIN PHONE (Generate JWT tokens for phone connection)
exports.loginPhone = async (req, res) => {
  try {
    const { telephone } = req.body

    if (!telephone) {
      return res.status(400).json({ message: 'Téléphone obligatoire' })
    }

    const [users] = await db.query(
      'SELECT * FROM users WHERE telephone = ? AND deleted_at IS NULL',
      [telephone]
    )

    if (users.length === 0) {
      return res.status(404).json({
        message: 'Numéro non reconnu'
      })
    }

    const user = users[0]

    // Vérifier si bloqué
    if (user.bloque_jusqua &&
        new Date() < new Date(user.bloque_jusqua)) {
      return res.status(400).json({
        message: 'Compte bloqué temporairement'
      })
    }

    // Réinitialiser tentatives
    await db.query(
      `UPDATE users SET
       tentatives_login = 0,
       derniere_connexion = NOW()
       WHERE id = ?`,
      [user.id]
    )

    // Générer tokens
    const token = jwt.sign(
      { id: user.id, uuid: user.uuid },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE }
    )

    const refreshToken = jwt.sign(
      { id: user.id },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_REFRESH_EXPIRE }
    )

    // Sauvegarder token
    await db.query(
      `INSERT INTO tokens
       (user_id, token, refresh_token, expire_le)
       VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))`,
      [user.id, token, refreshToken]
    )

    res.json({
      message: 'Connexion réussie',
      token,
      refreshToken,
      user: {
        uuid: user.uuid,
        prenom: user.prenom,
        nom: user.nom,
        email: user.email,
        photo: user.photo,
        telephone: user.telephone,
        statut: user.statut
      }
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// Helper pour uploader un buffer de fichier vers Cloudinary dans le dossier 'profiles'
const uploadFromBuffer = (fileBuffer) => {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: 'profiles' },
      (error, result) => {
        if (result) resolve(result);
        else reject(error);
      }
    );
    stream.end(fileBuffer);
  });
};

// POST /auth/profile/photo - Mettre à jour la photo de profil du user connecté
exports.updateProfilePhoto = async (req, res) => {
  try {
    if (!req.files || Object.keys(req.files).length === 0) {
      return res.status(400).json({ success: false, message: 'Aucun fichier n\'a été fourni.' });
    }

    const file = req.files.photo || req.files.image || Object.values(req.files)[0];
    let uploadResult;
    if (file.tempFilePath) {
      uploadResult = await cloudinary.uploader.upload(file.tempFilePath, { folder: 'profiles' });
    } else if (file.data) {
      uploadResult = await uploadFromBuffer(file.data);
    } else {
      return res.status(400).json({ success: false, message: 'Données de fichier invalides.' });
    }

    const photoUrl = uploadResult.secure_url;

    // Mise à jour de l'utilisateur connecté dans MySQL
    await db.query('UPDATE users SET photo = ? WHERE id = ?', [photoUrl, req.user.id]);

    res.json({
      success: true,
      message: 'Photo de profil mise à jour avec succès',
      photo: photoUrl
    });

  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ═══════════════════════════
// POST — REFRESH TOKEN
// ═══════════════════════════
exports.refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body

    if (!refreshToken) {
      return res.status(400).json({ message: 'Refresh token obligatoire' })
    }

    // 1. Vérifier si le refresh token existe et n'est pas révoqué en BDD
    const [tokens] = await db.query(
      'SELECT * FROM tokens WHERE refresh_token = ? AND revoque = FALSE AND expire_le > NOW()',
      [refreshToken]
    )

    if (tokens.length === 0) {
      return res.status(401).json({ message: 'Refresh token invalide ou expiré' })
    }

    const tokenRecord = tokens[0]

    // 2. Vérifier la signature du refresh token
    let decoded;
    try {
      decoded = jwt.verify(refreshToken, process.env.JWT_SECRET)
    } catch (err) {
      return res.status(401).json({ message: 'Refresh token invalide' })
    }

    // 3. Récupérer l'utilisateur
    const [users] = await db.query('SELECT * FROM users WHERE id = ?', [tokenRecord.user_id])
    if (users.length === 0) {
      return res.status(401).json({ message: 'Utilisateur introuvable' })
    }
    const user = users[0]

    // 4. Générer un nouveau token d'accès
    const newToken = jwt.sign(
      { id: user.id, uuid: user.uuid },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE }
    )

    // 5. Mettre à jour le token d'accès en base de données pour cette session
    await db.query(
      'UPDATE tokens SET token = ? WHERE id = ?',
      [newToken, tokenRecord.id]
    )

    res.json({
      token: newToken
    })

  } catch (error) {
    res.status(500).json({ message: error.message })
  }
}

// ═══════════════════════════
// READ — AVIS PAR CATÉGORIE (offres du user connecté)
// ═══════════════════════════
exports.getMyAvisStats = async (req, res) => {
  try {
    const userId = req.user.id

    const [globalStats] = await db.query(
      `SELECT
        ROUND(AVG(c.note), 1) AS note_globale,
        COUNT(c.id) AS nb_avis_total
       FROM commentaires c
       JOIN annonces a ON a.id = c.annonce_id
       WHERE a.user_id = ?
         AND c.type = 'avis'
         AND a.type_publication = 'offre'
         AND c.note IS NOT NULL`,
      [userId]
    )

    const [parCategorie] = await db.query(
      `SELECT
        a.categorie,
        ROUND(AVG(c.note), 1) AS note,
        COUNT(c.id) AS nb_avis
       FROM commentaires c
       JOIN annonces a ON a.id = c.annonce_id
       WHERE a.user_id = ?
         AND c.type = 'avis'
         AND a.type_publication = 'offre'
         AND c.note IS NOT NULL
         AND a.categorie IS NOT NULL
         AND a.categorie != ''
       GROUP BY a.categorie
       ORDER BY nb_avis DESC`,
      [userId]
    )
const [avisRecents] = await db.query(
  `SELECT
    c.id, c.contenu, c.note, c.created_at,
    CONCAT(u.prenom, ' ', u.nom) AS nom_user,
    u.photo AS avatar_user,
    a.categorie, a.titre
   FROM commentaires c
   JOIN annonces a ON a.id = c.annonce_id
   JOIN users u ON u.id = c.user_id
   WHERE a.user_id = ?
     AND c.type = 'avis'
     AND a.type_publication = 'offre'
   ORDER BY c.created_at DESC
   LIMIT 20`,
  [userId]
)

    res.json({
      success: true,
      note_globale: globalStats[0]?.note_globale ?? null,
      nb_avis_total: Number(globalStats[0]?.nb_avis_total ?? 0),
      par_categorie: parCategorie,
      avis_recents: avisRecents,
    })
  } catch (error) {
    res.status(500).json({ success: false, message: error.message })
  }
}