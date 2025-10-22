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

  // Define all users to be created
  const users = [
    // ADMINS
    { email: 'admin@tcs.com', name: 'TCS Admin', role: 'ADMIN' as const },
    { email: 'diego@tcs.com', name: 'Diego Admin', role: 'ADMIN' as const },
    { email: 'abinadmin@tcs.com', name: 'Abin Admin', role: 'ADMIN' as const },

    // MANAGERS
    { email: 'manager@tcs.com', name: 'Test Manager', role: 'MANAGER' as const },
    { email: 'orestes@tcs.com', name: 'Orestes Manager', role: 'MANAGER' as const },
    { email: 'ashok@tcs.com', name: 'Ashok Manager', role: 'MANAGER' as const },
    { email: 'abinmanager@tcs.com', name: 'Abin Manager', role: 'MANAGER' as const },
    { email: 'tulio@tcs.com', name: 'Tulio Manager', role: 'MANAGER' as const },
    { email: 'danielle@tcs.com', name: 'Danielle Manager', role: 'MANAGER' as const },

    // USERS
    { email: 'user@tcs.com', name: 'Test User', role: 'USER' as const },
    { email: 'abinuser@tcs.com', name: 'Abin User', role: 'USER' as const },
    { email: 'diegouser@tcs.com', name: 'Diego User', role: 'USER' as const },
  ];

  // Create all users
  console.log(`Creating ${users.length} users...`);

  for (const userData of users) {
    const user = await prisma.user.upsert({
      where: { email: userData.email },
      update: {},
      create: {
        email: userData.email,
        passwordHash,
        name: userData.name,
        role: userData.role,
      },
    });
    console.log(`✅ Created ${userData.role.toLowerCase()}: ${user.email}`);
  }

  console.log('\n🔑 All users password: Tata@123');
  console.log('✅ Database seeded successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
