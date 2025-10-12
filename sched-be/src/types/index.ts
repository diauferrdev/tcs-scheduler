import { z } from 'zod';

// Enums
export const UserRoleSchema = z.enum(['ADMIN', 'MANAGER', 'GUEST']);
export const VisitDurationSchema = z.enum(['ONE_HOUR', 'TWO_HOURS', 'THREE_HOURS', 'FOUR_HOURS', 'FIVE_HOURS', 'SIX_HOURS']);
export const BookingStatusSchema = z.enum(['PENDING_APPROVAL', 'CONFIRMED', 'CANCELLED', 'RESCHEDULED']);
export const EventTypeSchema = z.enum(['TCS', 'PARTNER']);
export const DealStatusSchema = z.enum(['SWON', 'WON']);
export const TCSSupporterSchema = z.enum(['SUPPORTER', 'NEUTRAL', 'DETRACTOR']);

// New: Visit Type (Quick Tour or Innovation Exchange)
export const VisitTypeSchema = z.enum(['QUICK_TOUR', 'INNOVATION_EXCHANGE']);

// Auth
export const LoginSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

// Attendee schema (Updated - limite 3 por booking)
export const AttendeeSchema = z.object({
  // Basic Info
  name: z.string().min(2, 'Attendee name must be at least 2 characters'),
  email: z.string().email('Invalid email format'),
  role: z.string().optional(),

  // TCS Relationship
  tcsSupporter: TCSSupporterSchema.optional(),
  understandingOfTCS: z.string().max(1000).optional(),
  focusAreas: z.string().max(1000).optional(),
  yearsWorkingWithTCS: z.number().int().min(0).max(100).optional(),

  // Professional Info
  position: z.string().optional(),
  educationalQualification: z.string().max(1000).optional(),
  careerBackground: z.string().max(1000).optional(),
  linkedinProfile: z.string().url('Invalid LinkedIn URL').optional().or(z.literal('')),

  // Optional
  photoUrl: z.string().url('Invalid photo URL').optional().or(z.literal('')),
});

// Booking (Updated with new fields)
export const BookingCreateSchema = z.object({
  // Date & Time (9h-17h, blocos de 1-4 horas)
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format'),
  startTime: z.string().regex(/^([0-1][0-9]|2[0-3]):[0-5][0-9]$/, 'Invalid time format (HH:MM)'),
  duration: VisitDurationSchema,

  // Visit Type (QUICK_TOUR ou INNOVATION_EXCHANGE)
  visitType: VisitTypeSchema,

  // Account & Company Info
  accountName: z.string().min(2, 'Account name must be at least 2 characters'),
  companyName: z.string().min(2, 'Company name must be at least 2 characters'),
  companySector: z.string().optional(),
  companyVertical: z.string().optional(),
  companySize: z.string().optional(),

  // Contact Info (kept for compatibility)
  contactName: z.string().optional(),
  contactEmail: z.string().email('Invalid email format').optional(),
  contactPhone: z.string().optional(),
  contactPosition: z.string().optional(),

  // Visit Details
  venue: z.string().optional(),
  expectedAttendees: z.number().int().min(1).max(3, 'Maximum 3 attendees allowed').default(1),
  overallTheme: z.string().max(500).optional(),
  lastInnovationDay: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format').optional(),

  // Event Type
  eventType: EventTypeSchema.optional(),
  partnerName: z.string().optional(),

  // Deal Status
  dealStatus: DealStatusSchema.optional(),

  // Approvals
  segmentHeadApproval: z.boolean().default(false),

  // Attendees (máximo 3)
  attendees: z.array(AttendeeSchema).min(1, 'At least one attendee is required').max(3, 'Maximum 3 attendees allowed').optional(),

  // TCS Participants (opcional - user IDs que serão convidados para participar)
  participantUserIds: z.array(z.string()).optional(),

  // Legacy fields (kept for compatibility)
  interestArea: z.string().optional(),
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
