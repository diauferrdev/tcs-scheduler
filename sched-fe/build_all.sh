#!/bin/bash
# ============================================
# Pace Scheduler - Multi-Platform Build Script
# ============================================
# Usage: bash build_all.sh [platform]
#   platforms: android, web, windows, linux, macos, ios, all
#   Example:  bash build_all.sh android
#             bash build_all.sh all

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

FLUTTER="flutter"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

VERSION=$(grep 'version:' pubspec.yaml | head -1 | sed 's/version: //' | tr -d ' ')
VERSION_NAME=$(echo "$VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$VERSION" | cut -d'+' -f2)

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Pace Scheduler v${VERSION_NAME} (build ${BUILD_NUMBER})${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

PLATFORM="${1:-menu}"

show_menu() {
  echo -e "${BLUE}Select platform to build:${NC}"
  echo ""
  echo "  1) android   - APK (Firebase App Distribution)"
  echo "  2) web       - Web app (deploy to pacesched.com)"
  echo "  3) windows   - MSIX desktop app"
  echo "  4) linux     - Linux desktop app"
  echo "  5) macos     - macOS desktop app"
  echo "  6) ios       - iOS app (TestFlight)"
  echo "  7) all       - Build all platforms"
  echo "  0) exit"
  echo ""
  read -p "Choice: " choice
  case $choice in
    1) PLATFORM="android" ;;
    2) PLATFORM="web" ;;
    3) PLATFORM="windows" ;;
    4) PLATFORM="linux" ;;
    5) PLATFORM="macos" ;;
    6) PLATFORM="ios" ;;
    7) PLATFORM="all" ;;
    0) exit 0 ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
  esac
}

prep() {
  echo -e "${BLUE}[PREP]${NC} Getting dependencies..."
  $FLUTTER pub get
  echo ""
}

build_android() {
  echo -e "${GREEN}━━━ ANDROID BUILD ━━━${NC}"

  # Check keystore
  if [ -f android/key.properties ]; then
    echo -e "${GREEN}[✓]${NC} Release keystore configured"
  else
    echo -e "${YELLOW}[!]${NC} No key.properties — building with debug signing"
  fi

  echo -e "${BLUE}[BUILD]${NC} Building APK..."
  $FLUTTER build apk --release

  APK="build/app/outputs/flutter-apk/app-release.apk"
  VERSIONED_APK="build/app/outputs/flutter-apk/pace-scheduler-v${VERSION_NAME}.apk"

  if [ -f "$APK" ]; then
    cp "$APK" "$VERSIONED_APK"
    SIZE=$(du -h "$APK" | cut -f1)
    echo -e "${GREEN}[✓]${NC} APK built: ${VERSIONED_APK} (${SIZE})"

    # Firebase App Distribution (optional)
    if command -v firebase &> /dev/null; then
      echo ""
      read -p "Deploy to Firebase App Distribution? (y/N): " deploy
      if [[ "$deploy" =~ ^[Yy]$ ]]; then
        firebase appdistribution:distribute "$APK" \
          --app "1:874457674237:android:81596c5009b03f9a9fa994" \
          --groups "testers" \
          --release-notes "v${VERSION_NAME} (build ${BUILD_NUMBER})"
        echo -e "${GREEN}[✓]${NC} Deployed to Firebase App Distribution"
      fi
    fi
  else
    echo -e "${RED}[✗]${NC} APK build failed"
    return 1
  fi
  echo ""
}

build_web() {
  echo -e "${GREEN}━━━ WEB BUILD ━━━${NC}"
  echo -e "${BLUE}[BUILD]${NC} Building web..."
  $FLUTTER build web --release

  if [ -d "build/web" ]; then
    echo -e "${GREEN}[✓]${NC} Web built: build/web/"

    # Inject SW killer for cache busting
    sed -i 's|<head>|<head>\n<script>if("serviceWorker" in navigator){navigator.serviceWorker.getRegistrations().then(function(r){r.forEach(function(reg){reg.unregister()})});caches.keys().then(function(c){c.forEach(function(n){caches.delete(n)})})}</script>|' build/web/index.html
    echo -e "${GREEN}[✓]${NC} Service worker cache buster injected"
  else
    echo -e "${RED}[✗]${NC} Web build failed"
    return 1
  fi
  echo ""
}

build_windows() {
  echo -e "${GREEN}━━━ WINDOWS BUILD ━━━${NC}"
  echo -e "${BLUE}[BUILD]${NC} Building Windows..."
  $FLUTTER build windows --release

  if [ -d "build/windows/x64/runner/Release" ]; then
    echo -e "${GREEN}[✓]${NC} Windows built: build/windows/x64/runner/Release/"

    # MSIX packaging
    if grep -q "msix_config" pubspec.yaml; then
      echo -e "${BLUE}[MSIX]${NC} Creating MSIX package..."
      dart run msix:create 2>/dev/null && echo -e "${GREEN}[✓]${NC} MSIX created" || echo -e "${YELLOW}[!]${NC} MSIX packaging skipped (cert missing)"
    fi
  else
    echo -e "${RED}[✗]${NC} Windows build failed"
    return 1
  fi
  echo ""
}

build_linux() {
  echo -e "${GREEN}━━━ LINUX BUILD ━━━${NC}"
  echo -e "${BLUE}[BUILD]${NC} Building Linux..."
  $FLUTTER build linux --release

  if [ -d "build/linux/x64/release/bundle" ]; then
    echo -e "${GREEN}[✓]${NC} Linux built: build/linux/x64/release/bundle/"
  else
    echo -e "${RED}[✗]${NC} Linux build failed"
    return 1
  fi
  echo ""
}

build_macos() {
  echo -e "${GREEN}━━━ MACOS BUILD ━━━${NC}"
  echo -e "${BLUE}[BUILD]${NC} Building macOS..."
  $FLUTTER build macos --release

  if [ -d "build/macos/Build/Products/Release" ]; then
    echo -e "${GREEN}[✓]${NC} macOS built: build/macos/Build/Products/Release/"
  else
    echo -e "${RED}[✗]${NC} macOS build failed"
    return 1
  fi
  echo ""
}

build_ios() {
  echo -e "${GREEN}━━━ IOS BUILD ━━━${NC}"
  echo -e "${BLUE}[BUILD]${NC} Building iOS..."
  $FLUTTER build ipa --release --export-options-plist=ios/ExportOptions.plist 2>/dev/null \
    || $FLUTTER build ios --release

  if [ -d "build/ios" ]; then
    echo -e "${GREEN}[✓]${NC} iOS built"
  else
    echo -e "${RED}[✗]${NC} iOS build failed"
    return 1
  fi
  echo ""
}

# Main
if [ "$PLATFORM" = "menu" ]; then
  show_menu
fi

prep

case $PLATFORM in
  android)  build_android ;;
  web)      build_web ;;
  windows)  build_windows ;;
  linux)    build_linux ;;
  macos)    build_macos ;;
  ios)      build_ios ;;
  all)
    build_android || true
    build_web || true
    build_windows || true
    build_linux || true
    build_macos || true
    build_ios || true
    ;;
  *) echo -e "${RED}Unknown platform: $PLATFORM${NC}"; exit 1 ;;
esac

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Build complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
