import { prisma } from '../lib/prisma';
import type { BookingCreateInput, BookingUpdateInput } from '../types';

export async function checkAvailability(date: string) {
  const bookings = await prisma.booking.findMany({
    where: {
      date: new Date(date),
      status: { not: 'CANCELLED' },
    },
  });

  const hasSixHour = bookings.some((b) => b.duration === 'SIX_HOURS');
  const hasMorning = bookings.some((b) => b.startTime === '09:00');
  const hasAfternoon = bookings.some((b) => b.startTime === '14:00');

  const availableSlots: string[] = [];

  if (!hasSixHour) {
    if (!hasMorning && !hasAfternoon) {
      availableSlots.push('morning', 'afternoon', 'full-day');
    } else if (!hasMorning) {
      availableSlots.push('morning');
    } else if (!hasAfternoon) {
      availableSlots.push('afternoon');
    }
  }

  return {
    date,
    isFull: availableSlots.length === 0,
    availableSlots,
    existingBookings: bookings,
  };
}

export async function createBooking(data: BookingCreateInput, createdById?: string) {
  // Validate availability
  const availability = await checkAvailability(data.date);

  if (data.duration === 'SIX_HOURS' && !availability.availableSlots.includes('full-day')) {
    throw new Error('Full day slot not available');
  }

  if (data.duration === 'THREE_HOURS') {
    const slot = data.startTime === '09:00' ? 'morning' : 'afternoon';
    if (!availability.availableSlots.includes(slot)) {
      throw new Error(`${slot} slot not available`);
    }
  }

  const { attendees, ...bookingData } = data;

  const booking = await prisma.booking.create({
    data: {
      ...bookingData,
      date: new Date(data.date),
      expectedAttendees: data.expectedAttendees || 1,
      status: 'PENDING',
      createdById,
      attendees: attendees
        ? {
            create: attendees.map((att) => ({
              name: att.name,
              position: att.position,
              email: att.email,
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
    status: { not: 'CANCELLED' },
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
      status: true,
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

  return booking;
}

export async function deleteBooking(id: string) {
  await prisma.booking.delete({
    where: { id },
  });

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
