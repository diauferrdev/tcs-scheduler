import { PrismaClient } from '@prisma/client';
import { hash } from '@node-rs/argon2';

const prisma = new PrismaClient();

async function main() {
  try {
    console.log('Creating test user...');

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email: 'user@tcs.com' },
    });

    if (existingUser) {
      console.log('✅ User user@tcs.com already exists');
      console.log(`   ID: ${existingUser.id}`);
      console.log(`   Name: ${existingUser.name}`);
      console.log(`   Role: ${existingUser.role}`);
      return;
    }

    // Hash password using same config as auth.service.ts
    const passwordHash = await hash('Tata@1234', {
      memoryCost: 19456,
      timeCost: 2,
      outputLen: 32,
      parallelism: 1,
    });

    // Create user
    const user = await prisma.user.create({
      data: {
        email: 'user@tcs.com',
        passwordHash,
        name: 'Test User',
        role: 'USER',
        isActive: true,
      },
    });

    console.log('✅ Test user created successfully!');
    console.log(`   Email: ${user.email}`);
    console.log(`   Password: Tata@1234`);
    console.log(`   Role: ${user.role}`);
    console.log(`   ID: ${user.id}`);
  } catch (error) {
    console.error('❌ Error creating test user:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

main();
