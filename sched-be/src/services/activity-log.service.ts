import { prisma } from '../lib/prisma';
import type { ActivityAction, ActivityResource } from '@prisma/client';

interface LogActivityInput {
  action: ActivityAction;
  resource: ActivityResource;
  resourceId?: string;
  description: string;
  userId?: string;
  metadata?: any;
  ipAddress?: string;
  userAgent?: string;
}

export async function logActivity(data: LogActivityInput) {
  try {
    await prisma.activityLog.create({
      data: {
        action: data.action,
        resource: data.resource,
        resourceId: data.resourceId,
        description: data.description,
        userId: data.userId,
        metadata: data.metadata,
        ipAddress: data.ipAddress,
        userAgent: data.userAgent,
      },
    });
  } catch (error) {
    // Log error but don't fail the request
    console.error('Failed to log activity:', error);
  }
}

export async function getActivityLogs(filters?: {
  userId?: string;
  action?: ActivityAction;
  resource?: ActivityResource;
  search?: string;
  limit?: number;
  offset?: number;
}) {
  const where: any = {};

  if (filters?.userId) {
    where.userId = filters.userId;
  }

  if (filters?.action) {
    where.action = filters.action;
  }

  if (filters?.resource) {
    where.resource = filters.resource;
  }

  // Add search functionality
  if (filters?.search) {
    where.OR = [
      {
        description: {
          contains: filters.search,
          mode: 'insensitive',
        },
      },
      {
        user: {
          name: {
            contains: filters.search,
            mode: 'insensitive',
          },
        },
      },
      {
        user: {
          email: {
            contains: filters.search,
            mode: 'insensitive',
          },
        },
      },
    ];
  }

  const logs = await prisma.activityLog.findMany({
    where,
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
        },
      },
    },
    orderBy: {
      createdAt: 'desc',
    },
    take: filters?.limit || 100,
    skip: filters?.offset || 0,
  });

  const total = await prisma.activityLog.count({ where });

  return {
    logs,
    total,
    limit: filters?.limit || 100,
    offset: filters?.offset || 0,
  };
}

export async function getUserActivitySummary(userId: string) {
  const [totalActions, recentLogs, actionBreakdown] = await Promise.all([
    prisma.activityLog.count({
      where: { userId },
    }),
    prisma.activityLog.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 10,
    }),
    prisma.activityLog.groupBy({
      by: ['action'],
      where: { userId },
      _count: {
        action: true,
      },
    }),
  ]);

  return {
    totalActions,
    recentLogs,
    actionBreakdown,
  };
}
