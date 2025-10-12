import { prisma } from '../src/lib/prisma';

/**
 * Reset database while preserving users
 *
 * This script will:
 * - Delete all bookings (and related attendees via cascade)
 * - Delete all notifications
 * - Delete all activity logs
 * - Delete all invitations
 * - Delete all FCM analytics
 * - Delete all booking participants
 * - Delete all push subscriptions
 *
 * Preserve:
 * - Users and their credentials
 * - Active sessions
 * - FCM tokens (to avoid re-registration)
 */

async function resetDatabase() {
  try {
    console.log('[Reset] Starting database reset...\n');

    // 1. Delete FCM Analytics
    console.log('[Reset] Deleting FCM analytics...');
    const fcmAnalyticsCount = await prisma.fCMAnalytics.deleteMany({});
    console.log(`[Reset] ✅ Deleted ${fcmAnalyticsCount.count} FCM analytics records\n`);

    // 2. Delete Notifications
    console.log('[Reset] Deleting notifications...');
    const notificationsCount = await prisma.notification.deleteMany({});
    console.log(`[Reset] ✅ Deleted ${notificationsCount.count} notifications\n`);

    // 3. Delete Activity Logs
    console.log('[Reset] Deleting activity logs...');
    const activityLogsCount = await prisma.activityLog.deleteMany({});
    console.log(`[Reset] ✅ Deleted ${activityLogsCount.count} activity logs\n`);

    // 4. Delete Invitations (must be before bookings due to relation)
    console.log('[Reset] Deleting invitations...');
    const invitationsCount = await prisma.invitation.deleteMany({});
    console.log(`[Reset] ✅ Deleted ${invitationsCount.count} invitations\n`);

    // 5. Delete Bookings (this will cascade delete Attendees and BookingParticipants)
    console.log('[Reset] Deleting bookings (attendees and participants will cascade)...');
    const bookingsCount = await prisma.booking.deleteMany({});
    console.log(`[Reset] ✅ Deleted ${bookingsCount.count} bookings\n`);

    // 6. Delete Push Subscriptions (optional - user can re-subscribe)
    console.log('[Reset] Deleting push subscriptions...');
    const pushSubsCount = await prisma.pushSubscription.deleteMany({});
    console.log(`[Reset] ✅ Deleted ${pushSubsCount.count} push subscriptions\n`);

    // Summary
    console.log('═'.repeat(60));
    console.log('[Reset] Database reset completed successfully! ✅\n');
    console.log('Deleted:');
    console.log(`  - ${bookingsCount.count} bookings`);
    console.log(`  - ${notificationsCount.count} notifications`);
    console.log(`  - ${activityLogsCount.count} activity logs`);
    console.log(`  - ${invitationsCount.count} invitations`);
    console.log(`  - ${fcmAnalyticsCount.count} FCM analytics`);
    console.log(`  - ${pushSubsCount.count} push subscriptions\n`);

    // Show preserved data
    const usersCount = await prisma.user.count();
    const sessionsCount = await prisma.session.count();
    const fcmTokensCount = await prisma.fCMToken.count();

    console.log('Preserved:');
    console.log(`  - ${usersCount} users`);
    console.log(`  - ${sessionsCount} active sessions`);
    console.log(`  - ${fcmTokensCount} FCM tokens\n`);
    console.log('═'.repeat(60));

  } catch (error) {
    console.error('[Reset] ❌ Error resetting database:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

resetDatabase()
  .then(() => process.exit(0))
  .catch(() => process.exit(1));
