import { prisma } from '../lib/prisma';
import { startOfMonth, endOfMonth, startOfYear, endOfYear, subMonths, format } from 'date-fns';

export async function getDashboardStats() {
  const now = new Date();
  const startOfThisMonth = startOfMonth(now);
  const endOfThisMonth = endOfMonth(now);
  const startOfThisYear = startOfYear(now);
  const endOfThisYear = endOfYear(now);

  // Total bookings
  const totalBookings = await prisma.booking.count({
    where: { status: { not: 'CANCELLED' } },
  });

  // This month bookings
  const thisMonthBookings = await prisma.booking.count({
    where: {
      status: { not: 'CANCELLED' },
      date: {
        gte: startOfThisMonth,
        lte: endOfThisMonth,
      },
    },
  });

  // This year bookings
  const thisYearBookings = await prisma.booking.count({
    where: {
      status: { not: 'CANCELLED' },
      date: {
        gte: startOfThisYear,
        lte: endOfThisYear,
      },
    },
  });

  // Pending bookings
  const pendingBookings = await prisma.booking.count({
    where: { status: 'PENDING' },
  });

  // Total companies (unique)
  const uniqueCompanies = await prisma.booking.groupBy({
    by: ['companyName'],
    where: { status: { not: 'CANCELLED' } },
  });

  // Total expected attendees this year
  const attendeesThisYear = await prisma.booking.aggregate({
    _sum: {
      expectedAttendees: true,
    },
    where: {
      status: { not: 'CANCELLED' },
      date: {
        gte: startOfThisYear,
        lte: endOfThisYear,
      },
    },
  });

  return {
    totalBookings,
    thisMonthBookings,
    thisYearBookings,
    pendingBookings,
    uniqueCompanies: uniqueCompanies.length,
    totalAttendeesThisYear: attendeesThisYear._sum.expectedAttendees || 0,
  };
}

export async function getBookingsByMonth(year: number) {
  const bookings = await prisma.booking.findMany({
    where: {
      status: { not: 'CANCELLED' },
      date: {
        gte: new Date(year, 0, 1),
        lte: new Date(year, 11, 31),
      },
    },
    select: {
      date: true,
      duration: true,
    },
  });

  // Group by month
  const monthlyData = Array.from({ length: 12 }, (_, i) => ({
    month: format(new Date(year, i, 1), 'MMM'),
    threeHours: 0,
    sixHours: 0,
    total: 0,
  }));

  bookings.forEach((booking) => {
    const month = new Date(booking.date).getMonth();
    monthlyData[month].total++;
    if (booking.duration === 'THREE_HOURS') {
      monthlyData[month].threeHours++;
    } else {
      monthlyData[month].sixHours++;
    }
  });

  return monthlyData;
}

export async function getBookingsBySector(year?: number) {
  const where: any = { status: { not: 'CANCELLED' } };

  if (year) {
    where.date = {
      gte: new Date(year, 0, 1),
      lte: new Date(year, 11, 31),
    };
  }

  const bookings = await prisma.booking.groupBy({
    by: ['companySector'],
    where,
    _count: {
      id: true,
    },
    orderBy: {
      _count: {
        id: 'desc',
      },
    },
  });

  return bookings.map((b) => ({
    sector: b.companySector,
    count: b._count.id,
  }));
}

export async function getBookingsByVertical() {
  const bookings = await prisma.booking.groupBy({
    by: ['companyVertical'],
    where: { status: { not: 'CANCELLED' } },
    _count: {
      id: true,
    },
    orderBy: {
      _count: {
        id: 'desc',
      },
    },
  });

  return bookings.map((b) => ({
    vertical: b.companyVertical,
    count: b._count.id,
  }));
}

export async function getBookingsByInterestArea(year?: number) {
  const where: any = { status: { not: 'CANCELLED' } };

  if (year) {
    where.date = {
      gte: new Date(year, 0, 1),
      lte: new Date(year, 11, 31),
    };
  }

  const bookings = await prisma.booking.groupBy({
    by: ['interestArea'],
    where,
    _count: {
      id: true,
    },
    orderBy: {
      _count: {
        id: 'desc',
      },
    },
  });

  return bookings.map((b) => ({
    area: b.interestArea,
    count: b._count.id,
  }));
}

export async function getTopCompanies(limit: number = 10) {
  const companies = await prisma.booking.groupBy({
    by: ['companyName'],
    where: { status: { not: 'CANCELLED' } },
    _count: {
      id: true,
    },
    orderBy: {
      _count: {
        id: 'desc',
      },
    },
    take: limit,
  });

  return companies.map((c) => ({
    company: c.companyName,
    visits: c._count.id,
  }));
}

export async function getRecentBookings(limit: number = 10) {
  const bookings = await prisma.booking.findMany({
    where: { status: { not: 'CANCELLED' } },
    include: {
      createdBy: {
        select: {
          name: true,
          email: true,
        },
      },
    },
    orderBy: {
      createdAt: 'desc',
    },
    take: limit,
  });

  return bookings;
}

export async function getUpcomingBookings(limit: number = 10) {
  const now = new Date();

  const bookings = await prisma.booking.findMany({
    where: {
      status: { not: 'CANCELLED' },
      date: {
        gte: now,
      },
    },
    include: {
      createdBy: {
        select: {
          name: true,
          email: true,
        },
      },
    },
    orderBy: {
      date: 'asc',
    },
    take: limit,
  });

  return bookings;
}

export async function getBookingTrends(months: number = 6) {
  const now = new Date();
  const monthsData = Array.from({ length: months }, (_, i) => {
    const date = subMonths(now, months - 1 - i);
    return {
      start: startOfMonth(date),
      end: endOfMonth(date),
      label: format(date, 'MMM yyyy'),
    };
  });

  const trends = await Promise.all(
    monthsData.map(async ({ start, end, label }) => {
      const count = await prisma.booking.count({
        where: {
          status: { not: 'CANCELLED' },
          date: {
            gte: start,
            lte: end,
          },
        },
      });

      const attendees = await prisma.booking.aggregate({
        _sum: {
          expectedAttendees: true,
        },
        where: {
          status: { not: 'CANCELLED' },
          date: {
            gte: start,
            lte: end,
          },
        },
      });

      return {
        month: label,
        bookings: count,
        attendees: attendees._sum.expectedAttendees || 0,
      };
    })
  );

  return trends;
}

export async function getCompanySizeDistribution() {
  const bookings = await prisma.booking.groupBy({
    by: ['companySize'],
    where: {
      status: { not: 'CANCELLED' },
      companySize: { not: null },
    },
    _count: {
      id: true,
    },
  });

  return bookings.map((b) => ({
    size: b.companySize || 'Not specified',
    count: b._count.id,
  }));
}

export async function getBookingStatusDistribution() {
  const bookings = await prisma.booking.groupBy({
    by: ['status'],
    _count: {
      id: true,
    },
  });

  return bookings.map((b) => ({
    status: b.status,
    count: b._count.id,
  }));
}
