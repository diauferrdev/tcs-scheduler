import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { serveStatic } from 'hono/bun';
import 'dotenv/config';
import type { ServerWebSocket } from 'bun';

import authRoutes from './routes/auth';
import bookingRoutes from './routes/bookings';
import invitationRoutes from './routes/invitations';
import analyticsRoutes from './routes/analytics';
import analyticsFcmRoutes from './routes/analytics-fcm';
import activityLogRoutes from './routes/activity-logs';
import pushRoutes from './routes/push';
import ogRoutes from './routes/og';
import notificationRoutes from './routes/notifications';
import testNotificationRoutes from './routes/test-notifications';
import fcmRoutes from './routes/fcm';
import versionRoutes from './routes/version';
import uploadRoutes from './routes/upload';
import dashboardRoutes from './routes/dashboard';
import { errorHandler } from './middleware/errorHandler';
import type { AppContext } from './lib/context';
import { lucia } from './lib/lucia';
import * as websocketService from './services/websocket.service';

const app = new Hono<AppContext>();

app.use('*', logger());

// CORS Configuration - Strict in production
const allowedOrigins = [
  process.env.FRONTEND_URL || 'https://ppspsched.lat',
  'https://ppspsched.lat',
  'https://www.ppspsched.lat',
  'https://app.ppspsched.lat',
  'https://api.ppspsched.lat',
];

// Only allow localhost in development
if (process.env.NODE_ENV !== 'production') {
  allowedOrigins.push('http://localhost:3000', 'http://localhost:5173');
}

app.use('*', cors({
  origin: (origin) => {
    // Allow requests with no origin (mobile apps, curl, etc)
    if (!origin) return true;

    // Check if origin is in allowed list
    if (allowedOrigins.includes(origin)) return origin;

    console.warn(`[CORS] Blocked origin: ${origin}`);
    return false;
  },
  credentials: true,
  allowHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With',
    'Cookie',
    'Origin',
    'Accept',
    'X-CSRF-Token',
  ],
  allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'HEAD'],
  exposeHeaders: ['Set-Cookie', 'Content-Length', 'Content-Type'],
  maxAge: 86400,
}));

// Serve static files for uploads
app.use('/uploads/*', serveStatic({ root: './' }));

app.route('/api/auth', authRoutes);
app.route('/api/bookings', bookingRoutes);
app.route('/api/invitations', invitationRoutes);
app.route('/api/analytics', analyticsRoutes);
app.route('/api/analytics-fcm', analyticsFcmRoutes);
app.route('/api/activity-logs', activityLogRoutes);
app.route('/api/push', pushRoutes);
app.route('/api/og', ogRoutes);
app.route('/api/test-notifications', testNotificationRoutes);
app.route('/api/notifications', notificationRoutes);
app.route('/api/fcm', fcmRoutes);
app.route('/api/version', versionRoutes);
app.route('/api/upload', uploadRoutes);
app.route('/api/dashboard', dashboardRoutes);

app.get('/health', (c) => c.json({
  status: 'ok',
  timestamp: new Date().toISOString(),
  services: {
    api: 'ok',
    websocket: 'native',
    connections: websocketService.getTotalConnections(),
  }
}));

app.onError(errorHandler);

const port = process.env.PORT || 7777;

interface WebSocketData {
  userId: string;
  createdAt: number;
}

// Extract session ID from various sources
function extractSessionId(request: Request): string | null {
  const url = new URL(request.url);

  // Try query parameter
  const querySessionId = url.searchParams.get('sessionId');
  if (querySessionId) return querySessionId;

  // Try Cookie header
  const cookieHeader = request.headers.get('cookie');
  if (cookieHeader) {
    const cookies = cookieHeader.split(';').map(c => c.trim());
    for (const cookie of cookies) {
      const [name, value] = cookie.split('=');
      if (name === lucia.sessionCookieName) {
        return value;
      }
    }
  }

  return null;
}

const server = Bun.serve<WebSocketData>({
  port,
  fetch: app.fetch,

  // WebSocket upgrade handler
  websocket: {
    open(ws) {
      console.log('[WS] Connection opened for user:', ws.data.userId);
      websocketService.addConnection(ws.data.userId, ws);

      // Send connection success message
      ws.send(JSON.stringify({
        type: 'connected',
        data: {
          userId: ws.data.userId,
          timestamp: Date.now(),
        }
      }));
    },

    message(ws, message) {
      try {
        const data = typeof message === 'string' ? JSON.parse(message) : message;
        console.log('[WS] Message from user', ws.data.userId, ':', data);

        // Handle ping/pong
        if (data.type === 'ping') {
          ws.send(JSON.stringify({ type: 'pong' }));
        }
      } catch (error) {
        console.error('[WS] Error handling message:', error);
      }
    },

    close(ws, code, reason) {
      console.log('[WS] Connection closed for user:', ws.data.userId, code, reason);
      websocketService.removeConnection(ws.data.userId, ws);
    },

    error(ws, error) {
      console.error('[WS] Error for user:', ws.data.userId, error);
    },
  },

  async fetch(request, server) {
    const url = new URL(request.url);

    // Handle WebSocket upgrade
    if (url.pathname === '/ws' && request.headers.get('upgrade') === 'websocket') {
      console.log('[WS] Upgrade request received');

      // Extract and validate session
      const sessionId = extractSessionId(request);

      if (!sessionId) {
        console.log('[WS] No session ID provided');
        return new Response('Unauthorized: No session ID', { status: 401 });
      }

      // Validate session with Lucia
      try {
        const { session, user } = await lucia.validateSession(sessionId);

        if (!session || !user || !user.isActive) {
          console.log('[WS] Invalid session or inactive user');
          return new Response('Unauthorized: Invalid session', { status: 401 });
        }

        console.log('[WS] User authenticated:', user.id, user.email);

        // Upgrade to WebSocket with user data
        const success = server.upgrade(request, {
          data: {
            userId: user.id,
            createdAt: Date.now(),
          }
        });

        if (!success) {
          console.error('[WS] Failed to upgrade connection');
          return new Response('Failed to upgrade to WebSocket', { status: 500 });
        }

        return undefined; // Connection upgraded successfully
      } catch (error) {
        console.error('[WS] Authentication error:', error);
        return new Response('Unauthorized: Authentication failed', { status: 401 });
      }
    }

    // Handle regular HTTP requests through Hono
    return app.fetch(request, server);
  }
});

console.log(`
╔════════════════════════════════════════╗
║   TCS PacePort Scheduler - Backend    ║
╚════════════════════════════════════════╝

🚀 Server: http://localhost:${port}
📊 API: http://localhost:${port}/api
🏥 Health: http://localhost:${port}/health
🔌 WebSocket: ws://localhost:${port}/ws
🌍 Environment: ${process.env.NODE_ENV || 'development'}

Real-time: Native Bun WebSocket ✨
`);

process.on('SIGTERM', () => {
  console.log('[Server] Shutting down gracefully...');
  server.stop();
  process.exit(0);
});
