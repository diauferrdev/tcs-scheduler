import type { Context, Next } from 'hono';
import type { AppContext } from '../lib/context';

// In-memory, per-process rate limiter.
// NOTE: This state lives in the Node/Bun process memory only. It works correctly
// for a single PM2 instance (current deployment), but if the app is ever scaled
// horizontally (multiple instances/replicas behind a load balancer), each instance
// will track its own counters independently and this will no longer enforce a
// global limit. In that case, move this to a shared store (e.g. Redis).

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

interface RateLimitOptions {
  windowMs: number;
  max: number;
  keyPrefix?: string;
}

const store = new Map<string, RateLimitEntry>();

// Avoid unbounded memory growth from expired entries without paying sweep cost
// on every single request.
const SWEEP_THRESHOLD = 5000;

function sweepExpired(now: number) {
  if (store.size <= SWEEP_THRESHOLD) return;

  for (const [key, entry] of store) {
    if (now > entry.resetAt) {
      store.delete(key);
    }
  }
}

function getClientIp(c: Context<AppContext>): string {
  const forwardedFor = c.req.header('x-forwarded-for');
  if (forwardedFor) {
    const first = forwardedFor.split(',')[0]?.trim();
    if (first) return first;
  }
  return c.req.header('x-real-ip') || 'unknown';
}

export function rateLimit(opts: RateLimitOptions) {
  const { windowMs, max, keyPrefix = 'rl' } = opts;

  return async (c: Context<AppContext>, next: Next) => {
    const now = Date.now();

    sweepExpired(now);

    const clientIp = getClientIp(c);
    const key = `${keyPrefix}:${clientIp}`;

    let entry = store.get(key);

    if (!entry || now > entry.resetAt) {
      entry = { count: 0, resetAt: now + windowMs };
      store.set(key, entry);
    }

    entry.count += 1;

    if (entry.count > max) {
      const retryAfterSeconds = Math.max(0, Math.ceil((entry.resetAt - now) / 1000));
      c.header('Retry-After', String(retryAfterSeconds));
      return c.json({ error: 'Too many requests, please try again later.' }, 429);
    }

    await next();
  };
}
