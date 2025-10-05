import { PrismaClient } from '@prisma/client';
import { hash } from '@node-rs/argon2';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // Create default admin
  const passwordHash = await hash('TCSPacePort2024!', {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

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
  console.log('🔑 Password: TCSPacePort2024!');

  // Create a manager user for testing
  const managerHash = await hash('Manager2024!', {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

  const manager = await prisma.user.upsert({
    where: { email: 'manager@tcs.com' },
    update: {},
    create: {
      email: 'manager@tcs.com',
      passwordHash: managerHash,
      name: 'Test Manager',
      role: 'MANAGER',
    },
  });

  console.log('✅ Created manager user:', manager.email);
  console.log('🔑 Password: Manager2024!');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
