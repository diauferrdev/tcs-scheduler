import { Context } from 'hono';
import { ZodError } from 'zod';

interface KnownError {
  status: 401 | 403 | 404 | 409;
  error: string;
}

/**
 * Curated, low-cardinality mapping from known business-error messages to an
 * HTTP status + a safe, generic client-facing message. Matching is
 * case-insensitive on substrings so services can keep throwing plain
 * `Error('Ticket not found')`-style messages. Anything that doesn't match
 * one of these patterns is treated as unexpected and its real message/stack
 * is never sent to the client (see catch-all below).
 */
function mapKnownError(message: string): KnownError | null {
  const lower = message.toLowerCase();

  if (lower.includes('unique constraint')) {
    return { status: 409, error: 'Resource already exists' };
  }

  if (lower.includes('not found')) {
    return { status: 404, error: 'Resource not found' };
  }

  if (lower.includes('unauthorized')) {
    return { status: 401, error: 'Unauthorized' };
  }

  if (lower.includes('forbidden') || lower.includes('access denied')) {
    return { status: 403, error: 'Forbidden' };
  }

  return null;
}

export function errorHandler(err: Error, c: Context) {
  if (err instanceof ZodError) {
    if (process.env.NODE_ENV !== 'production') {
      console.error('[ErrorHandler] Validation error:', err.errors);
    }

    return c.json(
      {
        error: 'Validation failed',
        // Curated details only — no internal Zod metadata (codes, expected/
        // received types, etc.) reaches the client.
        details: err.errors.map((e) => ({
          path: e.path.join('.'),
          message: e.message,
        })),
      },
      400
    );
  }

  const known = mapKnownError(err.message);
  if (known) {
    if (process.env.NODE_ENV !== 'production') {
      console.error(`[ErrorHandler] ${known.status}:`, err.message);
    }
    return c.json({ error: known.error }, known.status);
  }

  // Unexpected error (Prisma internals, programming bugs, etc). Never leak
  // err.message or stack to the client — always log the real error
  // server-side so it stays debuggable in production.
  console.error('[ErrorHandler] Unexpected error:', err);

  return c.json({ error: 'Internal server error' }, 500);
}
