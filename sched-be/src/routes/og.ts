import { Hono } from 'hono';
import { prisma } from '../lib/prisma';
import { format } from 'date-fns';

const app = new Hono();

/**
 * GET /api/og/attendee/:attendeeId
 * Generate Open Graph image for attendee badge
 * Returns SVG that can be used as social media preview
 */
app.get('/attendee/:attendeeId', async (c) => {
  try {
    const { attendeeId } = c.req.param();

    // Get attendee data
    const attendee = await prisma.attendee.findUnique({
      where: { id: attendeeId },
      include: {
        booking: true,
      },
    });

    if (!attendee) {
      return c.json({ error: 'Attendee not found' }, 404);
    }

    const booking = attendee.booking;
    const visitDate = format(new Date(booking.date), 'MMMM d, yyyy');
    const visitTime = booking.duration === 'SIX_HOURS'
      ? 'Full Day (09:00-17:00)'
      : booking.startTime === '09:00'
        ? 'Morning (09:00-12:00)'
        : 'Afternoon (14:00-17:00)';

    // Generate SVG image
    const svg = `
      <svg width="1200" height="630" viewBox="0 0 1200 630" xmlns="http://www.w3.org/2000/svg">
        <!-- Background -->
        <rect width="1200" height="630" fill="#000000"/>

        <!-- Gradient overlay -->
        <defs>
          <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#1a1a1a;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#000000;stop-opacity:1" />
          </linearGradient>
        </defs>
        <rect width="1200" height="630" fill="url(#grad1)"/>

        <!-- Decorative lines -->
        <line x1="0" y1="100" x2="1200" y2="100" stroke="#333333" stroke-width="2" opacity="0.5"/>
        <line x1="0" y1="530" x2="1200" y2="530" stroke="#333333" stroke-width="2" opacity="0.5"/>

        <!-- Logo text -->
        <text x="80" y="80" font-family="Arial, sans-serif" font-size="42" font-weight="bold" fill="#FFFFFF">
          PACEPORT
        </text>
        <text x="80" y="110" font-family="Arial, sans-serif" font-size="18" fill="#999999" letter-spacing="3">
          ACCESS BADGE
        </text>

        <!-- Main content card -->
        <rect x="80" y="160" width="1040" height="320" rx="16" fill="#1a1a1a" stroke="#FFFFFF" stroke-width="3"/>

        <!-- Attendee name -->
        <text x="120" y="240" font-family="Arial, sans-serif" font-size="52" font-weight="bold" fill="#FFFFFF">
          ${attendee.name}
        </text>

        <!-- Position and Company -->
        <text x="120" y="290" font-family="Arial, sans-serif" font-size="24" fill="#CCCCCC">
          ${attendee.position || 'Visitor'}
        </text>
        <text x="120" y="325" font-family="Arial, sans-serif" font-size="24" fill="#999999">
          ${booking.companyName}
        </text>

        <!-- Visit details -->
        <text x="120" y="390" font-family="Arial, sans-serif" font-size="20" fill="#999999">
          📅 ${visitDate}
        </text>
        <text x="120" y="430" font-family="Arial, sans-serif" font-size="20" fill="#999999">
          🕐 ${visitTime}
        </text>

        <!-- QR Code placeholder (visual representation) -->
        <rect x="900" y="200" width="180" height="180" rx="8" fill="#FFFFFF"/>
        <text x="990" y="300" font-family="Arial, sans-serif" font-size="14" fill="#000000" text-anchor="middle">
          QR CODE
        </text>

        <!-- Footer -->
        <text x="600" y="580" font-family="Arial, sans-serif" font-size="16" fill="#666666" text-anchor="middle">
          Authorized Access • PacePort São Paulo
        </text>
      </svg>
    `;

    c.header('Content-Type', 'image/svg+xml');
    c.header('Cache-Control', 'public, max-age=86400'); // Cache for 24 hours
    return c.body(svg);
  } catch (error) {
    console.error('Error generating OG image:', error);
    return c.json({ error: 'Failed to generate image' }, 500);
  }
});

/**
 * GET /api/og/booking/:bookingId
 * Generate Open Graph image for booking
 */
app.get('/booking/:bookingId', async (c) => {
  try {
    const { bookingId } = c.req.param();

    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        attendees: true,
      },
    });

    if (!booking) {
      return c.json({ error: 'Booking not found' }, 404);
    }

    const visitDate = format(new Date(booking.date), 'MMMM d, yyyy');
    const attendeeCount = booking.attendees?.length || 0;

    const svg = `
      <svg width="1200" height="630" viewBox="0 0 1200 630" xmlns="http://www.w3.org/2000/svg">
        <rect width="1200" height="630" fill="#000000"/>
        <defs>
          <linearGradient id="grad2" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#1a1a1a;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#000000;stop-opacity:1" />
          </linearGradient>
        </defs>
        <rect width="1200" height="630" fill="url(#grad2)"/>

        <text x="80" y="80" font-family="Arial, sans-serif" font-size="42" font-weight="bold" fill="#FFFFFF">
          PACEPORT
        </text>
        <text x="80" y="110" font-family="Arial, sans-serif" font-size="18" fill="#999999" letter-spacing="3">
          VISIT BOOKING
        </text>

        <rect x="80" y="160" width="1040" height="320" rx="16" fill="#1a1a1a" stroke="#FFFFFF" stroke-width="3"/>

        <text x="120" y="240" font-family="Arial, sans-serif" font-size="48" font-weight="bold" fill="#FFFFFF">
          ${booking.companyName}
        </text>

        <text x="120" y="300" font-family="Arial, sans-serif" font-size="28" fill="#CCCCCC">
          📅 ${visitDate}
        </text>

        <text x="120" y="360" font-family="Arial, sans-serif" font-size="24" fill="#999999">
          👥 ${attendeeCount} ${attendeeCount === 1 ? 'Attendee' : 'Attendees'}
        </text>

        <text x="120" y="420" font-family="Arial, sans-serif" font-size="24" fill="#999999">
          🏢 ${booking.companySector}
        </text>

        <text x="600" y="580" font-family="Arial, sans-serif" font-size="16" fill="#666666" text-anchor="middle">
          Pace Scheduler • São Paulo
        </text>
      </svg>
    `;

    c.header('Content-Type', 'image/svg+xml');
    c.header('Cache-Control', 'public, max-age=86400');
    return c.body(svg);
  } catch (error) {
    console.error('Error generating OG image:', error);
    return c.json({ error: 'Failed to generate image' }, 500);
  }
});

export default app;
