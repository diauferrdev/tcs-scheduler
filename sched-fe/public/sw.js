// TCS PacePort Scheduler - Service Worker
const CACHE_NAME = 'tcs-scheduler-v1';
const RUNTIME_CACHE = 'tcs-scheduler-runtime-v1';

// Assets to cache on install
const PRECACHE_URLS = [
  '/',
  '/manifest.json',
  '/pwa-192x192.png',
  '/pwa-512x512.png',
];

// Install event - cache essential assets
self.addEventListener('install', (event) => {
  console.log('Service Worker installing...');
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => {
        console.log('Precaching app shell');
        return cache.addAll(PRECACHE_URLS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('Service Worker activating...');
  event.waitUntil(
    caches
      .keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((cacheName) => {
              return cacheName !== CACHE_NAME && cacheName !== RUNTIME_CACHE;
            })
            .map((cacheName) => {
              console.log('Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            })
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch event - network first, fallback to cache
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip cross-origin requests
  if (url.origin !== location.origin) {
    return;
  }

  // Skip API requests from caching
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(fetch(request));
    return;
  }

  // Network first, fallback to cache
  event.respondWith(
    fetch(request)
      .then((response) => {
        // Cache successful responses
        if (response.status === 200) {
          const responseClone = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => {
            cache.put(request, responseClone);
          });
        }
        return response;
      })
      .catch(() => {
        // Network failed, try cache
        return caches.match(request).then((response) => {
          if (response) {
            return response;
          }
          // If not in cache, return offline page or error
          return new Response('Offline - Content not available', {
            status: 503,
            statusText: 'Service Unavailable',
            headers: new Headers({
              'Content-Type': 'text/plain',
            }),
          });
        });
      })
  );
});

// Push notification event - Enhanced for background operation on Android
self.addEventListener('push', (event) => {
  console.log('[Service Worker] Push notification received:', event);
  console.log('[Service Worker] Service Worker is active and processing push event');

  let data;
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    console.error('[Service Worker] Error parsing push data:', e);
    data = {
      title: 'TCS PacePort Scheduler',
      body: event.data ? event.data.text() : 'You have a new notification',
    };
  }

  const title = data.title || 'TCS PacePort Scheduler';

  // Enhanced options for better Android background behavior
  const options = {
    body: data.body || 'You have a new notification',
    icon: data.icon || '/pwa-192x192.png',
    badge: data.badge || '/pwa-192x192.png',
    vibrate: data.vibrate || [200, 100, 200],
    tag: data.tag || `notification-${Date.now()}`,
    // requireInteraction true makes notification persistent on Android
    // User must dismiss or interact - won't auto-dismiss
    requireInteraction: data.requireInteraction !== undefined ? data.requireInteraction : true,
    data: data.data || {},
    actions: data.actions || [],
    silent: false,
    renotify: true,
    timestamp: Date.now(),
    // Additional options for better mobile experience
    dir: 'auto',
    lang: 'en-US',
  };

  // Important: Always show notification in push event
  // Even if app is in foreground, SW must show notification
  event.waitUntil(
    Promise.all([
      // Show notification
      self.registration.showNotification(title, options)
        .then(() => {
          console.log('[Service Worker] Notification displayed successfully');
          console.log('[Service Worker] Notification options:', options);
        })
        .catch((error) => {
          console.error('[Service Worker] Error showing notification:', error);
        }),

      // Optional: Track notification received (for analytics)
      trackNotificationReceived(data)
    ])
  );
});

// Helper function to track notifications (can be used for analytics)
async function trackNotificationReceived(data) {
  try {
    console.log('[Service Worker] Notification received and tracked:', data);
    // Could send analytics here if needed
  } catch (error) {
    console.error('[Service Worker] Error tracking notification:', error);
  }
}

// Notification click event - Enhanced with action handling
self.addEventListener('notificationclick', (event) => {
  console.log('[Service Worker] Notification clicked:', event.action);

  event.notification.close();

  // Determine URL based on action or data
  let urlToOpen = '/';

  if (event.action) {
    // Handle specific action clicks
    switch (event.action) {
      case 'view':
        urlToOpen = event.notification.data?.url || '/calendar';
        break;
      case 'dismiss':
        console.log('[Service Worker] Notification dismissed');
        return; // Just close the notification
      default:
        urlToOpen = event.notification.data?.url || '/';
    }
  } else {
    // Handle general notification click
    urlToOpen = event.notification.data?.url || '/';
  }

  // Make URL absolute
  const baseUrl = self.location.origin;
  const absoluteUrl = new URL(urlToOpen, baseUrl).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        console.log('[Service Worker] Found', clientList.length, 'window clients');

        // Check if there's already a window with this URL
        for (const client of clientList) {
          const clientUrl = new URL(client.url);
          const targetUrl = new URL(absoluteUrl);

          // Match by pathname (ignore query params for focus check)
          if (clientUrl.pathname === targetUrl.pathname && 'focus' in client) {
            console.log('[Service Worker] Focusing existing window');
            return client.focus();
          }
        }

        // Check if any window is open (focus the first one and navigate)
        if (clientList.length > 0) {
          console.log('[Service Worker] Navigating existing window to:', absoluteUrl);
          return clientList[0].focus().then(client => {
            if ('navigate' in client) {
              return client.navigate(absoluteUrl);
            }
            // If navigate not supported, open new window
            return clients.openWindow(absoluteUrl);
          });
        }

        // If no window is open, open a new one
        if (clients.openWindow) {
          console.log('[Service Worker] Opening new window:', absoluteUrl);
          return clients.openWindow(absoluteUrl);
        }
      })
      .catch((error) => {
        console.error('[Service Worker] Error handling notification click:', error);
      })
  );
});

// Notification close event - for analytics/cleanup
self.addEventListener('notificationclose', (event) => {
  console.log('[Service Worker] Notification closed:', event.notification.tag);
  // Can be used for tracking dismissed notifications
});

// Background sync event (for offline actions)
self.addEventListener('sync', (event) => {
  console.log('Background sync:', event);
  if (event.tag === 'sync-bookings') {
    event.waitUntil(syncBookings());
  }
});

async function syncBookings() {
  // Placeholder for syncing bookings when back online
  console.log('Syncing bookings...');
}

console.log('Service Worker loaded successfully');
