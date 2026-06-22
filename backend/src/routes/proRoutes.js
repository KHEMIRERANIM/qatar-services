const express = require('express');
const router = express.Router();
const proController = require('../controllers/proController');
const authMiddleware = require('../middlewares/authMiddleware');

// Protected routes (require JWT token)
router.post('/upload-documents', authMiddleware, proController.uploadDocuments);
router.post('/verify', authMiddleware, proController.verify);
router.get('/status', authMiddleware, proController.getStatus);
router.post('/complete-native-veriff', authMiddleware, proController.completeNativeVeriff);

// Admin routes (require X-Admin-Secret header)
router.get('/admin/pending', proController.adminListPending);
router.post('/admin/approve/:userId', proController.adminApprove);
router.post('/admin/reject/:userId', proController.adminReject);

// Public mock veriff page for Webview simulation
router.get('/mock-veriff', proController.renderMockVeriff);

module.exports = router;
