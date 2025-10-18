#!/bin/bash

# Production Build Script for TCS PacePort Scheduler
# Este script faz o build de produção com a URL da API correta

set -e

echo "🚀 Starting production build..."

# Check if API_URL is set, use default if not provided
if [ -z "$API_URL" ]; then
    API_URL="https://api.ppspsched.lat"
    echo "⚠️  Using default API_URL: $API_URL"
    echo "   To use a different URL, run: API_URL=https://your-api.com ./web.sh"
    echo ""
fi

echo "📝 Configuration:"
echo "   API URL: $API_URL"
echo ""

# Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web production
echo "🏗️  Building for web production..."
flutter build web \
    --release \
    --dart-define=API_URL=$API_URL \
    --source-maps

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "📁 Output directory: build/web/"
echo ""
echo "Next steps:"
echo "1. Upload build/web/ contents to your VPS: /var/www/scheduler/tcs_pace_scheduler/build/web"
echo "2. Set correct permissions: sudo chown -R www-data:www-data build/web"
echo "3. Restart Nginx: sudo systemctl reload nginx"
echo ""
echo "Or use rsync to deploy:"
echo "rsync -avz --delete build/web/ user@your-vps:/var/www/scheduler/tcs_pace_scheduler/build/web/"
