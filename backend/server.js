const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const fileUpload = require('express-fileupload');
const db = require('./src/config/database');
//const { runMigrations } = require('./src/config/migrate');

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

// Utilisation des routes
app.use('/auth', authRoutes);
app.use('/pro', proRoutes);
app.post('/veriff-callback', proController.veriffCallback);

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

    // 2. Lancement du job quotidien de nettoyage des tokens expirés (chaque 24h)
    setInterval(async () => {
      try {
        const [result] = await db.query('DELETE FROM tokens WHERE expire_le < NOW()');
        console.log(`🧹 Nettoyage automatique : ${result.affectedRows} tokens expirés supprimés`);
      } catch (err) {
        console.error('❌ Erreur lors du nettoyage automatique des tokens:', err.message);
      }
    }, 24 * 60 * 60 * 1000);

    // Exécuter un nettoyage initial au démarrage
    const [result] = await db.query('DELETE FROM tokens WHERE expire_le < NOW()');
    if (result.affectedRows > 0) {
      console.log(`🧹 Nettoyage initial : ${result.affectedRows} tokens expirés supprimés`);
    }

  } catch (error) {
    console.error('❌ Erreur initialisation database:', error.message);
  }
}

app.listen(PORT, () => {
  console.log(`✅ Serveur démarré sur http://localhost:${PORT}`);
  initDatabase();
});