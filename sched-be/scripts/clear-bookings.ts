#!/usr/bin/env bun
import { prisma } from '../src/lib/prisma';

async function clearBookings() {
  console.log('🗑️  Clearing all bookings, attendees, participants, and notifications...');

  try {
    // Delete in order due to foreign key constraints
    const deletedNotifications = await prisma.notification.deleteMany({});
    console.log(`✅ Deleted ${deletedNotifications.count} notifications`);

    const deletedParticipants = await prisma.bookingParticipant.deleteMany({});
    console.log(`✅ Deleted ${deletedParticipants.count} booking participants`);

    const deletedAttendees = await prisma.attendee.deleteMany({});
    console.log(`✅ Deleted ${deletedAttendees.count} attendees`);

    const deletedBookings = await prisma.booking.deleteMany({});
    console.log(`✅ Deleted ${deletedBookings.count} bookings`);

    console.log('\n✨ Database cleared successfully!');
  } catch (error) {
    console.error('❌ Error clearing database:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

clearBookings();
