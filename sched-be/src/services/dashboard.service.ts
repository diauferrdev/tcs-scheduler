import { prisma } from '../lib/prisma';

export async function getDashboardStatistics() {
  // Get all bookings (excluding DRAFT and CANCELLED)
  const allBookings = await prisma.booking.findMany({
    where: {
      status: { notIn: ['DRAFT', 'CANCELLED'] },
    },
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
        },
      },
    },
    orderBy: {
      date: 'desc',
    },
  });

  // Get current month bookings
  const now = new Date();
  const firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const lastDayOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);

  const thisMonthBookings = allBookings.filter(
    (b) => b.date >= firstDayOfMonth && b.date <= lastDayOfMonth
  );

  // Status distribution
  const statusDistribution = {
    pending: allBookings.filter(
      (b) =>
        b.status === 'CREATED' ||
        b.status === 'UNDER_REVIEW' ||
        b.status === 'NEED_EDIT' ||
        b.status === 'NEED_RESCHEDULE'
    ).length,
    approved: allBookings.filter((b) => b.status === 'APPROVED').length,
    notApproved: allBookings.filter((b) => b.status === 'NOT_APPROVED').length,
  };

  // Visit type distribution
  const visitTypeDistribution = {
    PACE_TOUR: allBookings.filter((b) => b.visitType === 'PACE_TOUR').length,
    PACE_EXPERIENCE: allBookings.filter((b) => b.visitType === 'PACE_EXPERIENCE').length,
    INNOVATION_EXCHANGE: allBookings.filter((b) => b.visitType === 'INNOVATION_EXCHANGE').length,
    QUICK_TOUR: allBookings.filter((b) => b.visitType === 'QUICK_TOUR').length,
  };

  // Average attendees
  const totalAttendees = allBookings.reduce((sum, b) => sum + b.expectedAttendees, 0);
  const avgAttendees = allBookings.length > 0 ? totalAttendees / allBookings.length : 0;

  // Organization type distribution
  const organizationTypeDistribution: Record<string, number> = {};
  allBookings.forEach((b) => {
    if (b.organizationType) {
      organizationTypeDistribution[b.organizationType] = (organizationTypeDistribution[b.organizationType] || 0) + 1;
    }
  });

  // TCS Vertical distribution
  const verticalDistribution: Record<string, number> = {};
  allBookings.forEach((b) => {
    if (b.vertical) {
      verticalDistribution[b.vertical] = (verticalDistribution[b.vertical] || 0) + 1;
    }
  });

  // Monthly trend (last 6 months)
  const monthlyTrend: Array<{ month: string; count: number; approved: number }> = [];
  for (let i = 5; i >= 0; i--) {
    const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const month = date.toISOString().substring(0, 7); // YYYY-MM format
    const monthStart = new Date(date.getFullYear(), date.getMonth(), 1);
    const monthEnd = new Date(date.getFullYear(), date.getMonth() + 1, 0);

    const monthBookings = allBookings.filter(
      (b) => b.date >= monthStart && b.date <= monthEnd
    );

    monthlyTrend.push({
      month,
      count: monthBookings.length,
      approved: monthBookings.filter((b) => b.status === 'APPROVED').length,
    });
  }

  // Most popular time slots (9:00-10:00, 10:00-11:00, etc.)
  const timeSlotDistribution: Record<string, number> = {};
  allBookings.forEach((b) => {
    const hour = parseInt(b.startTime.split(':')[0]);
    const slot = `${hour}:00`;
    timeSlotDistribution[slot] = (timeSlotDistribution[slot] || 0) + 1;
  });

  // Top companies by number of bookings
  const companyBookingCount: Record<string, number> = {};
  allBookings.forEach((b) => {
    const companyName = b.companyName || b.organizationName || 'Unknown';
    companyBookingCount[companyName] = (companyBookingCount[companyName] || 0) + 1;
  });

  const topCompanies = Object.entries(companyBookingCount)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([company, count]) => ({ company, visits: count }));

  // Status breakdown detail
  const statusBreakdown = {
    created: allBookings.filter((b) => b.status === 'CREATED').length,
    underReview: allBookings.filter((b) => b.status === 'UNDER_REVIEW').length,
    needEdit: allBookings.filter((b) => b.status === 'NEED_EDIT').length,
    needReschedule: allBookings.filter((b) => b.status === 'NEED_RESCHEDULE').length,
    approved: allBookings.filter((b) => b.status === 'APPROVED').length,
    notApproved: allBookings.filter((b) => b.status === 'NOT_APPROVED').length,
  };

  return {
    totalBookings: allBookings.length,
    thisMonthBookings: thisMonthBookings.length,
    statusDistribution,
    statusBreakdown,
    visitTypeDistribution,
    avgAttendees: Math.round(avgAttendees * 10) / 10, // Round to 1 decimal
    organizationTypeDistribution,
    verticalDistribution,
    monthlyTrend,
    timeSlotDistribution,
    topCompanies,
  };
}
