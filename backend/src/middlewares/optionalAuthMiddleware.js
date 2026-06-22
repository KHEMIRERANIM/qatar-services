const jwt = require('jsonwebtoken');
const db = require('../config/database');

module.exports = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      // Aucun token fourni : continuer en mode invité
      return next();
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
      return next();
    }

    // Vérifier si le token est révoqué dans la base de données
    const [tokens] = await db.query(
      'SELECT * FROM tokens WHERE token = ? AND revoque = FALSE',
      [token]
    );

    if (tokens.length === 0) {
      // Si un token est fourni mais révoqué ou inexistant, on rejette avec 401
      return res.status(401).json({
        message: 'Token invalide ou révoqué'
      });
    }

    // Vérifier la signature et l'expiration du JWT
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;

    next();
  } catch (error) {
    // Si un token est fourni mais invalide/expiré, on rejette avec 401
    return res.status(401).json({
      message: 'Token invalide ou expiré'
    });
  }
};
