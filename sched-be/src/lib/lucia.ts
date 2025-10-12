import { Lucia } from 'lucia';
import { PrismaAdapter } from '@lucia-auth/adapter-prisma';
import { prisma } from './prisma';

const adapter = new PrismaAdapter(prisma.session, prisma.user);

const isNgrok = process.env.FRONTEND_URL?.includes('ngrok') || false;
const isProduction = process.env.NODE_ENV === 'production';

export const lucia = new Lucia(adapter, {
  sessionCookie: {
    attributes: {
      // Secure must be true when sameSite is 'none' (required by iOS Safari)
      // Also enable for production environments
      secure: isNgrok || isProduction,
      // SameSite 'none' required for cross-origin cookies (ngrok)
      // iOS Safari strictly enforces secure=true when sameSite='none'
      sameSite: isNgrok ? 'none' : 'lax',
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
