import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { BugReportCreateSchema, BugReportUpdateSchema, BugReportFilterSchema, BugCommentCreateSchema, BugCommentUpdateSchema } from '../types';
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

    // Notify all ADMINs about new bug report
    try {
      const admins = await prisma.user.findMany({
        where: { role: 'ADMIN', isActive: true },
      });

      for (const admin of admins) {
        // Create in-app notification
        await prisma.notification.create({
          data: {
            type: 'BUG_REPORT_CREATED',
            title: 'New Bug Report',
            message: `${user.name} reported a new bug: "${bugReport.title}"`,
            userId: admin.id,
            actionUrl: `/bug-reports/${bugReport.id}`,
            metadata: {
              bugReportId: bugReport.id,
              reportedById: user.id,
              reportedByName: user.name,
              platform: bugReport.platform,
            },
          },
        });

        // Send push notification
        await pushService.sendPushToUser(
          admin.id,
          'New Bug Report',
          `${user.name}: "${bugReport.title}"`,
          `/bug-reports/${bugReport.id}`
        );
      }
    } catch (notificationError) {
      console.error('[BugReports] Error sending notifications to ADMINs:', notificationError);
      // Don't fail the request if notification fails
    }

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

    // Check permissions
    const isOwner = originalBug.reportedById === user.id;
    const isAdmin = user.role === 'ADMIN';

    // Users can only edit their own bugs (title/description) and only if not resolved/closed
    if (!isAdmin && !isOwner) {
      return c.json({ error: 'You can only edit your own bug reports' }, 403);
    }

    if (!isAdmin && (originalBug.status === 'RESOLVED' || originalBug.status === 'CLOSED')) {
      return c.json({ error: 'Cannot edit resolved or closed bug reports' }, 403);
    }

    // Only ADMIN can change status
    if (data.status && !isAdmin) {
      return c.json({ error: 'Only ADMIN can change bug status' }, 403);
    }

    // Only ADMIN can add resolution notes
    if (data.resolutionNotes && !isAdmin) {
      return c.json({ error: 'Only ADMIN can add resolution notes' }, 403);
    }

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

// Get bug statistics (ADMIN only)
app.get('/stats/overview', authMiddleware, async (c) => {
  try {
    const user = c.get('user');

    if (user.role !== 'ADMIN') {
      return c.json({ error: 'Only ADMIN can view statistics' }, 403);
    }

    const stats = await bugReportService.getBugStatistics();
    return c.json(stats);
  } catch (error: any) {
    console.error('[BugReports] Error fetching statistics:', error);
    return c.json({ error: error.message || 'Failed to fetch statistics' }, 400);
  }
});

// ==================== BUG COMMENTS ====================

// Get comments for a bug report
app.get('/:id/comments', authMiddleware, async (c) => {
  try {
    const id = c.req.param('id');
    const comments = await bugReportService.getBugComments(id);
    return c.json({ comments });
  } catch (error: any) {
    console.error('[BugReports] Error fetching comments:', error);
    return c.json({ error: error.message || 'Failed to fetch comments' }, 400);
  }
});

// Create comment on bug report
app.post('/:id/comments', authMiddleware, zValidator('json', BugCommentCreateSchema), async (c) => {
  try {
    const user = c.get('user');
    const id = c.req.param('id');
    const { content, deviceInfo } = c.req.valid('json');

    const comment = await bugReportService.createBugComment(id, content, user.id, deviceInfo);
    return c.json(comment, 201);
  } catch (error: any) {
    console.error('[BugReports] Error creating comment:', error);
    return c.json({ error: error.message || 'Failed to create comment' }, 400);
  }
});

// Update comment
app.patch('/comments/:commentId', authMiddleware, zValidator('json', BugCommentUpdateSchema), async (c) => {
  try {
    const user = c.get('user');
    const commentId = c.req.param('commentId');
    const { content } = c.req.valid('json');

    const comment = await bugReportService.updateBugComment(commentId, content, user.id);
    return c.json(comment);
  } catch (error: any) {
    console.error('[BugReports] Error updating comment:', error);
    return c.json({ error: error.message || 'Failed to update comment' }, 400);
  }
});

// Delete comment
app.delete('/comments/:commentId', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const commentId = c.req.param('commentId');

    const result = await bugReportService.deleteBugComment(commentId, user.id, user.role);
    return c.json(result);
  } catch (error: any) {
    console.error('[BugReports] Error deleting comment:', error);
    return c.json({ error: error.message || 'Failed to delete comment' }, 400);
  }
});

// Upload attachments for a comment (up to 6)
app.post('/comments/:commentId/attachments', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const commentId = c.req.param('commentId');

    // Verify comment exists and user has permission
    const comment = await bugReportService.getBugCommentById(commentId);
    if (comment.userId !== user.id && user.role !== 'ADMIN') {
      return c.json({ error: 'You can only add attachments to your own comments' }, 403);
    }

    // Check current attachment count
    const currentCount = await bugReportService.getBugCommentAttachmentCount(commentId);
    if (currentCount >= 6) {
      return c.json({ error: 'Maximum 6 attachments per comment' }, 400);
    }

    const formData = await c.req.formData();
    const files = formData.getAll('files') as File[];

    if (!files || files.length === 0) {
      return c.json({ error: 'No files provided' }, 400);
    }

    if (currentCount + files.length > 6) {
      return c.json({
        error: `Cannot upload ${files.length} files. Only ${6 - currentCount} more attachment(s) allowed.`
      }, 400);
    }

    const attachments = await bugReportService.addCommentAttachments(commentId, files);
    return c.json({ attachments }, 201);
  } catch (error: any) {
    console.error('[BugReports] Error uploading comment attachments:', error);
    return c.json({ error: error.message || 'Failed to upload attachments' }, 400);
  }
});

// Delete a comment attachment
app.delete('/comments/:commentId/attachments/:attachmentId', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const commentId = c.req.param('commentId');
    const attachmentId = c.req.param('attachmentId');

    // Verify comment ownership
    const comment = await bugReportService.getBugCommentById(commentId);
    if (comment.userId !== user.id && user.role !== 'ADMIN') {
      return c.json({ error: 'You can only delete attachments from your own comments' }, 403);
    }

    const result = await bugReportService.deleteCommentAttachment(attachmentId);
    return c.json(result);
  } catch (error: any) {
    console.error('[BugReports] Error deleting comment attachment:', error);
    return c.json({ error: error.message || 'Failed to delete attachment' }, 400);
  }
});

export default app;
