#!/bin/bash

# Script para instalar ícones em todas as plataformas

echo "🎨 Instalando ícones do TCS Pace Scheduler..."

# Android
echo "📱 Android..."
rm -rf android/app/src/main/res/mipmap-*
cp -r assets/icons/android/res/* android/app/src/main/res/
echo "✅ Android ícones copiados"

# iOS
echo "🍎 iOS..."
rm -rf ios/Runner/Assets.xcassets/AppIcon.appiconset/*
cp assets/icons/ios/* ios/Runner/Assets.xcassets/AppIcon.appiconset/
echo "✅ iOS ícones copiados"

# macOS
echo "🖥️  macOS..."
cp assets/icons/macos/AppIcon.icns macos/Runner/Assets.xcassets/AppIcon.appiconset/
echo "✅ macOS ícone copiado"

# Web
echo "🌐 Web..."
cp assets/icons/web/favicon.ico web/
cp assets/icons/web/icon-192.png web/
cp assets/icons/web/icon-192-maskable.png web/
cp assets/icons/web/icon-512.png web/
cp assets/icons/web/icon-512-maskable.png web/
cp assets/icons/web/apple-touch-icon.png web/
echo "✅ Web ícones copiados"

echo ""
echo "✨ Todos os ícones instalados com sucesso!"
echo ""
echo "⚠️  Para aplicar as mudanças:"
echo "   1. flutter clean"
echo "   2. flutter pub get"
echo "   3. Rebuild o app"
