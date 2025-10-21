import { prisma } from '../lib/prisma';
import type { BugReportCreateInput, BugReportUpdateInput, BugReportFilterInput } from '../types';
import type { Platform, BugStatus } from '@prisma/client';

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

// ==================== CREATE BUG REPORT ====================

export async function createBugReport(
  data: BugReportCreateInput,
  userId: string
) {
  const { title, description, platform, deviceInfo, attachments } = data;

  // Create bug report with attachments
  const bugReport = await prisma.bugReport.create({
    data: {
      title,
      description,
      platform: platform as Platform,
      deviceInfo: deviceInfo || {},
      reportedById: userId,
      // Create attachments if provided
      attachments: attachments ? {
        create: attachments.map((url, index) => {
          // Extract file info from URL
          const fileName = url.split('/').pop() || `attachment-${index + 1}`;
          return {
            fileUrl: url,
            fileName,
            fileSize: 0, // Will be updated by frontend if needed
            fileType: 'application/octet-stream', // Default, will be updated by frontend
          };
        }),
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
      attachments: true,
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

  // Only the reporter can update title/description (and only if not resolved)
  if ((data.title || data.description) && bug.reportedById !== userId) {
    throw new Error('Only the reporter can update bug details');
  }

  if ((data.title || data.description) && bug.status === 'RESOLVED') {
    throw new Error('Cannot update resolved bugs');
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

  return updatedBug;
}

// ==================== DELETE BUG REPORT ====================

export async function deleteBugReport(id: string, userId: string, userRole: 'ADMIN' | 'MANAGER' | 'USER') {
  const bug = await getBugReportById(id);

  // Only ADMIN can delete bugs
  if (userRole !== 'ADMIN') {
    throw new Error('Only ADMIN can delete bug reports');
  }

  await prisma.bugReport.delete({
    where: { id },
  });

  console.log('[BugReport] Deleted:', {
    id,
    title: bug.title,
    deletedBy: userId,
  });

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
