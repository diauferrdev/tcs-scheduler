import { Hono } from 'hono';
import * as dashboardService from '../services/dashboard.service';
import { authMiddleware } from '../middleware/auth';
import type { AppContext } from '../lib/context';

const app = new Hono<AppContext>();

// Get dashboard statistics (authenticated)
app.get('/stats', authMiddleware, async (c) => {
  try {
    const stats = await dashboardService.getDashboardStatistics();
    return c.json(stats);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

export default app;
