const express = require('express')
const router = express.Router()
const authController = require('../controllers/authController')
const authMiddleware = require('../middlewares/authMiddleware')

// Routes publiques
router.post('/register', authController.register)
router.post('/login', authController.login)
router.post('/refresh', authController.refreshToken)
router.post('/forgot-password', authController.forgotPassword)
router.post('/social-login', authController.socialLogin)
router.post('/sync-password', authController.syncPassword)
router.post('/reset-password', authController.resetPassword)
router.post('/check-phone', authController.checkPhone)
router.post('/login-phone', authController.loginPhone)

// Routes protégées
router.get('/users/:id/public', authMiddleware, authController.getPublicProfile)
router.get('/profile', authMiddleware, authController.profile)
router.get('/profile/avis', authMiddleware, authController.getMyAvisStats)
router.put('/profile/update', authMiddleware, authController.updateProfile)
router.post('/profile/photo', authMiddleware, authController.updateProfilePhoto)
router.post('/verify-email', authMiddleware, authController.verifyEmail)
router.post('/logout', authMiddleware, authController.logout)

module.exports = router