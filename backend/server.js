const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const fileUpload = require('express-fileupload');
const db = require('./src/config/database');
//const { runMigrations } = require('./src/config/migrate');
const cron = require('node-cron');

dotenv.config();

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());
app.use(fileUpload());

app.get('/', (req, res) => {
  res.json({ message: 'API Qatar Services fonctionne !' });
});

// Importation des routes
const authRoutes = require('./src/routes/authRoutes');
const proRoutes = require('./src/routes/proRoutes');
const proController = require('./src/controllers/proController');
const annoncesRoutes = require('./src/routes/annonces');
const { sendPushNotification } = require('./src/services/notificationService');

// Utilisation des routes
app.use('/auth', authRoutes);
app.use('/pro', proRoutes);
app.use('/api/annonces', annoncesRoutes);
app.post('/veriff-callback', proController.veriffCallback);

// Fonction pour expirer les annonces de plus de 30 jours et envoyer une notification push
async function checkExpiredAnnonces(db) {
  try {
    const [expiredListings] = await db.query(
      `SELECT a.id, a.titre, a.user_id, u.fcm_token 
       FROM annonces a
       JOIN users u ON a.user_id = u.id
       WHERE a.statut = 'active' 
       AND a.created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)`
    );

    if (expiredListings.length > 0) {
      console.log(`🔍 Tâche d'expiration : ${expiredListings.length} annonces à traiter.`);
      for (const annonce of expiredListings) {
        await db.query("UPDATE annonces SET statut = 'expiree' WHERE id = ?", [annonce.id]);
        console.log(`🚫 Annonce "${annonce.titre}" (ID: ${annonce.id}) expirée.`);

        if (annonce.fcm_token) {
          sendPushNotification(
            annonce.fcm_token,
            'Votre annonce a expiré ⏰',
            `Votre annonce "${annonce.titre}" a dépassé la limite de 30 jours et a été archivée.`,
            {
              type: 'annonce_expirée',
              annonceId: String(annonce.id)
            }
          );
        }
      }
    }
  } catch (err) {
    console.error('❌ Erreur lors de la vérification des annonces expirées:', err.message);
  }
}

// Initialisation de la base de données et tâche de nettoyage
async function initDatabase() {
  try {
   // await runMigrations(db);

    // 1. Assurer que l'index sur la colonne token existe
    try {
      await db.query('CREATE INDEX idx_token ON tokens (token)');
      console.log('✅ Index idx_token créé avec succès');
    } catch (_) {
      // L'index existe déjà, pas d'action requise
    }

    // 2. Colonne type sur commentaires (commentaires privés)
    try {
      await db.query(`ALTER TABLE commentaires ADD COLUMN type VARCHAR(20) DEFAULT 'commentaire'`);
      console.log('✅ Colonne commentaires.type ajoutée');
    } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }

    // 3. Lancement du job quotidien de nettoyage des tokens expirés (chaque 24h)
    setInterval(async () => {
      try {
        const [result] = await db.query('DELETE FROM tokens WHERE expire_le < NOW()');
        console.log(`🧹 Nettoyage automatique : ${result.affectedRows} tokens expirés supprimés`);
      } catch (err) {
        console.error('❌ Erreur lors du nettoyage automatique des tokens:', err.message);
      }
    }, 24 * 60 * 60 * 1000);

    // 4. Lancement du job horaire d'expiration des annonces (chaque 1h)
    setInterval(() => {
      checkExpiredAnnonces(db);
    }, 60 * 60 * 1000);

    // 5. Lancement du job mensuel de recalculation des Top Prestataires (chaque 30 jours)
  cron.schedule('0 0 1 * *', async () => {
    try {
      await proController.recalculateTopPrestataires();
    } catch (err) {
      console.error('❌ Erreur lors de la recalculation mensuelle des Top Prestataires:', err.message);
    }
  });

    // Exécuter un nettoyage initial au démarrage
    const [result] = await db.query('DELETE FROM tokens WHERE expire_le < NOW()');
    if (result.affectedRows > 0) {
      console.log(`🧹 Nettoyage initial : ${result.affectedRows} tokens expirés supprimés`);
    }

    // Exécuter la vérification initiale des annonces expirées au démarrage
    await checkExpiredAnnonces(db);

    // Exécuter le calcul initial des Top Prestataires au démarrage
    await proController.recalculateTopPrestataires();

  } catch (error) {
    console.error('❌ Erreur initialisation database:', error.message);
  }
}

app.listen(PORT, () => {
  console.log(`✅ Serveur démarré sur http://localhost:${PORT}`);
  initDatabase();
});