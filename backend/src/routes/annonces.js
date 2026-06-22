const express = require('express');
const router = express.Router();
const annoncesController = require('../controllers/annoncesController');
const authMiddleware = require('../middlewares/authMiddleware');
const optionalAuthMiddleware = require('../middlewares/optionalAuthMiddleware');

// Route publique - Feed paginé (authentification optionnelle pour filtrage "mes offres" / "offres des autres")
router.get('/', optionalAuthMiddleware, annoncesController.getFeed);

// TEMPORARY: Alter db endpoint
router.get('/alter-db', async (req, res) => {
  const db = require('../config/database');
  try {
    try {
      await db.query(`ALTER TABLE commentaires ADD COLUMN type VARCHAR(20) DEFAULT 'commentaire'`);
    } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    try {
      await db.query(`ALTER TABLE annonces ADD COLUMN type_paiement VARCHAR(100) DEFAULT 'Espèces'`);
    } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
    res.json({ success: true, message: 'Tables altered successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Route publique avec authentification facultative (pour is_owner et likes)
router.get('/:id', optionalAuthMiddleware, annoncesController.getDetail);

// Routes protégées - Création, modification et suppression de l'annonce
router.post('/', authMiddleware, annoncesController.createAnnonce);
router.put('/:id', authMiddleware, annoncesController.updateAnnonce);
router.delete('/:id', authMiddleware, annoncesController.deleteAnnonce);

// Upload photo Cloudinary
router.post('/:id/photos', authMiddleware, annoncesController.uploadPhoto);

// Actions (Likes et Commentaires)
router.post('/:id/like', authMiddleware, annoncesController.toggleLike);
router.post('/:id/commentaires', authMiddleware, annoncesController.addCommentaire);
router.delete('/:id/commentaires/:cid', authMiddleware, annoncesController.deleteCommentaire);

// Ouvrir chat privé (Stub pour plus tard)
router.post('/:id/commentaires/:cid/contacter', authMiddleware, annoncesController.contacterCommentateur);

module.exports = router;
