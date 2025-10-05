import { Hono } from 'hono';
import * as activityLogService from '../services/activity-log.service';
import { authMiddleware, requireRole } from '../middleware/auth';
import type { AppContext } from '../lib/context';

const app = new Hono<AppContext>();

// Get activity logs (ADMIN only)
app.get('/', authMiddleware, requireRole('ADMIN'), async (c) => {
  try {
    const { userId, action, resource, limit, offset } = c.req.query();

    const filters: any = {};

    if (userId) filters.userId = userId;
    if (action) filters.action = action as any;
    if (resource) filters.resource = resource as any;
    if (limit) filters.limit = parseInt(limit);
    if (offset) filters.offset = parseInt(offset);

    const result = await activityLogService.getActivityLogs(filters);
    return c.json(result);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Get user activity summary (ADMIN only)
app.get('/user/:userId', authMiddleware, requireRole('ADMIN'), async (c) => {
  try {
    const userId = c.req.param('userId');
    const summary = await activityLogService.getUserActivitySummary(userId);
    return c.json(summary);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

export default app;
