import { Lucia } from 'lucia';
import { PrismaAdapter } from '@lucia-auth/adapter-prisma';
import { prisma } from './prisma';

const adapter = new PrismaAdapter(prisma.session, prisma.user);

export const lucia = new Lucia(adapter, {
  sessionCookie: {
    attributes: {
      // Enable secure cookies for production and ngrok (https)
      secure: process.env.NODE_ENV === 'production' || process.env.FRONTEND_URL?.includes('ngrok'),
      // SameSite None is required for cross-origin cookies (ngrok)
      sameSite: process.env.FRONTEND_URL?.includes('ngrok') ? 'none' : 'lax',
    },
  },
  getUserAttributes: (attributes) => ({
    email: attributes.email,
    name: attributes.name,
    role: attributes.role,
    isActive: attributes.isActive,
  }),
});

declare module 'lucia' {
  interface Register {
    Lucia: typeof lucia;
    DatabaseUserAttributes: DatabaseUserAttributes;
  }
}

interface DatabaseUserAttributes {
  email: string;
  name: string;
  role: 'ADMIN' | 'MANAGER' | 'GUEST';
  isActive: boolean;
}
