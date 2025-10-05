import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import 'dotenv/config';

import authRoutes from './routes/auth';
import bookingRoutes from './routes/bookings';
import invitationRoutes from './routes/invitations';
import analyticsRoutes from './routes/analytics';
import activityLogRoutes from './routes/activity-logs';
import pushRoutes from './routes/push';
import ogRoutes from './routes/og';
import { errorHandler } from './middleware/errorHandler';
import type { AppContext } from './lib/context';

const app = new Hono<AppContext>();

// Middleware
app.use('*', logger());
app.use('*', cors({
  origin: (origin) => {
    // Allow localhost and ngrok domains
    const allowedOrigins = [
      'http://localhost:3000',
      process.env.FRONTEND_URL,
    ].filter(Boolean);

    // Allow any ngrok domain
    if (origin?.includes('.ngrok-free.dev') || origin?.includes('.ngrok.io') || origin?.includes('.ngrok.app')) {
      return origin;
    }

    return allowedOrigins.includes(origin || '') ? origin : allowedOrigins[0];
  },
  credentials: true,
  allowHeaders: ['Content-Type', 'Authorization', 'ngrok-skip-browser-warning'],
  exposeHeaders: ['Set-Cookie'],
}));

// Routes
app.route('/api/auth', authRoutes);
app.route('/api/bookings', bookingRoutes);
app.route('/api/invitations', invitationRoutes);
app.route('/api/analytics', analyticsRoutes);
app.route('/api/activity-logs', activityLogRoutes);
app.route('/api/push', pushRoutes);
app.route('/api/og', ogRoutes);

// Health check
app.get('/health', (c) => c.json({ status: 'ok', timestamp: new Date().toISOString() }));

// Error handling
app.onError(errorHandler);

const port = process.env.PORT || 7777;

console.log(`
╔════════════════════════════════════════╗
║   TCS PacePort Scheduler - Backend    ║
╚════════════════════════════════════════╝

🚀 Server running on http://localhost:${port}
📊 API: http://localhost:${port}/api
🏥 Health: http://localhost:${port}/health
🌍 Environment: ${process.env.NODE_ENV || 'development'}
`);

export default {
  port,
  fetch: app.fetch,
};
