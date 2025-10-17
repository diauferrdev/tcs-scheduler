import { PrismaClient } from '@prisma/client';
import { hash } from '@node-rs/argon2';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // Standard password for all test users
  const passwordHash = await hash('Tata@123', {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

  // Create default admin
  const admin = await prisma.user.upsert({
    where: { email: 'admin@tcs.com' },
    update: {},
    create: {
      email: 'admin@tcs.com',
      passwordHash,
      name: 'TCS Admin',
      role: 'ADMIN',
    },
  });

  console.log('✅ Created admin user:', admin.email);
  console.log('🔑 Password: Tata@123');

  // Create a manager user for testing
  const manager = await prisma.user.upsert({
    where: { email: 'manager@tcs.com' },
    update: {},
    create: {
      email: 'manager@tcs.com',
      passwordHash,
      name: 'Test Manager',
      role: 'MANAGER',
    },
  });

  console.log('✅ Created manager user:', manager.email);
  console.log('🔑 Password: Tata@123');

  // Create a regular user for testing
  const user = await prisma.user.upsert({
    where: { email: 'user@tcs.com' },
    update: {},
    create: {
      email: 'user@tcs.com',
      passwordHash,
      name: 'Test User',
      role: 'USER',
    },
  });

  console.log('✅ Created user:', user.email);
  console.log('🔑 Password: Tata@123');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
