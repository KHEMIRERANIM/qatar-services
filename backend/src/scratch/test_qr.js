const { Jimp } = require('jimp');
const QrCodeReader = require('qrcode-reader');

async function test() {
  console.log('Testing QrCodeReader...');
  try {
    const qr = new QrCodeReader();
    console.log('QrCodeReader instance created successfully.');
  } catch (err) {
    console.error('Error instantiating QrCodeReader:', err);
  }
}

test();
