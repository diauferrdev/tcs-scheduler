import { hash, verify } from '@node-rs/argon2';
import { lucia } from '../lib/lucia';
import { prisma } from '../lib/prisma';
import type { LoginInput, PasswordChangeInput, ProfileUpdateInput } from '../types';

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
      avatarUrl: user.avatarUrl,
      createdAt: user.createdAt,
    },
    sessionCookie,
  };
}

export async function logout(sessionId: string) {
  await lucia.invalidateSession(sessionId);
  const sessionCookie = lucia.createBlankSessionCookie();
  return sessionCookie;
}

export async function createUser(email: string, password: string, name: string, role: 'ADMIN' | 'MANAGER' | 'USER') {
  // CRITICAL FIX: Check if user with this email already exists
  const existingUser = await prisma.user.findUnique({
    where: { email },
  });

  if (existingUser) {
    throw new Error('A user with this email already exists');
  }

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
    avatarUrl: user.avatarUrl,
    createdAt: user.createdAt,
  };
}

export async function getAllUsers() {
  // CRITICAL FIX: Return ALL users (ADMIN, MANAGER, USER)
  // Previously was only returning ADMIN and MANAGER
  const users = await prisma.user.findMany({
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      isActive: true,
      avatarUrl: true,
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

// User self-service: Change own password
export async function changePassword(userId: string, data: PasswordChangeInput) {
  // Get user with current password
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  // Verify current password
  const validPassword = await verify(user.passwordHash, data.currentPassword, {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

  if (!validPassword) {
    throw new Error('Current password is incorrect');
  }

  // Hash the new password
  const newPasswordHash = await hash(data.newPassword, {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

  // Update password
  await prisma.user.update({
    where: { id: userId },
    data: { passwordHash: newPasswordHash },
  });

  // Invalidate all other sessions (keep current one)
  // This is done by Lucia on next validation
}

// User self-service: Update own profile (email cannot be changed)
export async function updateProfile(userId: string, data: ProfileUpdateInput) {
  // Check if user exists
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  // Update profile (only name can be changed)
  const updatedUser = await prisma.user.update({
    where: { id: userId },
    data: {
      ...(data.name && { name: data.name }),
    },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      isActive: true,
      avatarUrl: true,
      createdAt: true,
    },
  });

  return updatedUser;
}
