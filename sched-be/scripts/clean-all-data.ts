import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function cleanAllData() {
  console.log('🧹 Cleaning all bookings and notifications...\n');

  try {
    // Delete in correct order to respect foreign key constraints

    // 1. Delete all attendees first (they reference bookings)
    const deletedAttendees = await prisma.attendee.deleteMany({});
    console.log(`✅ Deleted ${deletedAttendees.count} attendees`);

    // 2. Delete all notifications
    const deletedNotifications = await prisma.notification.deleteMany({});
    console.log(`✅ Deleted ${deletedNotifications.count} notifications`);

    // 3. Delete all invitations
    const deletedInvitations = await prisma.invitation.deleteMany({});
    console.log(`✅ Deleted ${deletedInvitations.count} invitations`);

    // 4. Delete all bookings
    const deletedBookings = await prisma.booking.deleteMany({});
    console.log(`✅ Deleted ${deletedBookings.count} bookings`);

    console.log('\n🎉 All data cleaned successfully!');
    console.log('📊 Users are kept intact for login.');
  } catch (error) {
    console.error('❌ Error cleaning data:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

cleanAllData();
