import { prisma } from './src/lib/prisma';

async function main() {
  const bookings = await prisma.booking.findMany({
    where: {
      status: { notIn: ['DRAFT', 'CANCELLED'] },
    },
    take: 3,
  });

  console.log('Sample booking fields:');
  bookings.forEach((b, i) => {
    console.log(`\nBooking ${i + 1}:`);
    console.log(JSON.stringify(b, null, 2));
  });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
