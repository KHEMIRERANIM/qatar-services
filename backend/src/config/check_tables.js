const mysql = require('mysql2/promise');
require('dotenv').config();

async function run() {
  console.log('Connecting to database...');
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '', // default for XAMPP is empty
    database: 'qatar_services'
  });

  try {
    const [tables] = await connection.query('SHOW TABLES');
    console.log('Tables in database:', tables);
    for (let row of tables) {
      const tableName = Object.values(row)[0];
      const [columns] = await connection.query(`DESCRIBE \`${tableName}\``);
      console.log(`\nColumns in ${tableName}:`);
      console.table(columns.map(c => ({ Field: c.Field, Type: c.Type, Null: c.Null, Key: c.Key, Default: c.Default })));
    }
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await connection.end();
  }
}

run();
