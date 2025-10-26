#!/bin/bash

# ========================================
# Release Notes Updater
# ========================================
#
# Interactive script to update RELEASE_NOTES.md before a release
#
# USAGE:
#   bash scripts/update-release-notes.sh
#
# This script helps you:
# 1. Update the "Next Release" section with your changes
# 2. Ensures all build scripts use the same release notes
# 3. Maintains consistency across Android, iOS, and GitHub Releases
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

cd "$(dirname "$0")/.."

RELEASE_NOTES_FILE="RELEASE_NOTES.md"

print_header "📝 Update Release Notes"

if [ ! -f "$RELEASE_NOTES_FILE" ]; then
    print_error "RELEASE_NOTES.md not found!"
    exit 1
fi

echo ""
print_info "Current 'Next Release' section:"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"

# Extract and display current Next Release section
awk '
    /^## Next Release/ { capture=1; next }
    /^---/ && capture { exit }
    /^## / && capture && !/^## Next Release/ { exit }
    capture { print }
' "$RELEASE_NOTES_FILE"

echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo ""

print_warning "You need to update RELEASE_NOTES.md with your changes before building"
echo ""
print_info "Options:"
echo "  1. Edit RELEASE_NOTES.md manually"
echo "  2. Use this guided wizard (below)"
echo ""

read -p "$(echo -e ${YELLOW}Would you like to use the guided wizard? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Please edit RELEASE_NOTES.md manually, then run your build script"
    print_info "The file is located at: $RELEASE_NOTES_FILE"
    echo ""
    print_info "After updating, you can run:"
    echo "  - Android: bash scripts/build/android.sh patch"
    echo "  - iOS: bash scripts/build/ios.sh patch"
    echo "  - Desktop (tag): git tag v1.0.0 && git push --tags"
    exit 0
fi

print_header "✏️  Guided Update Wizard"

# Collect changes
echo ""
print_info "Enter changes (one per line, press Enter on empty line when done):"
echo -e "${CYAN}Example: - Fixed login authentication bug${NC}"
echo -e "${CYAN}Example: - Added dark mode support${NC}"
echo ""

CHANGES=()
while true; do
    read -p "Change: " line
    if [ -z "$line" ]; then
        break
    fi
    # Add "- " prefix if not present
    if [[ ! "$line" =~ ^-\  ]]; then
        line="- $line"
    fi
    CHANGES+=("$line")
done

# Collect features
echo ""
print_info "Enter new features (one per line, press Enter on empty line when done):"
echo ""

FEATURES=()
while true; do
    read -p "Feature: " line
    if [ -z "$line" ]; then
        break
    fi
    if [[ ! "$line" =~ ^-\  ]]; then
        line="- $line"
    fi
    FEATURES+=("$line")
done

# Collect bug fixes
echo ""
print_info "Enter bug fixes (one per line, press Enter on empty line when done):"
echo ""

BUGFIXES=()
while true; do
    read -p "Bug fix: " line
    if [ -z "$line" ]; then
        break
    fi
    if [[ ! "$line" =~ ^-\  ]]; then
        line="- $line"
    fi
    BUGFIXES+=("$line")
done

# Build new Next Release section
TEMP_FILE=$(mktemp)

# Write everything before Next Release section
awk '
    /^## Next Release/ { exit }
    { print }
' "$RELEASE_NOTES_FILE" > "$TEMP_FILE"

# Write new Next Release section
echo "" >> "$TEMP_FILE"
echo "## Next Release" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"

if [ ${#CHANGES[@]} -gt 0 ]; then
    echo "### Changes" >> "$TEMP_FILE"
    for change in "${CHANGES[@]}"; do
        echo "$change" >> "$TEMP_FILE"
    done
    echo "" >> "$TEMP_FILE"
fi

if [ ${#FEATURES[@]} -gt 0 ]; then
    echo "### Features" >> "$TEMP_FILE"
    for feature in "${FEATURES[@]}"; do
        echo "$feature" >> "$TEMP_FILE"
    done
    echo "" >> "$TEMP_FILE"
fi

if [ ${#BUGFIXES[@]} -gt 0 ]; then
    echo "### Bug Fixes" >> "$TEMP_FILE"
    for fix in "${BUGFIXES[@]}"; do
        echo "$fix" >> "$TEMP_FILE"
    done
    echo "" >> "$TEMP_FILE"
fi

# Write everything after Next Release section
awk '
    /^---/ { found_separator=1 }
    found_separator { print }
' "$RELEASE_NOTES_FILE" >> "$TEMP_FILE"

# Preview
echo ""
print_header "📋 Preview"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"

awk '
    /^## Next Release/ { capture=1; next }
    /^---/ && capture { exit }
    /^## / && capture && !/^## Next Release/ { exit }
    capture { print }
' "$TEMP_FILE"

echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo ""

read -p "$(echo -e ${YELLOW}Save these release notes? [Y/n]: ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    rm "$TEMP_FILE"
    print_warning "Release notes not saved"
    exit 0
fi

# Save
mv "$TEMP_FILE" "$RELEASE_NOTES_FILE"
print_success "Release notes updated successfully!"

echo ""
print_info "Next steps:"
echo "  - Android: bash scripts/build/android.sh patch"
echo "  - iOS: bash scripts/build/ios.sh patch"
echo "  - Desktop (tag): git tag v1.0.0 && git push --tags"
echo ""
print_success "All build scripts will now use these release notes!"
