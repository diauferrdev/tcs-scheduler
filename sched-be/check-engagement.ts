import { prisma } from './src/lib/prisma';

async function main() {
  const bookings = await prisma.booking.findMany({
    where: {
      status: { notIn: ['DRAFT', 'CANCELLED'] },
    },
    select: {
      id: true,
      engagementType: true,
      status: true,
    },
  });

  console.log('Total bookings:', bookings.length);
  console.log('\nEngagement Type Distribution:');

  const dist = {
    INTERNAL: bookings.filter((b: any) => b.engagementType === 'INTERNAL').length,
    EXTERNAL: bookings.filter((b: any) => b.engagementType === 'EXTERNAL').length,
    PARTNER: bookings.filter((b: any) => b.engagementType === 'PARTNER').length,
    NULL: bookings.filter((b: any) => !b.engagementType).length,
  };

  console.log(JSON.stringify(dist, null, 2));

  console.log('\nSample bookings (first 5):');
  bookings.slice(0, 5).forEach((b: any) => {
    console.log('- ID: ' + b.id.substring(0, 8) + ', Type: ' + (b.engagementType || 'NULL') + ', Status: ' + b.status);
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
