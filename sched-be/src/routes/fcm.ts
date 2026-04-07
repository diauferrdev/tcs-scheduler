import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth';
import * as pushService from '../services/push.service';

const app = new Hono();

// Register FCM token
app.post('/register', authMiddleware, async (c) => {
  const { token, deviceInfo } = await c.req.json();
  const userId = c.get('user').id;

  if (!token) {
    return c.json({ error: 'Token is required' }, 400);
  }

  await pushService.registerFCMToken(userId, token, deviceInfo);

  return c.json({ success: true });
});

// Unregister FCM token
app.post('/unregister', authMiddleware, async (c) => {
  const { token } = await c.req.json();
  const userId = c.get('user').id;

  if (!token) {
    return c.json({ error: 'Token is required' }, 400);
  }

  await pushService.unregisterFCMToken(userId, token);

  return c.json({ success: true });
});

// Debug: Get registered tokens for current user
app.get('/tokens', authMiddleware, async (c) => {
  const userId = c.get('user').id;
  const tokens = await pushService.getTokensForUser(userId);

  return c.json({
    userId,
    tokens,
    count: tokens.length,
  });
});

// Admin: Get all registered FCM tokens (admin only)
app.get('/tokens/all', authMiddleware, async (c) => {
  const userEmail = c.get('user').email;

  // Only allow diego@tcs.com
  if (userEmail !== 'diego@tcs.com') {
    return c.json({ error: 'Unauthorized. Only diego@tcs.com can view all tokens.' }, 403);
  }

  try {
    const { prisma } = await import('../lib/prisma');

    const tokens = await prisma.fCMToken.findMany({
      where: { isValid: true },
      select: {
        id: true,
        userId: true,
        deviceInfo: true,
        createdAt: true,
        lastUsedAt: true,
        user: {
          select: {
            name: true,
            email: true,
            role: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return c.json({
      totalUsers: tokens.length,
      tokens: tokens.map(t => ({
        userName: t.user.name,
        userEmail: t.user.email,
        userRole: t.user.role,
        deviceInfo: t.deviceInfo || 'Unknown device',
        registeredAt: t.createdAt,
        lastUsedAt: t.lastUsedAt,
      })),
    });
  } catch (error: any) {
    console.error('[FCM] Error fetching all tokens:', error);
    return c.json({ error: error.message }, 500);
  }
});

// Send test notification to all devices (admin only)
app.post('/test-notification', authMiddleware, async (c) => {
  const userEmail = c.get('user').email;

  // Only allow diego@tcs.com to send test notifications
  if (userEmail !== 'diego@tcs.com') {
    return c.json({ error: 'Unauthorized. Only diego@tcs.com can send test notifications.' }, 403);
  }

  try {
    const result = await pushService.sendTestNotificationToAll();
    return c.json({
      success: true,
      message: `Test notification sent to ${result.deviceCount} device(s)`,
      deviceCount: result.deviceCount,
    });
  } catch (error: any) {
    console.error('[FCM] Error in test-notification endpoint:', error);
    return c.json({ error: error.message || 'Failed to send test notification' }, 500);
  }
});

export default app;
