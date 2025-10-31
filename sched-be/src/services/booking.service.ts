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
// IMPORTANT: Use getUTCDay() to avoid timezone issues
function isWeekend(date: Date): boolean {
  const day = date.getUTCDay(); // Use UTC to avoid timezone shifting
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

// Helper: Get previous business day (skip weekends)
// IMPORTANT: Use UTC methods to avoid timezone issues
function getPreviousBusinessDay(date: Date): Date {
  const prevDay = new Date(date);
  console.log(`[getPreviousBusinessDay] Input date: ${date.toISOString()}, day of week (UTC): ${date.getUTCDay()}`);

  prevDay.setUTCDate(prevDay.getUTCDate() - 1);
  console.log(`[getPreviousBusinessDay] After -1 day: ${prevDay.toISOString()}, day of week (UTC): ${prevDay.getUTCDay()}, isWeekend: ${isWeekend(prevDay)}`);

  // Keep going back until we find a weekday
  let iterations = 0;
  while (isWeekend(prevDay)) {
    iterations++;
    console.log(`[getPreviousBusinessDay] Iteration ${iterations}: ${prevDay.toISOString()} is weekend, going back...`);
    prevDay.setUTCDate(prevDay.getUTCDate() - 1);
    console.log(`[getPreviousBusinessDay] After -1 day: ${prevDay.toISOString()}, day of week (UTC): ${prevDay.getUTCDay()}, isWeekend: ${isWeekend(prevDay)}`);
  }

  console.log(`[getPreviousBusinessDay] Final result: ${prevDay.toISOString()}, day of week (UTC): ${prevDay.getUTCDay()}`);
  return prevDay;
}

// Helper: Get next business day (skip weekends)
// IMPORTANT: Use UTC methods to avoid timezone issues
function getNextBusinessDay(date: Date): Date {
  const nextDay = new Date(date);
  nextDay.setUTCDate(nextDay.getUTCDate() + 1);

  // Keep going forward until we find a weekday
  while (isWeekend(nextDay)) {
    nextDay.setUTCDate(nextDay.getUTCDate() + 1);
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
// Only considers APPROVED bookings (PENDING do not block)
async function isPeriodFree(date: Date, isMorning: boolean, excludeBookingId?: string): Promise<boolean> {
  const dateStr = date.toISOString().split('T')[0];

  const bookings = await prisma.booking.findMany({
    where: {
      date: new Date(dateStr),
      status: 'APPROVED', // Only count APPROVED bookings
      ...(excludeBookingId ? { id: { not: excludeBookingId } } : {}),
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

// Helper: Check if a period is free considering BOTH direct bookings AND IE virtual blocks
// This is crucial for Innovation Exchange validation to prevent overlapping prep/teardown periods
async function isPeriodFreeConsideringIEBlocks(
  date: Date,
  isMorning: boolean,
  excludeBookingId?: string
): Promise<boolean> {
  const dateStr = date.toISOString().split('T')[0];
  const periodLabel = isMorning ? 'morning' : 'afternoon';

  console.log(`[IE Block Check] Checking if ${dateStr} ${periodLabel} is free...`);

  // 1. Check for direct bookings in the period
  const periodFree = await isPeriodFree(date, isMorning, excludeBookingId);
  console.log(`[IE Block Check] Direct bookings check: ${periodFree ? 'FREE' : 'OCCUPIED'}`);

  if (!periodFree) {
    console.log(`[IE Block Check] ❌ ${dateStr} ${periodLabel} is OCCUPIED by direct booking`);
    return false;
  }

  // 2. Check if this period is blocked by prep/teardown of existing APPROVED IEs/PEs
  // Get all APPROVED Innovation Exchange and Pace Experience bookings
  const confirmedFullDayEvents = await prisma.booking.findMany({
    where: {
      visitType: { in: ['INNOVATION_EXCHANGE', 'PACE_EXPERIENCE'] },
      status: 'APPROVED',
      ...(excludeBookingId ? { id: { not: excludeBookingId } } : {}),
    },
  });

  console.log(`[IE/PE Block Check] Found ${confirmedFullDayEvents.length} confirmed IE/PE events to check against`);

  for (const event of confirmedFullDayEvents) {
    const eventDate = event.date;
    const eventDateStr = eventDate.toISOString().split('T')[0];
    const isEventInMorning = isMorningPeriod(event.startTime);
    const eventTimeLabel = isEventInMorning ? 'morning' : 'afternoon';

    console.log(`[IE/PE Block Check] Checking ${event.visitType} on ${eventDateStr} ${eventTimeLabel} (${event.companyName})`);

    // Check if this IE/PE blocks the period we're checking
    if (isEventInMorning) {
      // IE/PE morning blocks:
      // - Previous day afternoon (prep)
      // - Same day morning (event)
      // - Same day afternoon (teardown)

      // Check if we're checking the prep period (prev day afternoon)
      const prevDayStr = getPreviousBusinessDay(eventDate).toISOString().split('T')[0];
      if (dateStr === prevDayStr && !isMorning) {
        console.log(`[IE/PE Block Check] ❌ ${dateStr} afternoon is blocked as PREP for ${event.visitType} on ${eventDateStr} morning`);
        return false; // This afternoon is blocked as prep for IE/PE
      }

      // Check if we're checking the event or teardown period (same day)
      if (dateStr === eventDateStr) {
        console.log(`[IE/PE Block Check] ❌ ${dateStr} ${periodLabel} is blocked by ${event.visitType} EVENT+TEARDOWN on same day`);
        return false; // Both morning and afternoon blocked by IE/PE
      }
    } else {
      // IE/PE afternoon blocks:
      // - Same day morning (prep)
      // - Same day afternoon (event)
      // - Next day morning (teardown)

      // Check if we're checking the prep or event period (same day)
      if (dateStr === eventDateStr) {
        console.log(`[IE/PE Block Check] ❌ ${dateStr} ${periodLabel} is blocked by ${event.visitType} PREP+EVENT on same day`);
        return false; // Both morning and afternoon blocked by IE/PE
      }

      // Check if we're checking the teardown period (next day morning)
      const nextDayStr = getNextBusinessDay(eventDate).toISOString().split('T')[0];
      if (dateStr === nextDayStr && isMorning) {
        console.log(`[IE/PE Block Check] ❌ ${dateStr} morning is blocked as TEARDOWN for ${event.visitType} on ${eventDateStr} afternoon`);
        return false; // This morning is blocked as teardown for IE/PE
      }
    }
  }

  console.log(`[IE Block Check] ✅ ${dateStr} ${periodLabel} is FREE`);
  return true; // Period is free (no direct bookings and no IE blocks)
}

// Validate Innovation Exchange and Pace Experience bookings (need prep/teardown periods)
async function validateInnovationExchange(
  date: string,
  startTime: string,
  duration: string
): Promise<{ valid: boolean; error?: string }> {
  const bookingDate = new Date(date);
  const durationHours = durationToHours(duration);

  // Must be 4-6 hours (Pace Experience = 4h, Innovation Exchange = 6h)
  if (durationHours < 4 || durationHours > 6) {
    return {
      valid: false,
      error: 'Pace Experience and Innovation Exchange must be between 4-6 hours',
    };
  }

  const isBookingInMorning = isMorningPeriod(startTime);

  // Check prep period (before the event)
  if (isBookingInMorning) {
    // Event in morning → need afternoon of previous business day free (considering IE blocks)
    const prevDay = getPreviousBusinessDay(bookingDate);
    const afternoonFree = await isPeriodFreeConsideringIEBlocks(prevDay, false);

    if (!afternoonFree) {
      return {
        valid: false,
        error: `Cannot book Innovation Exchange on ${date} morning: afternoon of ${prevDay.toISOString().split('T')[0]} is already occupied or blocked by another event`,
      };
    }
  } else {
    // Event in afternoon → need morning of same day free (considering IE blocks)
    const morningFree = await isPeriodFreeConsideringIEBlocks(bookingDate, true);

    if (!morningFree) {
      return {
        valid: false,
        error: `Cannot book Innovation Exchange on ${date} afternoon: morning is already occupied or blocked by another event`,
      };
    }
  }

  // Check teardown period (after the event)
  if (isBookingInMorning) {
    // Event in morning → afternoon of same day must be free (considering IE blocks)
    const afternoonFree = await isPeriodFreeConsideringIEBlocks(bookingDate, false);

    if (!afternoonFree) {
      return {
        valid: false,
        error: `Cannot book Innovation Exchange on ${date} morning: afternoon is already occupied or blocked by another event`,
      };
    }
  } else {
    // Event in afternoon → morning of next business day must be free (considering IE blocks)
    const nextDay = getNextBusinessDay(bookingDate);
    const morningFree = await isPeriodFreeConsideringIEBlocks(nextDay, true);

    if (!morningFree) {
      return {
        valid: false,
        error: `Cannot book Innovation Exchange on ${date} afternoon: morning of ${nextDay.toISOString().split('T')[0]} is already occupied or blocked by another event`,
      };
    }
  }

  return { valid: true };
}

// Validate Pace Tour booking (max 2 per day, only 2 hours, no prep/teardown)
async function validatePaceTour(
  date: string,
  duration: string
): Promise<{ valid: boolean; error?: string }> {
  const durationHours = durationToHours(duration);

  // Must be exactly 2 hours
  if (durationHours !== 2) {
    return {
      valid: false,
      error: 'Pace Tour must be exactly 2 hours',
    };
  }

  // Check how many APPROVED Pace Tours are already booked on this date
  // PENDING do not block
  const existingPaceTours = await prisma.booking.findMany({
    where: {
      date: new Date(date),
      visitType: 'PACE_TOUR',
      status: 'APPROVED', // Only count APPROVED bookings
    },
  });

  if (existingPaceTours.length >= 2) {
    return {
      valid: false,
      error: 'Maximum 2 Pace Tours allowed per day (already have 2 confirmed)',
    };
  }

  return { valid: true };
}

export async function checkAvailability(date: string, visitType?: 'PACE_TOUR' | 'INNOVATION_EXCHANGE' | 'PACE_EXPERIENCE') {
  const bookingDate = new Date(date);

  // Get ONLY APPROVED bookings for availability
  // Pending statuses (CREATED, UNDER_REVIEW, etc) do not block slots
  const bookings = await prisma.booking.findMany({
    where: {
      date: bookingDate,
      status: 'APPROVED', // Only count APPROVED bookings
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
  if (visitType === 'PACE_TOUR') {
    // Pace Tour: max 1 in morning AND 1 in afternoon
    const existingPaceTours = await prisma.booking.findMany({
      where: {
        date: bookingDate,
        visitType: 'PACE_TOUR',
        status: 'APPROVED', // Only count APPROVED bookings
      },
    });

    // Mark periods as unavailable if already have a Pace Tour in that period
    for (const pt of existingPaceTours) {
      const isMorning = isMorningPeriod(pt.startTime);
      const periodIndex = isMorning ? 0 : 1;
      periods[periodIndex].available = false;
      periods[periodIndex].blockedBy = `Pace Tour already confirmed`;
    }

    // IMPORTANT: Pace Tours must also respect IE/PE prep/teardown blocks
    // Check if morning period is blocked by IE/PE prep/teardown
    const morningFree = await isPeriodFreeConsideringIEBlocks(bookingDate, true);
    if (!morningFree && periods[0].available) {
      periods[0].available = false;
      periods[0].blockedBy = 'Period blocked by Innovation Exchange or Pace Experience prep/teardown';
    }

    // Check if afternoon period is blocked by IE/PE prep/teardown
    const afternoonFree = await isPeriodFreeConsideringIEBlocks(bookingDate, false);
    if (!afternoonFree && periods[1].available) {
      periods[1].available = false;
      periods[1].blockedBy = 'Period blocked by Innovation Exchange or Pace Experience prep/teardown';
    }
  } else if (visitType === 'INNOVATION_EXCHANGE' || visitType === 'PACE_EXPERIENCE') {
    // Innovation Exchange and Pace Experience: only 1 per day, need prep/teardown
    const existingFullDay = await prisma.booking.findMany({
      where: {
        date: bookingDate,
        visitType: { in: ['INNOVATION_EXCHANGE', 'PACE_EXPERIENCE'] },
        status: 'APPROVED', // Only count APPROVED bookings
      },
    });

    if (existingFullDay.length > 0) {
      // Already have an IE/PE, no periods available
      const typeLabel = visitType === 'INNOVATION_EXCHANGE' ? 'Innovation Exchange' : 'Pace Experience';
      periods[0].available = false;
      periods[0].blockedBy = `${typeLabel} already confirmed for this day`;
      periods[1].available = false;
      periods[1].blockedBy = `${typeLabel} already confirmed for this day`;
    } else {
      // Check prep/teardown availability for each period (considering IE blocks)

      // Morning period check
      const prevDay = getPreviousBusinessDay(bookingDate);
      const morningPrepOk = await isPeriodFreeConsideringIEBlocks(prevDay, false); // Need prev afternoon free
      const morningTeardownOk = await isPeriodFreeConsideringIEBlocks(bookingDate, false); // Need same afternoon free

      console.log(`[IE Check] ${date} morning - prep ok: ${morningPrepOk} (prev day: ${prevDay.toISOString().split('T')[0]} afternoon), teardown ok: ${morningTeardownOk} (same day afternoon)`);

      if (!morningPrepOk || !morningTeardownOk) {
        periods[0].available = false;
        periods[0].blockedBy = !morningPrepOk
          ? `Requires free afternoon on ${prevDay.toISOString().split('T')[0]} (prep) - already occupied or blocked`
          : 'Requires free afternoon on same day (teardown) - already occupied or blocked';
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
      const afternoonPrepOk = await isPeriodFreeConsideringIEBlocks(bookingDate, true); // Need same morning free
      const afternoonTeardownOk = await isPeriodFreeConsideringIEBlocks(nextDay, true); // Need next morning free

      if (!afternoonPrepOk || !afternoonTeardownOk) {
        periods[1].available = false;
        periods[1].blockedBy = !afternoonPrepOk
          ? 'Requires free morning on same day (prep) - already occupied or blocked'
          : `Requires free morning on ${nextDay.toISOString().split('T')[0]} (teardown) - already occupied or blocked`;
      } else {
        // Add info about what will be blocked
        periods[1].willBlock = [
          { date: date, period: 'Morning (prep)' },
          { date: date, period: 'Afternoon (event)' },
          { date: nextDay.toISOString().split('T')[0], period: 'Morning (teardown)' },
        ];
      }
    }
  } else {
    // No specific visit type filter: check IE/PE blocks for general availability
    const morningFree = await isPeriodFreeConsideringIEBlocks(bookingDate, true);
    if (!morningFree && periods[0].available) {
      periods[0].available = false;
      periods[0].blockedBy = 'Period blocked by Innovation Exchange or Pace Experience prep/teardown';
    }

    const afternoonFree = await isPeriodFreeConsideringIEBlocks(bookingDate, false);
    if (!afternoonFree && periods[1].available) {
      periods[1].available = false;
      periods[1].blockedBy = 'Period blocked by Innovation Exchange or Pace Experience prep/teardown';
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
  if (data.visitType === 'PACE_TOUR') {
    // Pace Tour must be exactly 2 hours
    if (data.duration !== 'TWO_HOURS') {
      throw new Error('Pace Tour must be exactly 2 hours');
    }

    // Validate Pace Tour specific rules (max 2 per day, no prep/teardown)
    const paceTourValidation = await validatePaceTour(data.date, data.duration);
    if (!paceTourValidation.valid) {
      throw new Error(paceTourValidation.error);
    }
  } else if (data.visitType === 'PACE_EXPERIENCE') {
    // Pace Experience must be exactly 4 hours
    if (data.duration !== 'FOUR_HOURS') {
      throw new Error('Pace Experience must be exactly 4 hours');
    }

    // Validate Pace Experience prep/teardown periods
    const peValidation = await validateInnovationExchange(
      data.date,
      data.startTime,
      data.duration
    );
    if (!peValidation.valid) {
      throw new Error(peValidation.error);
    }
  } else if (data.visitType === 'INNOVATION_EXCHANGE') {
    // Innovation Exchange must be exactly 6 hours
    if (data.duration !== 'SIX_HOURS') {
      throw new Error('Innovation Exchange must be exactly 6 hours');
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

  let booking = await prisma.booking.create({
    data: {
      ...bookingData,
      date: new Date(data.date),
      lastInnovationDay: lastInnovationDay ? new Date(lastInnovationDay) : null,
      expectedAttendees: data.expectedAttendees || 1,
      status: 'CREATED', // Start with CREATED
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

  // Automatically transition from CREATED to UNDER_REVIEW
  const updatedBooking = await prisma.booking.update({
      where: { id: booking.id },
      data: { status: 'UNDER_REVIEW' },
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

    // Notify all managers about the new booking (async, don't block)
    const notificationService = await import('./notification.service');
    notificationService.notifyAllManagers(
      'BOOKING_UNDER_REVIEW',
      'New Booking - Awaiting Review',
      `${updatedBooking.companyName} requested a visit on ${new Date(updatedBooking.date).toLocaleDateString()} at ${updatedBooking.startTime}. ${updatedBooking.expectedAttendees} attendees expected.`,
      updatedBooking.id
    ).catch((error: any) => {
      console.error('Failed to send manager notifications:', error);
    });

  // Update booking reference to return the updated version
  booking = updatedBooking;

  // Broadcast booking creation for real-time UI updates
  websocketService.broadcastBookingCreated(booking);
  console.log('[Booking] Broadcast booking_created to', websocketService.getTotalConnections(), 'connections');

  return booking;
}

export async function getBookings(month?: string, status?: string, userId?: string) {
  const where: any = {};

  // Filter by userId if provided (for USER role - only see their own bookings)
  if (userId) {
    where.createdById = userId;
  }

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
    // Only show APPROVED bookings to public (hide pending/created/under_review/etc)
    status: { notIn: ['CANCELLED', 'CREATED', 'UNDER_REVIEW', 'NEED_EDIT', 'NEED_RESCHEDULE', 'NOT_APPROVED'] },
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

  // Return minimal data needed for availability display
  const bookings = await prisma.booking.findMany({
    where,
    select: {
      id: true,
      date: true,
      startTime: true,
      duration: true,
      visitType: true,
      status: true,
      // Required fields for Flutter Booking model
      accountName: true,
      companyName: true,
      expectedAttendees: true,
      createdAt: true,
      updatedAt: true,
    },
    orderBy: {
      date: 'asc',
    },
  });

  return bookings;
}

// Get bookings availability for Admins/Managers (includes all pending statuses as "intentions")
export async function getBookingsAvailabilityForAdmins(month?: string) {
  const where: any = {
    // Include CREATED, UNDER_REVIEW, NEED_EDIT, NEED_RESCHEDULE, APPROVED, NOT_APPROVED
    // Exclude only CANCELLED
    status: { notIn: ['CANCELLED'] },
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
      status: true, // CREATED/UNDER_REVIEW = intention, APPROVED = actual booking
      // Required fields for Flutter Booking model
      accountName: true,
      companyName: true,
      expectedAttendees: true,
      createdAt: true,
      updatedAt: true,
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

  // Broadcast booking update to all connected clients for real-time schedule updates
  websocketService.broadcastBookingUpdated(booking);
  console.log('[Booking] Broadcast booking_updated to', websocketService.getTotalConnections(), 'connections');

  return booking;
}

export async function deleteBooking(id: string) {
  // Get booking details before cancellation for notification
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

  // SOFT DELETE: Mark as CANCELLED instead of deleting
  // This preserves the booking data so notifications can link to it
  const cancelledBooking = await prisma.booking.update({
    where: { id },
    data: {
      status: 'CANCELLED',
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

  // NOTE: Notification sent via pushService.sendBookingCancelledNotification() in routes/bookings.ts
  // This handles both user and managers notifications to avoid duplicates

  // Broadcast booking deletion to all connected clients for real-time schedule updates
  websocketService.broadcastBookingDeleted(id);
  console.log('[Booking] Broadcast booking_deleted to', websocketService.getTotalConnections(), 'connections');

  return cancelledBooking;
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
// Automatically marks all conflicting PENDING bookings as NEED_RESCHEDULE (not cancelled!)
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

  // Can approve from CREATED or UNDER_REVIEW
  if (booking.status !== 'CREATED' && booking.status !== 'UNDER_REVIEW') {
    throw new Error(`Cannot approve booking with status ${booking.status}. Booking must be in CREATED or UNDER_REVIEW status.`);
  }

  // Validate that the slot is still free (considering only APPROVED bookings)
  const dateStr = booking.date.toISOString().split('T')[0];
  const availability = await checkAvailability(dateStr, booking.visitType);

  const requestedStartMinutes = timeToMinutes(booking.startTime);
  const requestedDurationHours = durationToHours(booking.duration);

  // Check for conflicts with APPROVED bookings
  for (const existing of availability.existingBookings) {
    if (existing.id === bookingId) continue; // Skip self

    const existingStart = timeToMinutes(existing.startTime);
    const existingDuration = durationToHours(existing.duration);

    if (timeRangesOverlap(
      requestedStartMinutes,
      requestedDurationHours,
      existingStart,
      existingDuration
    )) {
      throw new Error('Cannot approve: slot is now occupied by another confirmed booking');
    }
  }

  // Approve the booking
  const updatedBooking = await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: 'APPROVED',
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

  // Find all pending/under review bookings that conflict with this approved booking
  const conflictingBookings = await prisma.booking.findMany({
    where: {
      id: { not: bookingId }, // Exclude the approved booking
      status: { in: ['CREATED', 'UNDER_REVIEW', 'NEED_EDIT', 'NEED_RESCHEDULE'] }, // All non-final statuses
      OR: [
        // Direct time conflict on same date
        {
          date: booking.date,
        },
        // For Innovation Exchange and Pace Experience, also check prep/teardown periods
        ...(booking.visitType === 'INNOVATION_EXCHANGE' || booking.visitType === 'PACE_EXPERIENCE' ? [
          // If approved IE is in morning, it blocks:
          // - Previous day afternoon (prep)
          // - Same day morning + afternoon (event + teardown)
          ...(isMorningPeriod(booking.startTime) ? [
            {
              date: getPreviousBusinessDay(booking.date),
            },
          ] : []),
          // If approved IE is in afternoon, it blocks:
          // - Same day morning (prep)
          // - Same day afternoon (event)
          // - Next day morning (teardown)
          ...(!isMorningPeriod(booking.startTime) ? [
            {
              date: getNextBusinessDay(booking.date),
            },
          ] : []),
        ] : []),
      ],
    },
    include: {
      createdBy: true,
    },
  });

  // Filter conflicting bookings to only those that actually conflict
  const bookingsToCancel: typeof conflictingBookings = [];

  for (const pending of conflictingBookings) {
    const pendingDateStr = pending.date.toISOString().split('T')[0];
    const pendingStartMinutes = timeToMinutes(pending.startTime);
    const pendingDurationHours = durationToHours(pending.duration);

    // Check direct time overlap on same date
    if (pendingDateStr === dateStr) {
      if (timeRangesOverlap(
        requestedStartMinutes,
        requestedDurationHours,
        pendingStartMinutes,
        pendingDurationHours
      )) {
        bookingsToCancel.push(pending);
        continue;
      }
    }

    // For Innovation Exchange and Pace Experience approved booking, check if pending conflicts with prep/teardown
    if (booking.visitType === 'INNOVATION_EXCHANGE' || booking.visitType === 'PACE_EXPERIENCE') {
      const isApprovedInMorning = isMorningPeriod(booking.startTime);

      if (isApprovedInMorning) {
        // Approved IE morning blocks: prev day afternoon + same day all day
        const prevDayStr = getPreviousBusinessDay(booking.date).toISOString().split('T')[0];

        if (pendingDateStr === prevDayStr && isAfternoonPeriod(pending.startTime)) {
          bookingsToCancel.push(pending);
        } else if (pendingDateStr === dateStr) {
          bookingsToCancel.push(pending);
        }
      } else {
        // Approved IE afternoon blocks: same day all day + next day morning
        const nextDayStr = getNextBusinessDay(booking.date).toISOString().split('T')[0];

        if (pendingDateStr === dateStr) {
          bookingsToCancel.push(pending);
        } else if (pendingDateStr === nextDayStr && isMorningPeriod(pending.startTime)) {
          bookingsToCancel.push(pending);
        }
      }
    }

    // Check if pending IE or PE prep/teardown conflicts with approved booking
    if (pending.visitType === 'INNOVATION_EXCHANGE' || pending.visitType === 'PACE_EXPERIENCE') {
      const isPendingInMorning = isMorningPeriod(pending.startTime);
      const pendingDate = pending.date;

      if (isPendingInMorning) {
        // Pending IE morning requires: prev day afternoon + same day all day
        const prevDayStr = getPreviousBusinessDay(pendingDate).toISOString().split('T')[0];

        if (dateStr === prevDayStr && isAfternoonPeriod(booking.startTime)) {
          bookingsToCancel.push(pending);
        } else if (dateStr === pendingDateStr) {
          bookingsToCancel.push(pending);
        }
      } else {
        // Pending IE afternoon requires: same day all day + next day morning
        const nextDayStr = getNextBusinessDay(pendingDate).toISOString().split('T')[0];

        if (dateStr === pendingDateStr) {
          bookingsToCancel.push(pending);
        } else if (dateStr === nextDayStr && isMorningPeriod(booking.startTime)) {
          bookingsToCancel.push(pending);
        }
      }
    }
  }

  // Mark all conflicting PENDING bookings as NEED_RESCHEDULE (not cancelled!)
  const notificationService = await import('./notification.service');
  const conflictingCount = bookingsToCancel.length;

  if (conflictingCount > 0) {
    console.log(`[Approval] Marking ${conflictingCount} conflicting bookings as NEED_RESCHEDULE`);

    for (const pendingBooking of bookingsToCancel) {
      // Mark as NEED_RESCHEDULE instead of CANCELLED
      await prisma.booking.update({
        where: { id: pendingBooking.id },
        data: {
          status: 'NEED_RESCHEDULE',
          rescheduleRequestMessage: `Another booking was approved for a conflicting time slot. Please choose a new date and time.`
        },
      });

      // Notify the creator that their booking needs rescheduling
      if (pendingBooking.createdById) {
        notificationService.createNotification({
          type: 'BOOKING_NEED_RESCHEDULE',
          title: 'Booking Needs Rescheduling',
          message: `Your booking for ${pendingBooking.companyName || pendingBooking.organizationName} on ${new Date(pendingBooking.date).toLocaleDateString()} at ${pendingBooking.startTime} conflicts with another approved booking. Please reschedule to a new date and time.`,
          userId: pendingBooking.createdById,
          bookingId: pendingBooking.id,
          screen: 'my_bookings', // ✅ Changed to my_bookings for better UX
        }).catch((error: any) => {
          console.error('Failed to send reschedule notification:', error);
        });
      }

      // Broadcast booking update (not deletion, since it's not cancelled)
      websocketService.broadcastBookingUpdated(pendingBooking);
    }

    console.log(`[Approval] Successfully marked ${conflictingCount} conflicting bookings as NEED_RESCHEDULE`);
  }

  // NOTE: Notification is sent via push.service.sendBookingApprovedNotification() in routes/bookings.ts
  // No need to create duplicate notification here

  // Notify all other managers that the booking was approved
  notificationService.notifyAllManagers(
    'BOOKING_APPROVED',
    'Booking Confirmed',
    `${booking.companyName} visit on ${new Date(booking.date).toLocaleDateString()} at ${booking.startTime} has been approved by ${updatedBooking.approvedBy?.name}.${conflictingCount > 0 ? ` (${conflictingCount} conflicting bookings were marked for rescheduling)` : ''}`,
    booking.id,
    managerId // Exclude the manager who approved
  ).catch((error: any) => {
    console.error('Failed to send confirmation notifications to managers:', error);
  });

  // Broadcast booking approval to all connected clients for real-time schedule updates
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
      status: 'CREATED',
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

  // Mark original booking as cancelled (rescheduled)
  await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: 'CANCELLED',
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

// ==================== NEW STATUS FLOW METHODS ====================

// Manager/Admin: Request Edit (CREATED/UNDER_REVIEW → NEED_EDIT)
export async function requestEdit(
  bookingId: string,
  managerId: string,
  message?: string
) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      createdBy: true,
    },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  // Can only request edit from CREATED or UNDER_REVIEW
  if (booking.status !== 'CREATED' && booking.status !== 'UNDER_REVIEW') {
    throw new Error(`Cannot request edit from status ${booking.status}. Booking must be in CREATED or UNDER_REVIEW status.`);
  }

  const updatedBooking = await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: 'NEED_EDIT',
      editRequestMessage: message,
    },
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

  // NOTE: Notification is sent via push.service.sendEditRequestNotification() in routes/bookings.ts
  // No need to create duplicate notification here

  // Broadcast update
  websocketService.broadcastBookingUpdated(updatedBooking);

  return updatedBooking;
}

// Manager/Admin: Request Reschedule (CREATED/UNDER_REVIEW → NEED_RESCHEDULE)
export async function requestReschedule(
  bookingId: string,
  managerId: string,
  message?: string
) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      createdBy: true,
    },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  // Can only request reschedule from CREATED or UNDER_REVIEW
  if (booking.status !== 'CREATED' && booking.status !== 'UNDER_REVIEW') {
    throw new Error(`Cannot request reschedule from status ${booking.status}. Booking must be in CREATED or UNDER_REVIEW status.`);
  }

  const updatedBooking = await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: 'NEED_RESCHEDULE',
      rescheduleRequestMessage: message,
    },
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

  // NOTE: Notification is sent via push.service.sendRescheduleRequestNotification() in routes/bookings.ts
  // No need to create duplicate notification here

  // Broadcast update
  websocketService.broadcastBookingUpdated(updatedBooking);

  return updatedBooking;
}

// Manager/Admin: Reject Booking (CREATED/UNDER_REVIEW → NOT_APPROVED)
export async function rejectBooking(
  bookingId: string,
  managerId: string,
  rejectionReason: string
) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      createdBy: true,
    },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  // Can only reject from CREATED, UNDER_REVIEW, NEED_EDIT, or NEED_RESCHEDULE
  const allowedStatuses = ['CREATED', 'UNDER_REVIEW', 'NEED_EDIT', 'NEED_RESCHEDULE'];
  if (!allowedStatuses.includes(booking.status)) {
    throw new Error(`Cannot reject booking from status ${booking.status}. Booking must be in CREATED, UNDER_REVIEW, NEED_EDIT, or NEED_RESCHEDULE status.`);
  }

  const updatedBooking = await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: 'NOT_APPROVED',
      rejectionReason,
      rejectedById: managerId,
      rejectedAt: new Date(),
    },
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
      rejectedBy: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
    },
  });

  // Notify the booking creator
  if (booking.createdById) {
    const notificationService = await import('./notification.service');
    notificationService.createNotification({
      type: 'BOOKING_NOT_APPROVED',
      title: 'Booking Not Approved',
      message: `Your booking for ${booking.organizationName || booking.companyName} was not approved. Reason: ${rejectionReason}`,
      userId: booking.createdById,
      bookingId: booking.id,
      screen: 'booking_details',
    }).catch((error: any) => {
      console.error('Failed to send rejection notification:', error);
    });
  }

  // Broadcast update
  websocketService.broadcastBookingUpdated(updatedBooking);

  return updatedBooking;
}

// Manager/Admin: Cancel Booking (ANY → CANCELLED)
export async function cancelBooking(
  bookingId: string,
  managerId: string,
  cancellationReason: string
) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      createdBy: true,
    },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  if (booking.status === 'CANCELLED') {
    throw new Error('Booking is already cancelled');
  }

  const updatedBooking = await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: 'CANCELLED',
      cancellationReason,
      cancelledById: managerId,
      cancelledAt: new Date(),
    },
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

  // Notify the booking creator
  if (booking.createdById) {
    const notificationService = await import('./notification.service');
    notificationService.createNotification({
      type: 'BOOKING_CANCELLED',
      title: 'Booking Cancelled',
      message: `Your booking for ${booking.organizationName || booking.companyName} on ${new Date(booking.date).toLocaleDateString()} was cancelled. Reason: ${cancellationReason}`,
      userId: booking.createdById,
      bookingId: booking.id,
      screen: 'my_bookings',
    }).catch((error: any) => {
      console.error('Failed to send cancellation notification:', error);
    });
  }

  // Broadcast deletion
  websocketService.broadcastBookingDeleted(bookingId);

  return updatedBooking;
}

// User: Reschedule when status is NEED_RESCHEDULE (NEED_RESCHEDULE → UNDER_REVIEW)
export async function userRescheduleBooking(
  bookingId: string,
  userId: string,
  newDate: string,
  newStartTime: string,
  newDuration: string
) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      createdBy: true,
    },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  // User can only reschedule their own booking
  if (booking.createdById !== userId) {
    throw new Error('You can only reschedule your own bookings');
  }

  // Can only reschedule when status is NEED_RESCHEDULE
  if (booking.status !== 'NEED_RESCHEDULE') {
    throw new Error('Booking must be in NEED_RESCHEDULE status to reschedule');
  }

  // Validate new date/time (similar to createBooking validations)
  const bookingDate = new Date(newDate);

  // Block weekends
  if (isWeekend(bookingDate)) {
    throw new Error('Bookings are not allowed on weekends (Saturday/Sunday)');
  }

  // Validate visit type specific rules
  if (booking.visitType === 'PACE_TOUR') {
    const paceTourValidation = await validatePaceTour(newDate, newDuration);
    if (!paceTourValidation.valid) {
      throw new Error(paceTourValidation.error);
    }
  } else if (booking.visitType === 'INNOVATION_EXCHANGE' || booking.visitType === 'PACE_EXPERIENCE') {
    const innovationValidation = await validateInnovationExchange(
      newDate,
      newStartTime,
      newDuration
    );
    if (!innovationValidation.valid) {
      throw new Error(innovationValidation.error);
    }
  }

  // Check availability
  const availability = await checkAvailability(newDate, booking.visitType);
  const requestedStartMinutes = timeToMinutes(newStartTime);
  const requestedDurationHours = durationToHours(newDuration);

  // Check for time conflicts
  for (const existing of availability.existingBookings) {
    if (existing.id === bookingId) continue; // Skip self

    const existingStart = timeToMinutes(existing.startTime);
    const existingDuration = durationToHours(existing.duration);

    if (timeRangesOverlap(
      requestedStartMinutes,
      requestedDurationHours,
      existingStart,
      existingDuration
    )) {
      throw new Error('New date/time conflicts with existing booking');
    }
  }

  // Update booking with new date/time and set status to UNDER_REVIEW
  const updatedBooking = await prisma.booking.update({
    where: { id: bookingId },
    data: {
      date: new Date(newDate),
      startTime: newStartTime,
      duration: newDuration,
      status: 'UNDER_REVIEW', // Back to review after user reschedules
      rescheduleRequestMessage: null, // Clear the message
    },
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

  // Notify all managers that the booking was rescheduled and is ready for review
  const notificationService = await import('./notification.service');
  notificationService.notifyAllManagers(
    'BOOKING_UNDER_REVIEW',
    'Booking Rescheduled - Ready for Review',
    `${booking.organizationName || booking.companyName} has been rescheduled to ${new Date(newDate).toLocaleDateString()} at ${newStartTime} and is ready for review.`,
    booking.id
  ).catch((error: any) => {
    console.error('Failed to send reschedule notifications:', error);
  });

  // Broadcast update
  websocketService.broadcastBookingUpdated(updatedBooking);

  return updatedBooking;
}

// Update existing booking - transitions NEED_EDIT → UNDER_REVIEW after user edits
// This enhances the existing updateBooking function
export async function updateBookingWithStatusTransition(id: string, data: BookingUpdateInput, userId?: string) {
  const originalBooking = await prisma.booking.findUnique({
    where: { id },
  });

  if (!originalBooking) {
    throw new Error('Booking not found');
  }

  // If booking is in NEED_EDIT status and user is editing, transition to UNDER_REVIEW
  let updateData = { ...data };
  if (originalBooking.status === 'NEED_EDIT' && userId === originalBooking.createdById) {
    updateData.status = 'UNDER_REVIEW';
    updateData.editRequestMessage = null; // Clear the edit request message
  }

  const booking = await prisma.booking.update({
    where: { id },
    data: updateData,
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

  // If status changed to UNDER_REVIEW, notify managers
  if (originalBooking.status === 'NEED_EDIT' && booking.status === 'UNDER_REVIEW') {
    const notificationService = await import('./notification.service');
    notificationService.notifyAllManagers(
      'BOOKING_UNDER_REVIEW',
      'Booking Edited - Ready for Review',
      `${booking.organizationName || booking.companyName} has been edited and is ready for review.`,
      booking.id
    ).catch((error: any) => {
      console.error('Failed to send edit completion notifications:', error);
    });
  }

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
  if (importantChanges.length > 0 && booking.status !== 'UNDER_REVIEW') {
    const notificationService = await import('./notification.service');
    notificationService.notifyAllManagers(
      'BOOKING_IMPORTANT_CHANGE',
      'Important Booking Change',
      `${booking.organizationName || booking.companyName} booking updated: ${importantChanges.join(', ')}`,
      booking.id
    ).catch((error: any) => {
      console.error('Failed to send important change notifications:', error);
    });
  } else if (importantChanges.length === 0) {
    // Send regular update notification (async, don't block)
    pushService.sendBookingUpdateNotification(booking.id).catch((error) => {
      console.error('Failed to send booking update notification:', error);
    });
  }

  // Broadcast booking update to all connected clients for real-time schedule updates
  websocketService.broadcastBookingUpdated(booking);
  console.log('[Booking] Broadcast booking_updated to', websocketService.getTotalConnections(), 'connections');

  return booking;
}

// Auto-transition CREATED → UNDER_REVIEW (called by manager when they open booking details)
export async function markAsUnderReview(bookingId: string, managerId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  // Only transition if status is CREATED
  if (booking.status !== 'CREATED') {
    return booking; // No change needed
  }

  const updatedBooking = await prisma.booking.update({
    where: { id: bookingId },
    data: {
      status: 'UNDER_REVIEW',
    },
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

  // Notify the booking creator that their booking is under review
  if (booking.createdById) {
    const notificationService = await import('./notification.service');
    notificationService.createNotification({
      type: 'BOOKING_UNDER_REVIEW',
      title: 'Booking Under Review',
      message: `Your booking for ${booking.organizationName || booking.companyName} is now under review by the management team.`,
      userId: booking.createdById,
      bookingId: booking.id,
      screen: 'booking_details',
    }).catch((error: any) => {
      console.error('Failed to send under review notification:', error);
    });
  }

  // Broadcast update
  websocketService.broadcastBookingUpdated(updatedBooking);

  return updatedBooking;
}
