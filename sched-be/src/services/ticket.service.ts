import { prisma } from '../lib/prisma';
import type { TicketCreate, TicketUpdate, TicketFilter, TicketMessageCreate } from '../types/ticket.types';
import { join } from 'path';

// Audio MIME types
const AUDIO_MIME_TYPES = [
  'audio/mp4',
  'audio/mpeg',
  'audio/wav',
  'audio/ogg',
  'audio/aac',
  'audio/webm',
  'audio/x-m4a',
];

/**
 * Extract audio duration from file in milliseconds using ffprobe
 * Returns null if not an audio file or extraction fails
 */
async function extractAudioDuration(fileUrl: string, mimeType: string): Promise<number | null> {
  if (!AUDIO_MIME_TYPES.includes(mimeType)) {
    return null; // Not an audio file
  }

  try {
    // Convert URL to file system path
    // URLs can be in format: https://api.pacesched.com/uploads/attachments/filename.m4a
    // or /uploads/attachments/filename.m4a
    const UPLOAD_BASE_DIR = join(process.cwd(), 'uploads');

    // Extract path after /uploads/
    let relativePath = fileUrl;
    if (relativePath.includes('://')) {
      // Full URL - extract path after domain
      const urlObj = new URL(relativePath);
      relativePath = urlObj.pathname; // Gets /uploads/attachments/filename.m4a
    }
    relativePath = relativePath.replace('/uploads/', '');
    const filepath = join(UPLOAD_BASE_DIR, relativePath);

    console.log(`[AudioExtract] Extracting duration from: ${filepath}`);

    // Use ffprobe to extract duration (more reliable than music-metadata)
    const proc = Bun.spawn(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', filepath], {
      stdout: 'pipe',
      stderr: 'pipe',
    });

    const output = await new Response(proc.stdout).text();
    await proc.exited;

    const durationSeconds = parseFloat(output.trim());

    if (!isNaN(durationSeconds) && durationSeconds > 0) {
      const durationMs = Math.round(durationSeconds * 1000);
      console.log(`[AudioExtract] ✅ Duration extracted: ${durationMs}ms (${durationSeconds}s)`);
      return durationMs;
    }

    console.log('[AudioExtract] ⚠️ No duration found in metadata');
    return null;
  } catch (error) {
    console.error('[AudioExtract] ❌ Error extracting duration:', error);
    return null;
  }
}

export async function createTicket(data: TicketCreate, userId: string) {
  // Extract durations for audio attachments
  let attachmentsWithDuration = undefined;
  if (data.attachments) {
    attachmentsWithDuration = await Promise.all(
      data.attachments.map(async (att) => {
        const duration = await extractAudioDuration(att.fileUrl, att.mimeType);
        return {
          fileName: att.fileName,
          fileUrl: att.fileUrl,
          fileSize: att.fileSize,
          mimeType: att.mimeType,
          duration,
          uploadedById: userId,
        };
      })
    );
  }

  const ticket = await prisma.ticket.create({
    data: {
      title: data.title,
      description: data.description,
      category: data.category,
      priority: data.priority || 'MEDIUM',
      platform: data.platform,
      deviceInfo: data.deviceInfo,
      createdById: userId,
      attachments: attachmentsWithDuration
        ? {
            create: attachmentsWithDuration,
          }
        : undefined,
    },
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
          avatarUrl: true,
          role: true,
          createdAt: true,
        },
      },
      assignedTo: {
        select: {
          id: true,
          name: true,
          email: true,
          avatarUrl: true,
          createdAt: true,
        },
      },
      attachments: true,
      messages: {
        include: {
          author: {
            select: {
              id: true,
              name: true,
              email: true,
              avatarUrl: true,
              role: true,
              createdAt: true,
            },
          },
          attachments: true,
        },
        orderBy: {
          createdAt: 'asc',
        },
      },
    },
  });

  return ticket;
}

export async function getTickets(filters: TicketFilter, userId: string, userRole: string) {
  const where: any = {};

  // Users can only see their own tickets
  if (userRole === 'USER') {
    where.createdById = userId;
  }

  // Apply filters
  if (filters.status) {
    where.status = filters.status;
  }
  if (filters.priority) {
    where.priority = filters.priority;
  }
  if (filters.category) {
    where.category = filters.category;
  }
  if (filters.createdById) {
    where.createdById = filters.createdById;
  }
  if (filters.assignedToId) {
    where.assignedToId = filters.assignedToId;
  }
  if (filters.search) {
    where.OR = [
      { title: { contains: filters.search, mode: 'insensitive' } },
      { description: { contains: filters.search, mode: 'insensitive' } },
    ];
  }

  const tickets = await prisma.ticket.findMany({
    where,
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
          avatarUrl: true,
          role: true,
          createdAt: true,
        },
      },
      assignedTo: {
        select: {
          id: true,
          name: true,
          email: true,
          avatarUrl: true,
          createdAt: true,
        },
      },
      messages: {
        where: userRole === 'ADMIN' ? {} : { isInternal: false }, // Users can't see internal notes
        include: {
          author: {
            select: {
              id: true,
              name: true,
              email: true,
              avatarUrl: true,
              role: true,
              createdAt: true,
            },
          },
          attachments: true,
        },
        orderBy: {
          createdAt: 'asc',
        },
      },
      _count: {
        select: {
          messages: true,
          attachments: true,
        },
      },
    },
    orderBy: [
      { status: 'asc' }, // Open first, then in progress, etc.
      { priority: 'desc' }, // Urgent first
      { createdAt: 'desc' }, // Newest first
    ],
  });

  return tickets;
}

export async function getTicketById(ticketId: string, userId: string, userRole: string) {
  const ticket = await prisma.ticket.findUnique({
    where: { id: ticketId },
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
          avatarUrl: true,
          role: true,
          createdAt: true,
        },
      },
      assignedTo: {
        select: {
          id: true,
          name: true,
          email: true,
          avatarUrl: true,
          createdAt: true,
        },
      },
      attachments: true,
      messages: {
        where: userRole === 'ADMIN' ? {} : { isInternal: false }, // Users can't see internal notes
        include: {
          author: {
            select: {
              id: true,
              name: true,
              email: true,
              avatarUrl: true,
              role: true,
              createdAt: true,
            },
          },
          attachments: true,
        },
        orderBy: {
          createdAt: 'asc',
        },
      },
    },
  });

  if (!ticket) {
    throw new Error('Ticket not found');
  }

  // Users can only see their own tickets
  if (userRole === 'USER' && ticket.createdById !== userId) {
    throw new Error('Access denied');
  }

  return ticket;
}

export async function updateTicket(ticketId: string, data: TicketUpdate, userId: string, userRole: string) {
  // Check permissions
  const ticket = await prisma.ticket.findUnique({
    where: { id: ticketId },
  });

  if (!ticket) {
    throw new Error('Ticket not found');
  }

  // Users can only update their own tickets and can't change status/assignedTo
  if (userRole === 'USER' && ticket.createdById !== userId) {
    throw new Error('Access denied');
  }

  if (userRole === 'USER' && (data.status || data.assignedToId !== undefined)) {
    throw new Error('Users cannot change status or assignment');
  }

  const updated = await prisma.ticket.update({
    where: { id: ticketId },
    data: {
      title: data.title,
      description: data.description,
      status: data.status,
      priority: data.priority,
      assignedToId: data.assignedToId,
      closedAt: data.status === 'CLOSED' ? new Date() : undefined,
    },
    include: {
      createdBy: {
        select: {
          id: true,
          name: true,
          email: true,
          avatarUrl: true,
          role: true,
          createdAt: true,
        },
      },
      assignedTo: {
        select: {
          id: true,
          name: true,
          email: true,
          avatarUrl: true,
          createdAt: true,
        },
      },
      attachments: true,
      messages: {
        include: {
          author: {
            select: {
              id: true,
              name: true,
              email: true,
              avatarUrl: true,
              role: true,
              createdAt: true,
            },
          },
          attachments: true,
        },
        orderBy: {
          createdAt: 'asc',
        },
      },
    },
  });

  return updated;
}

export async function deleteTicket(ticketId: string, userId: string, userRole: string) {
  // Only admins or the creator can delete
  const ticket = await prisma.ticket.findUnique({
    where: { id: ticketId },
  });

  if (!ticket) {
    throw new Error('Ticket not found');
  }

  if (userRole !== 'ADMIN' && ticket.createdById !== userId) {
    throw new Error('Access denied');
  }

  await prisma.ticket.delete({
    where: { id: ticketId },
  });
}

export async function createMessage(ticketId: string, data: TicketMessageCreate, userId: string, userRole: string) {
  // Check if ticket exists and user has access
  const ticket = await prisma.ticket.findUnique({
    where: { id: ticketId },
  });

  if (!ticket) {
    throw new Error('Ticket not found');
  }

  // Users can only message their own tickets
  if (userRole === 'USER' && ticket.createdById !== userId) {
    throw new Error('Access denied');
  }

  // Users cannot create internal notes
  if (userRole === 'USER' && data.isInternal) {
    throw new Error('Users cannot create internal notes');
  }

  // Extract durations for audio attachments
  let attachmentsWithDuration = undefined;
  if (data.attachments) {
    console.log(`[createMessage] Processing ${data.attachments.length} attachments`);
    attachmentsWithDuration = await Promise.all(
      data.attachments.map(async (att) => {
        console.log(`[createMessage] Attachment: ${att.fileName}, type: ${att.mimeType}`);
        const duration = await extractAudioDuration(att.fileUrl, att.mimeType);
        console.log(`[createMessage] Duration extracted: ${duration}ms for ${att.fileName}`);
        return {
          fileName: att.fileName,
          fileUrl: att.fileUrl,
          fileSize: att.fileSize,
          mimeType: att.mimeType,
          duration,
          uploadedById: userId,
        };
      })
    );
  }

  const message = await prisma.ticketMessage.create({
    data: {
      content: data.content,
      isInternal: data.isInternal || false,
      ticketId,
      authorId: userId,
      attachments: attachmentsWithDuration
        ? {
            create: attachmentsWithDuration,
          }
        : undefined,
    },
    include: {
      author: {
        select: {
          id: true,
          name: true,
          email: true,
          avatarUrl: true,
          role: true,
          createdAt: true,
        },
      },
      attachments: true,
    },
  });

  // Update ticket status based on who sent the message
  if (userRole === 'ADMIN' && ticket.status === 'WAITING_ADMIN') {
    await prisma.ticket.update({
      where: { id: ticketId },
      data: { status: 'WAITING_USER' },
    });
  } else if (userRole === 'USER' && ticket.status === 'WAITING_USER') {
    await prisma.ticket.update({
      where: { id: ticketId },
      data: { status: 'WAITING_ADMIN' },
    });
  }

  return message;
}

export async function getTicketStats(userId: string, userRole: string) {
  const where: any = userRole === 'USER' ? { createdById: userId } : {};

  const [total, open, inProgress, waitingUser, waitingAdmin, resolved, closed] = await Promise.all([
    prisma.ticket.count({ where }),
    prisma.ticket.count({ where: { ...where, status: 'OPEN' } }),
    prisma.ticket.count({ where: { ...where, status: 'IN_PROGRESS' } }),
    prisma.ticket.count({ where: { ...where, status: 'WAITING_USER' } }),
    prisma.ticket.count({ where: { ...where, status: 'WAITING_ADMIN' } }),
    prisma.ticket.count({ where: { ...where, status: 'RESOLVED' } }),
    prisma.ticket.count({ where: { ...where, status: 'CLOSED' } }),
  ]);

  return {
    total,
    open,
    inProgress,
    waitingUser,
    waitingAdmin,
    resolved,
    closed,
  };
}
