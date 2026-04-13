import { Lucia } from 'lucia';
import { PrismaAdapter } from '@lucia-auth/adapter-prisma';
import { prisma } from './prisma';

const adapter = new PrismaAdapter(prisma.session, prisma.user);

const isNgrok = process.env.FRONTEND_URL?.includes('ngrok') || false;
const isProduction = process.env.NODE_ENV === 'production';

export const lucia = new Lucia(adapter, {
  sessionCookie: {
    attributes: {
      // Always secure in production
      secure: isProduction,
      sameSite: isProduction ? 'none' : 'lax',
    },
  },
  getUserAttributes: (attributes) => ({
    email: attributes.email,
    name: attributes.name,
    role: attributes.role,
    roles: attributes.roles,
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
  role: 'ADMIN' | 'MANAGER' | 'USER';
  roles: Array<'ADMIN' | 'MANAGER' | 'USER'>;
  isActive: boolean;
}
