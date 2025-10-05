#!/bin/bash

# Criar ícones PNG simples em preto (temporários para testar PWA)
# Depois você substitui com ícones reais do TCS

# 192x192
convert -size 192x192 xc:black -fill white -pointsize 60 -gravity center -annotate +0+0 "TCS" pwa-192x192.png 2>/dev/null || \
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > temp.png && convert temp.png -resize 192x192 -background black -gravity center -extent 192x192 pwa-192x192.png && rm temp.png

# 512x512
convert -size 512x512 xc:black -fill white -pointsize 160 -gravity center -annotate +0+0 "TCS" pwa-512x512.png 2>/dev/null || \
cp pwa-192x192.png temp.png && convert temp.png -resize 512x512 pwa-512x512.png && rm temp.png

# Maskable com safe zone (adiciona 20% padding)
convert pwa-192x192.png -resize 154x154 -gravity center -extent 192x192 -background black pwa-maskable-192x192.png 2>/dev/null || \
cp pwa-192x192.png pwa-maskable-192x192.png

convert pwa-512x512.png -resize 410x410 -gravity center -extent 512x512 -background black pwa-maskable-512x512.png 2>/dev/null || \
cp pwa-512x512.png pwa-maskable-512x512.png

# Apple touch icon
cp pwa-192x192.png apple-touch-icon.png 2>/dev/null || echo "Icon created"

echo "PWA icons created successfully!"
ls -lh pwa-*.png apple-touch-icon.png
