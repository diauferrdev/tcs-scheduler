import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { BookingCreateSchema, BookingGuestCreateSchema, BookingUpdateSchema } from '../types';
import * as bookingService from '../services/booking.service';
import * as invitationService from '../services/invitation.service';
import * as pushService from '../services/push.service';
import { authMiddleware } from '../middleware/auth';
import type { AppContext } from '../lib/context';

const app = new Hono<AppContext>();

// Public endpoint - get all bookings availability (minimal data for guests)
app.get('/availability', async (c) => {
  try {
    const month = c.req.query('month');
    const bookings = await bookingService.getBookingsAvailability(month);
    return c.json(bookings);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Public endpoint - check availability for specific date
app.get('/availability/:date', async (c) => {
  try {
    const date = c.req.param('date');
    const availability = await bookingService.checkAvailability(date);
    return c.json(availability);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Create booking (authenticated)
app.post('/', authMiddleware, zValidator('json', BookingCreateSchema), async (c) => {
  try {
    const user = c.get('user');
    const data = c.req.valid('json');
    const booking = await bookingService.createBooking(data, user.id);

    // Send push notification to all admins and managers
    try {
      await pushService.sendNewBookingNotification(booking.id);
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
      // Don't fail the request if notification fails
    }

    return c.json(booking, 201);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Create booking with invitation token (public)
app.post('/guest', zValidator('json', BookingGuestCreateSchema), async (c) => {
  try {
    const data = c.req.valid('json');

    // Validate token
    const validation = await invitationService.validateToken(data.token);
    if (!validation.valid) {
      return c.json({ error: 'Invalid, expired, or used invitation token' }, 400);
    }

    // Create booking
    const { token, ...bookingData } = data;
    const booking = await bookingService.createBooking(bookingData);

    // Mark invitation as used and link to booking
    await invitationService.markInvitationUsed(token);

    // Send push notification to all admins and managers
    try {
      await pushService.sendNewBookingNotification(booking.id);
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
      // Don't fail the request if notification fails
    }

    return c.json(booking, 201);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Get latest booking (for notifications)
app.get('/latest', authMiddleware, async (c) => {
  try {
    const booking = await bookingService.getLatestBooking();
    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Get all bookings (authenticated)
app.get('/', authMiddleware, async (c) => {
  try {
    const month = c.req.query('month');
    const status = c.req.query('status');
    const bookings = await bookingService.getBookings(month, status);
    return c.json(bookings);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Get booking by ID (authenticated)
app.get('/:id', authMiddleware, async (c) => {
  try {
    const id = c.req.param('id');
    const booking = await bookingService.getBookingById(id);
    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 404);
  }
});

// Update booking (authenticated)
app.patch('/:id', authMiddleware, zValidator('json', BookingUpdateSchema), async (c) => {
  try {
    const id = c.req.param('id');
    const data = c.req.valid('json');
    const booking = await bookingService.updateBooking(id, data);

    // Send push notification about update
    try {
      await pushService.sendBookingUpdateNotification(booking.id);
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
      // Don't fail the request if notification fails
    }

    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Delete booking (authenticated)
app.delete('/:id', authMiddleware, async (c) => {
  try {
    const id = c.req.param('id');

    // Send cancellation notification BEFORE deleting (we need booking data)
    try {
      await pushService.sendBookingCancelledNotification(id);
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
      // Don't fail the request if notification fails
    }

    const result = await bookingService.deleteBooking(id);
    return c.json(result);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Get attendee by ID (public - for badge display)
app.get('/attendee/:attendeeId', async (c) => {
  try {
    const attendeeId = c.req.param('attendeeId');
    const attendee = await bookingService.getAttendeeById(attendeeId);
    return c.json(attendee);
  } catch (error: any) {
    return c.json({ error: error.message }, 404);
  }
});

export default app;
