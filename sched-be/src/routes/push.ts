import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import { authMiddleware } from '../middleware/auth';
import * as pushService from '../services/push.service';

const app = new Hono();

// Schema for push subscription
const PushSubscriptionSchema = z.object({
  endpoint: z.string().url(),
  expirationTime: z.number().nullable().optional(),
  keys: z.object({
    p256dh: z.string(),
    auth: z.string(),
  }),
});

// Schema for sending push notification
const SendPushSchema = z.object({
  title: z.string().min(1),
  body: z.string().min(1),
  icon: z.string().optional(),
  badge: z.string().optional(),
  data: z.any().optional(),
  url: z.string().optional(),
  requireInteraction: z.boolean().optional(), // Makes notification persistent
  actions: z
    .array(
      z.object({
        action: z.string(),
        title: z.string(),
        icon: z.string().optional(),
      })
    )
    .optional(),
});

/**
 * GET /api/push/vapid-public-key
 * Get the VAPID public key for push notifications
 */
app.get('/vapid-public-key', (c) => {
  const publicKey = process.env.VAPID_PUBLIC_KEY;

  if (!publicKey) {
    return c.json({ error: 'VAPID public key not configured' }, 500);
  }

  return c.json({ publicKey });
});

/**
 * POST /api/push/subscribe
 * Subscribe to push notifications
 */
app.post(
  '/subscribe',
  authMiddleware,
  zValidator('json', PushSubscriptionSchema),
  async (c) => {
    try {
      const user = c.get('user');
      const subscription = c.req.valid('json');
      const userAgent = c.req.header('user-agent');

      const result = await pushService.subscribeToPush(
        user.id,
        subscription,
        userAgent
      );

      return c.json({
        message: 'Successfully subscribed to push notifications',
        subscription: result,
      });
    } catch (error: any) {
      console.error('Error subscribing to push:', error);
      return c.json({ error: error.message || 'Failed to subscribe' }, 500);
    }
  }
);

/**
 * POST /api/push/unsubscribe
 * Unsubscribe from push notifications
 */
app.post(
  '/unsubscribe',
  authMiddleware,
  zValidator('json', z.object({ endpoint: z.string() })),
  async (c) => {
    try {
      const user = c.get('user');
      const { endpoint } = c.req.valid('json');

      await pushService.unsubscribeFromPush(user.id, endpoint);

      return c.json({ message: 'Successfully unsubscribed from push notifications' });
    } catch (error: any) {
      console.error('Error unsubscribing from push:', error);
      return c.json({ error: error.message || 'Failed to unsubscribe' }, 500);
    }
  }
);

/**
 * GET /api/push/subscriptions
 * Get all push subscriptions for current user
 */
app.get('/subscriptions', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const subscriptions = await pushService.getUserSubscriptions(user.id);

    return c.json(subscriptions);
  } catch (error: any) {
    console.error('Error getting subscriptions:', error);
    return c.json({ error: error.message || 'Failed to get subscriptions' }, 500);
  }
});

/**
 * POST /api/push/test
 * Send a test push notification (for testing purposes)
 */
app.post(
  '/test',
  authMiddleware,
  zValidator('json', SendPushSchema),
  async (c) => {
    try {
      const user = c.get('user');
      const payload = c.req.valid('json');

      const result = await pushService.sendPushToUser(user.id, payload);

      return c.json({
        message: 'Test notification sent',
        result,
      });
    } catch (error: any) {
      console.error('Error sending test push:', error);
      return c.json({ error: error.message || 'Failed to send test push' }, 500);
    }
  }
);

/**
 * POST /api/push/send-to-user/:userId
 * Send push notification to specific user (admin only)
 */
app.post(
  '/send-to-user/:userId',
  authMiddleware,
  zValidator('json', SendPushSchema),
  async (c) => {
    try {
      const user = c.get('user');

      // Only admins can send push to other users
      if (user.role !== 'ADMIN') {
        return c.json({ error: 'Unauthorized' }, 403);
      }

      const userId = c.req.param('userId');
      const payload = c.req.valid('json');

      const result = await pushService.sendPushToUser(userId, payload);

      return c.json({
        message: 'Push notification sent',
        result,
      });
    } catch (error: any) {
      console.error('Error sending push to user:', error);
      return c.json({ error: error.message || 'Failed to send push' }, 500);
    }
  }
);

/**
 * POST /api/push/send-to-role/:role
 * Send push notification to all users with specific role (admin only)
 */
app.post(
  '/send-to-role/:role',
  authMiddleware,
  zValidator('json', SendPushSchema),
  async (c) => {
    try {
      const user = c.get('user');

      // Only admins can send push to roles
      if (user.role !== 'ADMIN') {
        return c.json({ error: 'Unauthorized' }, 403);
      }

      const role = c.req.param('role') as 'ADMIN' | 'MANAGER' | 'GUEST';
      const payload = c.req.valid('json');

      const result = await pushService.sendPushToRole(role, payload);

      return c.json({
        message: `Push notification sent to all ${role}s`,
        result,
      });
    } catch (error: any) {
      console.error('Error sending push to role:', error);
      return c.json({ error: error.message || 'Failed to send push' }, 500);
    }
  }
);

export default app;
