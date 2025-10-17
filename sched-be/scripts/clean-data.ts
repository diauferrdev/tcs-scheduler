import { prisma } from '../src/lib/prisma';

async function cleanData() {
  console.log('🧹 Starting data cleanup...');

  try {
    // Delete all bookings first (because of foreign key constraint)
    const deletedBookings = await prisma.booking.deleteMany({});
    console.log(`✅ Deleted ${deletedBookings.count} bookings`);

    // Delete all invitations
    const deletedInvitations = await prisma.invitation.deleteMany({});
    console.log(`✅ Deleted ${deletedInvitations.count} invitations`);

    console.log('✨ Data cleanup completed successfully!');
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

cleanData();
