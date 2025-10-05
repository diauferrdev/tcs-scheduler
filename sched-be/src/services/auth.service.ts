import { hash, verify } from '@node-rs/argon2';
import { lucia } from '../lib/lucia';
import { prisma } from '../lib/prisma';
import type { LoginInput } from '../types';

export async function login(data: LoginInput) {
  const user = await prisma.user.findUnique({
    where: { email: data.email },
  });

  if (!user) {
    throw new Error('Invalid credentials');
  }

  if (!user.isActive) {
    throw new Error('User is inactive');
  }

  const validPassword = await verify(user.passwordHash, data.password, {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

  if (!validPassword) {
    throw new Error('Invalid credentials');
  }

  const session = await lucia.createSession(user.id, {});
  const sessionCookie = lucia.createSessionCookie(session.id);

  return {
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
    },
    sessionCookie,
  };
}

export async function logout(sessionId: string) {
  await lucia.invalidateSession(sessionId);
  const sessionCookie = lucia.createBlankSessionCookie();
  return sessionCookie;
}

export async function createUser(email: string, password: string, name: string, role: 'ADMIN' | 'MANAGER') {
  const passwordHash = await hash(password, {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      name,
      role,
    },
  });

  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
  };
}

export async function getAllUsers() {
  const users = await prisma.user.findMany({
    where: {
      role: {
        in: ['ADMIN', 'MANAGER'],
      },
    },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      isActive: true,
      createdAt: true,
    },
    orderBy: {
      createdAt: 'desc',
    },
  });

  return users;
}

export async function deleteUser(userId: string) {
  // Check if user exists
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  // Delete all sessions first
  await prisma.session.deleteMany({
    where: { userId },
  });

  // Delete the user
  await prisma.user.delete({
    where: { id: userId },
  });
}

export async function resetUserPassword(userId: string, newPassword: string) {
  // Check if user exists
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  // Hash the new password
  const passwordHash = await hash(newPassword, {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

  // Update the password and invalidate all sessions
  await prisma.user.update({
    where: { id: userId },
    data: { passwordHash },
  });

  // Invalidate all sessions for this user
  await prisma.session.deleteMany({
    where: { userId },
  });
}
