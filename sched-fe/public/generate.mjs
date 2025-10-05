import sharp from 'sharp';
import fs from 'fs';

const svgBuffer = fs.readFileSync('icon.svg');

// 192x192
await sharp(svgBuffer)
  .resize(192, 192)
  .png()
  .toFile('pwa-192x192.png');

// 512x512
await sharp(svgBuffer)
  .resize(512, 512)
  .png()
  .toFile('pwa-512x512.png');

// Maskable 192
await sharp(svgBuffer)
  .resize(154, 154)
  .extend({
    top: 19,
    bottom: 19,
    left: 19,
    right: 19,
    background: { r: 0, g: 0, b: 0, alpha: 1 }
  })
  .png()
  .toFile('pwa-maskable-192x192.png');

// Maskable 512
await sharp(svgBuffer)
  .resize(410, 410)
  .extend({
    top: 51,
    bottom: 51,
    left: 51,
    right: 51,
    background: { r: 0, g: 0, b: 0, alpha: 1 }
  })
  .png()
  .toFile('pwa-maskable-512x512.png');

// Apple touch icon 180
await sharp(svgBuffer)
  .resize(180, 180)
  .png()
  .toFile('apple-touch-icon.png');

console.log('✅ All PWA icons generated successfully!');
