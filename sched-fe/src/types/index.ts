import { z } from 'zod';

// Enums
export const UserRoleSchema = z.enum(['ADMIN', 'MANAGER', 'GUEST']);
export const VisitDurationSchema = z.enum(['THREE_HOURS', 'SIX_HOURS']);
export const BookingStatusSchema = z.enum(['PENDING', 'CONFIRMED', 'CANCELLED']);

// Auth
export const LoginSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

// Attendee schema
export const AttendeeSchema = z.object({
  name: z.string().min(2, 'Attendee name must be at least 2 characters'),
  position: z.string().optional(),
  email: z.string().optional(),
});

// Booking
export const BookingCreateSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format'),
  duration: VisitDurationSchema,
  startTime: z.enum(['09:00', '14:00']),

  companyName: z.string().min(2, 'Company name must be at least 2 characters'),
  companySector: z.string().min(1, 'Company sector is required'),
  companyVertical: z.string().min(1, 'Company vertical is required'),
  companySize: z.string().optional(),

  contactName: z.string().min(2, 'Contact name must be at least 2 characters'),
  contactEmail: z.string().email('Invalid email format'),
  contactPhone: z.string().optional(),
  contactPosition: z.string().optional(),

  interestArea: z.string().min(1, 'Interest area is required'),
  expectedAttendees: z.number().int().min(1).max(50).default(1),
  attendees: z.array(AttendeeSchema).min(1, 'At least one attendee is required').optional(),
  businessGoal: z.string().max(500).optional(),
  additionalNotes: z.string().max(1000).optional(),
});

export const BookingGuestCreateSchema = BookingCreateSchema.extend({
  token: z.string().min(1, 'Token is required'),
});

export const BookingUpdateSchema = BookingCreateSchema.partial().extend({
  status: BookingStatusSchema.optional(),
});

// Invitation
export const InvitationCreateSchema = z.object({
  email: z.string().email().optional(),
  expiresInDays: z.number().int().min(1).max(30).default(7),
});

export const InvitationSendEmailSchema = z.object({
  email: z.string().email('Invalid email format'),
  message: z.string().max(500).optional(),
});

// User
export const UserCreateSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  name: z.string().min(2, 'Name must be at least 2 characters'),
  role: z.enum(['ADMIN', 'MANAGER']).default('MANAGER'),
});

export const UserUpdateSchema = z.object({
  email: z.string().email().optional(),
  name: z.string().min(2).optional(),
  role: UserRoleSchema.optional(),
  isActive: z.boolean().optional(),
});

// Type inference
export type LoginInput = z.infer<typeof LoginSchema>;
export type BookingCreateInput = z.infer<typeof BookingCreateSchema>;
export type BookingGuestCreateInput = z.infer<typeof BookingGuestCreateSchema>;
export type BookingUpdateInput = z.infer<typeof BookingUpdateSchema>;
export type InvitationCreateInput = z.infer<typeof InvitationCreateSchema>;
export type InvitationSendEmailInput = z.infer<typeof InvitationSendEmailSchema>;
export type UserCreateInput = z.infer<typeof UserCreateSchema>;
export type UserUpdateInput = z.infer<typeof UserUpdateSchema>;
