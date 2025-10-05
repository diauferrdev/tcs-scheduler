import webpush from 'web-push';
import { prisma } from '../lib/prisma';

// Configure VAPID details
const vapidDetails = {
  subject: process.env.VAPID_SUBJECT || 'mailto:noreply@tcs.com',
  publicKey: process.env.VAPID_PUBLIC_KEY || '',
  privateKey: process.env.VAPID_PRIVATE_KEY || '',
};

// Set VAPID details for web-push
if (vapidDetails.publicKey && vapidDetails.privateKey) {
  webpush.setVapidDetails(
    vapidDetails.subject,
    vapidDetails.publicKey,
    vapidDetails.privateKey
  );
}

export interface PushPayload {
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  data?: any;
  actions?: Array<{
    action: string;
    title: string;
    icon?: string;
  }>;
  url?: string;
  requireInteraction?: boolean; // Makes notification persistent (won't auto-dismiss)
}

/**
 * Subscribe user to push notifications
 */
export async function subscribeToPush(
  userId: string,
  subscription: PushSubscriptionJSON,
  userAgent?: string
) {
  if (!subscription.endpoint) {
    throw new Error('Invalid subscription: missing endpoint');
  }

  try {
    // Check if subscription already exists
    const existing = await prisma.pushSubscription.findUnique({
      where: { endpoint: subscription.endpoint },
    });

    if (existing) {
      // Update existing subscription
      return await prisma.pushSubscription.update({
        where: { endpoint: subscription.endpoint },
        data: {
          keys: subscription.keys as any,
          userAgent,
          updatedAt: new Date(),
        },
      });
    }

    // Create new subscription
    return await prisma.pushSubscription.create({
      data: {
        userId,
        endpoint: subscription.endpoint,
        keys: subscription.keys as any,
        userAgent,
      },
    });
  } catch (error) {
    console.error('Error subscribing to push:', error);
    throw error;
  }
}

/**
 * Unsubscribe from push notifications
 */
export async function unsubscribeFromPush(userId: string, endpoint: string) {
  try {
    return await prisma.pushSubscription.deleteMany({
      where: {
        userId,
        endpoint,
      },
    });
  } catch (error) {
    console.error('Error unsubscribing from push:', error);
    throw error;
  }
}

/**
 * Get all push subscriptions for a user
 */
export async function getUserSubscriptions(userId: string) {
  return await prisma.pushSubscription.findMany({
    where: { userId },
  });
}

/**
 * Send push notification to a specific user
 */
export async function sendPushToUser(userId: string, payload: PushPayload) {
  try {
    // Get all user's subscriptions
    const subscriptions = await prisma.pushSubscription.findMany({
      where: { userId },
    });

    if (subscriptions.length === 0) {
      console.log(`No push subscriptions found for user ${userId}`);
      return { sent: 0, failed: 0 };
    }

    // Prepare notification payload
    // Enhanced for better Android background behavior
    const notificationPayload = JSON.stringify({
      title: payload.title,
      body: payload.body,
      icon: payload.icon || '/pwa-192x192.png',
      badge: payload.badge || '/pwa-192x192.png',
      // requireInteraction makes notification persistent on Android
      // Set to true for important notifications (bookings, updates)
      // Set to false for less important notifications
      requireInteraction: payload.data?.requireInteraction !== undefined
        ? payload.data.requireInteraction
        : true, // Default to persistent
      data: {
        ...payload.data,
        url: payload.url || '/',
        timestamp: Date.now(),
      },
      actions: payload.actions || [],
      vibrate: [200, 100, 200], // Vibration pattern
      tag: payload.data?.tag || `notification-${Date.now()}`,
      renotify: true, // Always notify even if tag is the same
    });

    // Send to all user's devices
    const results = await Promise.allSettled(
      subscriptions.map(async (sub) => {
        try {
          const pushSubscription = {
            endpoint: sub.endpoint,
            keys: sub.keys as any,
          };

          await webpush.sendNotification(pushSubscription, notificationPayload);
          return { success: true, endpoint: sub.endpoint };
        } catch (error: any) {
          console.error(`Failed to send push to ${sub.endpoint}:`, error);

          // If subscription is no longer valid, remove it
          if (error.statusCode === 410 || error.statusCode === 404) {
            await prisma.pushSubscription.delete({
              where: { id: sub.id },
            });
            console.log(`Removed invalid subscription: ${sub.endpoint}`);
          }

          return { success: false, endpoint: sub.endpoint, error };
        }
      })
    );

    const sent = results.filter(
      (r) => r.status === 'fulfilled' && r.value.success
    ).length;
    const failed = results.length - sent;

    console.log(
      `Push notification sent to user ${userId}: ${sent} sent, ${failed} failed`
    );

    return { sent, failed };
  } catch (error) {
    console.error('Error sending push notification:', error);
    throw error;
  }
}

/**
 * Send push notification to multiple users
 */
export async function sendPushToUsers(userIds: string[], payload: PushPayload) {
  const results = await Promise.allSettled(
    userIds.map((userId) => sendPushToUser(userId, payload))
  );

  const totalSent = results.reduce(
    (acc, r) => acc + (r.status === 'fulfilled' ? r.value.sent : 0),
    0
  );
  const totalFailed = results.reduce(
    (acc, r) => acc + (r.status === 'fulfilled' ? r.value.failed : 0),
    0
  );

  return { sent: totalSent, failed: totalFailed };
}

/**
 * Send push notification to all users with a specific role
 */
export async function sendPushToRole(
  role: 'ADMIN' | 'MANAGER' | 'GUEST',
  payload: PushPayload
) {
  try {
    // Get all users with the specified role
    const users = await prisma.user.findMany({
      where: {
        role,
        isActive: true,
      },
      select: { id: true },
    });

    const userIds = users.map((u) => u.id);
    return await sendPushToUsers(userIds, payload);
  } catch (error) {
    console.error('Error sending push to role:', error);
    throw error;
  }
}

/**
 * Send push notification about a new booking
 */
export async function sendNewBookingNotification(bookingId: string) {
  try {
    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        attendees: true,
      },
    });

    if (!booking) {
      throw new Error('Booking not found');
    }

    const payload: PushPayload = {
      title: '🎯 New Booking Created',
      body: `${booking.companyName} - ${new Date(booking.date).toLocaleDateString()}`,
      icon: '/pwa-192x192.png',
      badge: '/pwa-192x192.png',
      requireInteraction: true, // Persistent notification for important bookings
      data: {
        type: 'NEW_BOOKING',
        bookingId: booking.id,
      },
      url: `/calendar?booking=${booking.id}`,
      actions: [
        {
          action: 'view',
          title: 'View Booking',
        },
      ],
    };

    // Send to all admins and managers
    await sendPushToRole('ADMIN', payload);
    await sendPushToRole('MANAGER', payload);

    console.log(`New booking notification sent for booking ${bookingId}`);
  } catch (error) {
    console.error('Error sending new booking notification:', error);
    throw error;
  }
}

/**
 * Send push notification about a booking update
 */
export async function sendBookingUpdateNotification(bookingId: string) {
  try {
    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        createdBy: true,
        attendees: true,
      },
    });

    if (!booking) {
      throw new Error('Booking not found');
    }

    const payload: PushPayload = {
      title: '📝 Booking Updated',
      body: `${booking.companyName} - ${new Date(booking.date).toLocaleDateString()}`,
      icon: '/pwa-192x192.png',
      badge: '/pwa-192x192.png',
      requireInteraction: true, // Persistent notification for updates
      data: {
        type: 'BOOKING_UPDATED',
        bookingId: booking.id,
      },
      url: `/calendar?booking=${booking.id}`,
    };

    // Send to booking creator if exists
    if (booking.createdById) {
      await sendPushToUser(booking.createdById, payload);
    }

    // Also notify admins
    await sendPushToRole('ADMIN', payload);

    console.log(`Booking update notification sent for booking ${bookingId}`);
  } catch (error) {
    console.error('Error sending booking update notification:', error);
    throw error;
  }
}

/**
 * Send push notification about a booking cancellation
 */
export async function sendBookingCancelledNotification(bookingId: string) {
  try {
    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        createdBy: true,
        attendees: true,
      },
    });

    if (!booking) {
      throw new Error('Booking not found');
    }

    const payload: PushPayload = {
      title: '❌ Booking Cancelled',
      body: `${booking.companyName} - ${new Date(booking.date).toLocaleDateString()}`,
      icon: '/pwa-192x192.png',
      badge: '/pwa-192x192.png',
      requireInteraction: true, // Persistent notification for cancellations
      data: {
        type: 'BOOKING_CANCELLED',
        bookingId: booking.id,
      },
      url: `/calendar`,
    };

    // Send to all admins and managers
    await sendPushToRole('ADMIN', payload);
    await sendPushToRole('MANAGER', payload);

    console.log(`Booking cancelled notification sent for booking ${bookingId}`);
  } catch (error) {
    console.error('Error sending booking cancelled notification:', error);
    throw error;
  }
}

export default {
  subscribeToPush,
  unsubscribeFromPush,
  getUserSubscriptions,
  sendPushToUser,
  sendPushToUsers,
  sendPushToRole,
  sendNewBookingNotification,
  sendBookingUpdateNotification,
  sendBookingCancelledNotification,
};
