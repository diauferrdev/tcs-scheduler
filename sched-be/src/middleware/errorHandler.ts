import { Context } from 'hono';
import { ZodError } from 'zod';

export function errorHandler(err: Error, c: Context) {
  console.error('Error:', err);

  if (err instanceof ZodError) {
    return c.json(
      {
        error: 'Validation error',
        details: err.errors,
      },
      400
    );
  }

  if (err.message.includes('Unique constraint')) {
    return c.json({ error: 'Resource already exists' }, 409);
  }

  if (err.message.includes('Not found')) {
    return c.json({ error: 'Resource not found' }, 404);
  }

  return c.json({ error: 'Internal server error' }, 500);
}
