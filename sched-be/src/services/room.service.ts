import { prisma } from '../lib/prisma';
import type { RoomBookingCreateInput, RoomBookingEditInput } from '../types/room.types';
import { RoomTypeSchema } from '../types/room.types';
import * as websocketService from './websocket.service';
import * as notificationService from './notification.service';

const ALL_ROOMS = RoomTypeSchema.options;

// ==================== CREATE ====================

export async function createRoomBooking(data: RoomBookingCreateInput, bookedById: string, bookerRole?: string) {
  // Check for time overlap with APPROVED or PENDING bookings on the same room and date
  const conflicting = await prisma.roomBooking.findFirst({
    where: {
      room: data.room,
      date: new Date(data.date),
      status: { in: ['APPROVED', 'PENDING'] },
      AND: [
        { startTime: { lt: data.endTime } },
        { endTime: { gt: data.startTime } },
      ],
    },
  });

  if (conflicting) {
    throw new Error(`Room is already booked from ${conflicting.startTime} to ${conflicting.endTime} (${conflicting.status.toLowerCase()})`);
  }

  const isPrivileged = bookerRole === 'MANAGER' || bookerRole === 'ADMIN';
  const booking = await prisma.roomBooking.create({
    data: {
      room: data.room,
      date: new Date(data.date),
      startTime: data.startTime,
      endTime: data.endTime,
      purpose: data.purpose,
      attendees: data.attendees,
      vertical: data.vertical,
      bookedById,
      createdAsRole: bookerRole || 'USER',
      status: isPrivileged ? 'APPROVED' : 'PENDING',
      reviewReason: isPrivileged ? null : 'NEW',
      ...(isPrivileged ? { approvedById: bookedById, approvedAt: new Date() } : {}),
    },
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
    },
  });

  websocketService.broadcastRoomBookingCreated(booking);

  // Notify all managers about new room booking
  const roomLabel = booking.room.replace(/_/g, ' ');
  notificationService.notifyAllManagers(
    'BOOKING_CREATED',
    'New Room Booking',
    `${booking.bookedBy.name} requested ${roomLabel} on ${booking.date.toISOString().split('T')[0]} (${booking.startTime}-${booking.endTime})`,
    undefined
  ).catch(() => {});

  return booking;
}

// ==================== LIST ====================

export async function getRoomBookings(filters: {
  date?: string;
  room?: string;
  status?: string;
  bookedById?: string;
  createdAsRole?: string;
}) {
  const where: Record<string, unknown> = {};

  if (filters.date) {
    where.date = new Date(filters.date);
  }
  if (filters.room) {
    where.room = filters.room;
  }
  if (filters.status) {
    where.status = filters.status;
  }
  if (filters.bookedById) {
    where.bookedById = filters.bookedById;
  }
  if (filters.createdAsRole) {
    where.createdAsRole = filters.createdAsRole;
  }

  const bookings = await prisma.roomBooking.findMany({
    where,
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
      approvedBy: { select: { id: true, name: true, email: true } },
    },
    orderBy: [{ date: 'asc' }, { startTime: 'asc' }],
  });

  return bookings;
}

// ==================== GET BY ID ====================

export async function getRoomBookingById(id: string) {
  const booking = await prisma.roomBooking.findUnique({
    where: { id },
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
      approvedBy: { select: { id: true, name: true, email: true } },
    },
  });

  if (!booking) {
    throw new Error('Room booking not found');
  }

  return booking;
}

// ==================== AVAILABILITY ====================

export async function getRoomAvailability(date: string, userId?: string, userRole?: string) {
  const targetDate = new Date(date);

  // Get all APPROVED and PENDING bookings for the date
  const allBookings = await prisma.roomBooking.findMany({
    where: {
      date: targetDate,
      status: { in: ['APPROVED', 'PENDING'] },
    },
    orderBy: { startTime: 'asc' },
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
    },
  });

  // Build availability map per room
  const availability = ALL_ROOMS.map((room) => {
    const isManagerOrAdmin = userRole === 'ADMIN' || userRole === 'MANAGER';
    const roomBookings = allBookings
      .filter((b) => b.room === room)
      .map((b) => {
        const isOwner = userId && b.bookedById === userId;
        const canSeeDetails = isOwner || isManagerOrAdmin;
        return {
          id: b.id,
          startTime: b.startTime,
          endTime: b.endTime,
          status: b.status,
          purpose: canSeeDetails ? b.purpose : 'Booked',
          bookedByName: canSeeDetails ? b.bookedBy.name : 'Reserved',
          bookedById: b.bookedById,
        };
      });

    // Calculate open time ranges (08:00 - 20:00) based on approved only
    const approvedSlots = roomBookings.filter((b) => b.status === 'APPROVED');
    const openSlots: Array<{ startTime: string; endTime: string }> = [];
    let cursor = '08:00';

    for (const slot of approvedSlots) {
      if (cursor < slot.startTime) {
        openSlots.push({ startTime: cursor, endTime: slot.startTime });
      }
      if (slot.endTime > cursor) {
        cursor = slot.endTime;
      }
    }

    if (cursor < '20:00') {
      openSlots.push({ startTime: cursor, endTime: '20:00' });
    }

    return {
      room,
      bookedSlots: roomBookings,
      openSlots,
    };
  });

  return { date, availability };
}

// ==================== APPROVE ====================

export async function approveRoomBooking(id: string, approvedById: string) {
  const booking = await prisma.roomBooking.findUnique({ where: { id } });

  if (!booking) {
    throw new Error('Room booking not found');
  }

  if (!['PENDING', 'NEED_EDIT', 'NEED_RESCHEDULE'].includes(booking.status)) {
    throw new Error(`Cannot approve a booking with status ${booking.status}`);
  }

  // Check for conflicts with other APPROVED bookings
  const conflicting = await prisma.roomBooking.findFirst({
    where: {
      id: { not: id },
      room: booking.room,
      date: booking.date,
      status: 'APPROVED',
      AND: [
        { startTime: { lt: booking.endTime } },
        { endTime: { gt: booking.startTime } },
      ],
    },
  });

  if (conflicting) {
    throw new Error(`Cannot approve: room ${booking.room} already has an approved booking from ${conflicting.startTime} to ${conflicting.endTime}`);
  }

  const updated = await prisma.roomBooking.update({
    where: { id },
    data: {
      status: 'APPROVED',
      approvedById,
      approvedAt: new Date(),
    },
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
      approvedBy: { select: { id: true, name: true, email: true } },
    },
  });

  websocketService.broadcastRoomBookingUpdated(updated);

  // Notify the user who booked
  const roomLabel = updated.room.replace(/_/g, ' ');
  notificationService.createNotification({
    userId: updated.bookedById,
    type: 'BOOKING_APPROVED',
    title: 'Room Booking Approved',
    message: `Your ${roomLabel} booking on ${updated.date.toISOString().split('T')[0]} (${updated.startTime}-${updated.endTime}) has been approved.`,
  }).catch(() => {});

  return updated;
}

// ==================== REJECT ====================

export async function rejectRoomBooking(id: string, approvedById: string, rejectionReason: string) {
  const booking = await prisma.roomBooking.findUnique({ where: { id } });

  if (!booking) {
    throw new Error('Room booking not found');
  }

  if (!['PENDING', 'NEED_EDIT', 'NEED_RESCHEDULE'].includes(booking.status)) {
    throw new Error(`Cannot reject a booking with status ${booking.status}`);
  }

  const updated = await prisma.roomBooking.update({
    where: { id },
    data: {
      status: 'REJECTED',
      approvedById,
      rejectionReason,
      rejectedAt: new Date(),
    },
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
      approvedBy: { select: { id: true, name: true, email: true } },
    },
  });

  websocketService.broadcastRoomBookingUpdated(updated);

  // Notify the user who booked
  const rejRoomLabel = updated.room.replace(/_/g, ' ');
  notificationService.createNotification({
    userId: updated.bookedById,
    type: 'BOOKING_NOT_APPROVED',
    title: 'Room Booking Rejected',
    message: `Your ${rejRoomLabel} booking on ${updated.date.toISOString().split('T')[0]} (${updated.startTime}-${updated.endTime}) was rejected. ${rejectionReason ? 'Reason: ' + rejectionReason : ''}`,
  }).catch(() => {});

  return updated;
}

// ==================== CANCEL ====================

export async function cancelRoomBooking(id: string) {
  const booking = await prisma.roomBooking.findUnique({ where: { id } });

  if (!booking) {
    throw new Error('Room booking not found');
  }

  if (booking.status === 'CANCELLED') {
    throw new Error('Booking is already cancelled');
  }

  const updated = await prisma.roomBooking.update({
    where: { id },
    data: { status: 'CANCELLED', cancelledAt: new Date() },
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
    },
  });

  websocketService.broadcastRoomBookingUpdated(updated);

  // Notify the user who booked
  const canRoomLabel = updated.room.replace(/_/g, ' ');
  notificationService.createNotification({
    userId: updated.bookedById,
    type: 'BOOKING_CANCELLED',
    title: 'Room Booking Cancelled',
    message: `Your ${canRoomLabel} booking on ${updated.date.toISOString().split('T')[0]} (${updated.startTime}-${updated.endTime}) has been cancelled.`,
  }).catch(() => {});

  return updated;
}

// ==================== UPDATE (EDIT) ====================

export async function updateRoomBooking(id: string, data: RoomBookingEditInput) {
  const booking = await prisma.roomBooking.findUnique({ where: { id } });

  if (!booking) {
    throw new Error('Room booking not found');
  }

  if (['REJECTED', 'CANCELLED'].includes(booking.status)) {
    throw new Error(`Cannot edit a booking with status ${booking.status}`);
  }

  const updateData: Record<string, unknown> = {};
  if (data.purpose !== undefined) updateData.purpose = data.purpose;
  if (data.attendees !== undefined) updateData.attendees = data.attendees;
  if (data.vertical !== undefined) updateData.vertical = data.vertical;

  // Owner edits set status back to PENDING for re-review
  updateData.status = 'PENDING';
  updateData.reviewReason = 'DATA_EDITED';

  const updated = await prisma.roomBooking.update({
    where: { id },
    data: updateData,
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
      approvedBy: { select: { id: true, name: true, email: true } },
    },
  });

  websocketService.broadcastRoomBookingUpdated(updated);

  const editRoomLabel = updated.room.replace(/_/g, ' ');
  notificationService.notifyAllManagers(
    'BOOKING_CREATED',
    'Room Booking Edited',
    `${updated.bookedBy.name} edited their ${editRoomLabel} booking on ${updated.date.toISOString().split('T')[0]} (${updated.startTime}-${updated.endTime})`,
    undefined
  ).catch(() => {});

  return updated;
}

// ==================== RESCHEDULE ====================

export async function rescheduleRoomBooking(
  id: string,
  userId: string,
  newDate: string,
  newStartTime: string,
  newEndTime: string,
) {
  const booking = await prisma.roomBooking.findUnique({ where: { id } });

  if (!booking) {
    throw new Error('Room booking not found');
  }

  if (['REJECTED', 'CANCELLED'].includes(booking.status)) {
    throw new Error(`Cannot reschedule a booking with status ${booking.status}`);
  }

  // Check for time conflicts on the new date/time (excluding this booking)
  const conflicting = await prisma.roomBooking.findFirst({
    where: {
      id: { not: id },
      room: booking.room,
      date: new Date(newDate),
      status: { in: ['APPROVED', 'PENDING'] },
      AND: [
        { startTime: { lt: newEndTime } },
        { endTime: { gt: newStartTime } },
      ],
    },
  });

  if (conflicting) {
    throw new Error(`Room is already booked from ${conflicting.startTime} to ${conflicting.endTime} (${conflicting.status.toLowerCase()})`);
  }

  const updated = await prisma.roomBooking.update({
    where: { id },
    data: {
      previousDate: booking.date,
      previousStartTime: booking.startTime,
      previousEndTime: booking.endTime,
      date: new Date(newDate),
      startTime: newStartTime,
      endTime: newEndTime,
      status: 'PENDING',
      reviewReason: 'RESCHEDULED',
    },
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
      approvedBy: { select: { id: true, name: true, email: true } },
    },
  });

  websocketService.broadcastRoomBookingUpdated(updated);

  const resRoomLabel = updated.room.replace(/_/g, ' ');
  notificationService.notifyAllManagers(
    'BOOKING_CREATED',
    'Room Booking Rescheduled',
    `${updated.bookedBy.name} rescheduled their ${resRoomLabel} booking to ${newDate} (${newStartTime}-${newEndTime})`,
    undefined
  ).catch(() => {});

  return updated;
}

// ==================== REQUEST EDIT ====================

export async function requestEditRoomBooking(id: string, managerId: string, message?: string) {
  const booking = await prisma.roomBooking.findUnique({ where: { id } });

  if (!booking) {
    throw new Error('Room booking not found');
  }

  if (!['PENDING', 'APPROVED'].includes(booking.status)) {
    throw new Error(`Cannot request edit for a booking with status ${booking.status}`);
  }

  const updated = await prisma.roomBooking.update({
    where: { id },
    data: {
      status: 'NEED_EDIT',
      editRequestMessage: message || null,
    },
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
      approvedBy: { select: { id: true, name: true, email: true } },
    },
  });

  websocketService.broadcastRoomBookingUpdated(updated);

  const reqEditRoomLabel = updated.room.replace(/_/g, ' ');
  notificationService.createNotification({
    userId: updated.bookedById,
    type: 'BOOKING_NOT_APPROVED',
    title: 'Room Booking: Edit Requested',
    message: `A manager has requested edits to your ${reqEditRoomLabel} booking on ${updated.date.toISOString().split('T')[0]}.${message ? ' Message: ' + message : ''}`,
  }).catch(() => {});

  return updated;
}

// ==================== REQUEST RESCHEDULE ====================

export async function requestRescheduleRoomBooking(id: string, managerId: string, message?: string) {
  const booking = await prisma.roomBooking.findUnique({ where: { id } });

  if (!booking) {
    throw new Error('Room booking not found');
  }

  if (!['PENDING', 'APPROVED'].includes(booking.status)) {
    throw new Error(`Cannot request reschedule for a booking with status ${booking.status}`);
  }

  const updated = await prisma.roomBooking.update({
    where: { id },
    data: {
      status: 'NEED_RESCHEDULE',
      rescheduleRequestMessage: message || null,
    },
    include: {
      bookedBy: { select: { id: true, name: true, email: true } },
      approvedBy: { select: { id: true, name: true, email: true } },
    },
  });

  websocketService.broadcastRoomBookingUpdated(updated);

  const reqResRoomLabel = updated.room.replace(/_/g, ' ');
  notificationService.createNotification({
    userId: updated.bookedById,
    type: 'BOOKING_NOT_APPROVED',
    title: 'Room Booking: Reschedule Requested',
    message: `A manager has requested you reschedule your ${reqResRoomLabel} booking on ${updated.date.toISOString().split('T')[0]}.${message ? ' Message: ' + message : ''}`,
  }).catch(() => {});

  return updated;
}
