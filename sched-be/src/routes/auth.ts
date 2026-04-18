import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { setCookie, deleteCookie } from 'hono/cookie';
import { LoginSchema, UserCreateSchema, PasswordChangeSchema, ProfileUpdateSchema, SwitchRoleSchema, UpdateUserRolesSchema, ApproveUserSchema } from '../types';
import * as authService from '../services/auth.service';
import * as activityLogService from '../services/activity-log.service';
import { authMiddleware, requireRole } from '../middleware/auth';
import type { AppContext } from '../lib/context';
import { prisma } from '../lib/prisma';

const app = new Hono<AppContext>();

app.post('/login', zValidator('json', LoginSchema), async (c) => {
  try {
    const data = c.req.valid('json');
    const result = await authService.login(data);
    const { user, sessionCookie } = result;
    const userAgent = c.req.header('user-agent') || '';
    const isIOS = /iPad|iPhone|iPod/.test(userAgent);
    const origin = c.req.header('origin') || '';

    setCookie(c, sessionCookie.name, sessionCookie.value, sessionCookie.attributes);

    // Debug logging
    console.log('[Login] Login successful:', {
      userId: user.id,
      cookieName: sessionCookie.name,
      cookieValue: sessionCookie.value.substring(0, 20) + '...',
      origin,
      isIOS,
      userAgent: userAgent.substring(0, 50)
    });

    // Log login activity
    await activityLogService.logActivity({
      action: 'LOGIN',
      resource: 'SESSION',
      description: `User ${user.name} logged in as ${user.role}`,
      userId: user.id,
      metadata: { activeRole: user.role },
      ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
      userAgent: c.req.header('user-agent'),
    });

    // IMPORTANT: Return cookie in body as fallback for Flutter Web
    // Some proxies (like ngrok) may strip Set-Cookie headers
    return c.json({
      user: { ...user, mustChangePassword: user.mustChangePassword },
      sessionCookie: {
        name: sessionCookie.name,
        value: sessionCookie.value
      }
    });
  } catch (error: any) {
    return c.json({ error: error.message }, 401);
  }
});

app.post('/logout', authMiddleware, async (c) => {
  try {
    const session = c.get('session');
    const user = c.get('user');
    const sessionCookie = await authService.logout(session.id);

    deleteCookie(c, sessionCookie.name, sessionCookie.attributes);

    // Log logout activity
    await activityLogService.logActivity({
      action: 'LOGOUT',
      resource: 'SESSION',
      description: `User ${user.name} logged out`,
      userId: user.id,
      ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
      userAgent: c.req.header('user-agent'),
    });

    return c.json({ success: true });
  } catch (error: any) {
    return c.json({ error: error.message }, 500);
  }
});

app.get('/me', authMiddleware, async (c) => {
  const sessionUser = c.get('user');

  // Fetch fresh user data from database including avatarUrl
  const user = await prisma.user.findUnique({
    where: { id: sessionUser.id },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      roles: true,
      isActive: true,
      avatarUrl: true,
      mustChangePassword: true,
      createdAt: true,
      updatedAt: true,
    }
  });

  if (!user) {
    return c.json({ error: 'User not found' }, 404);
  }

  return c.json({ user });
});

app.post('/users', authMiddleware, zValidator('json', UserCreateSchema), async (c) => {
  try {
    const currentUser = c.get('user');
    const data = c.req.valid('json');
    const role: 'ADMIN' | 'MANAGER' | 'USER' = data.role;

    // Only ADMIN and MANAGER can create users
    if (currentUser.role !== 'ADMIN' && currentUser.role !== 'MANAGER') {
      return c.json({ error: 'Unauthorized' }, 403);
    }

    // MANAGER can only create USER role
    if (currentUser.role === 'MANAGER' && role !== 'USER') {
      return c.json({ error: 'Managers can only create users with USER role' }, 403);
    }

    // ADMIN can create any role (ADMIN, MANAGER, USER)
    const email = `${data.nickname}@tcs.com`;
    const user = await authService.createUser(email, 'Tata@123', data.name, role);

    // Log user creation
    await activityLogService.logActivity({
      action: 'CREATE',
      resource: 'USER',
      resourceId: user.id,
      description: `${currentUser.name} created user ${user.name} (${user.role})`,
      userId: currentUser.id,
      metadata: { createdUserEmail: user.email, createdUserRole: user.role },
      ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
      userAgent: c.req.header('user-agent'),
    });

    return c.json({ user }, 201);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

app.get('/users', authMiddleware, async (c) => {
  try {
    const currentUser = c.get('user');

    // Only ADMIN and MANAGER can view users
    if (currentUser.role !== 'ADMIN' && currentUser.role !== 'MANAGER') {
      return c.json({ error: 'Unauthorized' }, 403);
    }

    const allUsers = await authService.getAllUsers();

    // ADMIN sees all users (ADMIN, MANAGER, USER)
    // MANAGER only sees USER role (cannot see other MANAGER or ADMIN accounts)
    const filteredUsers = currentUser.role === 'ADMIN'
      ? allUsers
      : allUsers.filter((u: any) => u.role === 'USER');

    return c.json(filteredUsers);
  } catch (error: any) {
    return c.json({ error: error.message }, 500);
  }
});

app.delete('/users/:id', authMiddleware, requireRole('ADMIN'), async (c) => {
  try {
    const currentUser = c.get('user');
    const id = c.req.param('id');

    // Get user info before deletion
    const users = await authService.getAllUsers();
    const deletedUser = users.find((u: any) => u.id === id);

    await authService.deleteUser(id);

    // Log user deletion
    if (deletedUser) {
      await activityLogService.logActivity({
        action: 'DELETE',
        resource: 'USER',
        resourceId: id,
        description: `${currentUser.name} deleted user ${deletedUser.name}`,
        userId: currentUser.id,
        metadata: { deletedUserEmail: deletedUser.email, deletedUserRole: deletedUser.role },
        ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
        userAgent: c.req.header('user-agent'),
      });
    }

    return c.json({ success: true });
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

app.patch('/users/:id/password', authMiddleware, requireRole('ADMIN'), async (c) => {
  try {
    const id = c.req.param('id');
    const { password } = await c.req.json();

    if (!password || password.length < 8) {
      return c.json({ error: 'Password must be at least 8 characters' }, 400);
    }

    await authService.resetUserPassword(id, password);
    return c.json({ success: true });
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// User self-service: Change own password
app.post('/me/change-password', authMiddleware, zValidator('json', PasswordChangeSchema), async (c) => {
  try {
    const user = c.get('user');
    const data = c.req.valid('json');

    await authService.changePassword(user.id, data);

    // Log password change
    await activityLogService.logActivity({
      action: 'UPDATE',
      resource: 'USER',
      resourceId: user.id,
      description: `${user.name} changed their password`,
      userId: user.id,
      ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
      userAgent: c.req.header('user-agent'),
    });

    return c.json({ success: true, message: 'Password changed successfully' });
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// User self-service: Update own profile
app.patch('/me/profile', authMiddleware, zValidator('json', ProfileUpdateSchema), async (c) => {
  try {
    const user = c.get('user');
    const data = c.req.valid('json');

    const updatedUser = await authService.updateProfile(user.id, data);

    // Log profile update
    await activityLogService.logActivity({
      action: 'UPDATE',
      resource: 'USER',
      resourceId: user.id,
      description: `${user.name} updated their profile`,
      userId: user.id,
      metadata: data,
      ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
      userAgent: c.req.header('user-agent'),
    });

    return c.json({ user: updatedUser });
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Switch active role
app.post('/switch-role', authMiddleware, zValidator('json', SwitchRoleSchema), async (c) => {
  try {
    const user = c.get('user');
    const { role } = c.req.valid('json');

    const updatedUser = await authService.switchRole(user.id, role);

    await activityLogService.logActivity({
      action: 'UPDATE',
      resource: 'USER',
      resourceId: user.id,
      description: `${user.name} switched active role to ${role}`,
      userId: user.id,
      metadata: { newRole: role },
      ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
      userAgent: c.req.header('user-agent'),
    });

    return c.json({ user: updatedUser });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 400);
  }
});

// Admin: Update user roles
app.post('/users/:id/roles', authMiddleware, requireRole('ADMIN'), zValidator('json', UpdateUserRolesSchema), async (c) => {
  try {
    const currentUser = c.get('user');
    const id = c.req.param('id');
    const { roles } = c.req.valid('json');

    const targetUser = await prisma.user.findUnique({ where: { id } });
    if (!targetUser) {
      return c.json({ error: 'User not found' }, 404);
    }

    const activeRole = roles.includes(targetUser.role) ? targetUser.role : roles[0];

    const updatedUser = await prisma.user.update({
      where: { id },
      data: { roles, role: activeRole },
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

    await activityLogService.logActivity({
      action: 'UPDATE',
      resource: 'USER',
      resourceId: id,
      description: `${currentUser.name} updated roles for ${updatedUser.name} to [${roles.join(', ')}]`,
      userId: currentUser.id,
      metadata: { targetUserId: id, newRoles: roles },
      ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
      userAgent: c.req.header('user-agent'),
    });

    return c.json({ user: updatedUser });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 400);
  }
});

// Get pending users (waiting for approval)
app.get('/users/pending', authMiddleware, async (c) => {
  try {
    const currentUser = c.get('user');

    if (currentUser.role !== 'ADMIN' && currentUser.role !== 'MANAGER') {
      return c.json({ error: 'Unauthorized' }, 403);
    }

    const pendingUsers = await authService.getPendingUsers();
    return c.json(pendingUsers);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 500);
  }
});

// Approve a pending user
app.post('/users/:id/approve', authMiddleware, zValidator('json', ApproveUserSchema), async (c) => {
  try {
    const currentUser = c.get('user');
    const id = c.req.param('id');
    const { roles } = c.req.valid('json');

    if (currentUser.role !== 'ADMIN' && currentUser.role !== 'MANAGER') {
      return c.json({ error: 'Unauthorized' }, 403);
    }

    // MANAGER cannot assign ADMIN role
    if (currentUser.role === 'MANAGER' && roles.includes('ADMIN')) {
      return c.json({ error: 'Managers cannot assign ADMIN role' }, 403);
    }

    const updatedUser = await authService.approveUser(id, roles);

    await activityLogService.logActivity({
      action: 'UPDATE',
      resource: 'USER',
      resourceId: id,
      description: `${currentUser.name} approved user ${updatedUser.name} with roles [${roles.join(', ')}]`,
      userId: currentUser.id,
      metadata: { approvedUserId: id, assignedRoles: roles },
      ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
      userAgent: c.req.header('user-agent'),
    });

    return c.json({ user: updatedUser });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return c.json({ error: message }, 400);
  }
});

export default app;
