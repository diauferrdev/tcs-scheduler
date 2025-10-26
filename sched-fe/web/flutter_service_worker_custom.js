// Custom Service Worker Configuration
// Wraps Flutter's default service worker to handle 206 errors

const FLUTTER_SW = 'flutter_service_worker.js';

// Import Flutter's service worker
self.importScripts(FLUTTER_SW);

// Override fetch to handle 206 responses
const originalFetch = self.fetch;
self.addEventListener('fetch', (event) => {
  event.respondWith(
    originalFetch(event.request)
      .then((response) => {
        // Don't cache partial responses (206)
        if (response.status === 206) {
          console.log('[SW] Skipping cache for 206 response:', event.request.url);
          return response;
        }

        // Let Flutter's SW handle the rest
        return response;
      })
      .catch((error) => {
        console.error('[SW] Fetch failed:', error);
        throw error;
      })
  );
});

console.log('[SW Custom] Service worker wrapper loaded');
