import { Context, Next } from 'hono';
import { lucia } from '../lib/lucia';
import { getCookie } from 'hono/cookie';
import type { AppContext } from '../lib/context';

export async function authMiddleware(c: Context<AppContext>, next: Next) {
  const sessionId = getCookie(c, lucia.sessionCookieName);

  if (!sessionId) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const { session, user } = await lucia.validateSession(sessionId);

  if (!session) {
    return c.json({ error: 'Invalid session' }, 401);
  }

  if (!user.isActive) {
    return c.json({ error: 'User is inactive' }, 403);
  }

  c.set('user', user);
  c.set('session', session);

  await next();
}

export function requireRole(...roles: Array<'ADMIN' | 'MANAGER'>) {
  return async (c: Context<AppContext>, next: Next) => {
    const user = c.get('user');

    if (!user || !roles.includes(user.role as 'ADMIN' | 'MANAGER')) {
      return c.json({ error: 'Forbidden' }, 403);
    }

    await next();
  };
}
