#!/bin/bash

# ========================================
# Windows Build Script
# TCS PacePort Scheduler
# ========================================
#
# IMPORTANT: Firebase is excluded from Windows builds
# due to C++ SDK linking incompatibilities.
# Windows uses local_notifier for desktop notifications.

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

print_header "🪟 Windows Build"

# Check if running on Windows (Git Bash, WSL, or native Windows)
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" && ! -d "/mnt/c" ]]; then
    print_warning "This script is optimized for Windows"
    print_info "You are running: $OSTYPE"
    echo ""
    print_info "For cross-platform builds, this may work on Linux/macOS with Flutter Windows support"
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

# ========================================
# FIREBASE EXCLUSION (WINDOWS-SPECIFIC)
# ========================================
print_header "🔧 Configuring Windows Build"
print_warning "Excluding Firebase from Windows build (C++ SDK incompatible)"
print_info "Windows will use local_notifier for notifications instead"
echo ""

# Exclude Firebase from CMake plugin list
if [ -f "windows/flutter/generated_plugins.cmake" ]; then
    sed -i 's/^  firebase_core$/  # firebase_core  # Excluded - Firebase C++ SDK has linking issues on Windows desktop/' windows/flutter/generated_plugins.cmake
    print_success "Firebase excluded from CMake plugin list"
fi

# Exclude Firebase from plugin registrant
if [ -f "windows/flutter/generated_plugin_registrant.cc" ]; then
    sed -i 's|^#include <firebase_core/firebase_core_plugin_c_api.h>$|// #include <firebase_core/firebase_core_plugin_c_api.h>  // Excluded - Firebase C++ SDK has linking issues|' windows/flutter/generated_plugin_registrant.cc
    sed -i 's/^  FirebaseCorePluginCApiRegisterWithRegistrar($/  \/\/ FirebaseCorePluginCApiRegisterWithRegistrar(  \/\/ Excluded - Firebase C++ SDK has linking issues/' windows/flutter/generated_plugin_registrant.cc
    sed -i 's/^      registry->GetRegistrarForPlugin("FirebaseCorePluginCApi"));$/  \/\/     registry->GetRegistrarForPlugin("FirebaseCorePluginCApi"));/' windows/flutter/generated_plugin_registrant.cc
    print_success "Firebase excluded from plugin registrant"
fi

echo ""

# Build Windows executable
print_header "🔨 Building Windows Executable"
print_info "Building release Windows executable..."
print_info "Using --no-pub to preserve Firebase exclusion"
print_warning "This may take 5-10 minutes on first build..."

flutter build windows --release --no-pub

BUILD_DIR="build/windows/x64/runner/Release"
EXE_PATH="$BUILD_DIR/flutter_multiplatform_app.exe"

if [ -f "$EXE_PATH" ]; then
    EXE_SIZE=$(du -h "$EXE_PATH" | cut -f1)
    print_success "Windows build complete!"
    echo ""
    print_info "Executable: $EXE_PATH ($EXE_SIZE)"

    # Create ZIP archive
    print_info "Creating ZIP archive for distribution..."
    ZIP_NAME="tcs-pace-scheduler-v${VERSION_NAME}-build${NEW_BUILD_NUMBER}-windows-x64.zip"
    cd "build/windows/x64/runner"

    # Use PowerShell to create ZIP on Windows, or zip command on WSL/Git Bash
    if command -v powershell.exe &> /dev/null; then
        powershell.exe -Command "Compress-Archive -Path 'Release\*' -DestinationPath '$ZIP_NAME' -Force" > /dev/null 2>&1
    else
        zip -r "$ZIP_NAME" "Release/" > /dev/null 2>&1
    fi

    cd - > /dev/null
    ZIP_PATH="build/windows/x64/runner/$ZIP_NAME"

    if [ -f "$ZIP_PATH" ]; then
        ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
        print_success "ZIP created: $ZIP_PATH ($ZIP_SIZE)"
    else
        print_warning "Could not create ZIP archive"
    fi
else
    print_error "Windows build failed - executable not found"
    exit 1
fi

# Summary
print_header "📋 Build Summary"

echo "Version:        $VERSION_NAME"
echo "Build Number:   $NEW_BUILD_NUMBER"
echo "Full Version:   $NEW_VERSION"
echo ""
echo "🪟 Executable: $EXE_PATH"
echo "📦 Distribution folder: $BUILD_DIR (copy entire folder)"
if [ -f "$ZIP_PATH" ]; then
    echo "📦 ZIP Archive: $ZIP_PATH"
fi
echo ""
echo "⚠️  Firebase: Excluded (uses local_notifier for notifications)"
echo ""

print_header "✅ Windows Build Complete!"
echo ""
print_info "Next steps:"
echo "  1. Test the executable: $EXE_PATH"
echo "  2. Distribute the entire Release folder or ZIP archive"
echo "  3. Required files for distribution:"
echo "     • flutter_multiplatform_app.exe (main executable)"
echo "     • flutter_windows.dll (Flutter runtime)"
echo "     • data/ folder (app resources)"
echo "     • Plugin DLLs (*.dll files)"
echo ""
print_info "Installation:"
echo "  1. Extract ZIP to any folder"
echo "  2. Run flutter_multiplatform_app.exe"
echo "  3. No installation required - portable application"
echo ""
