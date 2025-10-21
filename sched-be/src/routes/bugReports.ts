import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { BugReportCreateSchema, BugReportUpdateSchema, BugReportFilterSchema } from '../types';
import * as bugReportService from '../services/bugReport.service';
import * as pushService from '../services/push.service';
import { authMiddleware } from '../middleware/auth';
import type { AppContext } from '../lib/context';
import { prisma } from '../lib/prisma';

const app = new Hono<AppContext>();

// Create bug report
app.post('/', authMiddleware, zValidator('json', BugReportCreateSchema), async (c) => {
  try {
    const user = c.get('user');
    const data = c.req.valid('json');

    const bugReport = await bugReportService.createBugReport(data, user.id);

    return c.json(bugReport, 201);
  } catch (error: any) {
    console.error('[BugReports] Error creating bug report:', error);
    return c.json({ error: error.message || 'Failed to create bug report' }, 400);
  }
});

// Get all bug reports (with filters)
app.get('/', authMiddleware, async (c) => {
  try {
    const status = c.req.query('status');
    const platform = c.req.query('platform');
    const search = c.req.query('search');
    const sortBy = c.req.query('sortBy') as 'createdAt' | 'likeCount' | 'updatedAt' | undefined;
    const order = c.req.query('order') as 'asc' | 'desc' | undefined;

    const bugs = await bugReportService.getBugReports({
      status,
      platform,
      search,
      sortBy,
      order,
    });

    return c.json({ bugs });
  } catch (error: any) {
    console.error('[BugReports] Error fetching bug reports:', error);
    return c.json({ error: error.message || 'Failed to fetch bug reports' }, 400);
  }
});

// Get bug report by ID
app.get('/:id', authMiddleware, async (c) => {
  try {
    const id = c.req.param('id');
    const bug = await bugReportService.getBugReportById(id);

    return c.json(bug);
  } catch (error: any) {
    console.error('[BugReports] Error fetching bug report:', error);
    return c.json({ error: error.message || 'Bug report not found' }, 404);
  }
});

// Update bug report
app.patch('/:id', authMiddleware, zValidator('json', BugReportUpdateSchema), async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');
    const data = c.req.valid('json');

    const originalBug = await bugReportService.getBugReportById(id);
    const wasResolved = data.status === 'RESOLVED' && originalBug.status !== 'RESOLVED';

    const updatedBug = await bugReportService.updateBugReport(id, data, user.id, user.role);

    // Send notification if bug was just resolved
    if (wasResolved) {
      try {
        // Create in-app notification
        await prisma.notification.create({
          data: {
            type: 'BUG_REPORT_RESOLVED',
            title: 'Bug Report Resolved',
            message: `Your bug report "${updatedBug.title}" has been marked as resolved.${data.resolutionNotes ? ` Resolution notes: ${data.resolutionNotes}` : ''}`,
            userId: updatedBug.reportedById,
            actionUrl: `/bug-reports/${updatedBug.id}`,
            metadata: {
              bugReportId: updatedBug.id,
              resolvedById: user.id,
              resolvedByName: user.name,
            },
          },
        });

        // Send push notification
        await pushService.sendPushToUser(
          updatedBug.reportedById,
          'Bug Report Resolved',
          `Your bug report "${updatedBug.title}" has been resolved.`,
          `/bug-reports/${updatedBug.id}`
        );
      } catch (notificationError) {
        console.error('[BugReports] Error sending resolution notification:', notificationError);
        // Don't fail the request if notification fails
      }
    }

    return c.json(updatedBug);
  } catch (error: any) {
    console.error('[BugReports] Error updating bug report:', error);
    return c.json({ error: error.message || 'Failed to update bug report' }, 400);
  }
});

// Delete bug report (ADMIN only)
app.delete('/:id', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');

    if (user.role !== 'ADMIN') {
      return c.json({ error: 'Only ADMIN can delete bug reports' }, 403);
    }

    const result = await bugReportService.deleteBugReport(id, user.id, user.role);
    return c.json(result);
  } catch (error: any) {
    console.error('[BugReports] Error deleting bug report:', error);
    return c.json({ error: error.message || 'Failed to delete bug report' }, 400);
  }
});

// Like bug report
app.post('/:id/like', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');

    const like = await bugReportService.likeBugReport(id, user.id);
    return c.json(like);
  } catch (error: any) {
    console.error('[BugReports] Error liking bug report:', error);
    return c.json({ error: error.message || 'Failed to like bug report' }, 400);
  }
});

// Unlike bug report
app.delete('/:id/like', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');

    const result = await bugReportService.unlikeBugReport(id, user.id);
    return c.json(result);
  } catch (error: any) {
    console.error('[BugReports] Error unliking bug report:', error);
    return c.json({ error: error.message || 'Failed to unlike bug report' }, 400);
  }
});

// Check if user liked bug
app.get('/:id/liked', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');

    const liked = await bugReportService.hasUserLikedBug(id, user.id);
    return c.json({ liked });
  } catch (error: any) {
    console.error('[BugReports] Error checking like status:', error);
    return c.json({ error: error.message || 'Failed to check like status' }, 400);
  }
});

// Get bug statistics (ADMIN/MANAGER only)
app.get('/stats/overview', authMiddleware, async (c) => {
  try {
    const user = c.get('user');

    if (user.role !== 'ADMIN' && user.role !== 'MANAGER') {
      return c.json({ error: 'Only ADMIN and MANAGER can view statistics' }, 403);
    }

    const stats = await bugReportService.getBugStatistics();
    return c.json(stats);
  } catch (error: any) {
    console.error('[BugReports] Error fetching statistics:', error);
    return c.json({ error: error.message || 'Failed to fetch statistics' }, 400);
  }
});

export default app;
