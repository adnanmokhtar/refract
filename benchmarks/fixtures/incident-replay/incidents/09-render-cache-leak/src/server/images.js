const sharp = require('sharp');

async function thumbnail(buf) {
  return sharp(buf).resize(320).jpeg({ quality: 80 }).toBuffer();
}

module.exports = { thumbnail };
