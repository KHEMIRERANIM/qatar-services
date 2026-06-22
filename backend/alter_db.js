require('dotenv').config();
const mysql = require('mysql2/promise');
const db = mysql.createPool({ host: 'localhost', user: 'root', password: '', database: 'qatar_services' });

async function run() {
  try {
    await db.query(`ALTER TABLE commentaires ADD COLUMN type VARCHAR(20) DEFAULT 'commentaire'`);
    console.log('Column added');
  } catch (err) {
    if (err.code === 'ER_DUP_FIELDNAME') {
      console.log('Column already exists');
    } else {
      console.error(err);
    }
  } finally {
    process.exit();
  }
}

run();
