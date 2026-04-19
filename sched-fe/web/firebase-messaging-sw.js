/**
 * Firebase Cloud Messaging Service Worker
 * Handles background push notifications when app is closed/minimized
 */

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase app in service worker
// Note: This uses the same config as the main app
firebase.initializeApp({
  apiKey: "AIzaSyDrGoDIT_Ea9-_Asc7VKoZ_7dEhF2YLMng",
  authDomain: "tcs-paceport-scheduler.firebaseapp.com",
  projectId: "tcs-paceport-scheduler",
  storageBucket: "tcs-paceport-scheduler.firebasestorage.app",
  messagingSenderId: "874457674237",
  appId: "1:874457674237:web:3178aef43c686e2c9fa994"
});

const messaging = firebase.messaging();

// Handle background messages (when app is closed/minimized)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message received:', payload);

  const notificationTitle = payload.notification?.title || payload.data?.title || 'TCS Pace Scheduler';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.message || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
    tag: payload.data?.bookingId || 'default',
    requireInteraction: false,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click received:', event);

  event.notification.close();

  // Extract navigation data
  const data = event.notification.data || {};
  const screen = data.screen || 'notifications';
  const bookingId = data.bookingId;

  // Build URL based on screen
  let url = '/';
  if (screen === 'booking_details' && bookingId) {
    url = `/booking/${bookingId}`;
  } else if (screen === 'my_bookings') {
    url = '/my-visits';
  } else if (screen === 'approvals') {
    url = '/approvals';
  } else if (screen === 'calendar') {
    url = '/calendar';
  } else if (screen === 'notifications') {
    url = '/notifications';
  }

  // Open or focus window
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Check if app is already open
      for (const client of clientList) {
        if (client.url.includes(url) && 'focus' in client) {
          return client.focus();
        }
      }
      // Open new window if not already open
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});
