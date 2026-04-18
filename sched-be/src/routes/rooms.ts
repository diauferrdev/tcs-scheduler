import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { RoomBookingCreateSchema, RoomBookingRejectSchema } from '../types/room.types';
import * as roomService from '../services/room.service';
import { authMiddleware } from '../middleware/auth';
import type { AppContext } from '../lib/context';

const app = new Hono<AppContext>();

// Get room availability for a date (works with or without auth)
app.get('/availability/:date', authMiddleware, async (c) => {
  try {
    const date = c.req.param('date');
    const user = c.get('user');
    const availability = await roomService.getRoomAvailability(date, user.id, user.role);
    return c.json(availability);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 400);
  }
});

// Create room booking (authenticated)
app.post('/', authMiddleware, zValidator('json', RoomBookingCreateSchema), async (c) => {
  try {
    const user = c.get('user');
    const data = c.req.valid('json');
    const booking = await roomService.createRoomBooking(data, user.id, user.role);
    return c.json(booking, 201);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 400);
  }
});

// Get all room bookings (authenticated)
app.get('/', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const date = c.req.query('date');
    const room = c.req.query('room');
    const status = c.req.query('status');

    const mine = c.req.query('mine');
    const bookings = await roomService.getRoomBookings({
      date: date || undefined,
      room: room || undefined,
      status: status || undefined,
      bookedById: (user.role === 'USER' || mine === 'true') ? user.id : undefined,
      createdAsRole: mine === 'true' ? user.role : undefined,
    });

    return c.json({ bookings });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 400);
  }
});

// Get room booking by ID (authenticated)
app.get('/:id', authMiddleware, async (c) => {
  try {
    const id = c.req.param('id');
    const booking = await roomService.getRoomBookingById(id);
    return c.json(booking);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 404);
  }
});

// Approve room booking (manager/admin only)
app.post('/:id/approve', authMiddleware, async (c) => {
  try {
    const user = c.get('user');

    if (user.role !== 'MANAGER' && user.role !== 'ADMIN') {
      return c.json({ error: 'Only managers and admins can approve room bookings' }, 403);
    }

    const id = c.req.param('id');
    const booking = await roomService.approveRoomBooking(id, user.id);
    return c.json(booking);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 400);
  }
});

// Reject room booking (manager/admin only)
app.post('/:id/reject', authMiddleware, zValidator('json', RoomBookingRejectSchema), async (c) => {
  try {
    const user = c.get('user');

    if (user.role !== 'MANAGER' && user.role !== 'ADMIN') {
      return c.json({ error: 'Only managers and admins can reject room bookings' }, 403);
    }

    const id = c.req.param('id');
    const data = c.req.valid('json');
    const booking = await roomService.rejectRoomBooking(id, user.id, data.rejectionReason);
    return c.json(booking);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 400);
  }
});

// Cancel room booking (authenticated)
app.post('/:id/cancel', authMiddleware, async (c) => {
  try {
    const id = c.req.param('id');
    const booking = await roomService.cancelRoomBooking(id);
    return c.json(booking);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 400);
  }
});

export default app;
