import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { setCookie, deleteCookie } from 'hono/cookie';
import { LoginSchema, UserCreateSchema, PasswordChangeSchema, ProfileUpdateSchema } from '../types';
import * as authService from '../services/auth.service';
import * as activityLogService from '../services/activity-log.service';
import { authMiddleware, requireRole } from '../middleware/auth';
import type { AppContext } from '../lib/context';

const app = new Hono<AppContext>();

app.post('/login', zValidator('json', LoginSchema), async (c) => {
  try {
    const data = c.req.valid('json');
    const { user, sessionCookie } = await authService.login(data);
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
      description: `User ${user.name} logged in`,
      userId: user.id,
      ipAddress: c.req.header('x-forwarded-for') || c.req.header('x-real-ip'),
      userAgent: c.req.header('user-agent'),
    });

    // IMPORTANT: Return cookie in body as fallback for Flutter Web
    // Some proxies (like ngrok) may strip Set-Cookie headers
    return c.json({
      user,
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
  const user = c.get('user');
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
    const user = await authService.createUser(data.email, data.password, data.name, role);

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

    // Both ADMIN and MANAGER see all users (ADMIN, MANAGER, USER)
    // ADMIN can create any role, MANAGER can only create USER role
    return c.json(allUsers);
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

export default app;
