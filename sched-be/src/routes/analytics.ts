import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth';
import * as analyticsService from '../services/analytics.service';
import type { AppContext } from '../lib/context';

const app = new Hono<AppContext>();

// All analytics endpoints require authentication
app.use('*', authMiddleware);

// Dashboard stats
app.get('/dashboard', async (c) => {
  try {
    const stats = await analyticsService.getDashboardStats();
    return c.json(stats);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Bookings by month for a specific year
app.get('/bookings-by-month/:year', async (c) => {
  try {
    const year = parseInt(c.req.param('year'));
    const data = await analyticsService.getBookingsByMonth(year);
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Bookings by sector
app.get('/bookings-by-sector', async (c) => {
  try {
    const data = await analyticsService.getBookingsBySector();
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Bookings by vertical
app.get('/bookings-by-vertical', async (c) => {
  try {
    const data = await analyticsService.getBookingsByVertical();
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Bookings by interest area
app.get('/bookings-by-interest', async (c) => {
  try {
    const data = await analyticsService.getBookingsByInterestArea();
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Top companies
app.get('/top-companies', async (c) => {
  try {
    const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!) : 10;
    const data = await analyticsService.getTopCompanies(limit);
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Recent bookings
app.get('/recent-bookings', async (c) => {
  try {
    const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!) : 10;
    const data = await analyticsService.getRecentBookings(limit);
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Upcoming bookings
app.get('/upcoming-bookings', async (c) => {
  try {
    const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!) : 10;
    const data = await analyticsService.getUpcomingBookings(limit);
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Booking trends
app.get('/trends', async (c) => {
  try {
    const months = c.req.query('months') ? parseInt(c.req.query('months')!) : 6;
    const data = await analyticsService.getBookingTrends(months);
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Company size distribution
app.get('/company-size-distribution', async (c) => {
  try {
    const data = await analyticsService.getCompanySizeDistribution();
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

// Booking status distribution
app.get('/status-distribution', async (c) => {
  try {
    const data = await analyticsService.getBookingStatusDistribution();
    return c.json(data);
  } catch (error: any) {
    return c.json({ error: error.message }, 400);
  }
});

export default app;
