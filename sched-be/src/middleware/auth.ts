import { Context, Next } from 'hono';
import { lucia } from '../lib/lucia';
import { getCookie } from 'hono/cookie';
import type { AppContext } from '../lib/context';

export async function authMiddleware(c: Context<AppContext>, next: Next) {
  const sessionId = getCookie(c, lucia.sessionCookieName);
  const userAgent = c.req.header('user-agent') || '';
  const isIOS = /iPad|iPhone|iPod/.test(userAgent);
  const allCookies = c.req.header('cookie');

  // Enhanced debug logging
  console.log('[Auth Middleware] Request:', {
    path: c.req.path,
    method: c.req.method,
    cookieName: lucia.sessionCookieName,
    hasSessionId: !!sessionId,
    sessionIdLength: sessionId?.length || 0,
    sessionIdPreview: sessionId ? `${sessionId.substring(0, 20)}...` : 'none',
    allCookies: allCookies || 'none',
    origin: c.req.header('origin'),
    isIOS,
  });

  if (!sessionId) {
    console.log('[Auth Middleware] ❌ No session cookie found', {
      path: c.req.path,
      expectedCookieName: lucia.sessionCookieName,
      receivedCookies: allCookies,
    });
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const { session, user } = await lucia.validateSession(sessionId);

  if (!session) {
    console.log('[Auth Middleware] ❌ Invalid session', {
      path: c.req.path,
      sessionIdLength: sessionId.length,
      sessionIdPreview: sessionId.substring(0, 20) + '...',
    });
    return c.json({ error: 'Invalid session' }, 401);
  }

  if (!user.isActive) {
    console.log('[Auth Middleware] ❌ User is inactive', {
      userId: user.id,
      email: user.email,
    });
    return c.json({ error: 'User is inactive' }, 403);
  }

  console.log('[Auth Middleware] ✅ Authorized:', {
    userId: user.id,
    email: user.email,
    role: user.role,
    path: c.req.path,
  });

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
