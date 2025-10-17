import { Hono } from 'hono';
import { z } from 'zod';
import { authMiddleware } from '../middleware/auth';
import { prisma } from '../lib/prisma';
import type { AppContext } from '../lib/context';

const app = new Hono<AppContext>();

// Require admin role for FCM analytics
app.use('*', authMiddleware);

// Get FCM analytics overview
app.get('/overview', async (c) => {
  const user = c.get('user');

  // Only admins can view analytics
  if (user.role !== 'ADMIN') {
    return c.json({ error: 'Unauthorized' }, 403);
  }

  try {
    // Get all-time totals
    const [totalSent, totalDelivered, totalFailed, totalClicked] = await Promise.all([
      prisma.fCMAnalytics.count(),
      prisma.fCMAnalytics.count({ where: { delivered: true } }),
      prisma.fCMAnalytics.count({ where: { failed: true } }),
      prisma.fCMAnalytics.count({ where: { clicked: true } }),
    ]);

    // Get active tokens count
    const activeTokens = await prisma.fCMToken.count({
      where: { isValid: true },
    });

    // Get last 24h stats
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const [last24hSent, last24hDelivered] = await Promise.all([
      prisma.fCMAnalytics.count({
        where: { sentAt: { gte: oneDayAgo } },
      }),
      prisma.fCMAnalytics.count({
        where: { sentAt: { gte: oneDayAgo }, delivered: true },
      }),
    ]);

    // Calculate rates
    const deliveryRate = totalSent > 0 ? (totalDelivered / totalSent) * 100 : 0;
    const clickRate = totalDelivered > 0 ? (totalClicked / totalDelivered) * 100 : 0;
    const failureRate = totalSent > 0 ? (totalFailed / totalSent) * 100 : 0;

    return c.json({
      totalSent,
      totalDelivered,
      totalFailed,
      totalClicked,
      activeTokens,
      last24hSent,
      last24hDelivered,
      deliveryRate: Math.round(deliveryRate * 100) / 100,
      clickRate: Math.round(clickRate * 100) / 100,
      failureRate: Math.round(failureRate * 100) / 100,
    });
  } catch (error) {
    console.error('[FCM Analytics] Error:', error);
    return c.json({ error: 'Failed to fetch analytics' }, 500);
  }
});

// Get recent FCM notifications
app.get('/recent', async (c) => {
  const user = c.get('user');

  if (user.role !== 'ADMIN') {
    return c.json({ error: 'Unauthorized' }, 403);
  }

  try {
    const querySchema = z.object({
      limit: z.coerce.number().min(1).max(200).default(50),
      offset: z.coerce.number().min(0).default(0),
    });

    const { limit, offset } = querySchema.parse({
      limit: c.req.query('limit'),
      offset: c.req.query('offset'),
    });

    const [notifications, total] = await Promise.all([
      prisma.fCMAnalytics.findMany({
        orderBy: { sentAt: 'desc' },
        take: limit,
        skip: offset,
      }),
      prisma.fCMAnalytics.count(),
    ]);

    return c.json({
      notifications,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + limit < total,
      },
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return c.json({ error: 'Invalid query parameters', details: error.errors }, 400);
    }
    console.error('[FCM Analytics] Error:', error);
    return c.json({ error: 'Failed to fetch recent notifications' }, 500);
  }
});

// Get FCM tokens status
app.get('/tokens', async (c) => {
  const user = c.get('user');

  if (user.role !== 'ADMIN') {
    return c.json({ error: 'Unauthorized' }, 403);
  }

  try {
    // Get token summary
    const [validTokens, invalidTokens, usersWithTokens] = await Promise.all([
      prisma.fCMToken.count({ where: { isValid: true } }),
      prisma.fCMToken.count({ where: { isValid: false } }),
      prisma.fCMToken.groupBy({
        by: ['userId'],
        _count: { token: true },
      }),
    ]);

    const totalUsersWithTokens = usersWithTokens.length;
    const totalTokens = validTokens + invalidTokens;
    const avgTokensPerUser = totalUsersWithTokens > 0
      ? Math.round((totalTokens / totalUsersWithTokens) * 100) / 100
      : 0;

    // Get detailed token list
    const tokens = await prisma.fCMToken.findMany({
      orderBy: { lastUsedAt: 'desc' },
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

    return c.json({
      summary: {
        validTokens,
        invalidTokens,
        totalUsersWithTokens,
        avgTokensPerUser,
      },
      tokens: tokens.map(token => ({
        id: token.id,
        token: token.token.substring(0, 20) + '...', // Truncate for security
        isValid: token.isValid,
        deviceInfo: token.deviceInfo,
        lastUsedAt: token.lastUsedAt,
        createdAt: token.createdAt,
        user: token.user,
      })),
    });
  } catch (error) {
    console.error('[FCM Analytics] Error:', error);
    return c.json({ error: 'Failed to fetch FCM tokens' }, 500);
  }
});

// Get failures breakdown
app.get('/failures', async (c) => {
  const user = c.get('user');

  if (user.role !== 'ADMIN') {
    return c.json({ error: 'Unauthorized' }, 403);
  }

  try {
    // Get all failed notifications
    const failures = await prisma.fCMAnalytics.findMany({
      where: {
        failed: true,
      },
      orderBy: { sentAt: 'desc' },
    });

    // Group by failure reason
    const byReason: Record<string, number> = {};
    failures.forEach(failure => {
      const reason = failure.failureReason || 'Unknown';
      byReason[reason] = (byReason[reason] || 0) + 1;
    });

    const total = failures.length;

    // Get recent failures (last 20)
    const recentFailures = failures.slice(0, 20).map(failure => ({
      id: failure.id,
      title: failure.title,
      message: failure.message,
      sentAt: failure.sentAt,
      failureReason: failure.failureReason,
      userId: failure.userId,
      notificationId: failure.notificationId,
    }));

    return c.json({
      total,
      byReason: Object.entries(byReason)
        .map(([reason, count]) => ({
          reason,
          count,
          percentage: total > 0 ? Math.round((count / total) * 100 * 100) / 100 : 0,
        }))
        .sort((a, b) => b.count - a.count),
      recentFailures,
    });
  } catch (error) {
    console.error('[FCM Analytics] Error:', error);
    return c.json({ error: 'Failed to fetch FCM failures' }, 500);
  }
});

export default app;
