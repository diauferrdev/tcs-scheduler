// TCS PacePort Scheduler - Service Worker
// Handles push notifications and background sync

const CACHE_NAME = 'tcs-scheduler-v1';

// Install event
self.addEventListener('install', (event) => {
  console.log('[SW] Service Worker installing...');
  self.skipWaiting(); // Activate immediately
});

// Activate event
self.addEventListener('activate', (event) => {
  console.log('[SW] Service Worker activated');
  event.waitUntil(clients.claim()); // Take control immediately
});

// Push event - Receives push notifications from server
self.addEventListener('push', (event) => {
  console.log('[SW] Push notification received:', event);

  if (!event.data) {
    console.log('[SW] Push event but no data');
    return;
  }

  try {
    const data = event.data.json();
    console.log('[SW] Push data:', data);

    const title = data.title || 'TCS PacePort Scheduler';
    const notificationId = data.notificationId || data.type || Date.now().toString();

    const options = {
      body: data.message || data.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: {
        url: data.url || '/',
        notificationId: notificationId,
        type: data.type,
        bookingId: data.bookingId || data.data?.bookingId, // ✅ Include bookingId from FCM data
        screen: data.screen || data.data?.screen,           // ✅ Include screen from FCM data
        ...data.metadata
      },
      tag: notificationId,  // Use consistent tag to replace duplicates
      renotify: false,      // Don't vibrate when replacing
      requireInteraction: false,
      silent: false,
      vibrate: [200, 100, 200],
    };

    console.log('[SW] Showing notification with tag:', notificationId);

    event.waitUntil(
      self.registration.showNotification(title, options)
    );
  } catch (error) {
    console.error('[SW] Error handling push:', error);
    // Fallback notification
    event.waitUntil(
      self.registration.showNotification('TCS PacePort Scheduler', {
        body: 'You have a new notification',
        icon: '/icons/Icon-192.png',
      })
    );
  }
});

// Notification click event
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked:', event.notification.data);
  event.notification.close();

  // Extract notification data
  const data = event.notification.data || {};
  const bookingId = data.bookingId || data.metadata?.bookingId;
  const screen = data.screen || data.metadata?.screen;
  const type = data.type;

  console.log('[SW] Notification data:', { bookingId, screen, type });

  // Build navigation URL based on screen and bookingId
  let urlToOpen = '/';
  if (screen === 'approvals' && bookingId) {
    urlToOpen = `/app/approvals?bookingId=${bookingId}`;
  } else if (screen === 'my_bookings') {
    urlToOpen = bookingId ? `/app/my-bookings?bookingId=${bookingId}` : '/app/my-bookings';
  } else if (screen === 'booking_details' && bookingId) {
    urlToOpen = `/app/booking/${bookingId}`;
  } else if (bookingId) {
    // Default: navigate to booking details if we have a bookingId
    urlToOpen = `/app/booking/${bookingId}`;
  }

  console.log('[SW] Navigating to:', urlToOpen);

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Find any open window from the same origin
      for (const client of clientList) {
        // Check if client is from our app (same origin)
        if (client.url.includes(self.location.origin)) {
          console.log('[SW] Found open window, focusing...');
          // ✅ Focus the window first
          client.focus();

          // ✅ Send navigation message to Flutter app via postMessage
          console.log('[SW] Sending navigation message to Flutter:', urlToOpen);
          client.postMessage({
            type: 'NOTIFICATION_CLICK',
            url: urlToOpen,
            bookingId: bookingId,
            screen: screen,
          });

          return Promise.resolve();
        }
      }

      // If no window is open, open a new one
      console.log('[SW] No open window found, opening new window...');
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});

// Notification close event
self.addEventListener('notificationclose', (event) => {
  console.log('[SW] Notification closed:', event.notification.data);
});

// Message event - Communication with Flutter app
self.addEventListener('message', (event) => {
  console.log('[SW] Message received:', event.data);

  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

// Fetch event - Optional: Add offline support
self.addEventListener('fetch', (event) => {
  // For now, just pass through all requests
  // You can add caching strategies here if needed
  event.respondWith(fetch(event.request));
});

console.log('[SW] Service Worker script loaded');
