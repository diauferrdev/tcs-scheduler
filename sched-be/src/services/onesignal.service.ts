/**
 * OneSignal Push Notification Service
 * Sends push notifications to mobile devices (works with app closed/minimized)
 *
 * Setup:
 * 1. Create account at https://onesignal.com
 * 2. Get APP_ID and REST_API_KEY from dashboard
 * 3. Add to .env:
 *    ONESIGNAL_APP_ID=your_app_id
 *    ONESIGNAL_REST_API_KEY=your_rest_api_key
 */

interface OneSignalNotification {
  userId: string;
  title: string;
  message: string;
  data?: Record<string, any>;
}

export async function sendPushNotification(notification: OneSignalNotification) {
  const appId = process.env.ONESIGNAL_APP_ID;
  const restApiKey = process.env.ONESIGNAL_REST_API_KEY;

  if (!appId || !restApiKey) {
    console.warn('[OneSignal] Not configured. Set ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY');
    return;
  }

  try {
    const response = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${restApiKey}`,
      },
      body: JSON.stringify({
        app_id: appId,

        // Target specific user by external_user_id (your userId)
        include_external_user_ids: [notification.userId],

        // Notification content
        headings: { en: notification.title },
        contents: { en: notification.message },

        // Custom data (accessible in app)
        data: notification.data,

        // Android specific
        android_channel_id: 'booking_notifications',
        priority: 10, // High priority

        // iOS specific
        ios_sound: 'default',
        ios_badgeType: 'Increase',
        ios_badgeCount: 1,

        // Behavior
        content_available: true, // Wake app for data processing
      }),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error('[OneSignal] Error:', result);
      throw new Error(result.errors?.[0] || 'Failed to send push notification');
    }

    console.log('[OneSignal] Push sent successfully:', {
      id: result.id,
      recipients: result.recipients,
    });

    return result;
  } catch (error) {
    console.error('[OneSignal] Failed to send push notification:', error);
    throw error;
  }
}

/**
 * Send push to multiple users
 */
export async function sendPushToMultipleUsers(
  userIds: string[],
  title: string,
  message: string,
  data?: Record<string, any>
) {
  const appId = process.env.ONESIGNAL_APP_ID;
  const restApiKey = process.env.ONESIGNAL_REST_API_KEY;

  if (!appId || !restApiKey) {
    console.warn('[OneSignal] Not configured');
    return;
  }

  try {
    const response = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${restApiKey}`,
      },
      body: JSON.stringify({
        app_id: appId,
        include_external_user_ids: userIds,
        headings: { en: title },
        contents: { en: message },
        data,
        android_channel_id: 'booking_notifications',
        priority: 10,
        content_available: true,
      }),
    });

    const result = await response.json();
    console.log('[OneSignal] Bulk push sent:', result);
    return result;
  } catch (error) {
    console.error('[OneSignal] Bulk push failed:', error);
    throw error;
  }
}
