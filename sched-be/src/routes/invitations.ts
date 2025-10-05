import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { InvitationCreateSchema } from '../types';
import * as invitationService from '../services/invitation.service';
import { authMiddleware, requireRole } from '../middleware/auth';
import type { AppContext } from '../lib/context';

const app = new Hono<AppContext>();

// Create invitation (ADMIN/MANAGER only)
app.post('/', authMiddleware, requireRole('ADMIN', 'MANAGER'), zValidator('json', InvitationCreateSchema), async (c) => {
  try {
    const user = c.get('user');
    const data = c.req.valid('json');
    const invitation = await invitationService.createInvitation(data, user.id);
    return c.json(invitation, 201);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Validate token (public)
app.get('/:token/validate', async (c) => {
  try {
    const token = c.req.param('token');
    const validation = await invitationService.validateToken(token);
    return c.json(validation);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Get all invitations (authenticated)
app.get('/', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!) : 50;
    const offset = c.req.query('offset') ? parseInt(c.req.query('offset')!) : 0;
    const createdById = user.role === 'ADMIN' ? undefined : user.id;
    const result = await invitationService.getInvitations(createdById, limit, offset);
    return c.json(result);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

export default app;
