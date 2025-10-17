import type { Session, User } from 'lucia';

// Define context variables for Hono
export type AppContext = {
  Variables: {
    user: User;
    session: Session;
  };
};
