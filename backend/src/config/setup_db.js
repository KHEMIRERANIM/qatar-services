const mysql = require('mysql2/promise');
require('dotenv').config();

async function run() {
  console.log('Connecting to MySQL/MariaDB...');
  // Connect without database name first to create it if it doesn't exist
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: ''
  });

  try {
    // 1. Create database
    console.log('Creating database if not exists...');
    await connection.query('CREATE DATABASE IF NOT EXISTS `qatar_services` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
    await connection.query('USE `qatar_services`');
    console.log('Using qatar_services database.');

    // 2. Create users table
    console.log('Creating users table if not exists...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        uuid VARCHAR(255) NOT NULL UNIQUE,
        prenom VARCHAR(255) NOT NULL,
        nom VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL UNIQUE,
        telephone VARCHAR(255) NULL UNIQUE,
        mot_de_passe VARCHAR(255) NOT NULL,
        photo VARCHAR(255) NULL,
        statut VARCHAR(50) DEFAULT 'inactif',
        bloque_jusqua DATETIME NULL,
        tentatives_login INT DEFAULT 0,
        derniere_connexion DATETIME NULL,
        deleted_at DATETIME NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB
    `);

    // 3. Create tokens table
    console.log('Creating tokens table if not exists...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS tokens (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        token TEXT NOT NULL,
        refresh_token TEXT NOT NULL,
        revoque BOOLEAN DEFAULT FALSE,
        expire_le DATETIME NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB
    `);

    // 4. Create reset_password table
    console.log('Creating reset_password table if not exists...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS reset_password (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        token VARCHAR(255) NOT NULL,
        utilise BOOLEAN DEFAULT FALSE,
        expire_le DATETIME NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB
    `);

    // 5. Create documents table
    console.log('Creating documents table if not exists...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS documents (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        qid_num VARCHAR(50) NOT NULL,
        qid_recto VARCHAR(255) NOT NULL,
        qid_verso VARCHAR(255) NOT NULL,
        attestation VARCHAR(255) NOT NULL,
        licence VARCHAR(255) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB
    `);

    // 6. Create prestataires table
    console.log('Creating prestataires table if not exists...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS prestataires (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB
    `);

    // 7. Check and ALTER documents table
    console.log('Checking and altering documents table columns...');
    const [docColumns] = await connection.query('DESCRIBE documents');
    const docFields = docColumns.map(c => c.Field);

    const docAlterations = [
      { name: 'onfido_check_id', sql: 'ALTER TABLE documents ADD COLUMN onfido_check_id VARCHAR(255) NULL' },
      { name: 'qr_code_valide', sql: 'ALTER TABLE documents ADD COLUMN qr_code_valide BOOLEAN DEFAULT FALSE' },
      { name: 'qid_verifie', sql: 'ALTER TABLE documents ADD COLUMN qid_verifie BOOLEAN DEFAULT FALSE' },
      { name: 'date_expiration', sql: 'ALTER TABLE documents ADD COLUMN date_expiration DATE NULL' },
      { name: 'raison_refus', sql: 'ALTER TABLE documents ADD COLUMN raison_refus TEXT NULL' },
      { name: 'verifie_le', sql: 'ALTER TABLE documents ADD COLUMN verifie_le DATETIME NULL' }
    ];

    for (let alt of docAlterations) {
      if (!docFields.includes(alt.name)) {
        console.log(`Adding column ${alt.name} to documents...`);
        await connection.query(alt.sql);
      }
    }

    // 8. Check and ALTER prestataires table
    console.log('Checking and altering prestataires table columns...');
    const [presColumns] = await connection.query('DESCRIBE prestataires');
    const presFields = presColumns.map(c => c.Field);

    const presAlterations = [
      { name: 'statut_verification', sql: "ALTER TABLE prestataires ADD COLUMN statut_verification ENUM('en_attente','valide','refuse','en_attente_admin') DEFAULT 'en_attente'" },
      { name: 'badge_verifie', sql: 'ALTER TABLE prestataires ADD COLUMN badge_verifie BOOLEAN DEFAULT FALSE' },
      { name: 'raison_refus', sql: 'ALTER TABLE prestataires ADD COLUMN raison_refus TEXT NULL' },
      { name: 'documents_invalides', sql: 'ALTER TABLE prestataires ADD COLUMN documents_invalides TEXT NULL' },
      { name: 'verifie_le', sql: 'ALTER TABLE prestataires ADD COLUMN verifie_le DATETIME NULL' }
    ];

    for (let alt of presAlterations) {
      if (!presFields.includes(alt.name)) {
        console.log(`Adding column ${alt.name} to prestataires...`);
        await connection.query(alt.sql);
      }
    }

    console.log('Database initialization completed successfully! 🎉');

  } catch (err) {
    console.error('Migration error:', err);
  } finally {
    await connection.end();
  }
}

run();
