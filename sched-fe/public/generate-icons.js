// Gerar ícones PNG básicos para PWA usando canvas do navegador
const fs = require('fs');

// SVG simples TCS
const createSVG = (size) => `
<svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
  <rect width="${size}" height="${size}" fill="#000"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".3em" font-family="Arial, sans-serif" font-size="${size/4}" font-weight="bold" fill="#fff">TCS</text>
</svg>`;

// Criar SVGs
fs.writeFileSync('icon-192.svg', createSVG(192));
fs.writeFileSync('icon-512.svg', createSVG(512));

console.log('SVG icons created. Convert to PNG using: https://cloudconvert.com/svg-to-png');
console.log('Or use: npx svgexport icon-192.svg pwa-192x192.png');
