const jimp = require('jimp');
console.log('Jimp keys:', Object.keys(jimp));
try {
  const JimpExport = jimp.Jimp || jimp;
  console.log('JimpExport exists:', !!JimpExport);
  console.log('JimpExport read exists:', !!JimpExport.read);
} catch (e) {
  console.error(e);
}
