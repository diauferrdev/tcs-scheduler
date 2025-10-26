#!/bin/bash
# Fix service worker to not cache 206 responses

SW_FILE="build/web/flutter_service_worker.js"

if [ ! -f "$SW_FILE" ]; then
  echo "Service worker file not found: $SW_FILE"
  exit 1
fi

echo "Fixing service worker to handle 206 responses..."

# Backup original
cp "$SW_FILE" "${SW_FILE}.backup"

# Replace the cache.put line to check for status code
# Old: if (response && Boolean(response.ok)) {
# New: if (response && Boolean(response.ok) && response.status !== 206) {

sed -i 's/if (response && Boolean(response.ok)) {/if (response \&\& Boolean(response.ok) \&\& response.status !== 206) {/g' "$SW_FILE"

echo "✅ Service worker fixed!"
echo "   - Partial responses (206) will not be cached"
echo "   - Backup saved: ${SW_FILE}.backup"
