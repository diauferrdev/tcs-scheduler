/**
 * Generate a short alphanumeric token (5 characters)
 * Format: [a-zA-Z0-9]{5}
 * Example: aZ4pQ, 7bYxR, Q1vTn
 */
export function generateShortToken(): string {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let token = '';

  for (let i = 0; i < 5; i++) {
    const randomIndex = Math.floor(Math.random() * chars.length);
    token += chars[randomIndex];
  }

  return token;
}

/**
 * Generate a unique short token by checking against existing tokens
 */
export async function generateUniqueShortToken(
  checkExists: (token: string) => Promise<boolean>
): Promise<string> {
  let token: string;
  let attempts = 0;
  const maxAttempts = 100;

  do {
    token = generateShortToken();
    attempts++;

    if (attempts >= maxAttempts) {
      throw new Error('Failed to generate unique token after maximum attempts');
    }
  } while (await checkExists(token));

  return token;
}
