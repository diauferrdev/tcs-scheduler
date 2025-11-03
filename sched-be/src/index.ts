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
import ticketRoutes from './routes/tickets';
import { errorHandler } from './middleware/errorHandler';
import type { AppContext } from './lib/context';
import { lucia } from './lib/lucia';
import * as websocketService from './services/websocket.service';

const app = new Hono<AppContext>();

app.use('*', logger());

// CORS Configuration - Allow production domains and localhost for testing
const allowedOrigins = [
  process.env.FRONTEND_URL || 'https://ppspsched.lat',
  'https://ppspsched.lat',
  'https://www.ppspsched.lat',
  'https://app.ppspsched.lat',
  'https://api.ppspsched.lat',
  // Always allow localhost for development and testing
  'http://localhost:3000',
  'http://localhost:3005',
  'http://localhost:5173',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:3005',
  'http://127.0.0.1:5173',
];

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

// Serve static files for uploads with caching
app.use('/uploads/*', serveStatic({
  root: './',
  onFound: (path, c) => {
    // Cache static files for 1 year (immutable content with unique filenames)
    c.header('Cache-Control', 'public, max-age=31536000, immutable');
    c.header('Access-Control-Allow-Origin', '*');
    c.header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    c.header('Access-Control-Allow-Headers', 'Range, Content-Type');
    c.header('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges');
    c.header('Accept-Ranges', 'bytes');

    // Set appropriate Content-Type for PDFs and other documents
    if (path.endsWith('.pdf')) {
      c.header('Content-Type', 'application/pdf');
    } else if (path.endsWith('.doc') || path.endsWith('.docx')) {
      c.header('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    } else if (path.endsWith('.xls') || path.endsWith('.xlsx')) {
      c.header('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    }
  }
}));

app.route('/api/auth', authRoutes);
app.route('/api/bookings', bookingRoutes);
app.route('/api/invitations', invitationRoutes);
app.route('/api/analytics', analyticsRoutes);
app.route('/api/analytics-fcm', analyticsFcmRoutes);
app.route('/api/audit', activityLogRoutes);
app.route('/api/push', pushRoutes);
app.route('/api/og', ogRoutes);
app.route('/api/test-notifications', testNotificationRoutes);
app.route('/api/notifications', notificationRoutes);
app.route('/api/fcm', fcmRoutes);
app.route('/api/version', versionRoutes);
app.route('/api/upload', uploadRoutes);
app.route('/api/dashboard', dashboardRoutes);
app.route('/api/tickets', ticketRoutes);

app.get('/health', (c) => c.json({
  status: 'ok',
  timestamp: new Date().toISOString(),
  services: {
    api: 'ok',
    websocket: 'native',
    connections: websocketService.getTotalConnections(),
  }
}));

// Version endpoint (redirect to /api/version for consistency)
app.get('/version', (c) => c.redirect('/api/version', 301));

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

    async message(ws, message) {
      try {
        const data = typeof message === 'string' ? JSON.parse(message) : message;
        console.log('[WS] Message from user', ws.data.userId, ':', data);

        // Handle ping/pong
        if (data.type === 'ping') {
          ws.send(JSON.stringify({ type: 'pong' }));
        }

        // Handle mark as read
        else if (data.type === 'mark_as_read') {
          const { ticketId } = data;
          const userId = ws.data.userId;

          console.log(`[WS] mark_as_read: ticket ${ticketId} by user ${userId}`);

          // Import necessary services
          const { prisma } = await import('./lib/prisma');
          const ticketService = await import('./services/ticket.service');

          try {
            // Verify access to ticket
            const ticket = await prisma.ticket.findUnique({
              where: { id: ticketId },
            });

            if (!ticket) {
              ws.send(JSON.stringify({ type: 'error', message: 'Ticket not found' }));
              return;
            }

            // Get user to check role
            const user = await prisma.user.findUnique({
              where: { id: userId },
            });

            if (!user) {
              ws.send(JSON.stringify({ type: 'error', message: 'User not found' }));
              return;
            }

            // Check access permissions
            if (user.role !== 'ADMIN' && ticket.createdById !== userId) {
              ws.send(JSON.stringify({ type: 'error', message: 'Access denied' }));
              return;
            }

            // Update all unread messages from OTHER users in this ticket
            const result = await prisma.ticketMessage.updateMany({
              where: {
                ticketId,
                authorId: { not: userId },
                readAt: null,
              },
              data: {
                readAt: new Date(),
              },
            });

            console.log(`[WS] Marked ${result.count} messages as read for ticket ${ticketId} by user ${userId}`);

            // Send real-time WebSocket update to all parties
            if (result.count > 0) {
              const userIdsToNotify: string[] = [];

              if (user.role === 'ADMIN') {
                // Notify ticket creator
                userIdsToNotify.push(ticket.createdById);
              } else {
                // Notify assigned admin or all admins
                if (ticket.assignedToId) {
                  userIdsToNotify.push(ticket.assignedToId);
                } else {
                  const admins = await prisma.user.findMany({
                    where: { role: 'ADMIN', isActive: true },
                    select: { id: true },
                  });
                  userIdsToNotify.push(...admins.map(a => a.id));
                }
              }

              // Also notify the reader so their UI updates
              userIdsToNotify.push(userId);

              // Get updated ticket
              const updatedTicket = await ticketService.getTicketById(ticketId, userId, user.role);

              websocketService.broadcastTicketRead(userIdsToNotify, updatedTicket);
              console.log(`[WS] Broadcast ticket_read to ${userIdsToNotify.length} user(s)`);
            }

            // Send success response
            ws.send(JSON.stringify({
              type: 'mark_as_read_success',
              data: { ticketId, count: result.count }
            }));

          } catch (error: any) {
            console.error('[WS] Error marking as read:', error);
            ws.send(JSON.stringify({
              type: 'error',
              message: error.message || 'Failed to mark as read'
            }));
          }
        }

        // Handle typing indicator
        else if (data.type === 'typing') {
          const { ticketId, isTyping } = data;
          const userId = ws.data.userId;

          console.log(`[WS] typing: ticket ${ticketId}, user ${userId}, isTyping: ${isTyping}`);

          // Import necessary services
          const { prisma } = await import('./lib/prisma');

          try {
            // Get ticket to find who to notify
            const ticket = await prisma.ticket.findUnique({
              where: { id: ticketId },
            });

            if (!ticket) return;

            // Get user
            const user = await prisma.user.findUnique({
              where: { id: userId },
              select: { id: true, name: true, role: true },
            });

            if (!user) return;

            // Determine who to notify
            const userIdsToNotify: string[] = [];

            if (user.role === 'ADMIN') {
              // Notify ticket creator
              userIdsToNotify.push(ticket.createdById);
            } else {
              // Notify assigned admin or all admins
              if (ticket.assignedToId) {
                userIdsToNotify.push(ticket.assignedToId);
              } else {
                const admins = await prisma.user.findMany({
                  where: { role: 'ADMIN', isActive: true },
                  select: { id: true },
                });
                userIdsToNotify.push(...admins.map(a => a.id));
              }
            }

            // Broadcast typing status
            websocketService.sendToMultipleUsers(userIdsToNotify, {
              type: 'typing',
              data: {
                ticketId,
                userId: user.id,
                userName: user.name,
                isTyping,
              },
            });

          } catch (error: any) {
            console.error('[WS] Error handling typing:', error);
          }
        }

        // Handle recording indicator
        else if (data.type === 'recording') {
          const { ticketId, isRecording } = data;
          const userId = ws.data.userId;

          console.log(`[WS] recording: ticket ${ticketId}, user ${userId}, isRecording: ${isRecording}`);

          // Import necessary services
          const { prisma } = await import('./lib/prisma');

          try {
            // Get ticket to find who to notify
            const ticket = await prisma.ticket.findUnique({
              where: { id: ticketId },
            });

            if (!ticket) return;

            // Get user
            const user = await prisma.user.findUnique({
              where: { id: userId },
              select: { id: true, name: true, role: true },
            });

            if (!user) return;

            // Determine who to notify
            const userIdsToNotify: string[] = [];

            if (user.role === 'ADMIN') {
              // Notify ticket creator
              userIdsToNotify.push(ticket.createdById);
            } else {
              // Notify assigned admin or all admins
              if (ticket.assignedToId) {
                userIdsToNotify.push(ticket.assignedToId);
              } else {
                const admins = await prisma.user.findMany({
                  where: { role: 'ADMIN', isActive: true },
                  select: { id: true },
                });
                userIdsToNotify.push(...admins.map(a => a.id));
              }
            }

            // Broadcast recording status
            websocketService.sendToMultipleUsers(userIdsToNotify, {
              type: 'recording',
              data: {
                ticketId,
                userId: user.id,
                userName: user.name,
                isRecording,
              },
            });

          } catch (error: any) {
            console.error('[WS] Error handling recording:', error);
          }
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
