import { prisma } from '../lib/prisma';
import type { BookingCreateInput, BookingUpdateInput } from '../types';
import * as pushService from './push.service';
import * as websocketService from './websocket.service';

// Helper: Convert time string to minutes since 9AM
function timeToMinutes(timeStr: string): number {
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours - 9) * 60 + minutes; // Offset from 9AM
}

// Helper: Convert duration enum to hours
function durationToHours(duration: string): number {
  const map: Record<string, number> = {
    'ONE_HOUR': 1,
    'TWO_HOURS': 2,
    'THREE_HOURS': 3,
    'FOUR_HOURS': 4,
    'FIVE_HOURS': 5,
    'SIX_HOURS': 6,
  };
  return map[duration] || 0;
}

// Helper: Check if date is weekend (Saturday or Sunday)
function isWeekend(date: Date): boolean {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

// Helper: Get previous business day (skip weekends)
function getPreviousBusinessDay(date: Date): Date {
  const prevDay = new Date(date);
  prevDay.setDate(prevDay.getDate() - 1);

  // Keep going back until we find a weekday
  while (isWeekend(prevDay)) {
    prevDay.setDate(prevDay.getDate() - 1);
  }

  return prevDay;
}

// Helper: Get next business day (skip weekends)
function getNextBusinessDay(date: Date): Date {
  const nextDay = new Date(date);
  nextDay.setDate(nextDay.getDate() + 1);

  // Keep going forward until we find a weekday
  while (isWeekend(nextDay)) {
    nextDay.setDate(nextDay.getDate() + 1);
  }

  return nextDay;
}

// Helper: Check if time is in morning period (9:00-13:00)
function isMorningPeriod(startTime: string): boolean {
  const hour = parseInt(startTime.split(':')[0]);
  return hour >= 9 && hour < 13;
}

// Helper: Check if time is in afternoon period (13:00-17:00)
function isAfternoonPeriod(startTime: string): boolean {
  const hour = parseInt(startTime.split(':')[0]);
  return hour >= 13 && hour < 17;
}

// Helper: Check if two time ranges overlap
function timeRangesOverlap(
  start1Minutes: number,
  duration1Hours: number,
  start2Minutes: number,
  duration2Hours: number
): boolean {
  const end1Minutes = start1Minutes + duration1Hours * 60;
  const end2Minutes = start2Minutes + duration2Hours * 60;

  return start1Minutes < end2Minutes && start2Minutes < end1Minutes;
}

// Helper: Check if a period (morning or afternoon) is free on a given date
async function isPeriodFree(date: Date, isMorning: boolean): Promise<boolean> {
  const dateStr = date.toISOString().split('T')[0];

  const bookings = await prisma.booking.findMany({
    where: {
      date: new Date(dateStr),
      status: 'CONFIRMED', // Only count CONFIRMED bookings
    },
  });

  // Check if any booking conflicts with the period
  for (const booking of bookings) {
    if (isMorning) {
      // Morning period: 9:00-13:00
      if (isMorningPeriod(booking.startTime)) {
        return false; // Period is occupied
      }
    } else {
      // Afternoon period: 13:00-17:00
      if (isAfternoonPeriod(booking.startTime)) {
        return false; // Period is occupied
      }
    }
  }

  return true; // Period is free
}

// Validate Innovation Exchange booking (needs prep/teardown periods)
async function validateInnovationExchange(
  date: string,
  startTime: string,
  duration: string
): Promise<{ valid: boolean; error?: string }> {
  const bookingDate = new Date(date);
  const durationHours = durationToHours(duration);

  // Must be 4-6 hours
  if (durationHours < 4 || durationHours > 6) {
    return {
      valid: false,
      error: 'Innovation Exchange must be between 4-6 hours',
    };
  }

  const isBookingInMorning = isMorningPeriod(startTime);

  // Check prep period (before the event)
  if (isBookingInMorning) {
    // Event in morning → need afternoon of previous business day free
    const prevDay = getPreviousBusinessDay(bookingDate);
    const afternoonFree = await isPeriodFree(prevDay, false);

    if (!afternoonFree) {
      return {
        valid: false,
        error: `Cannot book Innovation Exchange on ${date} morning: afternoon of ${prevDay.toISOString().split('T')[0]} must be free for preparation`,
      };
    }
  } else {
    // Event in afternoon → need morning of same day free
    const morningFree = await isPeriodFree(bookingDate, true);

    if (!morningFree) {
      return {
        valid: false,
        error: `Cannot book Innovation Exchange on ${date} afternoon: morning must be free for preparation`,
      };
    }
  }

  // Check teardown period (after the event)
  if (isBookingInMorning) {
    // Event in morning → afternoon of same day must be free
    const afternoonFree = await isPeriodFree(bookingDate, false);

    if (!afternoonFree) {
      return {
        valid: false,
        error: `Cannot book Innovation Exchange on ${date} morning: afternoon must be free for teardown`,
      };
    }
  } else {
    // Event in afternoon → morning of next business day must be free
    const nextDay = getNextBusinessDay(bookingDate);
    const morningFree = await isPeriodFree(nextDay, true);

    if (!morningFree) {
      return {
        valid: false,
        error: `Cannot book Innovation Exchange on ${date} afternoon: morning of ${nextDay.toISOString().split('T')[0]} must be free for teardown`,
      };
    }
  }

  return { valid: true };
}

// Validate Quick Tour booking (max 2 per day, only 2 hours)
async function validateQuickTour(
  date: string,
  duration: string
): Promise<{ valid: boolean; error?: string }> {
  const durationHours = durationToHours(duration);

  // Must be exactly 2 hours
  if (durationHours !== 2) {
    return {
      valid: false,
      error: 'Quick Tour must be exactly 2 hours',
    };
  }

  // Check how many CONFIRMED Quick Tours are already booked on this date
  const existingQuickTours = await prisma.booking.findMany({
    where: {
      date: new Date(date),
      visitType: 'QUICK_TOUR',
      status: 'CONFIRMED', // Only count CONFIRMED bookings
    },
  });

  if (existingQuickTours.length >= 2) {
    return {
      valid: false,
      error: 'Maximum 2 Quick Tours allowed per day (already have 2 booked)',
    };
  }

  return { valid: true };
}

export async function checkAvailability(date: string, visitType?: 'QUICK_TOUR' | 'INNOVATION_EXCHANGE') {
  const bookingDate = new Date(date);

  // Get ONLY CONFIRMED bookings for this date (not PENDING_APPROVAL)
  const bookings = await prisma.booking.findMany({
    where: {
      date: bookingDate,
      status: 'CONFIRMED', // Only count confirmed bookings
    },
  });

  // Period-based availability structure
  type Period = {
    period: 'MORNING' | 'AFTERNOON';
    label: string;
    startTime: string;
    available: boolean;
    blockedBy?: string;
    willBlock?: Array<{date: string; period: string}>;
  };

  const periods: Period[] = [
    {
      period: 'MORNING',
      label: 'Morning (9:00 - 13:00)',
      startTime: '09:00',
      available: true,
    },
    {
      period: 'AFTERNOON',
      label: 'Afternoon (13:00 - 17:00)',
      startTime: '13:00',
      available: true,
    },
  ];

  // Check which periods are occupied
  for (const booking of bookings) {
    const isMorning = isMorningPeriod(booking.startTime);
    const periodIndex = isMorning ? 0 : 1;
    periods[periodIndex].available = false;
    periods[periodIndex].blockedBy = `${booking.companyName} - ${booking.visitType}`;
  }

  // Apply visit type filtering
  if (visitType === 'QUICK_TOUR') {
    // Quick Tour: max 1 in morning AND 1 in afternoon
    const existingQuickTours = await prisma.booking.findMany({
      where: {
        date: bookingDate,
        visitType: 'QUICK_TOUR',
        status: 'CONFIRMED', // Only count CONFIRMED bookings
      },
    });

    // Mark periods as unavailable if already have a Quick Tour in that period
    for (const qt of existingQuickTours) {
      const isMorning = isMorningPeriod(qt.startTime);
      const periodIndex = isMorning ? 0 : 1;
      periods[periodIndex].available = false;
      periods[periodIndex].blockedBy = `Quick Tour already scheduled`;
    }
  } else if (visitType === 'INNOVATION_EXCHANGE') {
    // Innovation Exchange: only 1 per day
    const existingIE = await prisma.booking.findMany({
      where: {
        date: bookingDate,
        visitType: 'INNOVATION_EXCHANGE',
        status: 'CONFIRMED', // Only count CONFIRMED bookings
      },
    });

    if (existingIE.length > 0) {
      // Already have an Innovation Exchange, no periods available
      periods[0].available = false;
      periods[0].blockedBy = 'Innovation Exchange already scheduled for this day';
      periods[1].available = false;
      periods[1].blockedBy = 'Innovation Exchange already scheduled for this day';
    } else {
      // Check prep/teardown availability for each period

      // Morning period check
      const prevDay = getPreviousBusinessDay(bookingDate);
      const morningPrepOk = await isPeriodFree(prevDay, false); // Need prev afternoon free
      const morningTeardownOk = await isPeriodFree(bookingDate, false); // Need same afternoon free

      if (!morningPrepOk || !morningTeardownOk) {
        periods[0].available = false;
        periods[0].blockedBy = !morningPrepOk
          ? `Requires free afternoon on ${prevDay.toISOString().split('T')[0]} (prep)`
          : 'Requires free afternoon on same day (teardown)';
      } else {
        // Add info about what will be blocked
        periods[0].willBlock = [
          { date: prevDay.toISOString().split('T')[0], period: 'Afternoon (prep)' },
          { date: date, period: 'Morning (event)' },
          { date: date, period: 'Afternoon (teardown)' },
        ];
      }

      // Afternoon period check
      const nextDay = getNextBusinessDay(bookingDate);
      const afternoonPrepOk = await isPeriodFree(bookingDate, true); // Need same morning free
      const afternoonTeardownOk = await isPeriodFree(nextDay, true); // Need next morning free

      if (!afternoonPrepOk || !afternoonTeardownOk) {
        periods[1].available = false;
        periods[1].blockedBy = !afternoonPrepOk
          ? 'Requires free morning on same day (prep)'
          : `Requires free morning on ${nextDay.toISOString().split('T')[0]} (teardown)`;
      } else {
        // Add info about what will be blocked
        periods[1].willBlock = [
          { date: date, period: 'Morning (prep)' },
          { date: date, period: 'Afternoon (event)' },
          { date: nextDay.toISOString().split('T')[0], period: 'Morning (teardown)' },
        ];
      }
    }
  }

  const availablePeriods = periods.filter(p => p.available);

  return {
    date,
    isFull: availablePeriods.length === 0,
    availablePeriods,
    allPeriods: periods,
    existingBookings: bookings,
  };
}

export async function createBooking(data: BookingCreateInput, createdById?: string) {
  const bookingDate = new Date(data.date);

  // 1. Block weekends
  if (isWeekend(bookingDate)) {
    throw new Error('Bookings are not allowed on weekends (Saturday/Sunday)');
  }

  // 2. Validate visit type and duration match
  if (data.visitType === 'QUICK_TOUR') {
    // Quick Tour must be exactly 2 hours
    if (data.duration !== 'TWO_HOURS') {
      throw new Error('Quick Tour must be exactly 2 hours');
    }

    // Validate Quick Tour specific rules
    const quickTourValidation = await validateQuickTour(data.date, data.duration);
    if (!quickTourValidation.valid) {
      throw new Error(quickTourValidation.error);
    }
  } else if (data.visitType === 'INNOVATION_EXCHANGE') {
    // Innovation Exchange must be 4-6 hours
    const durationHours = durationToHours(data.duration);
    if (durationHours < 4 || durationHours > 6) {
      throw new Error('Innovation Exchange must be between 4-6 hours');
    }

    // Validate Innovation Exchange specific rules (prep/teardown)
    const innovationValidation = await validateInnovationExchange(
      data.date,
      data.startTime,
      data.duration
    );
    if (!innovationValidation.valid) {
      throw new Error(innovationValidation.error);
    }
  }

  // 3. Validate availability (general conflict check)
  const availability = await checkAvailability(data.date);

  // Check if requested time and duration are available
  const requestedStartMinutes = timeToMinutes(data.startTime);
  const requestedDurationHours = durationToHours(data.duration);

  // Check for time conflicts with existing bookings
  for (const existing of availability.existingBookings) {
    const existingStart = timeToMinutes(existing.startTime);
    const existingDuration = durationToHours(existing.duration);

    if (timeRangesOverlap(
      requestedStartMinutes,
      requestedDurationHours,
      existingStart,
      existingDuration
    )) {
      throw new Error('Booking conflicts with existing booking');
    }
  }

  // 4. Validate attendees count (maximum 3)
  if (data.attendees && data.attendees.length > 3) {
    throw new Error('Maximum 3 attendees allowed per booking');
  }

  const { attendees, lastInnovationDay, ...bookingData } = data;

  const booking = await prisma.booking.create({
    data: {
      ...bookingData,
      date: new Date(data.date),
      lastInnovationDay: lastInnovationDay ? new Date(lastInnovationDay) : null,
      expectedAttendees: data.expectedAttendees || 1,
      status: 'PENDING_APPROVAL',
      createdById,
      attendees: attendees
        ? {
            create: attendees.map((att) => ({
              name: att.name,
              email: att.email,
              role: att.role,
              tcsSupporter: att.tcsSupporter,
              understandingOfTCS: att.understandingOfTCS,
              focusAreas: att.focusAreas,
              yearsWorkingWithTCS: att.yearsWorkingWithTCS,
              position: att.position,
              educationalQualification: att.educationalQualification,
              careerBackground: att.careerBackground,
              linkedinProfile: att.linkedinProfile,
              photoUrl: att.photoUrl,
            })),
          }
        : undefined,
    },
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
      attendees: true,
    },
  });

  // Notify all managers about the new booking pending approval (async, don't block)
  const notificationService = await import('./notification.service');
  notificationService.notifyAllManagers(
    'BOOKING_PENDING_APPROVAL',
    'New Booking Pending Approval',
    `${booking.companyName} requested a visit on ${new Date(booking.date).toLocaleDateString()} at ${booking.startTime}. ${booking.expectedAttendees} attendees expected.`,
    booking.id
  ).catch((error: any) => {
    console.error('Failed to send manager notifications:', error);
  });

  // Broadcast booking creation to all connected clients for real-time calendar updates
  websocketService.broadcastBookingCreated(booking);
  console.log('[Booking] Broadcast booking_created to', websocketService.getTotalConnections(), 'connections');

  return booking;
}

export async function getBookings(month?: string, status?: string) {
  const where: any = {};

  if (month) {
    const [year, monthNum] = month.split('-');
    const startDate = new Date(parseInt(year), parseInt(monthNum) - 1, 1);
    const endDate = new Date(parseInt(year), parseInt(monthNum), 0);

    where.date = {
      gte: startDate,
      lte: endDate,
    };
  }

  if (status) {
    where.status = status;
  }

  const bookings = await prisma.booking.findMany({
    where,
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
      attendees: true,
    },
    orderBy: {
      date: 'asc',
    },
  });

  return bookings;
}

export async function getBookingsAvailability(month?: string) {
  const where: any = {
    status: { notIn: ['CANCELLED', 'PENDING_APPROVAL'] },
  };

  if (month) {
    const [year, monthNum] = month.split('-');
    const startDate = new Date(parseInt(year), parseInt(monthNum) - 1, 1);
    const endDate = new Date(parseInt(year), parseInt(monthNum), 0);

    where.date = {
      gte: startDate,
      lte: endDate,
    };
  }

  // Return only minimal data needed for availability display
  // No personal information, company names, or booking details
  const bookings = await prisma.booking.findMany({
    where,
    select: {
      id: true,
      date: true,
      startTime: true,
      duration: true,
      visitType: true,
      status: true,
    },
    orderBy: {
      date: 'asc',
    },
  });

  return bookings;
}

// Get bookings availability for Admins/Managers (includes PENDING_APPROVAL as "intentions")
export async function getBookingsAvailabilityForAdmins(month?: string) {
  const where: any = {
    status: { notIn: ['CANCELLED', 'RESCHEDULED'] }, // Include PENDING_APPROVAL and CONFIRMED
  };

  if (month) {
    const [year, monthNum] = month.split('-');
    const startDate = new Date(parseInt(year), parseInt(monthNum) - 1, 1);
    const endDate = new Date(parseInt(year), parseInt(monthNum), 0);

    where.date = {
      gte: startDate,
      lte: endDate,
    };
  }

  // Return bookings with status to differentiate intentions vs confirmed
  const bookings = await prisma.booking.findMany({
    where,
    select: {
      id: true,
      date: true,
      startTime: true,
      duration: true,
      visitType: true,
      status: true, // PENDING_APPROVAL = intention, CONFIRMED = actual booking
      companyName: true, // Show company name for admins
    },
    orderBy: {
      date: 'asc',
    },
  });

  return bookings;
}

export async function getBookingById(id: string) {
  const booking = await prisma.booking.findUnique({
    where: { id },
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
      invitation: true,
      attendees: true,
    },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  return booking;
}

export async function updateBooking(id: string, data: BookingUpdateInput) {
  // Get original booking to compare changes
  const originalBooking = await prisma.booking.findUnique({
    where: { id },
  });

  if (!originalBooking) {
    throw new Error('Booking not found');
  }

  const booking = await prisma.booking.update({
    where: { id },
    data,
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
    },
  });

  // Detect important changes
  const importantChanges: string[] = [];

  if (data.expectedAttendees !== undefined && data.expectedAttendees !== originalBooking.expectedAttendees) {
    importantChanges.push(`Expected attendees changed from ${originalBooking.expectedAttendees} to ${data.expectedAttendees}`);
  }

  if (data.date !== undefined && new Date(data.date).getTime() !== originalBooking.date.getTime()) {
    importantChanges.push(`Date changed from ${new Date(originalBooking.date).toLocaleDateString()} to ${new Date(data.date).toLocaleDateString()}`);
  }

  if (data.startTime !== undefined && data.startTime !== originalBooking.startTime) {
    importantChanges.push(`Time changed from ${originalBooking.startTime} to ${data.startTime}`);
  }

  if (data.duration !== undefined && data.duration !== originalBooking.duration) {
    importantChanges.push(`Duration changed from ${originalBooking.duration} to ${data.duration}`);
  }

  // If there are important changes, notify all managers
  if (importantChanges.length > 0) {
    const notificationService = await import('./notification.service');
    notificationService.notifyAllManagers(
      'BOOKING_IMPORTANT_CHANGE',
      'Important Booking Change',
      `${booking.companyName} booking updated: ${importantChanges.join(', ')}`,
      booking.id
    ).catch((error: any) => {
      console.error('Failed to send important change notifications:', error);
    });
  } else {
    // Send regular update notification (async, don't block)
    pushService.sendBookingUpdateNotification(booking.id).catch((error) => {
      console.error('Failed to send booking update notification:', error);
    });
  }

  // Broadcast booking update to all connected clients for real-time calendar updates
  websocketService.broadcastBookingUpdated(booking);
  console.log('[Booking] Broadcast booking_updated to', websocketService.getTotalConnections(), 'connections');

  return booking;
}

export async function deleteBooking(id: string) {
  // Get booking details before deletion for notification
  const booking = await prisma.booking.findUnique({
    where: { id },
    include: {
      createdBy: true,
      attendees: true,
    },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  // Notify all managers about the cancellation/denial
  const notificationService = await import('./notification.service');
  notificationService.notifyAllManagers(
    'BOOKING_CANCELLED',
    'Booking Cancelled',
    `${booking.companyName} visit on ${new Date(booking.date).toLocaleDateString()} at ${booking.startTime} has been cancelled.`,
    booking.id
  ).catch((error: any) => {
    console.error('Failed to send cancellation notifications:', error);
  });

  // Notify the booking creator if exists
  if (booking.createdById) {
    notificationService.createNotification({
      type: 'BOOKING_CANCELLED',
      title: 'Booking Cancelled',
      message: `Your booking for ${booking.companyName} on ${new Date(booking.date).toLocaleDateString()} at ${booking.startTime} has been cancelled.`,
      userId: booking.createdById,
      bookingId: booking.id,
    }).catch((error: any) => {
      console.error('Failed to send cancellation notification to creator:', error);
    });
  }

  // Now delete the booking
  await prisma.booking.delete({
    where: { id },
  });

  // Broadcast booking deletion to all connected clients for real-time calendar updates
  websocketService.broadcastBookingDeleted(id);
  console.log('[Booking] Broadcast booking_deleted to', websocketService.getTotalConnections(), 'connections');

  return { success: true };
}


export async function getLatestBooking() {
  const booking = await prisma.booking.findFirst({
    orderBy: { createdAt: "desc" },
    include: {
      createdBy: {
        select: { id: true, name: true, email: true, role: true },
      },
    },
  });

  return booking;
}

export async function getAttendeeById(id: string) {
  const attendee = await prisma.attendee.findUnique({
    where: { id },
    include: {
      booking: {
        select: {
          id: true,
          date: true,
          startTime: true,
          duration: true,
          companyName: true,
          companySector: true,
          companyVertical: true,
        },
      },
    },
  });

  if (!attendee) {
    throw new Error('Attendee not found');
  }

  return attendee;
}

// Approve a booking (manager only)
export async function approveBooking(bookingId: string, managerId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      createdBy: true,
    },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  if (booking.status !== 'PENDING_APPROVAL') {
    throw new Error('Booking is not pending approval');
  }

  // Update booking status to CONFIRMED
  const updatedBooking = await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: 'CONFIRMED',
      approvedById: managerId,
      approvedAt: new Date(),
    },
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
      approvedBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
      attendees: true,
    },
  });

  // Notify the booking creator
  const notificationService = await import('./notification.service');
  if (booking.createdById) {
    notificationService.createNotification({
      type: 'BOOKING_APPROVED',
      title: 'Booking Approved',
      message: `Your booking for ${booking.companyName} on ${new Date(booking.date).toLocaleDateString()} at ${booking.startTime} has been approved!`,
      userId: booking.createdById,
      bookingId: booking.id,
    }).catch((error: any) => {
      console.error('Failed to send approval notification to creator:', error);
    });
  }

  // Notify all other managers that the booking was approved
  notificationService.notifyAllManagers(
    'BOOKING_CONFIRMED',
    'Booking Confirmed',
    `${booking.companyName} visit on ${new Date(booking.date).toLocaleDateString()} at ${booking.startTime} has been approved by ${updatedBooking.approvedBy?.name}.`,
    booking.id,
    managerId // Exclude the manager who approved
  ).catch((error: any) => {
    console.error('Failed to send confirmation notifications to managers:', error);
  });

  // Broadcast booking approval to all connected clients for real-time calendar updates
  websocketService.broadcastBookingApproved(updatedBooking);
  console.log('[Booking] Broadcast booking_approved to', websocketService.getTotalConnections(), 'connections');

  return updatedBooking;
}

// Reschedule a booking
export async function rescheduleBooking(
  bookingId: string,
  newDate: string,
  newStartTime: string,
  newDuration: string,
  userId: string
) {
  const originalBooking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      attendees: true,
    },
  });

  if (!originalBooking) {
    throw new Error('Booking not found');
  }

  // Validate new date/time availability
  const availability = await checkAvailability(newDate);
  const requestedStartMinutes = timeToMinutes(newStartTime);
  const requestedDurationHours = durationToHours(newDuration);

  const availableSlot = availability.availableTimeSlots.find(
    slot => slot.time === newStartTime
  );

  if (!availableSlot) {
    throw new Error(`Time slot ${newStartTime} is not available on ${newDate}`);
  }

  if (requestedDurationHours > availableSlot.maxDuration) {
    throw new Error(
      `Duration of ${requestedDurationHours} hours exceeds maximum available duration of ${availableSlot.maxDuration} hours at ${newStartTime}`
    );
  }

  // Create new booking with same data but new date/time
  const { id, createdAt, updatedAt, status, approvedById, approvedAt, ...bookingData } = originalBooking;

  const newBooking = await prisma.booking.create({
    data: {
      ...bookingData,
      date: new Date(newDate),
      startTime: newStartTime,
      duration: newDuration,
      status: 'PENDING_APPROVAL',
      originalBookingId: bookingId,
      createdById: userId,
      attendees: {
        create: originalBooking.attendees.map(att => ({
          name: att.name,
          email: att.email,
          role: att.role,
          tcsSupporter: att.tcsSupporter,
          understandingOfTCS: att.understandingOfTCS,
          focusAreas: att.focusAreas,
          yearsWorkingWithTCS: att.yearsWorkingWithTCS,
          position: att.position,
          educationalQualification: att.educationalQualification,
          careerBackground: att.careerBackground,
          linkedinProfile: att.linkedinProfile,
          photoUrl: att.photoUrl,
        })),
      },
    },
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
      attendees: true,
    },
  });

  // Mark original booking as rescheduled
  await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: 'RESCHEDULED',
      rescheduledToId: newBooking.id,
    },
  });

  // Notify all managers about the rescheduled booking
  const notificationService = await import('./notification.service');
  notificationService.notifyAllManagers(
    'BOOKING_RESCHEDULED',
    'Booking Rescheduled',
    `${originalBooking.companyName} visit has been rescheduled from ${new Date(originalBooking.date).toLocaleDateString()} to ${new Date(newBooking.date).toLocaleDateString()} at ${newBooking.startTime}.`,
    newBooking.id
  ).catch((error: any) => {
    console.error('Failed to send reschedule notifications:', error);
  });

  return newBooking;
}
