#!/bin/bash

# 🚀 TCS Pace Scheduler - Release Automation Script V2
# Suporta Android, iOS, ou ambos

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   TCS Pace Scheduler - Release V2     ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar diretório
if [ ! -f "flutter_multiplatform_app/pubspec.yaml" ]; then
    echo -e "${RED}❌ Erro: Execute da raiz do projeto${NC}"
    exit 1
fi

cd flutter_multiplatform_app

# Ler versão atual
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
CURRENT_BUILD=$(grep "^version:" pubspec.yaml | sed 's/.*+//')

echo -e "${YELLOW}📋 Versão atual: $CURRENT_VERSION (build $CURRENT_BUILD)${NC}"
echo ""

# Tipo de release
echo "Tipo de release:"
echo "  1) Patch (1.0.0 → 1.0.1)"
echo "  2) Minor (1.0.0 → 1.1.0)"
echo "  3) Major (1.0.0 → 2.0.0)"
echo "  4) Custom"
read -p "Opção [1-4]: " RELEASE_TYPE

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case $RELEASE_TYPE in
    1) PATCH=$((PATCH + 1)); NEW_VERSION="$MAJOR.$MINOR.$PATCH" ;;
    2) MINOR=$((MINOR + 1)); PATCH=0; NEW_VERSION="$MAJOR.$MINOR.$PATCH" ;;
    3) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0; NEW_VERSION="$MAJOR.$MINOR.$PATCH" ;;
    4) read -p "Nova versão (ex: 1.2.3): " NEW_VERSION ;;
    *) echo -e "${RED}❌ Opção inválida!${NC}"; exit 1 ;;
esac

NEW_BUILD=$((CURRENT_BUILD + 1))

echo ""
echo -e "${GREEN}✨ Nova versão: $NEW_VERSION (build $NEW_BUILD)${NC}"
echo ""

# Plataformas
echo "Selecione as plataformas:"
echo "  1) Android"
echo "  2) iOS (requer macOS)"
echo "  3) Ambos"
read -p "Opção [1-3]: " PLATFORM

case $PLATFORM in
    1) BUILD_ANDROID=true; BUILD_IOS=false ;;
    2) BUILD_ANDROID=false; BUILD_IOS=true ;;
    3) BUILD_ANDROID=true; BUILD_IOS=true ;;
    *) echo -e "${RED}❌ Opção inválida!${NC}"; exit 1 ;;
esac

# Release notes
read -p "Release notes (português): " RELEASE_NOTES
if [ -z "$RELEASE_NOTES" ]; then
    RELEASE_NOTES="Versão $NEW_VERSION - Melhorias e correções"
fi

echo ""
echo -e "${YELLOW}📝 Release notes: $RELEASE_NOTES${NC}"
echo ""

# Confirmar
read -p "Confirmar release? [Y/n] " CONFIRM
if [[ $CONFIRM != "" && $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
    echo -e "${RED}❌ Release cancelado${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}    Iniciando release...                ${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Atualizar versão
echo -e "${BLUE}[1/6] 📝 Atualizando versão...${NC}"
sed -i "s/^version: .*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml
echo -e "${GREEN}✅ Versão atualizada${NC}"
echo ""

# Flutter clean
echo -e "${BLUE}[2/6] 🧹 Limpando cache...${NC}"
flutter clean
flutter pub get
echo -e "${GREEN}✅ Cache limpo${NC}"
echo ""

ANDROID_LINK=""
IOS_LINK=""

# Build Android
if [ "$BUILD_ANDROID" = true ]; then
    echo -e "${BLUE}[3/6] 📱 Building Android...${NC}"
    flutter build apk --release --build-name="$NEW_VERSION" --build-number="$NEW_BUILD"

    if [ ! -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        echo -e "${RED}❌ Erro: APK não encontrado!${NC}"
        exit 1
    fi

    APK_SIZE=$(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)
    echo -e "${GREEN}✅ APK criado ($APK_SIZE)${NC}"

    # Upload Android
    echo -e "${BLUE}[4/6] 📤 Uploading Android...${NC}"
    FIREBASE_OUTPUT=$(firebase appdistribution:distribute \
      build/app/outputs/flutter-apk/app-release.apk \
      --app 1:874457674237:android:1ed8bb845b3e949d9fa994 \
      --groups "testers" \
      --release-notes "$RELEASE_NOTES" 2>&1)

    ANDROID_LINK=$(echo "$FIREBASE_OUTPUT" | grep "Share this release with testers" | sed 's/.*https/https/' | sed 's/?utm.*//')

    if [ -z "$ANDROID_LINK" ]; then
        echo -e "${RED}❌ Erro capturando link Android${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Android uploaded${NC}"
    echo -e "${YELLOW}🔗 $ANDROID_LINK${NC}"
fi

# Build iOS
if [ "$BUILD_IOS" = true ]; then
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}❌ iOS build requer macOS!${NC}"
        exit 1
    fi

    echo -e "${BLUE}[3/6] 🍎 Building iOS...${NC}"
    flutter build ipa --release --build-name="$NEW_VERSION" --build-number="$NEW_BUILD"

    if [ ! -f "build/ios/ipa/flutter_multiplatform_app.ipa" ]; then
        echo -e "${RED}❌ Erro: IPA não encontrado!${NC}"
        exit 1
    fi

    IPA_SIZE=$(du -h build/ios/ipa/flutter_multiplatform_app.ipa | cut -f1)
    echo -e "${GREEN}✅ IPA criado ($IPA_SIZE)${NC}"

    # Upload iOS
    echo -e "${BLUE}[4/6] 📤 Uploading iOS...${NC}"
    FIREBASE_OUTPUT=$(firebase appdistribution:distribute \
      build/ios/ipa/flutter_multiplatform_app.ipa \
      --app 1:874457674237:ios:705420cf66986a579fa994 \
      --groups "testers" \
      --release-notes "$RELEASE_NOTES" 2>&1)

    IOS_LINK=$(echo "$FIREBASE_OUTPUT" | grep "Share this release with testers" | sed 's/.*https/https/' | sed 's/?utm.*//')

    if [ -z "$IOS_LINK" ]; then
        echo -e "${RED}❌ Erro capturando link iOS${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ iOS uploaded${NC}"
    echo -e "${YELLOW}🔗 $IOS_LINK${NC}"
fi

echo ""

# Atualizar backend
echo -e "${BLUE}[5/6] 🔧 Atualizando backend...${NC}"
cd ../sched-be/src/routes

cat > version.ts << EOF
import { Hono } from 'hono';

const app = new Hono();

app.get('/current', (c) => {
  return c.json({
    version: '$NEW_VERSION',
    buildNumber: $NEW_BUILD,
    minVersion: '1.0.0',
    forceUpdate: false,
    downloadUrl: {
      android: '$ANDROID_LINK',
      ios: '$IOS_LINK',
      web: '',
      macos: '',
      windows: '',
      linux: '',
    },
    releaseNotes: {
      'pt-BR': '$RELEASE_NOTES',
      'en': 'Version $NEW_VERSION - Improvements and fixes.',
    },
    releaseDate: '$(date -Iseconds)',
    critical: false,
  });
});

export default app;
EOF

echo -e "${GREEN}✅ Backend atualizado${NC}"
echo ""

# Reiniciar backend
echo -e "${BLUE}[6/6] 🔄 Reiniciando backend...${NC}"
cd ../..

if lsof -Pi :7777 -sTCP:LISTEN -t >/dev/null 2>&1; then
    BACKEND_PID=$(lsof -ti:7777)
    kill $BACKEND_PID 2>/dev/null || true
    sleep 2
fi

nohup bun run dev > /dev/null 2>&1 &
sleep 3

echo -e "${GREEN}✅ Backend reiniciado${NC}"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     🎉 RELEASE $NEW_VERSION CONCLUÍDO!   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

if [ "$BUILD_ANDROID" = true ]; then
    echo -e "${YELLOW}📱 Android: $ANDROID_LINK${NC}"
fi

if [ "$BUILD_IOS" = true ]; then
    echo -e "${YELLOW}🍎 iOS: $IOS_LINK${NC}"
fi

echo ""
echo -e "${BLUE}💡 Testar update: Abrir app → Login → Aguardar 5 segundos${NC}"
echo ""
