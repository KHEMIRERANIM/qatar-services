const jwt = require('jsonwebtoken')
const db = require('../config/database')

module.exports = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1]

    if (!token) {
      return res.status(401).json({
        message: 'Token manquant'
      })
    }

    // Vérifier si token révoqué
    const [tokens] = await db.query(
      'SELECT * FROM tokens WHERE token = ? AND revoque = FALSE',
      [token]
    )

    if (tokens.length === 0) {
      return res.status(401).json({
        message: 'Token invalide ou révoqué'
      })
    }

    // Vérifier token JWT
    const decoded = jwt.verify(token, process.env.JWT_SECRET)
    req.user = decoded

    next()

  } catch (error) {
    res.status(401).json({
      message: 'Token invalide'
    })
  }
}