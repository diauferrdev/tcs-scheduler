import { prisma } from '../lib/prisma';
import { generateUniqueShortToken } from '../utils/token';
import type { InvitationCreateInput } from '../types';

export async function createInvitation(data: InvitationCreateInput, createdById: string) {
  const expiresInDays = data.expiresInDays || 7;
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + expiresInDays);

  // Generate unique short token
  const token = await generateUniqueShortToken(async (t) => {
    const existing = await prisma.invitation.findUnique({
      where: { token: t },
    });
    return existing !== null;
  });

  const invitation = await prisma.invitation.create({
    data: {
      token,
      email: data.email,
      expiresAt,
      createdById,
    },
  });

  const link = `${process.env.FRONTEND_URL}/book/${invitation.token}`;

  return {
    ...invitation,
    link,
  };
}

export async function validateToken(token: string) {
  const invitation = await prisma.invitation.findUnique({
    where: { token },
  });

  if (!invitation) {
    return {
      valid: false,
      expired: false,
      used: false,
      invitation: null,
    };
  }

  const now = new Date();
  const expired = invitation.expiresAt < now;
  const used = invitation.usedAt !== null;

  return {
    valid: !expired && !used && invitation.isActive,
    expired,
    used,
    invitation: invitation.isActive ? invitation : null,
  };
}

export async function getInvitations(createdById?: string, limit: number = 50, offset: number = 0) {
  const where: any = {};

  if (createdById) {
    where.createdById = createdById;
  }

  const [invitations, total] = await Promise.all([
    prisma.invitation.findMany({
      where,
      include: {
        createdBy: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        booking: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: limit,
      skip: offset,
    }),
    prisma.invitation.count({ where }),
  ]);

  return {
    invitations,
    total,
  };
}

export async function markInvitationUsed(token: string) {
  const invitation = await prisma.invitation.update({
    where: { token },
    data: {
      usedAt: new Date(),
      isActive: false,
    },
  });

  return invitation;
}
