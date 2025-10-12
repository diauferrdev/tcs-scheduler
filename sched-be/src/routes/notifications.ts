import { Hono } from 'hono';
import * as notificationService from '../services/notification.service';
import { authMiddleware } from '../middleware/auth';
import type { AppContext } from '../lib/context';
import { z } from 'zod';

const app = new Hono<AppContext>();

// Get user notifications
app.get('/', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    if (!user) {
      return c.json({ error: 'Unauthorized' }, 401);
    }
    const userId = user.id;

    const { isRead, type, limit, offset } = c.req.query();

    const filters: any = {};
    if (isRead !== undefined) filters.isRead = isRead === 'true';
    if (type) filters.type = type as any;
    if (limit) filters.limit = parseInt(limit);
    if (offset) filters.offset = parseInt(offset);

    const result = await notificationService.getUserNotifications(userId, filters);
    return c.json(result);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Mark notification as read
app.patch('/:id/read', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    if (!user) {
      return c.json({ error: 'Unauthorized' }, 401);
    }
    const userId = user.id;

    const id = c.req.param('id');
    const notification = await notificationService.markNotificationAsRead(id, userId);
    return c.json(notification);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Mark all as read
app.post('/mark-all-read', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    if (!user) {
      return c.json({ error: 'Unauthorized' }, 401);
    }
    const userId = user.id;

    const result = await notificationService.markAllAsRead(userId);
    return c.json(result);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Delete notification
app.delete('/:id', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    if (!user) {
      return c.json({ error: 'Unauthorized' }, 401);
    }
    const userId = user.id;

    const id = c.req.param('id');
    await notificationService.deleteNotification(id, userId);
    return c.json({ success: true });
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

export default app;
