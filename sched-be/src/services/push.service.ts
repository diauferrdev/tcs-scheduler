/**
 * Firebase Cloud Messaging V1 API Service
 * Sends push notifications to mobile devices (works with app closed/minimized)
 *
 * Uses FCM V1 API (not legacy Server Key API)
 * Requires Service Account JSON file
 *
 * Storage: Prisma database (FCMToken and FCMAnalytics models)
 */

import { readFileSync } from 'fs';
import { join } from 'path';
import { prisma } from '../lib/prisma';

interface PushNotification {
  title: string;
  body: string;
  data?: Record<string, string>; // FCM V1 requires all data values to be strings
}

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
  auth_provider_x509_cert_url: string;
  client_x509_cert_url: string;
}

let serviceAccount: ServiceAccount | null = null;
let accessToken: string | null = null;
let tokenExpiry: number = 0;

/**
 * Load Firebase Service Account
 */
function loadServiceAccount(): ServiceAccount | null {
  if (serviceAccount) return serviceAccount;

  try {
    const serviceAccountPath = join(process.cwd(), 'firebase-service-account.json');
    const content = readFileSync(serviceAccountPath, 'utf-8');
    serviceAccount = JSON.parse(content);
    console.log(`[FCM] Service account loaded: ${serviceAccount.project_id}`);
    return serviceAccount;
  } catch (error) {
    console.warn('[FCM] Firebase service account not found. Place firebase-service-account.json in project root.');
    console.warn('[FCM] Download from: Firebase Console → Project Settings → Service Accounts → Generate New Private Key');
    return null;
  }
}

/**
 * Generate OAuth 2.0 Access Token using Service Account
 * Required for FCM V1 API
 */
async function getAccessToken(): Promise<string | null> {
  // Return cached token if still valid
  if (accessToken && Date.now() < tokenExpiry) {
    return accessToken;
  }

  const account = loadServiceAccount();
  if (!account) return null;

  try {
    // Create JWT assertion
    const now = Math.floor(Date.now() / 1000);
    const expiry = now + 3600; // 1 hour

    const header = {
      alg: 'RS256',
      typ: 'JWT',
    };

    const payload = {
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: account.token_uri,
      exp: expiry,
      iat: now,
    };

    // Encode header and payload
    const base64url = (data: object): string => {
      return Buffer.from(JSON.stringify(data))
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
    };

    const encodedHeader = base64url(header);
    const encodedPayload = base64url(payload);
    const signatureInput = `${encodedHeader}.${encodedPayload}`;

    // Sign with private key
    const crypto = await import('crypto');
    const sign = crypto.createSign('RSA-SHA256');
    sign.update(signatureInput);
    sign.end();

    const signature = sign.sign(account.private_key, 'base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');

    const jwt = `${signatureInput}.${signature}`;

    // Exchange JWT for access token
    const response = await fetch(account.token_uri, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error('[FCM] Failed to get access token:', result);
      return null;
    }

    accessToken = result.access_token;
    tokenExpiry = Date.now() + (result.expires_in * 1000) - 60000; // Refresh 1 min before expiry

    console.log('[FCM] ✅ Access token obtained');
    return accessToken;
  } catch (error) {
    console.error('[FCM] Error getting access token:', error);
    return null;
  }
}

/**
 * Store FCM token for a user in database
 * @param userId - User ID
 * @param token - FCM token
 * @param deviceInfo - Optional device information (model, OS version, etc)
 */
export async function registerFCMToken(
  userId: string,
  token: string,
  deviceInfo?: string
): Promise<void> {
  try {
    // Upsert token: if exists, update lastUsedAt and mark as valid
    // If new, create with current timestamp
    await prisma.fCMToken.upsert({
      where: { token },
      update: {
        lastUsedAt: new Date(),
        isValid: true,
        deviceInfo: deviceInfo || undefined,
      },
      create: {
        userId,
        token,
        deviceInfo: deviceInfo || null,
        lastUsedAt: new Date(),
        isValid: true,
      },
    });

    // Get total token count for user
    const tokenCount = await prisma.fCMToken.count({
      where: { userId, isValid: true },
    });

    console.log(`[FCM] Token registered for user ${userId} (total valid tokens: ${tokenCount})`);
  } catch (error) {
    console.error(`[FCM] Error registering token for user ${userId}:`, error);
    throw error;
  }
}

/**
 * Remove FCM token for a user from database (on logout)
 * @param userId - User ID
 * @param token - FCM token to remove
 */
export async function unregisterFCMToken(
  userId: string,
  token: string
): Promise<void> {
  try {
    // Delete the token from database
    const deletedToken = await prisma.fCMToken.deleteMany({
      where: {
        userId,
        token,
      },
    });

    if (deletedToken.count > 0) {
      console.log(`[FCM] Token unregistered for user ${userId}`);
    } else {
      console.warn(`[FCM] Token not found for user ${userId}`);
    }
  } catch (error) {
    console.error(`[FCM] Error unregistering token for user ${userId}:`, error);
    throw error;
  }
}

/**
 * Get all valid tokens for a user from database
 * @param userId - User ID
 * @returns Array of valid FCM token strings
 */
export async function getTokensForUser(userId: string): Promise<string[]> {
  try {
    const tokens = await prisma.fCMToken.findMany({
      where: {
        userId,
        isValid: true,
      },
      select: {
        token: true,
      },
    });

    return tokens.map(t => t.token);
  } catch (error) {
    console.error(`[FCM] Error getting tokens for user ${userId}:`, error);
    return [];
  }
}

/**
 * Send push notification to specific user
 * Sends to all valid registered devices for the user
 * @param userId - User ID to send notification to
 * @param notification - Push notification payload
 */
export async function sendPushToUser(
  userId: string,
  notification: PushNotification
): Promise<void> {
  try {
    const tokens = await getTokensForUser(userId);

    if (tokens.length === 0) {
      console.warn(`[FCM] No valid tokens found for user ${userId}`);
      return;
    }

    const account = loadServiceAccount();
    if (!account) {
      console.warn('[FCM] Service account not configured');
      return;
    }

    console.log(`[FCM] Sending push to user ${userId} (${tokens.length} device(s))`);

    // Send to all tokens (user may have multiple devices)
    const promises = tokens.map(token =>
      sendPushToToken(token, notification, account.project_id, userId)
    );

    await Promise.allSettled(promises);
  } catch (error) {
    console.error(`[FCM] Error sending push to user ${userId}:`, error);
  }
}

/**
 * Send push notification to multiple users
 * @param userIds - Array of user IDs to send notification to
 * @param notification - Push notification payload
 */
export async function sendPushToMultipleUsers(
  userIds: string[],
  notification: PushNotification
): Promise<void> {
  console.log(`[FCM] Sending push to ${userIds.length} user(s)`);
  const promises = userIds.map(userId => sendPushToUser(userId, notification));
  await Promise.allSettled(promises);
}

/**
 * Send push notification to specific FCM token using V1 API
 * Creates FCMAnalytics record before sending, updates it based on result
 * @param token - FCM token to send to
 * @param notification - Push notification payload
 * @param projectId - Firebase project ID
 * @param userId - User ID (for analytics)
 */
async function sendPushToToken(
  token: string,
  notification: PushNotification,
  projectId: string,
  userId: string
): Promise<void> {
  let analyticsId: string | null = null;
  let fcmTokenRecord: { id: string } | null = null;

  try {
    // Get FCMToken record ID for analytics
    fcmTokenRecord = await prisma.fCMToken.findUnique({
      where: { token },
      select: { id: true },
    });

    // Create analytics record BEFORE sending
    const analytics = await prisma.fCMAnalytics.create({
      data: {
        userId,
        fcmTokenId: fcmTokenRecord?.id || null,
        title: notification.title,
        message: notification.body,
        sentAt: new Date(),
        delivered: false,
        failed: false,
        metadata: notification.data ? JSON.parse(JSON.stringify(notification.data)) : null,
      },
    });
    analyticsId = analytics.id;

    // Get access token
    const accessToken = await getAccessToken();
    if (!accessToken) {
      console.error('[FCM] No access token available');

      // Update analytics: failed
      await prisma.fCMAnalytics.update({
        where: { id: analyticsId },
        data: {
          failed: true,
          failureReason: 'No access token available',
        },
      });

      return;
    }

    // Convert data object values to strings (FCM V1 requirement)
    const dataStrings: Record<string, string> = {};
    if (notification.data) {
      for (const [key, value] of Object.entries(notification.data)) {
        dataStrings[key] = String(value);
      }
    }

    // Send FCM request
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: token,
            notification: {
              title: notification.title,
              body: notification.body,
            },
            data: dataStrings,
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channelId: 'booking_notifications',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                  'content-available': 1,
                },
              },
            },
          },
        }),
      }
    );

    const result = await response.json();

    if (!response.ok) {
      console.error('[FCM] Failed to send push:', result);

      // Check for invalid/unregistered token errors
      const errorCode = result.error?.details?.[0]?.errorCode || result.error?.code;
      const isInvalidToken =
        errorCode === 'UNREGISTERED' ||
        errorCode === 'INVALID_ARGUMENT' ||
        result.error?.message?.includes('not a valid FCM registration token');

      if (isInvalidToken) {
        console.warn('[FCM] Token is invalid/unregistered, marking as invalid in database');

        // Mark token as invalid in database
        if (fcmTokenRecord) {
          await prisma.fCMToken.update({
            where: { id: fcmTokenRecord.id },
            data: { isValid: false },
          });
        }

        // Update analytics: failed with reason
        await prisma.fCMAnalytics.update({
          where: { id: analyticsId },
          data: {
            failed: true,
            failureReason: `Invalid/Unregistered Token: ${errorCode || result.error?.message}`,
          },
        });
      } else {
        // Other FCM error
        await prisma.fCMAnalytics.update({
          where: { id: analyticsId },
          data: {
            failed: true,
            failureReason: `FCM Error: ${result.error?.message || 'Unknown error'}`,
          },
        });
      }
    } else {
      // Success: update analytics and token lastUsedAt
      console.log('[FCM] ✅ Push sent successfully:', {
        messageId: result.name,
        userId,
      });

      await prisma.fCMAnalytics.update({
        where: { id: analyticsId },
        data: {
          delivered: true,
          deliveredAt: new Date(),
        },
      });

      // Update FCMToken lastUsedAt
      if (fcmTokenRecord) {
        await prisma.fCMToken.update({
          where: { id: fcmTokenRecord.id },
          data: { lastUsedAt: new Date() },
        });
      }
    }
  } catch (error) {
    console.error('[FCM] Error sending push:', error);

    // Update analytics if we have the ID
    if (analyticsId) {
      try {
        await prisma.fCMAnalytics.update({
          where: { id: analyticsId },
          data: {
            failed: true,
            failureReason: error instanceof Error ? error.message : 'Unknown error',
          },
        });
      } catch (updateError) {
        console.error('[FCM] Error updating analytics after failure:', updateError);
      }
    }
  }
}

/**
 * Send a test notification
 * @param token - FCM token to send test notification to
 */
export async function sendTestPush(token: string): Promise<void> {
  const account = loadServiceAccount();
  if (!account) {
    throw new Error('Service account not configured');
  }

  // Get userId from token (for analytics)
  const fcmToken = await prisma.fCMToken.findUnique({
    where: { token },
    select: { userId: true },
  });

  if (!fcmToken) {
    throw new Error('Token not found in database');
  }

  await sendPushToToken(
    token,
    {
      title: 'Test Notification',
      body: 'This is a test push notification from TCS PacePort Scheduler',
      data: {
        test: 'true',
        timestamp: Date.now().toString(),
      },
    },
    account.project_id,
    fcmToken.userId
  );
}

/**
 * Web Push Subscription Types (for Web browsers, not mobile apps)
 * NOTE: We're using FCM for mobile, but keeping this for web browser support
 */
interface PushSubscription {
  endpoint: string;
  expirationTime?: number | null;
  keys: {
    p256dh: string;
    auth: string;
  };
}

/**
 * Subscribe to Web Push notifications (for web browsers)
 * NOTE: This is separate from FCM tokens (which are for mobile apps)
 * @param userId - User ID
 * @param subscription - Web Push subscription object
 * @param userAgent - Browser user agent string
 */
export async function subscribeToPush(
  userId: string,
  subscription: PushSubscription,
  userAgent?: string
): Promise<{ success: boolean; message: string }> {
  try {
    console.log(`[Web Push] Subscription request from user ${userId}`);
    console.log('[Web Push] Note: Using FCM for actual notifications, web push subscription saved for reference');

    // For now, we're using FCM for notifications
    // This endpoint exists for compatibility but doesn't actually send web push
    // The web app should use FCM tokens instead

    return {
      success: true,
      message: 'Subscription received (using FCM for notifications)',
    };
  } catch (error) {
    console.error('[Web Push] Error subscribing:', error);
    throw new Error('Failed to subscribe to push notifications');
  }
}

/**
 * Unsubscribe from Web Push notifications
 * @param userId - User ID
 * @param endpoint - Web Push endpoint URL
 */
export async function unsubscribeFromPush(
  userId: string,
  endpoint: string
): Promise<void> {
  console.log(`[Web Push] Unsubscribe request from user ${userId}`);
  // Since we're using FCM, no action needed
}

/**
 * Get all Web Push subscriptions for a user
 * @param userId - User ID
 * @returns Array of subscriptions (empty since we use FCM)
 */
export async function getUserSubscriptions(userId: string): Promise<any[]> {
  console.log(`[Web Push] Get subscriptions for user ${userId}`);
  // Since we're using FCM, return empty array
  return [];
}

/**
 * Send push to user using role
 * @param role - User role
 * @param notification - Notification payload
 */
export async function sendPushToRole(
  role: 'ADMIN' | 'MANAGER' | 'GUEST',
  notification: PushNotification
): Promise<void> {
  console.log(`[FCM] Sending push to all users with role: ${role}`);

  // Get all users with this role
  const users = await prisma.user.findMany({
    where: {
      role,
      isActive: true,
    },
    select: {
      id: true,
    },
  });

  const userIds = users.map(u => u.id);
  await sendPushToMultipleUsers(userIds, notification);
}
