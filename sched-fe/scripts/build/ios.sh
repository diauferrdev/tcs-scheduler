#!/bin/bash

# ========================================
# iOS Build Script
# TCS PacePort Scheduler
# ========================================
#
# USAGE:
#   bash scripts/build/ios.sh [patch|minor|major] [skip-build]
#   Examples:
#     bash scripts/build/ios.sh patch           # Bug fixes: 1.0.0 -> 1.0.1
#     bash scripts/build/ios.sh minor           # New features: 1.0.0 -> 1.1.0
#     bash scripts/build/ios.sh major           # Breaking changes: 1.0.0 -> 2.0.0
#     echo "Y" | bash scripts/build/ios.sh      # Auto-accept prompts
#
# WHAT THIS SCRIPT DOES:
#   1. Increments version in pubspec.yaml (semantic versioning)
#   2. Updates backend version.ts endpoint
#   3. Builds iOS IPA (release mode)
#   4. **Deploys to Firebase App Distribution** (PRIMARY MOBILE DISTRIBUTION)
#   5. Creates git commit and tag
#   6. Provides push instructions
#
# GENERATED FILES (NOT committed to git):
#   📦 build/ios/ipa/tcs_pace_scheduler.ipa                    - Standard IPA
#   📦 build/ios/ipa/tcs-pace-scheduler-vX.X.X.ipa             - Versioned IPA
#
# DISTRIBUTION METHOD:
#   **PRIMARY: Firebase App Distribution** (automatically deployed by script)
#   - Testers receive immediate notifications
#   - Download link provided in Firebase console
#   - App ID: 1:874457674237:ios:705420cf66986a579fa994
#   - Tester group: "testers"
#
#   ALTERNATIVE: Manual IPA distribution
#   - Share versioned IPA file directly
#   - Users must install via TestFlight or enterprise distribution
#
#   APP STORE: Use Xcode or Transporter
#   - Archive in Xcode: Product > Archive
#   - Validate and upload to App Store Connect
#
# REQUIREMENTS:
#   - macOS with Xcode installed
#   - Flutter SDK installed
#   - iOS development certificates configured
#   - Firebase CLI installed (npm install -g firebase-tools)
#   - Authenticated with Firebase (firebase login)
#   - Provisioning profile configured for distribution
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

# Load release notes helper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/get-release-notes.sh"

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

print_header "🍎 iOS Build"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "iOS builds require macOS!"
    echo ""
    print_info "You are running: $OSTYPE"
    print_info "Please run this script on a macOS machine with Xcode installed"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode not found!"
    echo ""
    print_info "Please install Xcode from the App Store"
    exit 1
fi

# Parse command line arguments
BUMP_TYPE=${1:-patch}  # patch, minor, or major
SKIP_BUILD=${2:-false}

if [[ ! "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]]; then
    print_error "Invalid bump type: $BUMP_TYPE"
    echo "Usage: ./ios.sh [patch|minor|major] [skip-build]"
    echo "  patch: 1.0.0 -> 1.0.1 (bug fixes)"
    echo "  minor: 1.0.0 -> 1.1.0 (new features)"
    echo "  major: 1.0.0 -> 2.0.0 (breaking changes)"
    exit 1
fi

print_info "Starting iOS release process..."
print_info "Bump type: $BUMP_TYPE"

# Read current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
CURRENT_BUILD=$(grep "^version:" pubspec.yaml | sed 's/.*+//')

print_info "Current version: $CURRENT_VERSION (build $CURRENT_BUILD)"

# Split version into major.minor.patch
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

# Increment version based on bump type
case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
NEW_BUILD=$((CURRENT_BUILD + 1))
NEW_VERSION_WITH_BUILD="$NEW_VERSION+$NEW_BUILD"

print_info "New version: $NEW_VERSION (build $NEW_BUILD)"

# Confirm with user
read -p "$(echo -e ${YELLOW}Proceed with version bump? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Release cancelled by user"
    exit 0
fi

# Update pubspec.yaml
print_info "Updating pubspec.yaml..."
sed -i '' "s/^version:.*/version: $NEW_VERSION_WITH_BUILD/" pubspec.yaml
print_success "Updated pubspec.yaml to version $NEW_VERSION_WITH_BUILD"

# Update backend version endpoint
BACKEND_VERSION_FILE="../sched-be/src/routes/version.ts"
if [ -f "$BACKEND_VERSION_FILE" ]; then
    print_info "Updating backend version endpoint..."

    # Update version
    sed -i '' "s/version: '[^']*'/version: '$NEW_VERSION'/" "$BACKEND_VERSION_FILE"

    # Update buildNumber
    sed -i '' "s/buildNumber: [0-9]*/buildNumber: $NEW_BUILD/" "$BACKEND_VERSION_FILE"

    # Update releaseDate to current date
    RELEASE_DATE=$(date -Iseconds)
    sed -i '' "s/releaseDate: '[^']*'/releaseDate: '$RELEASE_DATE'/" "$BACKEND_VERSION_FILE"

    print_success "Updated backend version endpoint"
else
    print_warning "Backend version file not found at $BACKEND_VERSION_FILE"
fi

# Clean previous builds
print_info "Cleaning previous builds..."
flutter clean
print_success "Clean complete"

# Get dependencies
print_info "Getting Flutter dependencies..."
flutter pub get
print_success "Dependencies updated"

# Build IPA (unless skipped)
if [ "$SKIP_BUILD" != "skip-build" ]; then
    print_header "🔨 Building IPA"
    print_info "Building release IPA..."
    print_warning "This may take several minutes..."

    flutter build ipa --release

    IPA_PATH="build/ios/ipa/tcs_pace_scheduler.ipa"

    if [ -f "$IPA_PATH" ]; then
        IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
        print_success "IPA built successfully: $IPA_PATH ($IPA_SIZE)"

        # Optionally rename IPA with version
        VERSIONED_IPA="build/ios/ipa/tcs-pace-scheduler-v$NEW_VERSION-build$NEW_BUILD.ipa"
        cp "$IPA_PATH" "$VERSIONED_IPA"
        print_success "Versioned IPA created: $VERSIONED_IPA"

        # Deploy to Firebase App Distribution
        print_info "Deploying to Firebase App Distribution..."

        # Get release notes from centralized RELEASE_NOTES.md file
        RELEASE_NOTES=$(format_notes_firebase "$NEW_VERSION" "$NEW_BUILD" "$BUMP_TYPE")

        if firebase appdistribution:distribute "$VERSIONED_IPA" \
            --app 1:874457674237:ios:705420cf66986a579fa994 \
            --groups "testers" \
            --release-notes "$RELEASE_NOTES" 2>&1; then
            print_success "Successfully deployed to Firebase App Distribution!"
        else
            print_warning "Failed to deploy to Firebase App Distribution"
            print_info "You can manually deploy later with:"
            echo -e "  ${BLUE}firebase appdistribution:distribute $VERSIONED_IPA --app 1:874457674237:ios:705420cf66986a579fa994${NC}"
        fi
    else
        print_error "IPA build failed"
        exit 1
    fi
else
    print_warning "Skipping IPA build (skip-build flag set)"
fi

# Git operations
print_info "Preparing Git commit..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_warning "Not a git repository, skipping git operations"
else
    # Check for uncommitted changes
    if [[ -n $(git status -s) ]]; then
        print_info "Uncommitted changes detected"

        # Stage all changes
        git add .

        # Create commit message
        COMMIT_MSG="chore: Release v$NEW_VERSION (build $NEW_BUILD)

- Version bumped from $CURRENT_VERSION to $NEW_VERSION
- Build number: $CURRENT_BUILD -> $NEW_BUILD
- Release type: $BUMP_TYPE

🤖 Generated with automated release script"

        git commit -m "$COMMIT_MSG"
        print_success "Changes committed"

        # Create git tag
        TAG_NAME="v$NEW_VERSION"
        git tag -a "$TAG_NAME" -m "Release $NEW_VERSION"
        print_success "Git tag created: $TAG_NAME"

        print_info "To push changes and tags, run:"
        echo -e "  ${BLUE}git push && git push --tags${NC}"
    else
        print_info "No uncommitted changes to commit"
    fi
fi

# Summary
echo ""
print_success "═══════════════════════════════════════════════"
print_success "  iOS Release v$NEW_VERSION (build $NEW_BUILD) completed!"
print_success "═══════════════════════════════════════════════"
echo ""
print_info "Version: $CURRENT_VERSION -> $NEW_VERSION"
print_info "Build: $CURRENT_BUILD -> $NEW_BUILD"
print_info "Type: $BUMP_TYPE"

if [ "$SKIP_BUILD" != "skip-build" ]; then
    print_info "IPA: build/ios/ipa/tcs-pace-scheduler-v$NEW_VERSION-build$NEW_BUILD.ipa"
fi

echo ""
print_info "Next steps:"
echo "  1. Test the IPA on device or download from Firebase App Distribution"
echo "  2. Push changes: git push && git push --tags"
echo ""
