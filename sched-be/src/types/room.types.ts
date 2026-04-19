import { z } from 'zod';
import { TCSVerticalSchema } from './index';

// ==================== ROOM ENUMS ====================

export const RoomTypeSchema = z.enum([
  'PHONE_BOOTH_1',
  'PHONE_BOOTH_2',
  'AGILE_SPACE',
  'THINKING_SPACE',
  'IMMERSIVE_ROOM',
  'CONFERENCE_ROOM',
  'PODCAST_ROOM',
  'GREEN_ROOM',
]);

export const RoomBookingStatusSchema = z.enum([
  'PENDING',
  'APPROVED',
  'REJECTED',
  'CANCELLED',
  'NEED_EDIT',
  'NEED_RESCHEDULE',
]);

// ==================== ROOM BOOKING SCHEMAS ====================

export const RoomBookingCreateSchema = z.object({
  room: RoomTypeSchema,
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format'),
  startTime: z.string().regex(/^\d{2}:\d{2}$/, 'Start time must be in HH:MM format'),
  endTime: z.string().regex(/^\d{2}:\d{2}$/, 'End time must be in HH:MM format'),
  purpose: z.string().min(2, 'Purpose must be at least 2 characters'),
  attendees: z.number().int().min(1).max(50).default(1),
  vertical: TCSVerticalSchema.optional(),
}).refine(
  (data) => data.endTime > data.startTime,
  { message: 'End time must be after start time', path: ['endTime'] }
).refine(
  (data) => data.startTime >= '08:00' && data.startTime <= '20:00' && data.endTime <= '21:00',
  { message: 'Start time must be between 08:00 and 20:00, end time by 21:00', path: ['startTime'] }
);

export const RoomBookingRejectSchema = z.object({
  rejectionReason: z.string().min(5, 'Rejection reason must be at least 5 characters').max(500, 'Rejection reason must be at most 500 characters'),
});

// ==================== EDIT / RESCHEDULE SCHEMAS ====================

export const RoomBookingEditSchema = z.object({
  purpose: z.string().min(2, 'Purpose must be at least 2 characters').optional(),
  attendees: z.number().int().min(1).max(50).optional(),
  vertical: TCSVerticalSchema.optional().nullable(),
});

export const RoomBookingRescheduleSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format'),
  startTime: z.string().regex(/^\d{2}:\d{2}$/, 'Start time must be in HH:MM format'),
  endTime: z.string().regex(/^\d{2}:\d{2}$/, 'End time must be in HH:MM format'),
}).refine(
  (data) => data.endTime > data.startTime,
  { message: 'End time must be after start time', path: ['endTime'] }
).refine(
  (data) => data.startTime >= '08:00' && data.startTime <= '20:00' && data.endTime <= '21:00',
  { message: 'Start time must be between 08:00 and 20:00, end time by 21:00', path: ['startTime'] }
);

export const RoomBookingRequestMessageSchema = z.object({
  message: z.string().max(500).optional(),
});

// ==================== TYPE EXPORTS ====================

export type RoomType = z.infer<typeof RoomTypeSchema>;
export type RoomBookingStatus = z.infer<typeof RoomBookingStatusSchema>;
export type RoomBookingCreateInput = z.infer<typeof RoomBookingCreateSchema>;
export type RoomBookingRejectInput = z.infer<typeof RoomBookingRejectSchema>;
export type RoomBookingEditInput = z.infer<typeof RoomBookingEditSchema>;
export type RoomBookingRescheduleInput = z.infer<typeof RoomBookingRescheduleSchema>;
