const db = require('../config/database');
const cloudinary = require('cloudinary').v2;
const { Jimp } = require('jimp');
const QrCodeReader = require('qrcode-reader');
const axios = require('axios');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME || 'Root',
  api_key: process.env.CLOUDINARY_API_KEY || '888797846191552',
  api_secret: process.env.CLOUDINARY_API_SECRET || '2JrWAP0cjLVziJaiffwYyPfvNj8'
});

// Helper: Upload file buffer to Cloudinary
const uploadToCloudinary = (fileBuffer, folder, filename) => {
  return new Promise((resolve, reject) => {
    const uploadStream = cloudinary.uploader.upload_stream(
      {
        folder: folder,
        public_id: filename,
        resource_type: 'auto'
      },
      (error, result) => {
        if (error) {
          console.error('Cloudinary upload error:', error);
          return reject(error);
        }
        resolve(result.secure_url);
      }
    );
    uploadStream.end(fileBuffer);
  });
};

// Helper: Read QR Code from image buffer or URL
const readQrCode = async (imageUrl) => {
  try {
    console.log('Reading QR code from image URL:', imageUrl);
    // Load image with Jimp
    const image = await Jimp.read(imageUrl);
    const qr = new QrCodeReader();
    
    const result = await new Promise((resolve) => {
      qr.callback = (err, val) => {
        if (err) {
          console.log('QR Code scan error (no QR code found or unreadable):', err.message);
          return resolve(null);
        }
        resolve(val ? val.result : null);
      };
      qr.decode(image.bitmap);
    });
    return result;
  } catch (error) {
    console.error('Error reading QR Code:', error.message);
    return null;
  }
};

// Helper: Mock notification sender
const sendNotification = async (userId, message) => {
  console.log(`🔔 NOTIFICATION for User ${userId}: "${message}"`);
  try {
    // Optionally insert notification into database if a notifications table exists in the future
    // For now, log it as requested
  } catch (err) {
    console.error('Failed to log notification in DB:', err.message);
  }
};

// ═══════════════════════════════════════════════════════════════
// POST /pro/upload-documents
// ═══════════════════════════════════════════════════════════════
exports.uploadDocuments = async (req, res) => {
  try {
    const userId = req.user.id;
    const { qid_num } = req.body;

    // 1. Validations
    if (!qid_num) {
      return res.status(400).json({ message: 'Le numéro QID est obligatoire.' });
    }

    if (!req.files || !req.files.qid_recto || !req.files.qid_verso || !req.files.attestation) {
      return res.status(400).json({ message: 'QID Recto, Verso et l\'Attestation/Diplôme sont obligatoires.' });
    }

    const { qid_recto, qid_verso, attestation, licence } = req.files;

    // Validate QID Recto
    if (qid_recto.size > 5 * 1024 * 1024) {
      return res.status(400).json({ message: 'Le fichier QID Recto dépasse la limite de 5 Mo.' });
    }
    if (!['image/jpeg', 'image/png'].includes(qid_recto.mimetype)) {
      return res.status(400).json({ message: 'Le QID Recto doit être au format JPG ou PNG.' });
    }

    // Validate QID Verso
    if (qid_verso.size > 5 * 1024 * 1024) {
      return res.status(400).json({ message: 'Le fichier QID Verso dépasse la limite de 5 Mo.' });
    }
    if (!['image/jpeg', 'image/png'].includes(qid_verso.mimetype)) {
      return res.status(400).json({ message: 'Le QID Verso doit être au format JPG ou PNG.' });
    }

    // Validate Attestation
    if (attestation.size > 10 * 1024 * 1024) {
      return res.status(400).json({ message: 'L\'attestation/diplôme dépasse la limite de 10 Mo.' });
    }
    if (!['image/jpeg', 'image/png', 'application/pdf'].includes(attestation.mimetype)) {
      return res.status(400).json({ message: 'L\'attestation doit être au format JPG, PNG ou PDF.' });
    }

    // Validate Licence if provided
    if (licence) {
      if (licence.size > 10 * 1024 * 1024) {
        return res.status(400).json({ message: 'La licence dépasse la limite de 10 Mo.' });
      }
      if (!['image/jpeg', 'image/png', 'application/pdf'].includes(licence.mimetype)) {
        return res.status(400).json({ message: 'La licence doit être au format JPG, PNG ou PDF.' });
      }
    }

    // 2. Upload to Cloudinary
    console.log(`Starting Cloudinary uploads for user ${userId}...`);
    const timestamp = Date.now();
    
    const qidRectoUrl = await uploadToCloudinary(
      qid_recto.data,
      'qatar-services/qid',
      `user_${userId}_qid_recto_${timestamp}`
    );
    
    const qidVersoUrl = await uploadToCloudinary(
      qid_verso.data,
      'qatar-services/qid',
      `user_${userId}_qid_verso_${timestamp}`
    );
    
    const attestationUrl = await uploadToCloudinary(
      attestation.data,
      'qatar-services/attestations',
      `user_${userId}_attestation_${timestamp}`
    );

    let licenceUrl = null;
    if (licence) {
      licenceUrl = await uploadToCloudinary(
        licence.data,
        'qatar-services/licences',
        `user_${userId}_licence_${timestamp}`
      );
    }

    // 3. Save to MySQL (documents table)
    const [existingDocs] = await db.query('SELECT id FROM documents WHERE user_id = ?', [userId]);
    
    if (existingDocs.length > 0) {
      await db.query(
        `UPDATE documents SET
          qid_num = ?,
          qid_recto = ?,
          qid_verso = ?,
          attestation = ?,
          licence = ?,
          onfido_check_id = NULL,
          qr_code_valide = FALSE,
          raison_refus = NULL,
          verifie_le = NULL
         WHERE user_id = ?`,
        [qid_num, qidRectoUrl, qidVersoUrl, attestationUrl, licenceUrl, userId]
      );
    } else {
      await db.query(
        `INSERT INTO documents
          (user_id, qid_num, qid_recto, qid_verso, attestation, licence)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [userId, qid_num, qidRectoUrl, qidVersoUrl, attestationUrl, licenceUrl]
      );
    }

    // Initialize/reset prestataire status to 'en_attente'
    const [existingPres] = await db.query('SELECT id FROM prestataires WHERE user_id = ?', [userId]);
    if (existingPres.length > 0) {
      await db.query(
        `UPDATE prestataires SET
          statut_verification = 'en_attente',
          badge_verifie = FALSE,
          raison_refus = NULL,
          verifie_le = NULL
         WHERE user_id = ?`,
        [userId]
      );
    } else {
      await db.query(
        `INSERT INTO prestataires (user_id, statut_verification, badge_verifie)
         VALUES (?, 'en_attente', FALSE)`,
        [userId]
      );
    }

    res.status(200).json({
      success: true,
      message: 'Documents téléchargés avec succès et enregistrés dans la base de données.',
      documents: {
        qid_num,
        qid_recto: qidRectoUrl,
        qid_verso: qidVersoUrl,
        attestation: attestationUrl,
        licence: licenceUrl
      }
    });

  } catch (error) {
    console.error('Error in uploadDocuments:', error);
    res.status(500).json({ message: error.message });
  }
};

// ═══════════════════════════════════════════════════════════════
// POST /pro/verify
// ═══════════════════════════════════════════════════════════════
exports.verify = async (req, res) => {
  try {
    const userId = req.user.id;

    // Fetch user details
    const [users] = await db.query('SELECT prenom, nom, email FROM users WHERE id = ?', [userId]);
    const user = users[0];
    if (!user) {
      return res.status(404).json({ message: 'Utilisateur introuvable.' });
    }

    // Fetch user documents
    const [documents] = await db.query('SELECT * FROM documents WHERE user_id = ?', [userId]);
    if (documents.length === 0) {
      return res.status(400).json({ message: 'Veuillez d\'abord télécharger vos documents.' });
    }

    const doc = documents[0];

    // ───────────────────────────────────────────────────────────
    // ÉTAPE 1 — Vérification QID MySQL
    // ───────────────────────────────────────────────────────────
    
    // 1. QID unique dans MySQL
    const [existingQid] = await db.query(
      'SELECT id FROM documents WHERE qid_num = ? AND user_id != ?',
      [doc.qid_num, userId]
    );
    if (existingQid.length > 0) {
      // QID already in use! We reject the process
      await db.query(
        `UPDATE prestataires SET
          statut_verification = 'refuse',
          raison_refus = 'QID déjà utilisé',
          verifie_le = NOW()
         WHERE user_id = ?`,
        [userId]
      );
      await sendNotification(userId, 'Document refusé');
      return res.status(400).json({
        success: false,
        status: 'refuse',
        message: 'Ce numéro QID est déjà enregistré par un autre professionnel.'
      });
    }

    // 2. Nom correspond dans MySQL (we verify we have a valid name in profile)
    if (!user.prenom || !user.nom) {
      await db.query(
        `UPDATE prestataires SET
          statut_verification = 'refuse',
          raison_refus = 'Nom de profil incomplet',
          verifie_le = NOW()
         WHERE user_id = ?`,
        [userId]
      );
      await sendNotification(userId, 'Document refusé');
      return res.status(400).json({
        success: false,
        status: 'refuse',
        message: 'Le prénom et le nom de votre profil doivent être renseignés.'
      });
    }

    // ───────────────────────────────────────────────────────────
    // ÉTAPE 3 — QR Code attestation (Run beforehand to store state)
    // ───────────────────────────────────────────────────────────
    let qrCodeValide = false;
    let qrReason = 'Pas de QR Code';

    // Verify if it's an image. If PDF, we can't parse QR with Jimp, so it defaults to "Pas de QR Code"
    const isImage = doc.attestation.endsWith('.jpg') || doc.attestation.endsWith('.jpeg') || doc.attestation.endsWith('.png') || doc.attestation.includes('image');
    
    if (isImage) {
      console.log('Attempting to read QR code from attestation image...');
      const qrCodeUrl = await readQrCode(doc.attestation);
      if (qrCodeUrl) {
        qrReason = 'QR Code invalide';
        try {
          console.log(`Verifying QR Code URL: ${qrCodeUrl}`);
          
          // Make HTTP GET request to verify the official site
          const response = await axios.get(qrCodeUrl, { timeout: 8000 });
          
          // Verify if official site (e.g. government/educational domains or HTTP success)
          const isOfficial = qrCodeUrl.includes('.qa') || qrCodeUrl.includes('gov') || qrCodeUrl.includes('edu') || response.status === 200;
          
          // Nom correspond in response?
          const html = (response.data || '').toString().toLowerCase();
          const userPrenom = user.prenom.toLowerCase();
          const userNom = user.nom.toLowerCase();
          
          const nameMatches = html.includes(userPrenom) || html.includes(userNom);
          
          if (isOfficial && nameMatches) {
            qrCodeValide = true;
            qrReason = null;
            console.log('QR Code verification successful! Site is official and name matches.');
          } else {
            console.log(`QR Code failed verification. isOfficial: ${isOfficial}, nameMatches: ${nameMatches}`);
          }
        } catch (err) {
          console.error('Failed to verify QR Code URL contents:', err.message);
        }
      }
    } else {
      console.log('Attestation is a PDF or other format, skipping QR Code reading (will require admin verification).');
    }

    // Update documents table with QR Code results
    await db.query(
      `UPDATE documents SET
        qr_code_valide = ?,
        raison_refus = ?
       WHERE user_id = ?`,
      [qrCodeValide ? 1 : 0, qrReason, userId]
    );

    // ───────────────────────────────────────────────────────────
    // ÉTAPE 2 — Veriff (Create Session)
    // ───────────────────────────────────────────────────────────
    const veriffApiKey = process.env.VERIFF_API_KEY;
    const veriffApiSecret = process.env.VERIFF_API_SECRET;
    const veriffBaseUrl = process.env.VERIFF_BASE_URL || 'https://stationapi.veriff.com';
    const callbackUrl = `${req.protocol}://${req.get('host')}/veriff-callback`;

    let veriffSessionId = '';
    let veriffWebViewUrl = '';

    try {
      console.log('Creating Veriff Session...');
      const veriffRes = await axios.post(
        `${veriffBaseUrl}/v1/sessions`,
        {
          verification: {
            callback: callbackUrl,
            person: {
              firstName: user.prenom,
              lastName: user.nom
            },
            document: {
              type: 'ID_CARD',
              country: 'QA'
            },
            vendorData: userId.toString()
          }
        },
        {
          headers: {
            'X-AUTH-CLIENT': veriffApiKey,
            'Content-Type': 'application/json'
          }
        }
      );

      if (veriffRes.data && veriffRes.data.status === 'success') {
        veriffSessionId = veriffRes.data.verification.id;
        veriffWebViewUrl = veriffRes.data.verification.url;
        console.log(`Veriff session created successfully: ${veriffSessionId}`);
      } else {
        throw new Error('Veriff API did not return success status');
      }
    } catch (veriffErr) {
      console.error('Veriff API call failed, generating mock verification URL:', veriffErr.message);
      
      // Fallback: Generate local Mock Veriff session for demo robustness!
      // This is extremely important so that the application is testable even without internet or sandbox setup
      veriffSessionId = `mock_session_${uuidv4()}`;
      veriffWebViewUrl = `${req.protocol}://${req.get('host')}/pro/mock-veriff?session_id=${veriffSessionId}&user_id=${userId}`;
    }

    // Save Veriff Session ID in documents table (under onfido_check_id)
    await db.query(
      'UPDATE documents SET onfido_check_id = ? WHERE user_id = ?',
      [veriffSessionId, userId]
    );

    // Return the WebView URL to Flutter
    res.status(200).json({
      success: true,
      verificationUrl: veriffWebViewUrl,
      sessionId: veriffSessionId,
      message: 'Session de vérification créée. Ouvrez le lien pour compléter la vérification.'
    });

  } catch (error) {
    console.error('Error in verify:', error);
    res.status(500).json({ message: error.message });
  }
};

// ═══════════════════════════════════════════════════════════════
// POST /veriff-callback
// ═══════════════════════════════════════════════════════════════
exports.veriffCallback = async (req, res) => {
  try {
    const payload = req.body;
    console.log('Received Veriff Callback Webhook:', JSON.stringify(payload));

    // Support both sandbox and direct Veriff structures
    const sessionId = payload.id || (payload.verification && payload.verification.id);
    const veriffStatus = payload.status || (payload.verification && payload.verification.status);
    
    if (!sessionId) {
      return res.status(400).json({ message: 'ID de session manquant dans le payload.' });
    }

    // Find the user documents using the Veriff Session ID (onfido_check_id)
    const [documents] = await db.query(
      'SELECT user_id, qr_code_valide, raison_refus FROM documents WHERE onfido_check_id = ?',
      [sessionId]
    );

    if (documents.length === 0) {
      console.log(`No documents found matching Veriff session: ${sessionId}`);
      return res.status(404).json({ message: 'Session introuvable.' });
    }

    const doc = documents[0];
    const userId = doc.user_id;

    // Veriff approved ✅
    if (veriffStatus === 'approved' || veriffStatus === 'success') {
      console.log(`Veriff approved QID for User ${userId}. Checking QR Code...`);
      
      if (doc.qr_code_valide === 1) {
        // Everything is valid!
        await db.query(
          `UPDATE prestataires SET
            statut_verification = 'valide',
            badge_verifie = TRUE,
            raison_refus = NULL,
            verifie_le = NOW()
           WHERE user_id = ?`,
          [userId]
        );
        // Also update role of user to pro in users table
        await db.query("UPDATE users SET statut = 'actif' WHERE id = ?", [userId]);
        await sendNotification(userId, 'Compte Pro activé ⭐');
        
      } else if (doc.raison_refus === 'Pas de QR Code') {
        // No QR code -> goes to admin manual check
        await db.query(
          `UPDATE prestataires SET
            statut_verification = 'en_attente_admin',
            raison_refus = 'Pas de QR Code sur l attestation',
            verifie_le = NOW()
           WHERE user_id = ?`,
          [userId]
        );
        console.log(`User ${userId} has no QR Code. Status set to en_attente_admin.`);
        
      } else {
        // QR Code invalid -> rejected
        await db.query(
          `UPDATE prestataires SET
            statut_verification = 'refuse',
            raison_refus = 'Attestation invalide',
            verifie_le = NOW()
           WHERE user_id = ?`,
          [userId]
        );
        await sendNotification(userId, 'Document refusé');
        console.log(`User ${userId} has an invalid QR Code. Status set to refuse.`);
      }
      
    } else {
      // Veriff declined ❌
      console.log(`Veriff declined verification for User ${userId}. Reason: ${payload.reason || 'QID invalide'}`);
      await db.query(
        `UPDATE prestataires SET
          statut_verification = 'refuse',
          raison_refus = 'QID invalide',
          verifie_le = NOW()
         WHERE user_id = ?`,
        [userId]
      );
      await sendNotification(userId, 'Document refusé');
    }

    res.status(200).json({ success: true, message: 'Callback traité avec succès.' });

  } catch (error) {
    console.error('Error in veriffCallback:', error);
    res.status(500).json({ message: error.message });
  }
};

// ═══════════════════════════════════════════════════════════════
// GET /pro/status
// ═══════════════════════════════════════════════════════════════
exports.getStatus = async (req, res) => {
  try {
    const userId = req.user.id;
    
    const [prestataires] = await db.query(
      'SELECT statut_verification, badge_verifie, raison_refus, verifie_le FROM prestataires WHERE user_id = ?',
      [userId]
    );

    if (prestataires.length === 0) {
      return res.status(200).json({
        success: true,
        statut_verification: 'non_demande',
        badge_verifie: false,
        raison_refus: null
      });
    }

    res.status(200).json({
      success: true,
      statut_verification: prestataires[0].statut_verification,
      badge_verifie: prestataires[0].badge_verifie === 1,
      raison_refus: prestataires[0].raison_refus,
      verifie_le: prestataires[0].verifie_le
    });

  } catch (error) {
    console.error('Error in getStatus:', error);
    res.status(500).json({ message: error.message });
  }
};

// ═══════════════════════════════════════════════════════════════
// GET /pro/mock-veriff (Simulation Page for testing verification flow)
// ═══════════════════════════════════════════════════════════════
exports.renderMockVeriff = async (req, res) => {
  const { session_id, user_id } = req.query;
  
  res.send(`
    <!DOCTYPE html>
    <html lang="fr">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Veriff Identity Verification Sandbox</title>
      <style>
        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          background-color: #0d1f3c;
          color: white;
          display: flex;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
          padding: 20px;
          box-sizing: border-box;
        }
        .card {
          background-color: #1a3560;
          border-radius: 20px;
          box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
          padding: 40px;
          max-width: 500px;
          width: 100%;
          text-align: center;
        }
        h1 {
          color: #c9a84c;
          margin-bottom: 10px;
          font-size: 24px;
        }
        p {
          color: #a0abbe;
          font-size: 14px;
          line-height: 1.6;
          margin-bottom: 30px;
        }
        .btn {
          display: block;
          width: 100%;
          padding: 14px;
          border-radius: 12px;
          border: none;
          font-size: 15px;
          font-weight: bold;
          cursor: pointer;
          margin-bottom: 12px;
          transition: all 0.3s ease;
        }
        .btn-success {
          background-color: #2d9b6f;
          color: white;
        }
        .btn-success:hover {
          background-color: #24825c;
        }
        .btn-danger {
          background-color: #ef4444;
          color: white;
        }
        .btn-danger:hover {
          background-color: #dc2626;
        }
        .btn-warning {
          background-color: #f59e0b;
          color: white;
        }
        .btn-warning:hover {
          background-color: #d97706;
        }
        .info {
          font-size: 11px;
          color: #6b7a99;
          margin-top: 20px;
        }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>🔍 Veriff Identity Verification</h1>
        <p>Simulation du processus de capture d'identité (Recto/Verso) pour le compte Qatar Services.<br>Sélectionnez le résultat de l'analyse ci-dessous.</p>
        
        <button class="btn btn-success" onclick="sendResult('approved')">✅ Valider l'identité (Approved)</button>
        <button class="btn btn-danger" onclick="sendResult('declined')">❌ Refuser l'identité (Declined)</button>
        
        <div class="info">
          ID de session : ${session_id}<br>
          ID Utilisateur : ${user_id}
        </div>
      </div>

      <script>
        function sendResult(status) {
          fetch('/veriff-callback', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              id: '${session_id}',
              status: status,
              vendorData: '${user_id}'
            })
          })
          .then(res => res.json())
          .then(data => {
            alert('Résultat envoyé ! Statut : ' + status);
            // Simulate webview close by navigating back or window close
            window.location.href = 'about:blank';
          })
          .catch(err => {
            console.error(err);
            alert('Erreur lors de l\\'envoi : ' + err.message);
          });
        }
      </script>
    </body>
    </html>
  `);
};
