import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function migrateCreatedToReview() {
  console.log('🔄 Starting migration: CREATED → UNDER_REVIEW');

  try {
    // Find all bookings with CREATED status
    const createdBookings = await prisma.booking.findMany({
      where: {
        status: 'CREATED',
      },
      select: {
        id: true,
        companyName: true,
        date: true,
        startTime: true,
      },
    });

    console.log(`\n📊 Found ${createdBookings.length} bookings with CREATED status\n`);

    if (createdBookings.length === 0) {
      console.log('✅ No bookings to migrate. All done!');
      return;
    }

    // Update all CREATED bookings to UNDER_REVIEW
    const result = await prisma.booking.updateMany({
      where: {
        status: 'CREATED',
      },
      data: {
        status: 'UNDER_REVIEW',
      },
    });

    console.log(`✅ Successfully migrated ${result.count} bookings to UNDER_REVIEW status\n`);

    // Show migrated bookings
    console.log('📋 Migrated bookings:');
    for (const booking of createdBookings) {
      console.log(`  - ${booking.companyName} on ${new Date(booking.date).toLocaleDateString()} at ${booking.startTime}`);
    }

    console.log('\n🎉 Migration complete!');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Run migration
migrateCreatedToReview();
