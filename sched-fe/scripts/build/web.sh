#!/bin/bash

# ========================================
# Web Production Build Script
# TCS PacePort Scheduler (Flutter Web)
# ========================================
#
# Builds Flutter web, updates version, deploys to nginx, and reloads server
# Follows the same modern pattern as android.sh and windows.sh

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

print_header "🌐 Web Production Build"

# Configuration
API_URL=${API_URL:-"https://api.ppspsched.lat"}
DEPLOY_DIR="/root/tcs/tcs-sched/tcs_pace_scheduler/build/web"
NGINX_CONFIG="/etc/nginx/sites-available/ppspsched"

print_info "Configuration:"
echo "  API URL: $API_URL"
echo "  Deploy Dir: $DEPLOY_DIR"
echo "  Nginx Config: $NGINX_CONFIG"
echo ""

# Version Management
print_info "Checking current version..."

CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

print_info "Current version: $VERSION_NAME (build $BUILD_NUMBER)"

NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${VERSION_NAME}+${NEW_BUILD_NUMBER}"

print_info "New version: $VERSION_NAME (build $NEW_BUILD_NUMBER)"
echo ""

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
echo ""

# Clean & Dependencies
print_header "🧹 Cleaning & Dependencies"
print_info "Cleaning previous builds..."
flutter clean > /dev/null 2>&1
print_success "Clean complete"

print_info "Getting Flutter dependencies..."
flutter pub get > /dev/null 2>&1
print_success "Dependencies updated"
echo ""

# Build for web production
print_header "🔨 Building Web Production"
print_info "Building release web app..."
print_warning "This may take 2-3 minutes..."

flutter build web \
    --release \
    --dart-define=API_URL=$API_URL \
    --source-maps

if [ ! -d "build/web" ]; then
    print_error "Build failed - build/web/ directory not created"
    exit 1
fi

BUILD_SIZE=$(du -sh build/web/ | cut -f1)
print_success "Web build complete! ($BUILD_SIZE)"
echo ""

# Fix service worker to handle 206 responses
print_header "🔧 Fixing Service Worker"
print_info "Patching service worker to handle partial responses (206)..."
if [ -f "scripts/fix_service_worker.sh" ]; then
    bash scripts/fix_service_worker.sh
else
    print_warning "Service worker fix script not found, skipping..."
fi
echo ""

# Update nginx and reload
print_header "🔧 Updating Nginx"

if [ -f "$NGINX_CONFIG" ]; then
    print_info "Testing nginx configuration..."
    if sudo nginx -t > /dev/null 2>&1; then
        print_success "Nginx configuration is valid"

        print_info "Reloading nginx to serve new build..."
        sudo systemctl reload nginx
        print_success "Nginx reloaded - new build is live!"
    else
        print_error "Nginx configuration test failed"
        sudo nginx -t
        exit 1
    fi
else
    print_warning "Nginx config not found at $NGINX_CONFIG"
fi
echo ""

# Set permissions
print_header "🔐 Setting Permissions"
print_info "Setting correct permissions for build/web/..."
sudo chown -R www-data:www-data build/web/
sudo chmod -R 755 build/web/
print_success "Permissions set"
echo ""

# Update backend version info
BACKEND_VERSION_FILE="../sched-be/src/routes/version.ts"
if [ -f "$BACKEND_VERSION_FILE" ]; then
    print_info "Updating backend version endpoint..."

    # Update web download URL
    sed -i "s|web: '.*'|web: 'https://ppspsched.lat'|" "$BACKEND_VERSION_FILE"

    print_success "Backend version endpoint updated"
fi
echo ""

# Summary
print_header "📋 Build Summary"

echo "Version:        $VERSION_NAME"
echo "Build Number:   $NEW_BUILD_NUMBER"
echo "Full Version:   $NEW_VERSION"
echo "API URL:        $API_URL"
echo "Output Size:    $BUILD_SIZE"
echo ""
echo "🌐 Frontend:    https://ppspsched.lat"
echo "🔌 API:         $API_URL"
echo ""

print_header "✅ Web Build & Deploy Complete!"
echo ""
print_info "Next steps:"
echo "  1. Test the app: https://ppspsched.lat"
echo "  2. Check nginx logs: sudo tail -f /var/log/nginx/error.log"
echo "  3. Monitor performance in browser DevTools"
echo ""
print_info "Deployment locations:"
echo "  • Web app: $DEPLOY_DIR"
echo "  • Nginx config: $NGINX_CONFIG"
echo "  • Served by: nginx (port 443, HTTPS)"
echo ""
