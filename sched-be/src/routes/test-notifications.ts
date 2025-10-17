import { Hono } from 'hono';
import type { AppContext } from '../lib/context';
import { authMiddleware } from '../middleware/auth';
import * as notificationService from '../services/notification.service';

const app = new Hono<AppContext>();

// All routes require authentication
app.use('*', authMiddleware);

// Send test notification to all managers
app.post('/send-test', async (c) => {
  const user = c.get('user');

  if (!user || !['ADMIN', 'MANAGER'].includes(user.role)) {
    return c.json({ error: 'Unauthorized' }, 403);
  }

  const body = await c.req.json();
  const { type = 'BOOKING_UPDATED', title, message } = body;

  if (!title || !message) {
    return c.json({ error: 'Title and message are required' }, 400);
  }

  try {
    const notifications = await notificationService.notifyAllManagers(
      type as any,
      title,
      message
    );

    return c.json({
      success: true,
      count: notifications.length,
      message: `Test notification sent to ${notifications.length} managers`,
    });
  } catch (error: any) {
    console.error('Error sending test notification:', error);
    return c.json({ error: error.message || 'Failed to send test notification' }, 500);
  }
});

export default app;
