import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import {
  BookingCreateSchema,
  BookingGuestCreateSchema,
  BookingUpdateSchema,
  RequestEditSchema,
  RequestRescheduleSchema,
  RejectBookingSchema,
  ApproveBookingSchema,
  CancelBookingSchema,
  UserRescheduleSchema,
} from '../types';
import * as bookingService from '../services/booking.service';
import * as invitationService from '../services/invitation.service';
import * as pushService from '../services/push.service';
import * as wsService from '../services/websocket.service';
import { authMiddleware } from '../middleware/auth';
import type { AppContext } from '../lib/context';
import { getQuestionnaire } from '../constants/questionnaire';

const app = new Hono<AppContext>();

// Public endpoint - get all bookings availability (minimal data for guests)
// NOTE: Only shows APPROVED bookings (not pending approvals)
app.get('/availability', async (c) => {
  try {
    const month = c.req.query('month');
    const bookings = await bookingService.getBookingsAvailability(month);
    return c.json({ bookings });
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Admin/Manager endpoint - get bookings availability INCLUDING pending approvals (intentions)
app.get('/availability-admin', authMiddleware, async (c) => {
  try {
    const user = c.get('user');

    // Only admins and managers can see pending bookings
    if (user.role !== 'ADMIN' && user.role !== 'MANAGER') {
      return c.json({ error: 'Only admins and managers can access this endpoint' }, 403);
    }

    const month = c.req.query('month');
    const bookings = await bookingService.getBookingsAvailabilityForAdmins(month);
    return c.json({ bookings });
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Public endpoint - check availability for specific date
app.get('/availability/:date', async (c) => {
  try {
    const date = c.req.param('date');
    const visitType = c.req.query('visitType');
    const availability = await bookingService.checkAvailability(date, visitType || undefined);
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
    const booking = await bookingService.createBooking(data, user.id, user.role);

    // NOTE: Notification sent via notifyAllManagers() in booking.service.ts
    // This avoids duplicate notifications

    // Broadcast WebSocket event for real-time UI updates
    wsService.broadcastBookingCreated(booking);

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

    // NOTE: Notification sent via notifyAllManagers() in booking.service.ts
    // This avoids duplicate notifications

    // Broadcast WebSocket event for real-time UI updates
    wsService.broadcastBookingCreated(booking);

    return c.json(booking, 201);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Get questionnaire (public - needed for Pace Visit Fullday, Innovation Exchange & Hackathon)
app.get('/questionnaire', async (c) => {
  try {
    const eventType = c.req.query('eventType');
    const questionnaire = getQuestionnaire(eventType);
    return c.json({ questionnaire });
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
    const user = c.get('user');
    const month = c.req.query('month');
    const status = c.req.query('status');

    // USER role can only see their own bookings
    // ADMIN and MANAGER can see all bookings
    const userId = user.role === 'USER' ? user.id : undefined;

    const bookings = await bookingService.getBookings(month, status, userId);
    return c.json({ bookings });
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
    const user = c.get('user');
    const id = c.req.param('id');
    const data = c.req.valid('json');

    // Get original booking to check status before update
    const originalBooking = await bookingService.getBookingById(id);
    const wasNeedEdit = originalBooking.status === 'NEED_EDIT';
    const wasNeedReschedule = originalBooking.status === 'NEED_RESCHEDULE';
    const isOwner = originalBooking.createdById === user.id;
    const isUserEditing = isOwner && user.role !== 'ADMIN';
    const isChangingToReview = data.status === 'UNDER_REVIEW' || data.status === 'CREATED';

    // When owner edits, set status back to UNDER_REVIEW for re-approval
    if (isUserEditing && !data.status) {
      data.status = 'UNDER_REVIEW';
    }

    const booking = await bookingService.updateBooking(id, data);

    // Send appropriate push notification
    try {
      // If USER edited a NEED_EDIT or NEED_RESCHEDULE booking and changed status to review, notify managers
      if ((wasNeedEdit || wasNeedReschedule) && isUserEditing && isChangingToReview) {
        await pushService.sendUserEditedNotification(booking.id);
      }
      // Otherwise, generic update notification (keep backward compatibility)
      else {
        await pushService.sendBookingUpdateNotification(booking.id);
      }
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
      // Don't fail the request if notification fails
    }

    // Broadcast WebSocket event for real-time UI updates
    wsService.broadcastBookingUpdated(booking);

    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Delete booking (authenticated)
app.delete('/:id', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');

    // Check permissions:
    // - USER can only delete their own bookings
    // - ADMIN and MANAGER can delete/deny any booking
    if (user.role === 'USER') {
      // Verify the booking belongs to the user
      const booking = await bookingService.getBookingById(id);
      if (booking.createdById !== user.id) {
        return c.json({ error: 'You can only cancel your own bookings' }, 403);
      }
    }
    // ADMIN and MANAGER can delete/deny any booking (no check needed)

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

// Approve booking (manager/admin only)
app.post('/:id/approve', authMiddleware, async (c) => {
  try {
    const user = c.get('user');

    // Check if user is manager or admin
    if (user.role !== 'MANAGER' && user.role !== 'ADMIN') {
      return c.json({ error: 'Only managers and admins can approve bookings' }, 403);
    }

    const id = c.req.param('id');
    const booking = await bookingService.approveBooking(id, user.id);

    // Send push notification to booking creator
    try {
      await pushService.sendBookingApprovedNotification(booking.id);
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
    }

    // Broadcast WebSocket event for real-time UI updates
    wsService.broadcastBookingUpdated(booking);

    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Reschedule booking (authenticated)
app.post('/:id/reschedule', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');
    const { date, startTime, duration } = await c.req.json();

    if (!date || !startTime || !duration) {
      return c.json({ error: 'Missing required fields: date, startTime, duration' }, 400);
    }

    const newBooking = await bookingService.rescheduleBooking(id, date, startTime, duration, user.id);
    return c.json(newBooking, 201);
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

// ==================== NEW STATUS FLOW ROUTES ====================

// Manager/Admin: Request Edit (CREATED/UNDER_REVIEW → NEED_EDIT)
app.post('/:id/request-edit', authMiddleware, zValidator('json', RequestEditSchema), async (c) => {
  try {
    const user = c.get('user');

    // Check if user is manager or admin
    if (user.role !== 'MANAGER' && user.role !== 'ADMIN') {
      return c.json({ error: 'Only managers and admins can request edits' }, 403);
    }

    const id = c.req.param('id');
    const data = c.req.valid('json');
    const booking = await bookingService.requestEdit(id, user.id, data.message);

    // Send push notification to the booking creator
    try {
      await pushService.sendEditRequestNotification(booking.id);
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
      // Don't fail the request if notification fails
    }

    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Manager/Admin: Request Reschedule (CREATED/UNDER_REVIEW → NEED_RESCHEDULE)
app.post('/:id/request-reschedule', authMiddleware, zValidator('json', RequestRescheduleSchema), async (c) => {
  try {
    const user = c.get('user');

    // Check if user is manager or admin
    if (user.role !== 'MANAGER' && user.role !== 'ADMIN') {
      return c.json({ error: 'Only managers and admins can request reschedules' }, 403);
    }

    const id = c.req.param('id');
    const data = c.req.valid('json');
    const booking = await bookingService.requestReschedule(id, user.id, data.message);

    // Send push notification to the booking creator
    try {
      await pushService.sendRescheduleRequestNotification(booking.id);
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
      // Don't fail the request if notification fails
    }

    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Manager/Admin: Reject Booking (CREATED/UNDER_REVIEW → NOT_APPROVED)
app.post('/:id/reject', authMiddleware, zValidator('json', RejectBookingSchema), async (c) => {
  try {
    const user = c.get('user');

    // Check if user is manager or admin
    if (user.role !== 'MANAGER' && user.role !== 'ADMIN') {
      return c.json({ error: 'Only managers and admins can reject bookings' }, 403);
    }

    const id = c.req.param('id');
    const data = c.req.valid('json');
    const booking = await bookingService.rejectBooking(id, user.id, data.rejectionReason);

    // Send push notification to booking creator
    try {
      await pushService.sendBookingRejectedNotification(booking.id);
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
    }

    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Manager/Admin: Cancel Booking (ANY → CANCELLED)
app.post('/:id/cancel', authMiddleware, zValidator('json', CancelBookingSchema), async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');
    const data = c.req.valid('json');

    // Allow managers/admins to cancel any booking, or users to cancel their own
    if (user.role === 'USER') {
      const booking = await bookingService.getBookingById(id);
      if (booking.createdById !== user.id) {
        return c.json({ error: 'You can only cancel your own bookings' }, 403);
      }
    }

    const booking = await bookingService.cancelBooking(id, user.id, data.cancellationReason);
    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// User: Reschedule when status is NEED_RESCHEDULE (NEED_RESCHEDULE → UNDER_REVIEW)
app.post('/:id/user-reschedule', authMiddleware, zValidator('json', UserRescheduleSchema), async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');
    const data = c.req.valid('json');

    const booking = await bookingService.userRescheduleBooking(
      id,
      user.id,
      data.date,
      data.startTime,
      data.duration
    );

    // Send push notification to managers about the reschedule
    try {
      await pushService.sendUserRescheduledNotification(booking.id);
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError);
      // Don't fail the request if notification fails
    }

    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Manager/Admin: Mark as Under Review (CREATED → UNDER_REVIEW)
app.post('/:id/mark-under-review', authMiddleware, async (c) => {
  try {
    const user = c.get('user');

    // Check if user is manager or admin
    if (user.role !== 'MANAGER' && user.role !== 'ADMIN') {
      return c.json({ error: 'Only managers and admins can mark bookings as under review' }, 403);
    }

    const id = c.req.param('id');
    const booking = await bookingService.markAsUnderReview(id, user.id);

    // No push notification needed - this is an internal status transition
    // The booking creator already receives an in-app notification from markAsUnderReview()

    return c.json(booking);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// ==================== QUESTIONNAIRE ROUTE ====================

export default app;
