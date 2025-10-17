import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkNotifications() {
  console.log('🔔 Recent notifications:\n');

  const notifications = await prisma.notification.findMany({
    include: {
      user: {
        select: {
          email: true,
          role: true,
        },
      },
    },
    orderBy: {
      createdAt: 'desc',
    },
    take: 10,
  });

  if (notifications.length === 0) {
    console.log('   No notifications found.');
  } else {
    for (const notif of notifications) {
      console.log(`   [${notif.type}] to ${notif.user.email} (${notif.user.role})`);
      console.log(`   Title: ${notif.title}`);
      console.log(`   Message: ${notif.message}`);
      if (notif.bookingId) {
        console.log(`   Booking ID: ${notif.bookingId}`);
      }
      console.log(`   Read: ${notif.isRead}`);
      console.log(`   Created: ${notif.createdAt.toLocaleString()}`);
      console.log('');
    }
  }

  await prisma.$disconnect();
}

checkNotifications();
