import { Context, Next } from 'hono';
import { lucia } from '../lib/lucia';
import { getCookie } from 'hono/cookie';
import type { AppContext } from '../lib/context';

// Never log session IDs, cookies, or tokens — they grant full account access.
// Any diagnostic logging here must stay non-sensitive and out of production.
const isDev = process.env.NODE_ENV !== 'production';

export async function authMiddleware(c: Context<AppContext>, next: Next) {
  const sessionId = getCookie(c, lucia.sessionCookieName);

  if (!sessionId) {
    if (isDev) console.log('[Auth] No session cookie:', c.req.method, c.req.path);
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const { session, user } = await lucia.validateSession(sessionId);

  if (!session) {
    if (isDev) console.log('[Auth] Invalid session:', c.req.method, c.req.path);
    return c.json({ error: 'Invalid session' }, 401);
  }

  if (!user.isActive) {
    if (isDev) console.log('[Auth] Inactive user:', user.id);
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
