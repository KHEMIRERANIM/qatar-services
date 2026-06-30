const db = require('../config/database');
const cloudinary = require('cloudinary').v2;
const { Jimp } = require('jimp');
const QrCodeReader = require('qrcode-reader');
const axios = require('axios');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

const getBackendBaseUrl = (req) =>
  process.env.BACKEND_URL || `${req.protocol}://${req.get('host')}`;

const shouldUseNativeVeriff = (backendBaseUrl) => {
  if (process.env.VERIFF_USE_MOCK === 'true') return true;
  // Veriff exige un callback HTTPS public — en local on utilise la caméra native
  if (!backendBaseUrl.startsWith('https://')) return true;
  return false;
};

const isBrokenTunnelUrl = (url) => {
  if (!url) return false;
  const lower = url.toLowerCase();
  return lower.includes('loca.lt')
    || lower.includes('localtunnel')
    || lower.includes('ngrok-free.app')
    || lower.includes('trycloudflare.com');
};

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

const DOC_LABELS = {
  qid: "Carte d'identité Qatar (QID)",
  attestation: 'Attestation professionnelle'
};

const USER_ERROR = 'Une erreur est survenue. Veuillez réessayer plus tard.';

const parseDocumentsInvalides = (value) => {
  if (!value) return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
};

const serializeDocumentsInvalides = (docs) => JSON.stringify([...new Set(docs)]);

const buildStatusMessage = (statut, documentsInvalides = []) => {
  switch (statut) {
    case 'en_attente':
      return 'Vérification en cours — consultez le détail par document ci-dessous';
    case 'en_attente_admin':
      return 'Votre QID est validé. L\'attestation est en vérification manuelle.';
    case 'valide':
      return 'Félicitations ! Compte professionnel activé !';
    case 'refuse': {
      if (documentsInvalides.length > 0) {
        const labels = documentsInvalides.map((d) => DOC_LABELS[d] || d);
        return `Documents invalides : ${labels.join(', ')}`;
      }
      return 'Documents invalides : veuillez vérifier vos justificatifs';
    }
    default:
      return null;
  }
};

const buildDocumentsStatus = (statut, doc, documentsInvalides = []) => {
  const qidInvalid = documentsInvalides.includes('qid');
  const attInvalid = documentsInvalides.includes('attestation');
  const qidVerified = doc?.qid_verifie === 1;
  const attVerified = doc?.qr_code_valide === 1;

  const make = (statutDoc, label, canReplace) => ({
    statut: statutDoc,
    label,
    can_replace: canReplace
  });

  let qid = make('en_cours', 'En cours de vérification', false);
  let attestation = make('en_cours', 'En cours de vérification', false);

  if (statut === 'valide') {
    qid = make('valide', 'Validé', false);
    attestation = make('valide', 'Validé', false);
  } else if (statut === 'refuse') {
    if (qidInvalid) {
      qid = make('invalide', 'Invalide — veuillez le remplacer', true);
    } else if (qidVerified) {
      qid = make('valide', 'Validé', false);
    } else {
      qid = make('invalide', 'Invalide — veuillez le remplacer', true);
    }

    if (attInvalid) {
      attestation = make('invalide', 'Invalide — veuillez la remplacer', true);
    } else if (attVerified) {
      attestation = make('valide', 'Validée', false);
    } else if (!qidInvalid) {
      attestation = make('invalide', 'Invalide — veuillez la remplacer', true);
    }
  } else if (statut === 'en_attente_admin') {
    qid = qidVerified
      ? make('valide', 'Validé', false)
      : make('en_cours', 'En cours de vérification', false);
    attestation = make(
      'en_attente_admin',
      'Vérification manuelle — vous pouvez soumettre une autre attestation',
      true
    );
  } else if (statut === 'en_attente') {
    qid = qidVerified
      ? make('valide', 'Validé', false)
      : make('en_cours', 'En cours de vérification', false);
    attestation = attVerified
      ? make('valide', 'Validée', false)
      : make('en_cours', 'En cours de vérification', false);
  }

  return { qid, attestation };
};

const mapRejectionToInvalidDocs = (raisonRefus, docRaisonRefus) => {
  const docs = [];
  const qidReasons = ['QID invalide', 'QID déjà utilisé', 'Nom de profil incomplet'];
  if (qidReasons.includes(raisonRefus)) docs.push('qid');
  if (raisonRefus === 'Attestation invalide' || docRaisonRefus === 'QR Code invalide') {
    docs.push('attestation');
  }
  return [...new Set(docs)];
};

const activateProAccount = async (userId) => {
  await db.query(
    `UPDATE prestataires SET
      statut_verification = 'valide',
      badge_verifie = TRUE,
      raison_refus = NULL,
      documents_invalides = NULL,
      verifie_le = NOW()
     WHERE user_id = ?`,
    [userId]
  );
  await db.query("UPDATE users SET statut = 'actif' WHERE id = ?", [userId]);
  await sendNotification(userId, 'Compte Pro activé ⭐');
};

const rejectVerification = async (userId, raisonRefus, documentsInvalides, docRaisonRefus = null) => {
  const invalidDocs = documentsInvalides.length > 0
    ? documentsInvalides
    : mapRejectionToInvalidDocs(raisonRefus, docRaisonRefus);

  await db.query(
    `UPDATE prestataires SET
      statut_verification = 'refuse',
      badge_verifie = FALSE,
      raison_refus = ?,
      documents_invalides = ?,
      verifie_le = NOW()
     WHERE user_id = ?`,
    [raisonRefus, serializeDocumentsInvalides(invalidDocs), userId]
  );

  if (docRaisonRefus) {
    await db.query(
      'UPDATE documents SET raison_refus = ? WHERE user_id = ?',
      [docRaisonRefus, userId]
    );
  }

  await sendNotification(userId, 'Document refusé');
  return invalidDocs;
};

// Helper: Verify attestation QR code from document URL
const verifyAttestationQr = async (attestationUrl, user) => {
  let qrCodeValide = false;
  let qrReason = 'Pas de QR Code';

  const isImage = attestationUrl.endsWith('.jpg') || attestationUrl.endsWith('.jpeg')
    || attestationUrl.endsWith('.png') || attestationUrl.includes('image');

  if (!isImage) {
    console.log('Attestation is a PDF or other format, skipping QR Code reading (will require admin verification).');
    return { qrCodeValide, qrReason };
  }

  console.log('Attempting to read QR code from attestation image...');
  const qrCodeUrl = await readQrCode(attestationUrl);
  if (!qrCodeUrl) {
    return { qrCodeValide, qrReason };
  }

  qrReason = 'QR Code invalide';
  try {
    console.log(`Verifying QR Code URL: ${qrCodeUrl}`);
    const response = await axios.get(qrCodeUrl, { timeout: 8000 });
    const isOfficial = qrCodeUrl.includes('.qa') || qrCodeUrl.includes('gov')
      || qrCodeUrl.includes('edu') || response.status === 200;
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

  return { qrCodeValide, qrReason };
};

const finalizeAttestationAfterQid = async (userId, doc, user) => {
  if (doc.qr_code_valide === 1) {
    await activateProAccount(userId);
    return { status: 'valide', message: buildStatusMessage('valide') };
  }

  if (doc.raison_refus === 'Pas de QR Code') {
    await db.query(
      `UPDATE prestataires SET
        statut_verification = 'en_attente_admin',
        raison_refus = 'Pas de QR Code sur l attestation',
        documents_invalides = NULL,
        verifie_le = NOW()
       WHERE user_id = ?`,
      [userId]
    );
    console.log(`User ${userId} has no QR Code. Status set to en_attente_admin.`);
    return { status: 'en_attente_admin', message: buildStatusMessage('en_attente_admin') };
  }

  await rejectVerification(userId, 'Attestation invalide', ['attestation'], 'QR Code invalide');
  console.log(`User ${userId} has an invalid QR Code. Status set to refuse.`);
  return {
    status: 'refuse',
    message: buildStatusMessage('refuse', ['attestation']),
    documents_invalides: ['attestation']
  };
};

// ═══════════════════════════════════════════════════════════════
// POST /pro/upload-documents
// ═══════════════════════════════════════════════════════════════
exports.uploadDocuments = async (req, res) => {
  try {
    const userId = req.user.id;
    const qid_num = req.body.qid_num || req.body.qid_number;

    const [existingPres] = await db.query(
      'SELECT statut_verification, documents_invalides FROM prestataires WHERE user_id = ?',
      [userId]
    );
    const presStatut = existingPres.length > 0 ? existingPres[0].statut_verification : null;
    const isRefuseResubmit = presStatut === 'refuse';
    const isAttestationCorrection = presStatut === 'en_attente_admin';
    const isResubmit = isRefuseResubmit || isAttestationCorrection;
    const invalidDocs = isRefuseResubmit
      ? parseDocumentsInvalides(existingPres[0].documents_invalides)
      : isAttestationCorrection
        ? ['attestation']
        : [];

    const hasQidRecto = req.files && req.files.qid_recto;
    const hasQidVerso = req.files && req.files.qid_verso;
    const hasAttestation = req.files && req.files.attestation;
    const hasQidUpload = hasQidRecto || hasQidVerso;

    if (isResubmit) {
      if (invalidDocs.length === 0) {
        return res.status(400).json({ message: 'Aucun document à corriger.' });
      }
      if (!hasQidUpload && !hasAttestation) {
        return res.status(400).json({
          message: 'Veuillez corriger uniquement les documents invalides et resoumettre.'
        });
      }
      if (invalidDocs.includes('qid')) {
        if (!qid_num) {
          return res.status(400).json({ message: 'Le numéro QID est obligatoire.' });
        }
        if (!hasQidRecto || !hasQidVerso) {
          return res.status(400).json({ message: 'Veuillez charger le QID Recto et Verso.' });
        }
      }
      if (invalidDocs.includes('attestation') && !hasAttestation) {
        return res.status(400).json({ message: 'Veuillez charger votre attestation professionnelle.' });
      }
      if (invalidDocs.includes('qid') && hasAttestation && !invalidDocs.includes('attestation')) {
        return res.status(400).json({
          message: 'Veuillez corriger uniquement les documents invalides et resoumettre.'
        });
      }
      if (invalidDocs.includes('attestation') && hasQidUpload && !invalidDocs.includes('qid')) {
        return res.status(400).json({
          message: 'Veuillez corriger uniquement les documents invalides et resoumettre.'
        });
      }
    } else {
      if (!qid_num) {
        return res.status(400).json({ message: 'Le numéro QID est obligatoire.' });
      }
      if (!hasQidRecto || !hasQidVerso) {
        return res.status(400).json({ message: 'Veuillez charger le QID Recto et Verso.' });
      }
      if (!hasAttestation) {
        return res.status(400).json({
          message: 'L\'attestation professionnelle est obligatoire.'
        });
      }
    }

    const qid_recto = hasQidRecto ? req.files.qid_recto : null;
    const qid_verso = hasQidVerso ? req.files.qid_verso : null;
    const attestation = hasAttestation ? req.files.attestation : null;

    if (qid_recto) {
      if (qid_recto.size > 5 * 1024 * 1024) {
        return res.status(400).json({ message: 'Le fichier QID Recto dépasse la limite de 5 Mo.' });
      }
if (!['image/jpeg', 'image/png', 'image/jpg'].includes(qid_recto.mimetype)) {        return res.status(400).json({ message: 'Le QID Recto doit être au format JPG ou PNG.' });
      }
    }

    if (qid_verso) {
      if (qid_verso.size > 5 * 1024 * 1024) {
        return res.status(400).json({ message: 'Le fichier QID Verso dépasse la limite de 5 Mo.' });
      }
      if (!['image/jpeg', 'image/png'].includes(qid_verso.mimetype)) {
        return res.status(400).json({ message: 'Le QID Verso doit être au format JPG ou PNG.' });
      }
    }

    if (attestation) {
      if (attestation.size > 10 * 1024 * 1024) {
        return res.status(400).json({ message: 'L\'attestation dépasse la limite de 10 Mo.' });
      }
      if (!['image/jpeg', 'image/png', 'application/pdf'].includes(attestation.mimetype)) {
        return res.status(400).json({ message: 'L\'attestation doit être au format JPG, PNG ou PDF.' });
      }
    }

    console.log(`Starting Cloudinary uploads for user ${userId}...`);
    const timestamp = Date.now();

    const [existingDocs] = await db.query('SELECT * FROM documents WHERE user_id = ?', [userId]);
    const existingDoc = existingDocs[0] || {};

    let qidRectoUrl = existingDoc.qid_recto;
    let qidVersoUrl = existingDoc.qid_verso;
    let attestationUrl = existingDoc.attestation;
    const finalQidNum = qid_num || existingDoc.qid_num;

    if (qid_recto) {
      qidRectoUrl = await uploadToCloudinary(
        qid_recto.data,
        'qatar-services/qid',
        `user_${userId}_qid_recto_${timestamp}`
      );
    }

    if (qid_verso) {
      qidVersoUrl = await uploadToCloudinary(
        qid_verso.data,
        'qatar-services/qid',
        `user_${userId}_qid_verso_${timestamp}`
      );
    }

    if (attestation) {
      attestationUrl = await uploadToCloudinary(
        attestation.data,
        'qatar-services/attestations',
        `user_${userId}_attestation_${timestamp}`
      );
    }

    if (existingDocs.length > 0) {
      const resetQidVerifie = qid_recto || qid_verso ? 0 : existingDoc.qid_verifie;
      await db.query(
        `UPDATE documents SET
          qid_num = ?,
          qid_recto = ?,
          qid_verso = ?,
          attestation = ?,
          onfido_check_id = ?,
          qr_code_valide = ?,
          qid_verifie = ?,
          raison_refus = NULL,
          verifie_le = NULL
         WHERE user_id = ?`,
        [
          finalQidNum,
          qidRectoUrl,
          qidVersoUrl,
          attestationUrl,
          qid_recto || qid_verso ? null : existingDoc.onfido_check_id,
          attestation ? 0 : existingDoc.qr_code_valide,
          resetQidVerifie,
          userId
        ]
      );
    } else {
      await db.query(
        `INSERT INTO documents
          (user_id, qid_num, qid_recto, qid_verso, attestation)
         VALUES (?, ?, ?, ?, ?)`,
        [userId, finalQidNum, qidRectoUrl, qidVersoUrl, attestationUrl]
      );
    }

    if (existingPres.length > 0) {
      await db.query(
        `UPDATE prestataires SET
          statut_verification = 'en_attente',
          badge_verifie = FALSE,
          raison_refus = NULL,
          documents_invalides = NULL,
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
      message: 'Documents téléchargés avec succès.',
      documents: {
        qid_num: finalQidNum,
        qid_recto: qidRectoUrl,
        qid_verso: qidVersoUrl,
        attestation: attestationUrl
      }
    });

  } catch (error) {
    console.error('Error in uploadDocuments:', error);
    res.status(500).json({ message: USER_ERROR });
  }
};

// ═══════════════════════════════════════════════════════════════
// POST /pro/verify
// ═══════════════════════════════════════════════════════════════
exports.verify = async (req, res) => {
  try {
    const userId = req.user.id;

    const [users] = await db.query('SELECT prenom, nom, email FROM users WHERE id = ?', [userId]);
    const user = users[0];
    if (!user) {
      return res.status(404).json({ message: 'Utilisateur introuvable.' });
    }

    const [documents] = await db.query('SELECT * FROM documents WHERE user_id = ?', [userId]);
    if (documents.length === 0) {
      return res.status(400).json({ message: 'Veuillez d\'abord télécharger vos documents.' });
    }

    const doc = documents[0];

    if (!doc.qid_verifie && (!doc.qid_recto || !doc.qid_verso || !doc.qid_num)) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez charger le QID Recto et Verso.'
      });
    }

    if (!doc.attestation) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez charger votre attestation professionnelle.'
      });
    }

    const [existingQid] = await db.query(
      'SELECT id FROM documents WHERE qid_num = ? AND user_id != ?',
      [doc.qid_num, userId]
    );
    if (existingQid.length > 0) {
      const invalidDocs = await rejectVerification(userId, 'QID déjà utilisé', ['qid']);
      return res.status(400).json({
        success: false,
        status: 'refuse',
        message: buildStatusMessage('refuse', invalidDocs),
        documents_invalides: invalidDocs
      });
    }

    if (!user.prenom || !user.nom) {
      const invalidDocs = await rejectVerification(userId, 'Nom de profil incomplet', ['qid']);
      return res.status(400).json({
        success: false,
        status: 'refuse',
        message: buildStatusMessage('refuse', invalidDocs),
        documents_invalides: invalidDocs
      });
    }

    const { qrCodeValide, qrReason } = await verifyAttestationQr(doc.attestation, user);
    await db.query(
      `UPDATE documents SET
        qr_code_valide = ?,
        raison_refus = ?
       WHERE user_id = ?`,
      [qrCodeValide ? 1 : 0, qrReason, userId]
    );

    const updatedDoc = { ...doc, qr_code_valide: qrCodeValide ? 1 : 0, raison_refus: qrReason };

    // QID déjà validé par Veriff → vérifier uniquement l'attestation
    if (doc.qid_verifie === 1) {
      console.log(`User ${userId} QID already verified. Processing attestation only...`);
      const result = await finalizeAttestationAfterQid(userId, updatedDoc, user);

      if (result.status === 'valide') {
        return res.status(200).json({
          success: true,
          status: 'valide',
          message: result.message,
          skipVeriff: true
        });
      }

      if (result.status === 'en_attente_admin') {
        return res.status(200).json({
          success: true,
          status: 'en_attente_admin',
          message: result.message,
          skipVeriff: true
        });
      }

      return res.status(400).json({
        success: false,
        status: 'refuse',
        message: result.message,
        documents_invalides: result.documents_invalides,
        skipVeriff: true
      });
    }

    const veriffApiKey = process.env.VERIFF_API_KEY;
    const veriffBaseUrl = process.env.VERIFF_BASE_URL || 'https://stationapi.veriff.com';
    const backendBaseUrl = getBackendBaseUrl(req);
    const callbackUrl = `${backendBaseUrl}/veriff-callback`;
    let veriffSessionId = '';
    let veriffWebViewUrl = '';
    let useNativeVerification = shouldUseNativeVeriff(backendBaseUrl);

    if (useNativeVerification) {
      veriffSessionId = `mock_session_${uuidv4()}`;
      console.log(`Using native identity verification (session ${veriffSessionId})`);
    } else {
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
          if (isBrokenTunnelUrl(veriffWebViewUrl)) {
            console.warn('Veriff URL points to unavailable tunnel, falling back to native verification');
            useNativeVerification = true;
            veriffSessionId = `mock_session_${uuidv4()}`;
            veriffWebViewUrl = '';
          } else {
            console.log(`Veriff session created successfully: ${veriffSessionId}`);
          }
        } else {
          throw new Error('Veriff API did not return success status');
        }
      } catch (veriffErr) {
        console.error('Veriff API call failed, using native verification:', veriffErr.message);
        useNativeVerification = true;
        veriffSessionId = `mock_session_${uuidv4()}`;
        veriffWebViewUrl = '';
      }
    }

    await db.query(
      'UPDATE documents SET onfido_check_id = ? WHERE user_id = ?',
      [veriffSessionId, userId]
    );

    res.status(200).json({
      success: true,
      verificationUrl: useNativeVerification ? null : veriffWebViewUrl,
      sessionId: veriffSessionId,
      useNativeVerification,
      message: 'Vos documents sont en cours de vérification',
      skipVeriff: false
    });

  } catch (error) {
    console.error('Error in verify:', error);
    res.status(500).json({ message: USER_ERROR });
  }
};

// ═══════════════════════════════════════════════════════════════
// POST /pro/complete-native-veriff — Fin vérification caméra native (dev)
// ═══════════════════════════════════════════════════════════════
exports.completeNativeVeriff = async (req, res) => {
  try {
    const userId = req.user.id;
    const { sessionId, status } = req.body;

    if (!sessionId) {
      return res.status(400).json({ message: 'Session de vérification introuvable.' });
    }

    const [documents] = await db.query(
      'SELECT user_id, qr_code_valide, raison_refus FROM documents WHERE onfido_check_id = ? AND user_id = ?',
      [sessionId, userId]
    );

    if (documents.length === 0) {
      console.error(`Native veriff: session ${sessionId} not found for user ${userId}`);
      return res.status(400).json({ message: 'Session de vérification expirée. Veuillez resoumettre.' });
    }

    const doc = documents[0];
    const veriffStatus = status === 'declined' ? 'declined' : 'approved';

    if (veriffStatus === 'approved') {
      console.log(`Native veriff approved QID for User ${userId}`);
      await db.query('UPDATE documents SET qid_verifie = TRUE WHERE user_id = ?', [userId]);
      const result = await finalizeAttestationAfterQid(userId, doc, { prenom: '', nom: '' });
      return res.status(200).json({
        success: true,
        status: result.status,
        message: result.message || buildStatusMessage(result.status)
      });
    }

    await db.query('UPDATE documents SET qid_verifie = FALSE WHERE user_id = ?', [userId]);
    const invalidDocs = await rejectVerification(userId, 'QID invalide', ['qid']);
    return res.status(200).json({
      success: true,
      status: 'refuse',
      message: buildStatusMessage('refuse', invalidDocs),
      documents_invalides: invalidDocs
    });
  } catch (error) {
    console.error('Error in completeNativeVeriff:', error);
    res.status(500).json({ message: USER_ERROR });
  }
};

// ═══════════════════════════════════════════════════════════════
// POST /veriff-callback
// ═══════════════════════════════════════════════════════════════
exports.veriffCallback = async (req, res) => {
  try {
    const payload = req.body;
    console.log('Received Veriff Callback Webhook:', JSON.stringify(payload));

    const sessionId = payload.id || (payload.verification && payload.verification.id);
    const veriffStatus = payload.status || (payload.verification && payload.verification.status);

    if (!sessionId) {
      return res.status(400).json({ message: 'ID de session manquant dans le payload.' });
    }

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

    if (veriffStatus === 'approved' || veriffStatus === 'success') {
      console.log(`Veriff approved QID for User ${userId}. Checking QR Code...`);

      await db.query(
        'UPDATE documents SET qid_verifie = TRUE WHERE user_id = ?',
        [userId]
      );

      await finalizeAttestationAfterQid(userId, doc, { prenom: '', nom: '' });
    } else {
      console.log(`Veriff declined verification for User ${userId}. Reason: ${payload.reason || 'QID invalide'}`);
      await db.query(
        'UPDATE documents SET qid_verifie = FALSE WHERE user_id = ?',
        [userId]
      );
      await rejectVerification(userId, 'QID invalide', ['qid']);
    }

    res.status(200).json({ success: true, message: 'Callback traité avec succès.' });

  } catch (error) {
    console.error('Error in veriffCallback:', error);
    res.status(500).json({ message: USER_ERROR });
  }
};

// ═══════════════════════════════════════════════════════════════
// GET /pro/status
// ═══════════════════════════════════════════════════════════════
exports.getStatus = async (req, res) => {
  try {
    const userId = req.user.id;

    const [prestataires] = await db.query(
      'SELECT statut_verification, badge_verifie, raison_refus, documents_invalides, verifie_le, badge_top_prestataire, pro_abonnement_actif FROM prestataires WHERE user_id = ?',
      [userId]
    );

    const [documents] = await db.query(
      'SELECT qid_verifie, qr_code_valide, raison_refus FROM documents WHERE user_id = ?',
      [userId]
    );
    const doc = documents[0] || null;

    if (prestataires.length === 0) {
      return res.status(200).json({
        success: true,
        statut_verification: 'non_demande',
        badge_verifie: false,
        raison_refus: null,
        documents_invalides: [],
        documents_status: null,
        message: null,
        verifie: false,
        top_prestataire: {
          obtenu: false,
          note: 0,
          nb_avis: 0,
          progression: 0.0
        },
        pro: false
      });
    }

    const prestataire = prestataires[0];
    const documentsInvalides = parseDocumentsInvalides(prestataire.documents_invalides);
    const statut = prestataire.statut_verification;
    const documentsStatus = buildDocumentsStatus(statut, doc, documentsInvalides);

    const verifie = statut === 'valide';
    const pro = prestataire.pro_abonnement_actif === 1;

    // Calculate top prestataire reviews metrics in the last 3 months
    const [stats] = await db.query(`
      SELECT 
        COALESCE(ROUND(AVG(c.note), 1), 0) AS note,
        COUNT(c.id) AS nb_avis
      FROM commentaires c
      JOIN annonces a ON a.id = c.annonce_id
      WHERE a.user_id = ?
        AND c.type = 'avis'
        AND a.type_publication = 'offre'
        AND c.note IS NOT NULL
        AND c.created_at >= DATE_SUB(NOW(), INTERVAL 3 MONTH)
    `, [userId]);

    const note = stats[0] ? Number(stats[0].note) : 0;
    const nb_avis = stats[0] ? Number(stats[0].nb_avis) : 0;
    const obtenu = prestataire.badge_top_prestataire === 1;
    const progression = obtenu ? 1.0 : Math.max(0.0, Math.min(1.0, Math.min(note / 4.8, nb_avis / 20)));

    res.status(200).json({
      success: true,
      statut_verification: statut,
      badge_verifie: prestataire.badge_verifie === 1,
      raison_refus: prestataire.raison_refus,
      documents_invalides: documentsInvalides,
      documents_status: documentsStatus,
      verifie_le: prestataire.verifie_le,
      message: buildStatusMessage(statut, documentsInvalides),
      resubmit_hint: statut === 'refuse' || documentsStatus.qid.can_replace || documentsStatus.attestation.can_replace
        ? 'Veuillez corriger uniquement les documents invalides et resoumettre.'
        : null,
      verifie: verifie,
      top_prestataire: {
        obtenu: obtenu,
        note: note,
        nb_avis: nb_avis,
        progression: progression
      },
      pro: pro
    });

  } catch (error) {
    console.error('Error in getStatus:', error);
    res.status(500).json({ message: USER_ERROR });
  }
};

// ═══════════════════════════════════════════════════════════════
// POST /pro/admin/approve/:userId — Vérification manuelle admin
// ═══════════════════════════════════════════════════════════════
exports.adminApprove = async (req, res) => {
  try {
    const adminSecret = req.headers['x-admin-secret'];
    if (!process.env.ADMIN_SECRET || adminSecret !== process.env.ADMIN_SECRET) {
      return res.status(403).json({ message: 'Accès refusé.' });
    }

    const userId = req.params.userId;
    const [prestataires] = await db.query(
      'SELECT statut_verification FROM prestataires WHERE user_id = ?',
      [userId]
    );

    if (prestataires.length === 0 || prestataires[0].statut_verification !== 'en_attente_admin') {
      return res.status(400).json({ message: 'Aucune demande en attente de vérification manuelle.' });
    }

    await activateProAccount(userId);
    console.log(`Admin approved manual verification for user ${userId}`);

    res.status(200).json({
      success: true,
      message: 'Compte professionnel activé.',
      statut_verification: 'valide'
    });
  } catch (error) {
    console.error('Error in adminApprove:', error);
    res.status(500).json({ message: USER_ERROR });
  }
};

// ═══════════════════════════════════════════════════════════════
// POST /pro/admin/reject/:userId — Rejet manuel admin
// ═══════════════════════════════════════════════════════════════
exports.adminReject = async (req, res) => {
  try {
    const adminSecret = req.headers['x-admin-secret'];
    if (!process.env.ADMIN_SECRET || adminSecret !== process.env.ADMIN_SECRET) {
      return res.status(403).json({ message: 'Accès refusé.' });
    }

    const userId = req.params.userId;
    const [prestataires] = await db.query(
      'SELECT statut_verification FROM prestataires WHERE user_id = ?',
      [userId]
    );

    if (prestataires.length === 0 || prestataires[0].statut_verification !== 'en_attente_admin') {
      return res.status(400).json({ message: 'Aucune demande en attente de vérification manuelle.' });
    }

    const invalidDocs = await rejectVerification(userId, 'Attestation invalide', ['attestation']);
    console.log(`Admin rejected manual verification for user ${userId}`);

    res.status(200).json({
      success: true,
      message: buildStatusMessage('refuse', invalidDocs),
      statut_verification: 'refuse',
      documents_invalides: invalidDocs
    });
  } catch (error) {
    console.error('Error in adminReject:', error);
    res.status(500).json({ message: USER_ERROR });
  }
};

// ═══════════════════════════════════════════════════════════════
// GET /pro/admin/pending — Liste des dossiers en attente admin
// ═══════════════════════════════════════════════════════════════
exports.adminListPending = async (req, res) => {
  try {
    const adminSecret = req.headers['x-admin-secret'];
    if (!process.env.ADMIN_SECRET || adminSecret !== process.env.ADMIN_SECRET) {
      return res.status(403).json({ message: 'Accès refusé.' });
    }

    const [rows] = await db.query(
      `SELECT p.user_id, u.prenom, u.nom, u.email, d.qid_num, d.attestation,
              p.statut_verification, p.raison_refus, p.verifie_le
       FROM prestataires p
       JOIN users u ON u.id = p.user_id
       JOIN documents d ON d.user_id = p.user_id
       WHERE p.statut_verification = 'en_attente_admin'
       ORDER BY p.verifie_le ASC`
    );

    res.status(200).json({ success: true, pending: rows });
  } catch (error) {
    console.error('Error in adminListPending:', error);
    res.status(500).json({ message: USER_ERROR });
  }
};

// ═══════════════════════════════════════════════════════════════
// GET /pro/mock-veriff (Simulation Page for testing verification flow)
// ═══════════════════════════════════════════════════════════════
exports.renderMockVeriff = async (req, res) => {
  const { session_id, user_id } = req.query;
  const backendBaseUrl = getBackendBaseUrl(req);

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
        #cameraPreview {
          width: 100%;
          max-height: 220px;
          border-radius: 12px;
          margin-bottom: 16px;
          background: #0d1f3c;
          object-fit: cover;
        }
        .camera-hint {
          font-size: 12px;
          color: #c9a84c;
          margin-bottom: 16px;
        }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>🔍 Vérification d'identité</h1>
        <p>Mode simulation — autorisez la caméra pour scanner votre QID, puis validez le résultat.</p>
        <video id="cameraPreview" autoplay playsinline muted></video>
        <p id="cameraStatus" class="camera-hint">Activation de la caméra...</p>
        
        <button class="btn btn-success" onclick="sendResult('approved')">✅ Valider l'identité (Approved)</button>
        <button class="btn btn-danger" onclick="sendResult('declined')">❌ Refuser l'identité (Declined)</button>
        
        <div class="info">
          ID de session : ${session_id}<br>
          ID Utilisateur : ${user_id}
        </div>
      </div>

      <script>
        async function startCamera() {
          const video = document.getElementById('cameraPreview');
          const status = document.getElementById('cameraStatus');
          try {
            const stream = await navigator.mediaDevices.getUserMedia({
              video: { facingMode: { ideal: 'environment' } },
              audio: false
            });
            video.srcObject = stream;
            status.textContent = 'Caméra active — placez votre QID devant l\\'objectif';
          } catch (err) {
            console.error('Camera error:', err);
            status.textContent = 'Caméra indisponible. Autorisez l\\'accès caméra dans les paramètres.';
          }
        }

        startCamera();

        function sendResult(status) {
          fetch('${backendBaseUrl}/veriff-callback', {
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

exports.subscribePro = async (req, res) => {
  try {
    const userId = req.user.id;

    const [prestataires] = await db.query(
      'SELECT statut_verification, pro_abonnement_actif FROM prestataires WHERE user_id = ?',
      [userId]
    );

    if (prestataires.length === 0 || prestataires[0].statut_verification !== 'valide') {
      return res.status(400).json({
        success: false,
        message: "Vous devez être vérifié pour souscrire à l'abonnement Pro."
      });
    }

    if (prestataires[0].pro_abonnement_actif === 1) {
      return res.status(400).json({
        success: false,
        message: "Votre abonnement Pro est déjà actif."
      });
    }

    await db.query(
      'UPDATE prestataires SET pro_abonnement_actif = TRUE WHERE user_id = ?',
      [userId]
    );

    res.status(200).json({
      success: true,
      message: "Félicitations ! Votre abonnement Pro a été activé avec succès."
    });
  } catch (error) {
    console.error('Error in subscribePro:', error);
    res.status(500).json({ message: USER_ERROR });
  }
};

exports.recalculateTopPrestataires = async () => {
  try {
    await db.query(`
      UPDATE prestataires p
      SET p.badge_top_prestataire = IF(
        (
          SELECT COALESCE(ROUND(AVG(c.note), 1), 0)
          FROM commentaires c
          JOIN annonces a ON a.id = c.annonce_id
          WHERE a.user_id = p.user_id
            AND c.type = 'avis'
            AND a.type_publication = 'offre'
            AND c.note IS NOT NULL
            AND c.created_at >= DATE_SUB(NOW(), INTERVAL 3 MONTH)
        ) >= 4.8 AND (
          SELECT COUNT(c.id)
          FROM commentaires c
          JOIN annonces a ON a.id = c.annonce_id
          WHERE a.user_id = p.user_id
            AND c.type = 'avis'
            AND a.type_publication = 'offre'
            AND c.note IS NOT NULL
            AND c.created_at >= DATE_SUB(NOW(), INTERVAL 3 MONTH)
        ) >= 20,
        TRUE,
        FALSE
      )
    `);
    console.log('✅ Recalculation des badges Top Prestataire terminée.');
  } catch (err) {
    console.error('❌ Erreur lors de la recalculation des badges Top Prestataire:', err.message);
  }
};

