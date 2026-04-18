import { hash, verify } from '@node-rs/argon2';
import { lucia } from '../lib/lucia';
import { prisma } from '../lib/prisma';
import type { LoginInput, PasswordChangeInput, ProfileUpdateInput } from '../types';

const DEFAULT_PASSWORD = 'Tata@123';

export async function login(data: LoginInput) {
  const email = data.email.includes('@') ? data.email : `${data.email}@tcs.com`;

  let user = await prisma.user.findUnique({
    where: { email },
  });

  // Auto-register: if user doesn't exist and password is the default, create account
  if (!user) {
    if (data.password !== DEFAULT_PASSWORD) {
      throw new Error('Invalid credentials');
    }

    // Derive display name from email: diego.ferreira@tcs.com → Diego Ferreira
    const namePart = email.split('@')[0];
    const displayName = namePart
      .split('.')
      .map((part: string) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
      .join(' ');

    const passwordHash = await hash(DEFAULT_PASSWORD, {
      memoryCost: 19456,
      timeCost: 2,
      outputLen: 32,
      parallelism: 1,
    });

    user = await prisma.user.create({
      data: {
        email,
        name: displayName,
        passwordHash,
        role: 'USER',
        roles: ['USER'],
        isActive: false,
        mustChangePassword: true,
      },
    });

    console.log(`[Auth] Auto-registered new user: ${email} (${displayName})`);
    throw new Error('Account created! Your account is pending approval by an administrator.');
  }

  if (!user.isActive) {
    throw new Error('Your account is still pending approval by an administrator.');
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
      roles: user.roles,
      avatarUrl: user.avatarUrl,
      mustChangePassword: user.mustChangePassword,
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
      roles: [role],
    },
  });

  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    roles: user.roles,
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
      roles: true,
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

export async function switchRole(userId: string, newRole: 'ADMIN' | 'MANAGER' | 'USER') {
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  if (!user.roles.includes(newRole)) {
    throw new Error('User does not have access to this role');
  }

  const updatedUser = await prisma.user.update({
    where: { id: userId },
    data: { role: newRole },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      roles: true,
      isActive: true,
      avatarUrl: true,
      createdAt: true,
    },
  });

  return updatedUser;
}

export async function addRole(userId: string, role: 'ADMIN' | 'MANAGER' | 'USER') {
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  if (user.roles.includes(role)) {
    return user;
  }

  const updatedUser = await prisma.user.update({
    where: { id: userId },
    data: { roles: { push: role } },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      roles: true,
      isActive: true,
      avatarUrl: true,
      createdAt: true,
    },
  });

  return updatedUser;
}

export async function removeRole(userId: string, role: 'ADMIN' | 'MANAGER' | 'USER') {
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  const newRoles = user.roles.filter((r) => r !== role);
  if (newRoles.length === 0) {
    throw new Error('Cannot remove the last role');
  }

  const activeRole = user.role === role ? newRoles[0] : user.role;

  const updatedUser = await prisma.user.update({
    where: { id: userId },
    data: { roles: newRoles, role: activeRole },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      roles: true,
      isActive: true,
      avatarUrl: true,
      createdAt: true,
    },
  });

  return updatedUser;
}

export async function getPendingUsers() {
  const users = await prisma.user.findMany({
    where: { isActive: false },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      roles: true,
      isActive: true,
      avatarUrl: true,
      createdAt: true,
    },
    orderBy: { createdAt: 'desc' },
  });

  return users;
}

export async function approveUser(userId: string, roles: Array<'ADMIN' | 'MANAGER' | 'USER'>) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new Error('User not found');
  }

  if (user.isActive) {
    throw new Error('User is already active');
  }

  const roleHierarchy: Record<string, number> = { ADMIN: 3, MANAGER: 2, USER: 1 };
  const highestRole = roles.sort((a, b) => roleHierarchy[b] - roleHierarchy[a])[0];

  const updatedUser = await prisma.user.update({
    where: { id: userId },
    data: {
      isActive: true,
      roles,
      role: highestRole,
    },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      roles: true,
      isActive: true,
      avatarUrl: true,
      createdAt: true,
    },
  });

  return updatedUser;
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

  // Update password and clear mustChangePassword flag
  await prisma.user.update({
    where: { id: userId },
    data: { passwordHash: newPasswordHash, mustChangePassword: false },
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
      roles: true,
      isActive: true,
      avatarUrl: true,
      createdAt: true,
    },
  });

  return updatedUser;
}
