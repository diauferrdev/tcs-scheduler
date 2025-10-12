import { useState, useEffect, useCallback } from 'react';
import { api } from '@/lib/api';
import { toast } from 'sonner';

interface UsePushNotificationsReturn {
  isSupported: boolean;
  permission: NotificationPermission;
  isSubscribed: boolean;
  isLoading: boolean;
  subscribe: () => Promise<void>;
  unsubscribe: () => Promise<void>;
  requestPermission: () => Promise<NotificationPermission>;
  sendTestNotification: () => Promise<void>;
}

/**
 * Custom hook for managing push notifications
 * Handles subscription, permission requests, and push notification management
 */
export function usePushNotifications(): UsePushNotificationsReturn {
  const [isSupported, setIsSupported] = useState(false);
  const [permission, setPermission] = useState<NotificationPermission>('default');
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [registration, setRegistration] = useState<ServiceWorkerRegistration | null>(null);

  // Check if push notifications are supported
  useEffect(() => {
    const checkSupport = () => {
      const supported =
        'serviceWorker' in navigator &&
        'PushManager' in window &&
        'Notification' in window;

      setIsSupported(supported);

      if (supported) {
        setPermission(Notification.permission);
      }
    };

    checkSupport();
  }, []);

  // Get service worker registration
  useEffect(() => {
    const getRegistration = async () => {
      if (!isSupported) {
        setIsLoading(false);
        return;
      }

      try {
        const reg = await navigator.serviceWorker.ready;
        setRegistration(reg);

        // Check if already subscribed
        const subscription = await reg.pushManager.getSubscription();
        setIsSubscribed(!!subscription);
      } catch (error) {
        console.error('Error getting service worker registration:', error);
      } finally {
        setIsLoading(false);
      }
    };

    getRegistration();
  }, [isSupported]);

  /**
   * Request notification permission from the user
   */
  const requestPermission = useCallback(async (): Promise<NotificationPermission> => {
    if (!isSupported) {
      throw new Error('Push notifications are not supported in this browser');
    }

    try {
      const result = await Notification.requestPermission();
      setPermission(result);
      return result;
    } catch (error) {
      console.error('Error requesting notification permission:', error);
      throw error;
    }
  }, [isSupported]);

  /**
   * Convert base64 string to Uint8Array
   */
  const urlBase64ToUint8Array = (base64String: string): Uint8Array => {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  };

  /**
   * Subscribe to push notifications
   */
  const subscribe = useCallback(async () => {
    if (!isSupported) {
      toast.error('Push notifications are not supported in this browser');
      return;
    }

    if (!registration) {
      toast.error('Service worker not ready');
      return;
    }

    setIsLoading(true);

    try {
      // Request permission if not granted
      let perm = permission;
      if (perm !== 'granted') {
        perm = await requestPermission();
      }

      if (perm !== 'granted') {
        toast.error('Notification permission denied');
        return;
      }

      // Get VAPID public key from backend
      const { data: vapidData } = await api.get('/api/push/vapid-public-key');
      const publicKey = vapidData.publicKey;

      if (!publicKey) {
        toast.error('VAPID public key not available');
        return;
      }

      // Subscribe to push manager
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(publicKey),
      });

      // Send subscription to backend
      await api.post('/api/push/subscribe', subscription.toJSON());

      setIsSubscribed(true);
      toast.success('✅ Push notifications enabled!');
    } catch (error: any) {
      console.error('Error subscribing to push notifications:', error);
      toast.error('Failed to enable push notifications');
    } finally {
      setIsLoading(false);
    }
  }, [isSupported, registration, permission, requestPermission]);

  /**
   * Unsubscribe from push notifications
   */
  const unsubscribe = useCallback(async () => {
    if (!registration) {
      return;
    }

    setIsLoading(true);

    try {
      const subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        // Unsubscribe from push manager
        await subscription.unsubscribe();

        // Remove subscription from backend
        await api.post('/api/push/unsubscribe', {
          endpoint: subscription.endpoint,
        });

        setIsSubscribed(false);
        toast.success('Push notifications disabled');
      }
    } catch (error) {
      console.error('Error unsubscribing from push notifications:', error);
      toast.error('Failed to disable push notifications');
    } finally {
      setIsLoading(false);
    }
  }, [registration]);

  /**
   * Send a test notification
   */
  const sendTestNotification = useCallback(async () => {
    if (!isSubscribed) {
      toast.error('Please enable notifications first');
      return;
    }

    try {
      await api.post('/api/push/test', {
        title: '🔔 Test Notification',
        body: 'This is a test notification from TCS PacePort Scheduler',
        icon: '/pwa-192x192.png',
        badge: '/pwa-192x192.png',
        url: '/calendar',
      });

      toast.success('Test notification sent!');
    } catch (error) {
      console.error('Error sending test notification:', error);
      toast.error('Failed to send test notification');
    }
  }, [isSubscribed]);

  return {
    isSupported,
    permission,
    isSubscribed,
    isLoading,
    subscribe,
    unsubscribe,
    requestPermission,
    sendTestNotification,
  };
}
