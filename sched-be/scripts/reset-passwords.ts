#!/usr/bin/env bun
/**
 * Reset all user passwords to "Tata@123"
 * Also creates user@tcs.com with role USER if it doesn't exist
 */

import { prisma } from '../src/lib/prisma';
import { hash } from '@node-rs/argon2';

const DEFAULT_PASSWORD = 'Tata@123';

async function main() {
  console.log('🔄 Starting password reset...\n');

  const hashedPassword = await hash(DEFAULT_PASSWORD, {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

  // Get all users
  const users = await prisma.user.findMany({
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
    },
  });

  console.log(`Found ${users.length} existing users\n`);

  // Update all existing users
  for (const user of users) {
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: hashedPassword },
    });
    console.log(`✅ Updated password for: ${user.email} (${user.role})`);
  }

  // Create default users if they don't exist
  const usersToCreate = [
    { email: 'admin@tcs.com', name: 'TCS Admin', role: 'ADMIN' as const },
    { email: 'manager@tcs.com', name: 'Test Manager', role: 'MANAGER' as const },
    { email: 'user@tcs.com', name: 'Test User', role: 'USER' as const },
  ];

  console.log('\n📝 Creating default users...');
  for (const userData of usersToCreate) {
    const userExists = users.find(u => u.email === userData.email);

    if (!userExists) {
      await prisma.user.create({
        data: {
          email: userData.email,
          name: userData.name,
          role: userData.role,
          passwordHash: hashedPassword,
          isActive: true,
        },
      });
      console.log(`✅ Created ${userData.email} with role ${userData.role}`);
    } else {
      console.log(`✅ ${userData.email} already exists`);
    }
  }

  console.log('\n✨ All passwords have been reset to: Tata@123');
  console.log('\n📋 Current users:');

  const allUsers = await prisma.user.findMany({
    select: {
      email: true,
      name: true,
      role: true,
      isActive: true,
    },
    orderBy: {
      role: 'asc',
    },
  });

  for (const user of allUsers) {
    console.log(`  - ${user.email} | ${user.name} | ${user.role} | ${user.isActive ? 'Active' : 'Inactive'}`);
  }
}

main()
  .then(() => {
    console.log('\n✅ Done!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
