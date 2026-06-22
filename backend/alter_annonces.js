const mysql = require('mysql2/promise');
require('dotenv').config({ path: './backend/.env' });

async function run() {
  const db = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'qatar_services'
  });
  try {
    await db.query(`ALTER TABLE annonces ADD COLUMN type_paiement VARCHAR(100) DEFAULT 'Espèces'`);
    console.log('Column type_paiement added successfully');
  } catch (err) {
    if (err.code === 'ER_DUP_FIELDNAME') {
      console.log('Column type_paiement already exists');
    } else {
      console.error(err);
    }
  } finally {
    process.exit();
  }
}
run();
