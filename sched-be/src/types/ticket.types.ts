import { z } from 'zod';

export const TicketCreateSchema = z.object({
  title: z.string().min(5).max(255),
  description: z.string().min(10),
  category: z.enum(['BUG', 'FEATURE_REQUEST', 'QUESTION', 'IMPROVEMENT', 'OTHER']),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH', 'URGENT']).optional(),
  platform: z.enum(['WINDOWS', 'LINUX', 'MACOS', 'ANDROID', 'IOS', 'WEB']).optional(),
  deviceInfo: z.record(z.any()).optional(),
  attachments: z.array(z.object({
    fileName: z.string(),
    fileUrl: z.string(),
    fileSize: z.number(),
    mimeType: z.string(),
  })).optional(),
});

export const TicketUpdateSchema = z.object({
  title: z.string().min(5).max(255).optional(),
  description: z.string().min(10).optional(),
  status: z.enum(['OPEN', 'IN_PROGRESS', 'WAITING_USER', 'WAITING_ADMIN', 'RESOLVED', 'CLOSED']).optional(),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH', 'URGENT']).optional(),
  assignedToId: z.string().nullable().optional(),
});

export const TicketMessageCreateSchema = z.object({
  content: z.string().min(1),
  isInternal: z.boolean().optional(),
  attachments: z.array(z.object({
    fileName: z.string(),
    fileUrl: z.string(),
    fileSize: z.number(),
    mimeType: z.string(),
  })).optional(),
});

export const TicketFilterSchema = z.object({
  status: z.enum(['OPEN', 'IN_PROGRESS', 'WAITING_USER', 'WAITING_ADMIN', 'RESOLVED', 'CLOSED']).optional(),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH', 'URGENT']).optional(),
  category: z.enum(['BUG', 'FEATURE_REQUEST', 'QUESTION', 'IMPROVEMENT', 'OTHER']).optional(),
  createdById: z.string().optional(),
  assignedToId: z.string().optional(),
  search: z.string().optional(),
});

export type TicketCreate = z.infer<typeof TicketCreateSchema>;
export type TicketUpdate = z.infer<typeof TicketUpdateSchema>;
export type TicketMessageCreate = z.infer<typeof TicketMessageCreateSchema>;
export type TicketFilter = z.infer<typeof TicketFilterSchema>;
