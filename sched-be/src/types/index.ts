import { z } from 'zod';

// ==================== ENUMS ====================

// User roles
export const UserRoleSchema = z.enum(['ADMIN', 'MANAGER', 'USER']);

// Visit duration (in hours)
export const VisitDurationSchema = z.enum(['ONE_HOUR', 'TWO_HOURS', 'THREE_HOURS', 'FOUR_HOURS', 'FIVE_HOURS', 'SIX_HOURS']);

// New Booking Status (updated flow)
export const BookingStatusSchema = z.enum([
  'DRAFT',            // DEPRECATED - kept for backwards compatibility
  'PENDING_APPROVAL', // DEPRECATED - kept for backwards compatibility
  'CREATED',          // Initial status when booking is submitted
  'UNDER_REVIEW',     // Manager/Admin is reviewing the booking
  'NEED_EDIT',        // User must edit information (except date)
  'NEED_RESCHEDULE',  // User must choose new date
  'APPROVED',         // Approved and scheduled (time blocked)
  'NOT_APPROVED',     // Rejected with reason
  'CANCELLED',        // Manually cancelled
]);

// Engagement Type
export const EngagementTypeSchema = z.enum(['VISIT', 'INNOVATION_EXCHANGE']);

// Visit Type (updated names)
export const VisitTypeSchema = z.enum([
  'QUICK_TOUR',          // DEPRECATED - kept for backwards compatibility
  'PACE_TOUR',           // 14h-16h (2 hours) - simple visit, no questionnaire
  'PACE_EXPERIENCE',     // 10h-16h (6 hours) - full day, requires questionnaire
  'INNOVATION_EXCHANGE', // 10h-17h (7 hours) - requires questionnaire and alignment call
]);

// Organization Type
export const OrganizationTypeSchema = z.enum([
  'GOVERNMENTAL_INSTITUTION',
  'PARTNER',
  'EXISTING_CUSTOMER',
  'PROSPECT',
  'OTHER',
]);

// TCS Verticals (official TCS nomenclature)
export const TCSVerticalSchema = z.enum([
  'BFSI',                      // Banking, Financial Services & Insurance
  'RETAIL_CPG',                // Retail & Consumer Packaged Goods
  'LIFE_SCIENCES_HEALTHCARE',  // Life Sciences & Healthcare
  'MANUFACTURING',
  'HI_TECH',
  'CMT',                       // Communications, Media & Technology
  'ERU',                       // Energy, Resources & Utilities
  'TRAVEL_HOSPITALITY',        // Travel, Transportation & Hospitality
  'PUBLIC_SERVICES',
  'BUSINESS_SERVICES',
]);

// Target Audience options
export const TargetAudienceSchema = z.enum([
  'EXECUTIVES',
  'MIDDLE_MANAGEMENT',
  'TECHNICAL_TEAM',
  'TRAINEES',
  'STUDENTS',
  'CELEBRITIES',
  'PARTNERS',
  'OTHER',
]);

export const EventTypeSchema = z.enum(['TCS', 'PARTNER']);
export const DealStatusSchema = z.enum(['SWON', 'WON']);
export const TCSSupporterSchema = z.enum(['SUPPORTER', 'NEUTRAL', 'DETRACTOR']);

// ==================== AUTH ====================

export const LoginSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

// ==================== ATTENDEE ====================

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

// ==================== BOOKING ====================

// Base schema without refinement (so we can extend it)
const BookingBaseSchema = z.object({
  // Date & Time
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format'),
  startTime: z.string().regex(/^([0-1][0-9]|2[0-3]):[0-5][0-9]$/, 'Invalid time format (HH:MM)'),
  duration: VisitDurationSchema,

  // Engagement Flow
  engagementType: EngagementTypeSchema.default('VISIT'),
  visitType: VisitTypeSchema.default('PACE_TOUR'),

  // Base Information (Drawer 2)
  requesterName: z.string().min(2, 'Requester name must be at least 2 characters'),
  employeeId: z.string().min(1, 'Employee ID is required'),
  vertical: TCSVerticalSchema,
  organizationName: z.string().min(2, 'Organization name must be at least 2 characters'),
  organizationType: OrganizationTypeSchema,
  organizationTypeOther: z.string().optional(), // Required when organizationType is 'OTHER'
  organizationDescription: z.string().max(1000).optional(),
  objectiveInterest: z.string().max(1000).optional(),
  targetAudience: z.array(TargetAudienceSchema).optional(),

  // Questionnaire (Drawer 3 - for Pace Experience & Innovation Exchange)
  questionnaireAnswers: z.record(z.any()).optional(), // Flexible JSON for questionnaire answers
  requiresAlignmentCall: z.boolean().default(false),

  // Legacy fields (kept for backwards compatibility)
  accountName: z.string().default(''),
  companyName: z.string().default(''),
  companySector: z.string().optional(),
  companyVertical: z.string().optional(),
  companySize: z.string().optional(),
  contactName: z.string().optional(),
  contactEmail: z.string().email('Invalid email format').optional(),
  contactPhone: z.string().optional(),
  contactPosition: z.string().optional(),
  venue: z.string().optional(),
  expectedAttendees: z.number().int().min(1).max(3, 'Maximum 3 attendees allowed').default(1),
  overallTheme: z.string().max(500).optional(),
  lastInnovationDay: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format').optional(),
  eventType: EventTypeSchema.optional(),
  partnerName: z.string().optional(),
  dealStatus: DealStatusSchema.optional(),
  attachHeadApproval: z.boolean().default(false),
  attachments: z.array(z.string().url()).max(6, 'Maximum 6 attachments allowed').optional(),
  attendees: z.array(AttendeeSchema).min(1, 'At least one attendee is required').max(3, 'Maximum 3 attendees allowed').optional(),
  participantUserIds: z.array(z.string()).optional(),
  interestArea: z.string().optional(),
  businessGoal: z.string().max(500).optional(),
  additionalNotes: z.string().max(1000).optional(),
});

// New Booking Create Schema (updated for new flow) with validation refinement
export const BookingCreateSchema = BookingBaseSchema.refine(
  (data) => data.organizationType !== 'OTHER' || data.organizationTypeOther,
  {
    message: 'Organization type specification is required when "OTHER" is selected',
    path: ['organizationTypeOther'],
  }
);

export const BookingGuestCreateSchema = BookingBaseSchema.extend({
  token: z.string().min(1, 'Token is required'),
}).refine(
  (data) => data.organizationType !== 'OTHER' || data.organizationTypeOther,
  {
    message: 'Organization type specification is required when "OTHER" is selected',
    path: ['organizationTypeOther'],
  }
);

export const BookingUpdateSchema = BookingBaseSchema.partial().extend({
  status: BookingStatusSchema.optional(),
});

// ==================== STATUS CHANGE SCHEMAS ====================

// Manager/Admin: Change status to NEED_EDIT
export const RequestEditSchema = z.object({
  message: z.string().max(500).optional(), // Optional message explaining what needs to be edited
});

// Manager/Admin: Change status to NEED_RESCHEDULE
export const RequestRescheduleSchema = z.object({
  message: z.string().max(500).optional(), // Optional message explaining why reschedule is needed
});

// Manager/Admin: Reject booking (NOT_APPROVED)
export const RejectBookingSchema = z.object({
  rejectionReason: z.string().min(10, 'Rejection reason must be at least 10 characters').max(1000),
});

// Manager/Admin: Approve booking
export const ApproveBookingSchema = z.object({
  // No additional fields required, just confirmation
});

// Manager/Admin: Cancel booking
export const CancelBookingSchema = z.object({
  cancellationReason: z.string().min(10, 'Cancellation reason must be at least 10 characters').max(1000),
});

// User: Reschedule booking (when status is NEED_RESCHEDULE)
export const UserRescheduleSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format'),
  startTime: z.string().regex(/^([0-1][0-9]|2[0-3]):[0-5][0-9]$/, 'Invalid time format (HH:MM)'),
  duration: VisitDurationSchema,
});

// ==================== INVITATION ====================

export const InvitationCreateSchema = z.object({
  email: z.string().email().optional(),
  expiresInDays: z.number().int().min(1).max(30).default(7),
});

export const InvitationSendEmailSchema = z.object({
  email: z.string().email('Invalid email format'),
  message: z.string().max(500).optional(),
});

// ==================== USER ====================

export const UserCreateSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  name: z.string().min(2, 'Name must be at least 2 characters'),
  role: UserRoleSchema.default('USER'),
});

export const UserUpdateSchema = z.object({
  email: z.string().email().optional(),
  name: z.string().min(2).optional(),
  role: UserRoleSchema.optional(),
  isActive: z.boolean().optional(),
});

export const PasswordChangeSchema = z.object({
  currentPassword: z.string().min(1, 'Current password is required'),
  newPassword: z.string().min(8, 'New password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
    .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
    .regex(/[0-9]/, 'Password must contain at least one number')
    .regex(/[@$!%*?&#]/, 'Password must contain at least one special character'),
});

export const ProfileUpdateSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters').optional(),
});

// ==================== TYPE INFERENCE ====================

export type LoginInput = z.infer<typeof LoginSchema>;
export type BookingCreateInput = z.infer<typeof BookingCreateSchema>;
export type BookingGuestCreateInput = z.infer<typeof BookingGuestCreateSchema>;
export type BookingUpdateInput = z.infer<typeof BookingUpdateSchema>;
export type RequestEditInput = z.infer<typeof RequestEditSchema>;
export type RequestRescheduleInput = z.infer<typeof RequestRescheduleSchema>;
export type RejectBookingInput = z.infer<typeof RejectBookingSchema>;
export type ApproveBookingInput = z.infer<typeof ApproveBookingSchema>;
export type CancelBookingInput = z.infer<typeof CancelBookingSchema>;
export type UserRescheduleInput = z.infer<typeof UserRescheduleSchema>;
export type InvitationCreateInput = z.infer<typeof InvitationCreateSchema>;
export type InvitationSendEmailInput = z.infer<typeof InvitationSendEmailSchema>;
export type UserCreateInput = z.infer<typeof UserCreateSchema>;
export type UserUpdateInput = z.infer<typeof UserUpdateSchema>;
export type PasswordChangeInput = z.infer<typeof PasswordChangeSchema>;
export type ProfileUpdateInput = z.infer<typeof ProfileUpdateSchema>;
