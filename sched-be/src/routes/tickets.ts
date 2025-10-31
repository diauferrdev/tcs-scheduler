import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { TicketCreateSchema, TicketUpdateSchema, TicketFilterSchema, TicketMessageCreateSchema } from '../types/ticket.types';
import * as ticketService from '../services/ticket.service';
import * as pushService from '../services/push.service';
import * as wsService from '../services/websocket.service';
import { authMiddleware } from '../middleware/auth';
import type { AppContext } from '../lib/context';
import { prisma } from '../lib/prisma';

const app = new Hono<AppContext>();

// Create ticket
app.post('/', authMiddleware, zValidator('json', TicketCreateSchema), async (c) => {
  try {
    const user = c.get('user');
    const data = c.req.valid('json');

    const ticket = await ticketService.createTicket(data, user.id);

    // Notify all ADMINs about new ticket
    try {
      const admins = await prisma.user.findMany({
        where: { role: 'ADMIN', isActive: true },
      });

      for (const admin of admins) {
        // Create in-app notification
        await prisma.notification.create({
          data: {
            type: 'TICKET_CREATED',
            title: 'New Support Ticket',
            message: `${user.name} created a new ticket: "${ticket.title}"`,
            userId: admin.id,
            actionUrl: `/app/support/${ticket.id}`,
            metadata: {
              ticketId: ticket.id,
              createdById: user.id,
              createdByName: user.name,
              category: ticket.category,
              priority: ticket.priority,
            },
          },
        });

        // Send push notification
        await pushService.sendPushToUser(
          admin.id,
          'New Support Ticket',
          `${user.name}: "${ticket.title}"`,
          `/app/support/${ticket.id}`
        );
      }
    } catch (error) {
      console.error('Error sending notifications:', error);
    }

    return c.json(ticket, 201);
  } catch (error: any) {
    console.error('Error creating ticket:', error);
    return c.json({ error: error.message || 'Failed to create ticket' }, 500);
  }
});

// Get all tickets (with filters)
app.get('/', authMiddleware, zValidator('query', TicketFilterSchema), async (c) => {
  try {
    const user = c.get('user');
    const filters = c.req.valid('query');

    const tickets = await ticketService.getTickets(filters, user.id, user.role);

    return c.json(tickets);
  } catch (error: any) {
    console.error('Error fetching tickets:', error);
    return c.json({ error: error.message || 'Failed to fetch tickets' }, 500);
  }
});

// Get ticket stats
app.get('/stats', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const stats = await ticketService.getTicketStats(user.id, user.role);
    return c.json(stats);
  } catch (error: any) {
    console.error('Error fetching ticket stats:', error);
    return c.json({ error: error.message || 'Failed to fetch stats' }, 500);
  }
});

// Get single ticket
app.get('/:id', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const ticketId = c.req.param('id');

    const ticket = await ticketService.getTicketById(ticketId, user.id, user.role);

    return c.json(ticket);
  } catch (error: any) {
    console.error('Error fetching ticket:', error);
    const status = error.message === 'Access denied' ? 403 : error.message === 'Ticket not found' ? 404 : 500;
    return c.json({ error: error.message || 'Failed to fetch ticket' }, status);
  }
});

// Update ticket
app.patch('/:id', authMiddleware, zValidator('json', TicketUpdateSchema), async (c) => {
  try {
    const user = c.get('user');
    const ticketId = c.req.param('id');
    const data = c.req.valid('json');

    const oldTicket = await prisma.ticket.findUnique({ where: { id: ticketId }, include: { createdBy: true } });
    const ticket = await ticketService.updateTicket(ticketId, data, user.id, user.role);

    // Send notifications based on what changed
    try {
      if (data.status && data.status !== oldTicket?.status) {
        // Notify ticket creator about status change
        await prisma.notification.create({
          data: {
            type: 'TICKET_STATUS_CHANGED',
            title: 'Ticket Status Updated',
            message: `Your ticket "${ticket.title}" status changed to ${data.status}`,
            userId: ticket.createdById,
            actionUrl: `/app/support/${ticket.id}`,
            metadata: {
              ticketId: ticket.id,
              oldStatus: oldTicket?.status,
              newStatus: data.status,
            },
          },
        });

        await pushService.sendPushToUser(
          ticket.createdById,
          'Ticket Status Updated',
          `Your ticket status changed to ${data.status}`,
          `/app/support/${ticket.id}`
        );
      }

      if (data.assignedToId && data.assignedToId !== oldTicket?.assignedToId) {
        // Notify assigned admin
        if (data.assignedToId) {
          await prisma.notification.create({
            data: {
              type: 'TICKET_ASSIGNED',
              title: 'Ticket Assigned to You',
              message: `Ticket "${ticket.title}" has been assigned to you`,
              userId: data.assignedToId,
              actionUrl: `/app/support/${ticket.id}`,
              metadata: {
                ticketId: ticket.id,
                assignedById: user.id,
              },
            },
          });

          await pushService.sendPushToUser(
            data.assignedToId,
            'Ticket Assigned',
            `"${ticket.title}"`,
            `/app/support/${ticket.id}`
          );
        }
      }

      if (data.priority && data.priority !== oldTicket?.priority) {
        // Notify ticket creator about priority change
        await prisma.notification.create({
          data: {
            type: 'TICKET_PRIORITY_CHANGED',
            title: 'Ticket Priority Updated',
            message: `Your ticket "${ticket.title}" priority changed to ${data.priority}`,
            userId: ticket.createdById,
            actionUrl: `/app/support/${ticket.id}`,
            metadata: {
              ticketId: ticket.id,
              oldPriority: oldTicket?.priority,
              newPriority: data.priority,
            },
          },
        });
      }
    } catch (error) {
      console.error('Error sending notifications:', error);
    }

    return c.json(ticket);
  } catch (error: any) {
    console.error('Error updating ticket:', error);
    const status = error.message === 'Access denied' ? 403 : error.message === 'Ticket not found' ? 404 : 500;
    return c.json({ error: error.message || 'Failed to update ticket' }, status);
  }
});

// Delete ticket
app.delete('/:id', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const ticketId = c.req.param('id');

    await ticketService.deleteTicket(ticketId, user.id, user.role);

    return c.json({ message: 'Ticket deleted successfully' });
  } catch (error: any) {
    console.error('Error deleting ticket:', error);
    const status = error.message === 'Access denied' ? 403 : error.message === 'Ticket not found' ? 404 : 500;
    return c.json({ error: error.message || 'Failed to delete ticket' }, status);
  }
});

// Create message in ticket
app.post('/:id/messages', authMiddleware, zValidator('json', TicketMessageCreateSchema), async (c) => {
  try {
    const user = c.get('user');
    const ticketId = c.req.param('id');
    const data = c.req.valid('json');

    const message = await ticketService.createMessage(ticketId, data, user.id, user.role);
    const ticket = await prisma.ticket.findUnique({ where: { id: ticketId }, include: { createdBy: true, assignedTo: true } });

    if (!ticket) {
      return c.json({ error: 'Ticket not found' }, 404);
    }

    // Send notification to the other party (not the sender)
    try {
      let recipientId: string | null = null;

      if (user.role === 'ADMIN') {
        // Admin sent message, notify ticket creator
        recipientId = ticket.createdById;
      } else {
        // User sent message, notify assigned admin or any admin
        recipientId = ticket.assignedToId;
        if (!recipientId) {
          // Notify all admins if not assigned
          const admins = await prisma.user.findMany({
            where: { role: 'ADMIN', isActive: true },
          });
          for (const admin of admins) {
            await prisma.notification.create({
              data: {
                type: 'TICKET_NEW_MESSAGE',
                title: 'New Message in Ticket',
                message: `${user.name} sent a message in "${ticket.title}"`,
                userId: admin.id,
                actionUrl: `/app/support/${ticket.id}`,
                metadata: {
                  ticketId: ticket.id,
                  messageId: message.id,
                  authorId: user.id,
                },
              },
            });

            await pushService.sendPushToUser(
              admin.id,
              'New Ticket Message',
              `${user.name}: ${message.content.slice(0, 50)}...`,
              `/app/support/${ticket.id}`
            );
          }
        }
      }

      if (recipientId && !data.isInternal) {
        await prisma.notification.create({
          data: {
            type: 'TICKET_NEW_MESSAGE',
            title: 'New Message in Ticket',
            message: `${user.name} sent a message in "${ticket.title}"`,
            userId: recipientId,
            actionUrl: `/app/support/${ticket.id}`,
            metadata: {
              ticketId: ticket.id,
              messageId: message.id,
              authorId: user.id,
            },
          },
        });

        await pushService.sendPushToUser(
          recipientId,
          'New Ticket Message',
          `${user.name}: ${message.content.slice(0, 50)}...`,
          `/app/support/${ticket.id}`
        );
      }
    } catch (error) {
      console.error('Error sending message notification:', error);
    }

    // Send real-time WebSocket update
    try {
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

      // Also notify the sender so their message appears immediately
      userIdsToNotify.push(user.id);

      wsService.sendTicketMessage(userIdsToNotify, message);
      console.log(`[WS] Sent ticket message to ${userIdsToNotify.length} user(s)`);
    } catch (error) {
      console.error('Error sending WebSocket message:', error);
    }

    return c.json(message, 201);
  } catch (error: any) {
    console.error('Error creating message:', error);
    const status = error.message === 'Access denied' ? 403 : error.message === 'Ticket not found' ? 404 : 500;
    return c.json({ error: error.message || 'Failed to create message' }, status);
  }
});

export default app;
