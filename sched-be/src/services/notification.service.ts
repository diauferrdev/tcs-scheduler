import { prisma } from '../lib/prisma';
import type { NotificationType } from '@prisma/client';
import * as pushService from './push.service';
import * as websocketService from './websocket.service';

interface CreateNotificationInput {
  type: NotificationType;
  title: string;
  message: string;
  userId: string;
  bookingId?: string;
  actionUrl?: string;
  screen?: 'approvals' | 'booking_details' | 'my_bookings' | 'calendar' | 'notifications';
  metadata?: any;
}

export async function createNotification(data: CreateNotificationInput) {
  const notification = await prisma.notification.create({
    data: {
      type: data.type,
      title: data.title,
      message: data.message,
      userId: data.userId,
      bookingId: data.bookingId,
      actionUrl: data.actionUrl,
      metadata: data.metadata,
    },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
    },
  });

  // Send real-time notification via native WebSocket
  websocketService.sendNotification(data.userId, {
    id: notification.id,
    type: data.type,
    title: data.title,
    message: data.message,
    userId: data.userId, // ✅ Include userId for Flutter AppNotification.fromJson()
    bookingId: data.bookingId,
    actionUrl: data.actionUrl,
    metadata: {
      ...data.metadata,
      screen: data.screen, // ✅ Include screen for navigation
    },
    isRead: false,
    createdAt: notification.createdAt.toISOString(), // ✅ Send as ISO String, not timestamp
  });

  console.log('[Notification] Created and sent notification:', {
    id: notification.id,
    userId: data.userId,
    type: data.type,
    wsConnected: websocketService.isUserConnected(data.userId),
  });

  // Send push notification
  pushService.sendPushToUser(data.userId, {
    title: data.title,
    body: data.message,
    data: {
      notificationId: notification.id,
      type: data.type,
      bookingId: data.bookingId || '', // ✅ CRITICAL: Include bookingId for deep linking
      screen: data.screen || 'booking_details', // ✅ Include screen for navigation
      ...(data.metadata || {}),
    },
  }).catch((error: any) => {
    console.error('[Notification] Failed to send push notification:', error);
  });

  return notification;
}

export async function getUserNotifications(
  userId: string,
  filters?: {
    isRead?: boolean;
    type?: NotificationType;
    limit?: number;
    offset?: number;
  }
) {
  const where: any = { userId };

  if (filters?.isRead !== undefined) {
    where.isRead = filters.isRead;
  }

  if (filters?.type) {
    where.type = filters.type;
  }

  const notifications = await prisma.notification.findMany({
    where,
    orderBy: {
      createdAt: 'desc',
    },
    take: filters?.limit || 50,
    skip: filters?.offset || 0,
  });

  const total = await prisma.notification.count({ where });
  const unreadCount = await prisma.notification.count({
    where: { userId, isRead: false },
  });

  return {
    notifications,
    total,
    unreadCount,
    limit: filters?.limit || 50,
    offset: filters?.offset || 0,
  };
}

export async function markNotificationAsRead(notificationId: string, userId: string) {
  const notification = await prisma.notification.findFirst({
    where: {
      id: notificationId,
      userId,
    },
  });

  if (!notification) {
    throw new Error('Notification not found');
  }

  return await prisma.notification.update({
    where: { id: notificationId },
    data: {
      isRead: true,
      readAt: new Date(),
    },
  });
}

export async function markAllAsRead(userId: string) {
  return await prisma.notification.updateMany({
    where: {
      userId,
      isRead: false,
    },
    data: {
      isRead: true,
      readAt: new Date(),
    },
  });
}

export async function deleteNotification(notificationId: string, userId: string) {
  const notification = await prisma.notification.findFirst({
    where: {
      id: notificationId,
      userId,
    },
  });

  if (!notification) {
    throw new Error('Notification not found');
  }

  return await prisma.notification.delete({
    where: { id: notificationId },
  });
}

export async function notifyAllManagers(
  type: NotificationType,
  title: string,
  message: string,
  bookingId?: string,
  excludeUserId?: string
) {
  const managers = await prisma.user.findMany({
    where: {
      role: { in: ['ADMIN', 'MANAGER'] },
      isActive: true,
      ...(excludeUserId ? { id: { not: excludeUserId } } : {}),
    },
  });

  console.log('[NotifyManagers] Found managers:', {
    count: managers.length,
    roles: managers.map(m => ({ email: m.email, role: m.role })),
    type,
    bookingId,
    excludeUserId,
  });

  const notifications = await Promise.all(
    managers.map(manager =>
      createNotification({
        type,
        title,
        message,
        userId: manager.id,
        bookingId,
        actionUrl: bookingId ? `/calendar?booking=${bookingId}` : undefined,
      })
    )
  );

  console.log('[NotifyManagers] ✅ Sent notifications:', {
    count: notifications.length,
    notificationIds: notifications.map(n => n.id),
  });

  return notifications;
}

export async function notifyBookingParticipants(
  bookingId: string,
  type: NotificationType,
  title: string,
  message: string,
  excludeUserId?: string
) {
  const participants = await prisma.bookingParticipant.findMany({
    where: {
      bookingId,
      ...(excludeUserId ? { userId: { not: excludeUserId } } : {}),
    },
    include: {
      user: true,
    },
  });

  const notifications = await Promise.all(
    participants.map(participant =>
      createNotification({
        type,
        title,
        message,
        userId: participant.userId,
        bookingId,
        actionUrl: `/calendar?booking=${bookingId}`,
      })
    )
  );

  return notifications;
}
