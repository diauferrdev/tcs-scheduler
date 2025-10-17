import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function listBookings() {
  console.log('📋 Current bookings:\n');

  const bookings = await prisma.booking.findMany({
    select: {
      id: true,
      companyName: true,
      organizationName: true,
      status: true,
      date: true,
      startTime: true,
    },
    orderBy: {
      createdAt: 'desc',
    },
  });

  if (bookings.length === 0) {
    console.log('   No bookings found.');
  } else {
    for (const booking of bookings) {
      const name = booking.organizationName || booking.companyName;
      const dateStr = new Date(booking.date).toLocaleDateString();
      console.log(`   - ${name}: ${booking.status} (${dateStr} at ${booking.startTime})`);
      console.log(`     ID: ${booking.id}`);
      console.log('');
    }
  }

  await prisma.$disconnect();
}

listBookings();
