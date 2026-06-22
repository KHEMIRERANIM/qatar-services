const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

let firebaseInitialized = false;

try {
  let serviceAccount = null;

  // 1. Tenter de charger le JSON de compte de service depuis l'environnement
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  } else {
    // 2. Tenter de charger depuis un fichier local (ex: firebase-service-account.json)
    const filePath = path.join(__dirname, '../../firebase-service-account.json');
    if (fs.existsSync(filePath)) {
      serviceAccount = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    }
  }

  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    firebaseInitialized = true;
    console.log('✅ Firebase Admin initialisé avec succès.');
  } else {
    console.warn('⚠️ Aucun compte de service Firebase trouvé (FIREBASE_SERVICE_ACCOUNT_JSON ou firebase-service-account.json absent). Mode simulation activé pour les notifications.');
  }
} catch (error) {
  console.error('❌ Erreur lors de l\'initialisation de Firebase Admin:', error.message);
  console.warn('⚠️ Mode simulation activé pour les notifications push.');
}

/**
 * Envoie une notification push FCM à un token spécifique.
 * 
 * @param {string} token - Le jeton FCM de destination.
 * @param {string} title - Le titre de la notification.
 * @param {string} body - Le corps du message.
 * @param {object} [data] - Métadonnées associées à la notification (facultatif).
 */
async function sendPushNotification(token, title, body, data = {}) {
  if (!token) {
    console.warn('⚠️ Impossible d\'envoyer la notification : Aucun token FCM fourni.');
    return;
  }

  if (firebaseInitialized) {
    try {
      const message = {
        token: token,
        notification: {
          title: title,
          body: body
        },
        data: data
      };
      const response = await admin.messaging().send(message);
      console.log(`✉️ Notification envoyée avec succès (Message ID: ${response})`);
      return response;
    } catch (err) {
      console.error('❌ Erreur lors de l\'envoi de la notification FCM:', err.message);
      // Fallback log
      console.log(`[Push Notification (FAIL FALLBACK)] Destinataire: ${token} | Titre: "${title}" | Message: "${body}" | Données:`, data);
    }
  } else {
    // Mode Simulation (mock)
    console.log(`[SIMULATION NOTIFICATION PUSH]`);
    console.log(`  Pour FCM Token: ${token}`);
    console.log(`  Titre         : ${title}`);
    console.log(`  Corps         : ${body}`);
    console.log(`  Données       :`, data);
  }
}

module.exports = {
  sendPushNotification
};
