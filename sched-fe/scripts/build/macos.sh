#!/bin/bash

# ========================================
# macOS Build Script
# TCS PacePort Scheduler
# ========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}"
    echo "════════════════════════════════════════════════════════"
    echo "  $1"
    echo "════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

cd "$(dirname "$0")/../.."

print_header "🖥️  macOS Build"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "macOS builds require macOS!"
    echo ""
    print_info "You are running: $OSTYPE"
    print_info "Please run this script on a macOS machine"
    exit 1
fi

# Version Management
print_info "Checking current version..."

CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

print_info "Current version: $VERSION_NAME (build $BUILD_NUMBER)"

NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${VERSION_NAME}+${NEW_BUILD_NUMBER}"

print_info "New version: $VERSION_NAME (build $NEW_BUILD_NUMBER)"

# Ask for confirmation
read -p "$(echo -e ${YELLOW}Continue with build? [Y/n]: ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    print_warning "Build cancelled by user"
    exit 0
fi

# Update version
print_info "Updating version in pubspec.yaml..."
sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
print_success "Version updated to $NEW_VERSION"

# Clean & Dependencies
print_info "Cleaning previous builds..."
flutter clean > /dev/null 2>&1
print_success "Clean complete"

print_info "Getting Flutter dependencies..."
flutter pub get > /dev/null 2>&1
print_success "Dependencies updated"

# Build macOS app
print_header "🔨 Building macOS App"
print_info "Building release macOS app..."
print_warning "This may take a few minutes..."

flutter build macos --release

APP_DIR="build/macos/Build/Products/Release"
APP_PATH="$APP_DIR/tcs_pace_scheduler.app"

if [ -d "$APP_PATH" ]; then
    APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
    print_success "macOS app build complete!"
    echo ""
    print_info "App Location: $APP_PATH ($APP_SIZE)"

    # Create DMG (optional)
    print_info "Creating ZIP archive..."
    ZIP_NAME="tcs-pace-scheduler-v${VERSION_NAME}-build${NEW_BUILD_NUMBER}-macos.zip"
    cd "$APP_DIR"
    zip -r "$ZIP_NAME" "tcs_pace_scheduler.app" > /dev/null 2>&1
    cd - > /dev/null
    ZIP_SIZE=$(du -h "$APP_DIR/$ZIP_NAME" | cut -f1)
    print_success "ZIP created: $APP_DIR/$ZIP_NAME ($ZIP_SIZE)"
else
    print_error "macOS app build failed - app not found"
    exit 1
fi

# Summary
print_header "📋 Build Summary"

echo "Version:        $VERSION_NAME"
echo "Build Number:   $NEW_BUILD_NUMBER"
echo "Full Version:   $NEW_VERSION"
echo ""
echo "🖥️  App Location: $APP_PATH"
echo "📦 ZIP Location: $APP_DIR/$ZIP_NAME"
echo ""

print_header "✅ macOS Build Complete!"
echo ""
print_info "Next steps:"
echo "  1. Test the app by opening: $APP_PATH"
echo "  2. Distribute the ZIP file for installation"
echo "  3. For App Store distribution, use Xcode to archive and upload"
echo ""
