#!/bin/bash

# ========================================
# Linux Build Script
# TCS PacePort Scheduler
# ========================================
#
# USAGE:
#   bash scripts/build/linux.sh
#   OR: echo "Y" | bash scripts/build/linux.sh  (auto-accept prompts)
#
# WHAT THIS SCRIPT DOES:
#   1. Increments build number in pubspec.yaml
#   2. Builds Flutter Linux binary (GTK application)
#   3. Creates tar.gz archive for direct download distribution
#   4. Creates AppImage (universal executable for all Linux distros)
#   5. Generates Flatpak manifest for Flathub Store distribution
#   6. Generates Snap configuration for Ubuntu Store distribution
#
# GENERATED FILES (NOT committed to git):
#   📁 build/linux/x64/release/bundle/          - Binary + libraries
#   📦 build/linux/x64/release/*.tar.gz         - Compressed archive (EXECUTABLE)
#   🖼️  build/linux/x64/release/*.AppImage       - Universal executable (EXECUTABLE)
#   📋 build/linux/flatpak/*.yml                - Flatpak manifest (STORE CONFIG)
#   📦 snap/snapcraft.yaml                      - Snap configuration (STORE CONFIG)
#
# HOW TO USE GENERATED FILES:
#
#   DIRECT EXECUTION:
#     ./build/linux/x64/release/bundle/tcs_pace_scheduler
#
#   TAR.GZ DISTRIBUTION:
#     tar -xzf *.tar.gz && cd bundle && ./tcs_pace_scheduler
#
#   APPIMAGE (Universal - runs on any distro):
#     chmod +x *.AppImage && ./file.AppImage
#     OR (WSL/no FUSE): ./file.AppImage --appimage-extract-and-run
#
#   FLATPAK (Flathub Store):
#     flatpak-builder build-dir build/linux/flatpak/com.tcs.pace_scheduler.yml
#     flatpak-builder --repo=repo --force-clean build-dir [manifest]
#     flatpak build-bundle repo tcs-pace-scheduler.flatpak com.tcs.pace_scheduler
#
#   SNAP (Ubuntu Store):
#     snapcraft
#     snapcraft upload --release=stable *.snap
#
# REQUIREMENTS:
#   - Flutter SDK installed
#   - GTK 3 development libraries (libgtk-3-dev)
#   - libnotify development libraries (libnotify-dev)
#   - wget (for downloading appimagetool)
#
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

print_header "🐧 Linux Build"

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    print_warning "This script is optimized for Linux"
    print_info "You are running: $OSTYPE"
    echo ""
    read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
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
sed -i "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
print_success "Version updated to $NEW_VERSION"

# Clean & Dependencies
print_info "Cleaning previous builds..."
flutter clean > /dev/null 2>&1
print_success "Clean complete"

print_info "Getting Flutter dependencies..."
flutter pub get > /dev/null 2>&1
print_success "Dependencies updated"

# Build Linux binary
print_header "🔨 Building Linux Binary"
print_info "Building release Linux binary..."
print_warning "This may take a few minutes..."

flutter build linux --release

BUILD_DIR="build/linux/x64/release/bundle"

if [ -d "$BUILD_DIR" ]; then
    BUILD_SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
    print_success "Linux build complete!"
    echo ""
    print_info "Build Location: $BUILD_DIR ($BUILD_SIZE)"

    # Create tar.gz archive
    print_info "Creating tar.gz archive for distribution..."
    TAR_NAME="tcs-pace-scheduler-v${VERSION_NAME}-build${NEW_BUILD_NUMBER}-linux-x64.tar.gz"
    cd "build/linux/x64/release"
    tar -czf "$TAR_NAME" "bundle/" > /dev/null 2>&1
    cd - > /dev/null
    TAR_PATH="build/linux/x64/release/$TAR_NAME"
    TAR_SIZE=$(du -h "$TAR_PATH" | cut -f1)
    print_success "Archive created: $TAR_PATH ($TAR_SIZE)"
else
    print_error "Linux build failed - directory not found"
    exit 1
fi

# ========================================
# CREATE APPIMAGE (Universal Linux Executable)
# ========================================
# AppImage is a universal format that runs on ANY Linux distribution
# without installation. Users just download, make executable, and run.
# Perfect for: Direct downloads, GitHub Releases
print_header "📦 Creating AppImage"
APPIMAGE_NAME="TCS-Pace-Scheduler-v${VERSION_NAME}-build${NEW_BUILD_NUMBER}-x86_64.AppImage"
APPDIR="build/linux/TCS-Pace-Scheduler.AppDir"

# AppImage requires a specific directory structure (AppDir)
print_info "Setting up AppImage structure..."
mkdir -p "$APPDIR/usr/bin"                                          # Binary location
mkdir -p "$APPDIR/usr/lib"                                          # Libraries location
mkdir -p "$APPDIR/usr/share/applications"                          # Desktop entry
mkdir -p "$APPDIR/usr/share/icons/hicolor/512x512/apps"           # Application icon

# Copy all application files into AppDir structure
cp -r "$BUILD_DIR"/* "$APPDIR/usr/bin/"
cp "linux/com.tcs.pace_scheduler.desktop" "$APPDIR/usr/share/applications/"
cp "linux/icons/hicolor/512x512/apps/com.tcs.pace_scheduler.png" "$APPDIR/usr/share/icons/hicolor/512x512/apps/"

# Create AppRun launcher script (entry point for AppImage)
# This script sets up environment and launches the application
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
cd "${HERE}/usr/bin"
exec "${HERE}/usr/bin/tcs_pace_scheduler" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Copy desktop entry and icon to AppDir root (required by AppImage spec)
cp "linux/com.tcs.pace_scheduler.desktop" "$APPDIR/"
cp "linux/icons/hicolor/512x512/apps/com.tcs.pace_scheduler.png" "$APPDIR/"

# Download appimagetool (only once, cached for future builds)
if [ ! -f "build/appimagetool-x86_64.AppImage" ]; then
    print_info "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" \
        -O "build/appimagetool-x86_64.AppImage" 2>&1 | grep -v "HTTP request sent"
    chmod +x "build/appimagetool-x86_64.AppImage"
fi

# Fix desktop file to comply with freedesktop.org specification
# "Productivity" is not a registered category, only "Office" is valid
sed -i 's/Categories=Office;Productivity;/Categories=Office;/' "$APPDIR/com.tcs.pace_scheduler.desktop"

# Extract appimagetool for WSL/non-FUSE environments
# WSL doesn't support FUSE by default, so we extract and use the tool directly
if [ ! -d "build/squashfs-root" ]; then
    print_info "Extracting appimagetool (for WSL/non-FUSE environments)..."
    cd build
    ./appimagetool-x86_64.AppImage --appimage-extract > /dev/null 2>&1
    cd - > /dev/null
fi

# Build AppImage using extracted appimagetool
# This packages the AppDir into a single executable file
print_info "Building AppImage..."
ARCH=x86_64 ./build/squashfs-root/AppRun "$APPDIR" "build/linux/x64/release/$APPIMAGE_NAME" > /dev/null 2>&1
if [ -f "build/linux/x64/release/$APPIMAGE_NAME" ]; then
    chmod +x "build/linux/x64/release/$APPIMAGE_NAME"
    APPIMAGE_SIZE=$(du -h "build/linux/x64/release/$APPIMAGE_NAME" | cut -f1)
    print_success "AppImage created: build/linux/x64/release/$APPIMAGE_NAME ($APPIMAGE_SIZE)"
else
    print_warning "AppImage creation failed"
fi

# ========================================
# CREATE FLATPAK MANIFEST (Flathub Store Distribution)
# ========================================
# Flatpak is a package format for Linux app stores (primarily Flathub)
# This generates a MANIFEST FILE, not an executable package
# Perfect for: Flathub Store, sandboxed application distribution
print_header "📦 Creating Flatpak Manifest"
FLATPAK_DIR="build/linux/flatpak"
mkdir -p "$FLATPAK_DIR"

# Generate Flatpak manifest (YAML configuration file)
# This tells flatpak-builder HOW to build the app
cat > "$FLATPAK_DIR/com.tcs.pace_scheduler.yml" << EOF
app-id: com.tcs.pace_scheduler
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk
command: tcs_pace_scheduler

finish-args:
  - --share=ipc
  - --socket=x11
  - --socket=wayland
  - --device=dri
  - --share=network
  - --filesystem=home

modules:
  - name: tcs-pace-scheduler
    buildsystem: simple
    build-commands:
      - install -D tcs_pace_scheduler /app/bin/tcs_pace_scheduler
      - install -D com.tcs.pace_scheduler.desktop /app/share/applications/com.tcs.pace_scheduler.desktop
      - install -D com.tcs.pace_scheduler.png /app/share/icons/hicolor/512x512/apps/com.tcs.pace_scheduler.png
    sources:
      - type: dir
        path: ../../x64/release/bundle
EOF

# Copy required files for Flatpak build
cp "$BUILD_DIR/tcs_pace_scheduler" "$FLATPAK_DIR/"
cp "linux/com.tcs.pace_scheduler.desktop" "$FLATPAK_DIR/"
cp "linux/icons/hicolor/512x512/apps/com.tcs.pace_scheduler.png" "$FLATPAK_DIR/"

print_success "Flatpak manifest created: $FLATPAK_DIR/com.tcs.pace_scheduler.yml"
print_info "To build Flatpak: flatpak-builder build-flatpak $FLATPAK_DIR/com.tcs.pace_scheduler.yml"

# ========================================
# CREATE SNAP CONFIGURATION (Ubuntu Store Distribution)
# ========================================
# Snap is Canonical's package format for Ubuntu and other Linux distros
# This generates a CONFIGURATION FILE (snapcraft.yaml), not an executable
# Perfect for: Ubuntu Store, automatic updates, strict confinement
print_header "📦 Creating Snap Configuration"
SNAP_DIR="snap"
mkdir -p "$SNAP_DIR"

# Generate snapcraft.yaml configuration
# This tells snapcraft HOW to build the snap package
cat > "$SNAP_DIR/snapcraft.yaml" << EOF
name: tcs-pace-scheduler
version: '${VERSION_NAME}'
summary: TCS Pace Scheduler
description: |
  Enterprise scheduling application for TCS PacePort office visits.

  Features:
  - Role-based access control
  - Automated booking management
  - Real-time notifications
  - Calendar integration

grade: stable
confinement: strict
base: core22

apps:
  tcs-pace-scheduler:
    command: tcs_pace_scheduler
    plugs:
      - network
      - network-bind
      - desktop
      - desktop-legacy
      - wayland
      - x11
      - opengl
      - home

parts:
  tcs-pace-scheduler:
    plugin: dump
    source: build/linux/x64/release/bundle
    organize:
      '*': bin/
    stage-packages:
      - libgtk-3-0
      - libglib2.0-0
      - libnotify4
EOF

print_success "Snap configuration created: $SNAP_DIR/snapcraft.yaml"
print_info "To build Snap: snapcraft"

# Summary
print_header "📋 Build Summary"

echo "Version:        $VERSION_NAME"
echo "Build Number:   $NEW_BUILD_NUMBER"
echo "Full Version:   $NEW_VERSION"
echo ""
echo "📦 Generated Packages:"
echo ""
echo "  🐧 Binary:     $BUILD_DIR/tcs_pace_scheduler"
echo "  📦 Tar.gz:     $TAR_PATH ($TAR_SIZE)"
if [ -f "build/linux/x64/release/$APPIMAGE_NAME" ]; then
    echo "  🖼️  AppImage:   build/linux/x64/release/$APPIMAGE_NAME ($APPIMAGE_SIZE)"
fi
echo "  📋 Flatpak:    $FLATPAK_DIR/com.tcs.pace_scheduler.yml"
echo "  📦 Snap:       $SNAP_DIR/snapcraft.yaml"
echo ""

print_header "✅ Linux Build Complete!"
echo ""
print_info "Distribution Options:"
echo ""
echo "  1. Direct Download (tar.gz):"
echo "     ${CYAN}tar -xzf $TAR_NAME && cd bundle && ./tcs_pace_scheduler${NC}"
echo ""
echo "  2. AppImage (Universal - Just click and run):"
if [ -f "build/linux/x64/release/$APPIMAGE_NAME" ]; then
    echo "     ${CYAN}chmod +x $APPIMAGE_NAME && ./$APPIMAGE_NAME${NC}"
else
    echo "     ${YELLOW}Run script again to generate AppImage${NC}"
fi
echo ""
echo "  3. Flatpak (Flathub Store):"
echo "     ${CYAN}flatpak-builder build-dir $FLATPAK_DIR/com.tcs.pace_scheduler.yml${NC}"
echo "     ${CYAN}flatpak-builder --repo=repo --force-clean build-dir $FLATPAK_DIR/com.tcs.pace_scheduler.yml${NC}"
echo ""
echo "  4. Snap (Ubuntu Store):"
echo "     ${CYAN}snapcraft${NC}"
echo ""
