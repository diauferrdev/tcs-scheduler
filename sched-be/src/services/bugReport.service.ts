import { prisma } from '../lib/prisma';
import type { BugReportCreateInput, BugReportUpdateInput, BugReportFilterInput } from '../types';
import type { Platform, BugStatus } from '@prisma/client';
import { stat, unlink } from 'fs/promises';
import { join } from 'path';
import * as websocketService from './websocket.service';

/**
 * Bug Report Service
 *
 * Features:
 * - Create bug reports with attachments and device info
 * - List bugs with search, filters, and sorting (by likes, date)
 * - Like/Unlike bugs
 * - Update bug status (ADMIN/MANAGER only)
 * - Mark bugs as resolved with notifications
 */

// ==================== HELPER FUNCTIONS ====================

/**
 * Detect MIME type from file extension
 */
function getFileTypeFromExtension(fileName: string): string {
  const ext = fileName.split('.').pop()?.toLowerCase();

  if (!ext) return 'application/octet-stream';

  // Images
  if (['jpg', 'jpeg'].includes(ext)) return 'image/jpeg';
  if (ext === 'png') return 'image/png';
  if (ext === 'gif') return 'image/gif';
  if (ext === 'webp') return 'image/webp';
  if (ext === 'svg') return 'image/svg+xml';

  // Videos
  if (ext === 'mp4') return 'video/mp4';
  if (ext === 'webm') return 'video/webm';
  if (ext === 'ogg') return 'video/ogg';
  if (ext === 'mov') return 'video/quicktime';
  if (ext === 'avi') return 'video/x-msvideo';

  // Documents
  if (ext === 'pdf') return 'application/pdf';
  if (ext === 'doc') return 'application/msword';
  if (ext === 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  if (ext === 'xls') return 'application/vnd.ms-excel';
  if (ext === 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (ext === 'txt') return 'text/plain';
  if (ext === 'csv') return 'text/csv';

  return 'application/octet-stream';
}

/**
 * Get file size from file system
 */
async function getFileSizeFromPath(fileUrl: string): Promise<number> {
  try {
    // Remove leading slash and construct full path
    const relativePath = fileUrl.startsWith('/') ? fileUrl.substring(1) : fileUrl;
    const fullPath = join(process.cwd(), relativePath);
    const stats = await stat(fullPath);
    return stats.size;
  } catch (error) {
    console.error('[BugReport] Error getting file size:', error);
    return 0;
  }
}

// ==================== CREATE BUG REPORT ====================

export async function createBugReport(
  data: BugReportCreateInput,
  userId: string
) {
  const { title, description, platform, deviceInfo, attachments } = data;

  // Process attachments to get proper metadata
  const attachmentData = attachments ? await Promise.all(
    attachments.map(async (item, index) => {
      let fileUrl: string;
      let fileName: string;
      let fileSize: number;
      let fileType: string;

      // Support both string URLs (legacy) and objects with metadata
      if (typeof item === 'string') {
        fileUrl = item;
        fileName = item.split('/').pop() || `attachment-${index + 1}`;
        fileSize = await getFileSizeFromPath(fileUrl);
        fileType = getFileTypeFromExtension(fileName);
      } else {
        // New format: { url, fileName, fileSize, fileType }
        fileUrl = item.url;
        fileName = item.fileName || item.url.split('/').pop() || `attachment-${index + 1}`;
        fileSize = item.fileSize || await getFileSizeFromPath(fileUrl);
        fileType = item.fileType || getFileTypeFromExtension(fileName);
      }

      return { fileUrl, fileName, fileSize, fileType };
    })
  ) : undefined;

  // Create bug report with attachments
  const bugReport = await prisma.bugReport.create({
    data: {
      title,
      description,
      platform: platform as Platform,
      deviceInfo: deviceInfo || {},
      reportedById: userId,
      // Create attachments if provided
      attachments: attachmentData ? {
        create: attachmentData,
      } : undefined,
    },
    include: {
      reportedBy: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
        },
      },
      attachments: true,
      likes: {
        include: {
          user: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      },
    },
  });

  console.log('[BugReport] Created:', {
    id: bugReport.id,
    title: bugReport.title,
    platform: bugReport.platform,
    reportedBy: bugReport.reportedBy.name,
  });

  // Broadcast to all connected users
  websocketService.broadcastBugCreated(bugReport);

  return bugReport;
}

// ==================== GET ALL BUG REPORTS ====================

export async function getBugReports(filters?: BugReportFilterInput) {
  const {
    status,
    platform,
    search,
    sortBy = 'likeCount', // Default: sort by likes (most popular first)
    order = 'desc',
  } = filters || {};

  const where: any = {};

  // Filter by status
  if (status) {
    where.status = status as BugStatus;
  }

  // Filter by platform
  if (platform) {
    where.platform = platform as Platform;
  }

  // Search in title and description
  if (search) {
    where.OR = [
      { title: { contains: search, mode: 'insensitive' } },
      { description: { contains: search, mode: 'insensitive' } },
    ];
  }

  // Get bugs with full details
  const bugs = await prisma.bugReport.findMany({
    where,
    include: {
      reportedBy: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          avatarUrl: true,
        },
      },
      resolvedBy: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
        },
      },
      attachments: true,
      likes: {
        include: {
          user: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      },
      _count: {
        select: {
          likes: true,
          attachments: true,
          comments: true,
        },
      },
    },
    orderBy: sortBy === 'likeCount'
      ? { likeCount: order }
      : sortBy === 'updatedAt'
      ? { updatedAt: order }
      : { createdAt: order },
  });

  return bugs;
}

// ==================== GET SINGLE BUG REPORT ====================

export async function getBugReportById(id: string) {
  const bug = await prisma.bugReport.findUnique({
    where: { id },
    include: {
      reportedBy: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          avatarUrl: true,
        },
      },
      resolvedBy: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
        },
      },
      closedBy: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
        },
      },
      attachments: true,
      comments: {
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
              role: true,
              avatarUrl: true,
            },
          },
        },
        orderBy: {
          createdAt: 'asc',
        },
      },
      likes: {
        include: {
          user: {
            select: {
              id: true,
              name: true,
              avatarUrl: true,
            },
          },
        },
      },
      _count: {
        select: {
          likes: true,
          attachments: true,
          comments: true,
        },
      },
    },
  });

  if (!bug) {
    throw new Error('Bug report not found');
  }

  return bug;
}

// ==================== UPDATE BUG REPORT ====================

export async function updateBugReport(
  id: string,
  data: BugReportUpdateInput,
  userId: string,
  userRole: 'ADMIN' | 'MANAGER' | 'USER'
) {
  const bug = await getBugReportById(id);

  // Only ADMIN/MANAGER can change status
  if (data.status && userRole !== 'ADMIN' && userRole !== 'MANAGER') {
    throw new Error('Only ADMIN and MANAGER can update bug status');
  }

  // Only the reporter or ADMIN can update title/description
  const isOwner = bug.reportedById === userId;
  const isAdmin = userRole === 'ADMIN';

  if ((data.title || data.description) && !isOwner && !isAdmin) {
    throw new Error('Only the reporter or ADMIN can update bug details');
  }

  // Non-admins cannot update resolved/closed bugs
  if ((data.title || data.description) && !isAdmin &&
      (bug.status === 'RESOLVED' || bug.status === 'CLOSED')) {
    throw new Error('Cannot update resolved or closed bugs');
  }

  const updateData: any = {};

  if (data.title) updateData.title = data.title;
  if (data.description) updateData.description = data.description;
  if (data.status) {
    updateData.status = data.status as BugStatus;

    // If marking as resolved, add resolver info
    if (data.status === 'RESOLVED') {
      updateData.resolvedById = userId;
      updateData.resolvedAt = new Date();
      if (data.resolutionNotes) {
        updateData.resolutionNotes = data.resolutionNotes;
      }
    }
  }

  const updatedBug = await prisma.bugReport.update({
    where: { id },
    data: updateData,
    include: {
      reportedBy: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
        },
      },
      resolvedBy: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
        },
      },
      attachments: true,
      likes: {
        include: {
          user: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      },
    },
  });

  console.log('[BugReport] Updated:', {
    id: updatedBug.id,
    status: updatedBug.status,
    updatedBy: userId,
  });

  // Broadcast to all connected users
  websocketService.broadcastBugUpdated(updatedBug);

  return updatedBug;
}

// ==================== DELETE BUG REPORT ====================

export async function deleteBugReport(id: string, userId: string, userRole: 'ADMIN' | 'MANAGER' | 'USER') {
  const bug = await getBugReportById(id);

  // Only ADMIN can delete bugs
  if (userRole !== 'ADMIN') {
    throw new Error('Only ADMIN can delete bug reports');
  }

  // Get all attachments to delete physical files
  const attachments = bug.attachments || [];

  // Delete physical files first
  for (const attachment of attachments) {
    try {
      const relativePath = attachment.fileUrl.startsWith('/')
        ? attachment.fileUrl.substring(1)
        : attachment.fileUrl;
      const fullPath = join(process.cwd(), relativePath);
      await unlink(fullPath);
      console.log('[BugReport] Deleted file:', attachment.fileName);
    } catch (error) {
      console.error('[BugReport] Failed to delete file:', attachment.fileName, error);
      // Continue with deletion even if file removal fails
    }
  }

  // Delete from database (cascade deletes attachments, comments, likes)
  await prisma.bugReport.delete({
    where: { id },
  });

  console.log('[BugReport] Deleted:', {
    id,
    title: bug.title,
    deletedBy: userId,
    filesDeleted: attachments.length,
  });

  // Broadcast to all connected users
  websocketService.broadcastBugDeleted(id);

  return { success: true, message: 'Bug report deleted successfully' };
}

// ==================== LIKE/UNLIKE BUG REPORT ====================

export async function likeBugReport(bugId: string, userId: string) {
  // Check if bug exists
  await getBugReportById(bugId);

  // Check if already liked
  const existingLike = await prisma.bugLike.findUnique({
    where: {
      bugReportId_userId: {
        bugReportId: bugId,
        userId,
      },
    },
  });

  if (existingLike) {
    throw new Error('You have already liked this bug report');
  }

  // Create like and increment counter atomically
  const [like] = await prisma.$transaction([
    prisma.bugLike.create({
      data: {
        bugReportId: bugId,
        userId,
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    }),
    prisma.bugReport.update({
      where: { id: bugId },
      data: {
        likeCount: {
          increment: 1,
        },
      },
    }),
  ]);

  console.log('[BugReport] Liked:', {
    bugId,
    userId,
    userName: like.user.name,
  });

  return like;
}

export async function unlikeBugReport(bugId: string, userId: string) {
  // Check if bug exists
  await getBugReportById(bugId);

  // Check if like exists
  const existingLike = await prisma.bugLike.findUnique({
    where: {
      bugReportId_userId: {
        bugReportId: bugId,
        userId,
      },
    },
  });

  if (!existingLike) {
    throw new Error('You have not liked this bug report');
  }

  // Delete like and decrement counter atomically
  await prisma.$transaction([
    prisma.bugLike.delete({
      where: {
        bugReportId_userId: {
          bugReportId: bugId,
          userId,
        },
      },
    }),
    prisma.bugReport.update({
      where: { id: bugId },
      data: {
        likeCount: {
          decrement: 1,
        },
      },
    }),
  ]);

  console.log('[BugReport] Unliked:', {
    bugId,
    userId,
  });

  return { success: true, message: 'Like removed successfully' };
}

// ==================== CHECK IF USER LIKED BUG ====================

export async function hasUserLikedBug(bugId: string, userId: string): Promise<boolean> {
  const like = await prisma.bugLike.findUnique({
    where: {
      bugReportId_userId: {
        bugReportId: bugId,
        userId,
      },
    },
  });

  return !!like;
}

// ==================== GET BUG STATISTICS ====================

export async function getBugStatistics() {
  const [
    total,
    open,
    inProgress,
    resolved,
    closed,
    byPlatform,
  ] = await Promise.all([
    prisma.bugReport.count(),
    prisma.bugReport.count({ where: { status: 'OPEN' } }),
    prisma.bugReport.count({ where: { status: 'IN_PROGRESS' } }),
    prisma.bugReport.count({ where: { status: 'RESOLVED' } }),
    prisma.bugReport.count({ where: { status: 'CLOSED' } }),
    prisma.bugReport.groupBy({
      by: ['platform'],
      _count: true,
    }),
  ]);

  const platformStats = byPlatform.reduce((acc, item) => {
    acc[item.platform] = item._count;
    return acc;
  }, {} as Record<string, number>);

  return {
    total,
    byStatus: {
      open,
      inProgress,
      resolved,
      closed,
    },
    byPlatform: platformStats,
  };
}

// ==================== BUG COMMENTS ====================

export async function createBugComment(
  bugReportId: string,
  content: string,
  userId: string
) {
  // Check if bug exists and is not closed
  const bug = await prisma.bugReport.findUnique({
    where: { id: bugReportId },
  });

  if (!bug) {
    throw new Error('Bug report not found');
  }

  if (bug.status === 'CLOSED') {
    throw new Error('Cannot comment on closed bug reports');
  }

  const comment = await prisma.bugComment.create({
    data: {
      content,
      bugReportId,
      userId,
    },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          avatarUrl: true,
        },
      },
    },
  });

  console.log('[BugComment] Created:', {
    id: comment.id,
    bugReportId,
    user: comment.user.name,
  });

  return comment;
}

export async function getBugComments(bugReportId: string) {
  return await prisma.bugComment.findMany({
    where: { bugReportId },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          avatarUrl: true,
        },
      },
    },
    orderBy: {
      createdAt: 'asc', // Oldest first (chronological order)
    },
  });
}

export async function updateBugComment(
  commentId: string,
  content: string,
  userId: string
) {
  const comment = await prisma.bugComment.findUnique({
    where: { id: commentId },
    include: { bugReport: true },
  });

  if (!comment) {
    throw new Error('Comment not found');
  }

  if (comment.userId !== userId) {
    throw new Error('You can only edit your own comments');
  }

  if (comment.bugReport.status === 'CLOSED') {
    throw new Error('Cannot edit comments on closed bug reports');
  }

  return await prisma.bugComment.update({
    where: { id: commentId },
    data: { content },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          avatarUrl: true,
        },
      },
    },
  });
}

export async function deleteBugComment(
  commentId: string,
  userId: string,
  userRole: string
) {
  const comment = await prisma.bugComment.findUnique({
    where: { id: commentId },
  });

  if (!comment) {
    throw new Error('Comment not found');
  }

  // Only comment owner or ADMIN can delete
  if (comment.userId !== userId && userRole !== 'ADMIN') {
    throw new Error('You can only delete your own comments');
  }

  await prisma.bugComment.delete({
    where: { id: commentId },
  });

  return { success: true, message: 'Comment deleted' };
}
