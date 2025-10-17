import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function cleanDatabase() {
  try {
    console.log('🗑️  Starting database cleanup...');

    // Delete all bookings
    const deletedBookings = await prisma.booking.deleteMany({});
    console.log(`✅ Deleted ${deletedBookings.count} bookings`);

    // Delete all invitations
    const deletedInvitations = await prisma.invitation.deleteMany({});
    console.log(`✅ Deleted ${deletedInvitations.count} invitations`);

    console.log('✨ Database cleaned successfully!');
  } catch (error) {
    console.error('❌ Error cleaning database:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

cleanDatabase();
