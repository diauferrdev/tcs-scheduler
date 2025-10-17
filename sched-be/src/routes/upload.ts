import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth';
import type { AppContext } from '../lib/context';
import { writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import { join } from 'path';
import { randomUUID } from 'crypto';

const app = new Hono<AppContext>();

// Allowed file types
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
const ALLOWED_DOCUMENT_TYPES = [
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/csv',
];
const ALL_ALLOWED_TYPES = [...ALLOWED_IMAGE_TYPES, ...ALLOWED_DOCUMENT_TYPES];

// Max file sizes (in bytes)
const MAX_AVATAR_SIZE = 5 * 1024 * 1024; // 5MB
const MAX_ATTACHMENT_SIZE = 10 * 1024 * 1024; // 10MB

// Upload directories
const UPLOAD_BASE_DIR = join(process.cwd(), 'uploads');
const AVATARS_DIR = join(UPLOAD_BASE_DIR, 'avatars');
const ATTACHMENTS_DIR = join(UPLOAD_BASE_DIR, 'attachments');

// Ensure upload directories exist
async function ensureUploadDirs() {
  if (!existsSync(UPLOAD_BASE_DIR)) {
    await mkdir(UPLOAD_BASE_DIR, { recursive: true });
  }
  if (!existsSync(AVATARS_DIR)) {
    await mkdir(AVATARS_DIR, { recursive: true });
  }
  if (!existsSync(ATTACHMENTS_DIR)) {
    await mkdir(ATTACHMENTS_DIR, { recursive: true });
  }
}

// Helper to get file extension from filename
function getFileExtension(filename: string): string {
  const parts = filename.split('.');
  return parts.length > 1 ? parts.pop()!.toLowerCase() : '';
}

// Helper to generate unique filename
function generateFilename(originalFilename: string): string {
  const ext = getFileExtension(originalFilename);
  const uuid = randomUUID();
  return ext ? `${uuid}.${ext}` : uuid;
}

/**
 * Upload avatar image for user profile
 * POST /api/upload/avatar
 * Body: multipart/form-data with 'file' field
 * Returns: { url: string }
 */
app.post('/avatar', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const file = formData.get('file') as File;

    if (!file) {
      return c.json({ error: 'No file provided' }, 400);
    }

    // Validate file type
    if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
      return c.json({
        error: 'Invalid file type. Only images are allowed for avatars.',
        allowedTypes: ALLOWED_IMAGE_TYPES
      }, 400);
    }

    // Validate file size
    if (file.size > MAX_AVATAR_SIZE) {
      return c.json({
        error: `File too large. Maximum size is ${MAX_AVATAR_SIZE / (1024 * 1024)}MB`
      }, 400);
    }

    // Generate unique filename
    const filename = generateFilename(file.name);
    const filepath = join(AVATARS_DIR, filename);

    // Save file
    const arrayBuffer = await file.arrayBuffer();
    await writeFile(filepath, Buffer.from(arrayBuffer));

    // Return URL (will be served by static file middleware)
    const url = `/uploads/avatars/${filename}`;

    console.log('[Upload] Avatar uploaded:', {
      userId: c.get('user').id,
      filename,
      size: file.size,
      type: file.type,
    });

    return c.json({ url });
  } catch (error: any) {
    console.error('[Upload] Error uploading avatar:', error);
    return c.json({ error: error.message || 'Failed to upload file' }, 500);
  }
});

/**
 * Upload attachment for booking
 * POST /api/upload/attachment
 * Body: multipart/form-data with 'file' field
 * Returns: { url: string, filename: string, size: number, type: string }
 */
app.post('/attachment', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const file = formData.get('file') as File;

    if (!file) {
      return c.json({ error: 'No file provided' }, 400);
    }

    // Validate file type
    if (!ALL_ALLOWED_TYPES.includes(file.type)) {
      return c.json({
        error: 'Invalid file type. Only images and documents are allowed.',
        allowedTypes: ALL_ALLOWED_TYPES
      }, 400);
    }

    // Validate file size
    if (file.size > MAX_ATTACHMENT_SIZE) {
      return c.json({
        error: `File too large. Maximum size is ${MAX_ATTACHMENT_SIZE / (1024 * 1024)}MB`
      }, 400);
    }

    // Generate unique filename
    const filename = generateFilename(file.name);
    const filepath = join(ATTACHMENTS_DIR, filename);

    // Save file
    const arrayBuffer = await file.arrayBuffer();
    await writeFile(filepath, Buffer.from(arrayBuffer));

    // Return file info
    const url = `/uploads/attachments/${filename}`;

    console.log('[Upload] Attachment uploaded:', {
      userId: c.get('user').id,
      filename,
      originalName: file.name,
      size: file.size,
      type: file.type,
    });

    return c.json({
      url,
      filename: file.name, // Original filename for display
      size: file.size,
      type: file.type,
    });
  } catch (error: any) {
    console.error('[Upload] Error uploading attachment:', error);
    return c.json({ error: error.message || 'Failed to upload file' }, 500);
  }
});

/**
 * Upload multiple attachments for booking (up to 6)
 * POST /api/upload/attachments
 * Body: multipart/form-data with multiple 'files' fields
 * Returns: { files: Array<{ url, filename, size, type }> }
 */
app.post('/attachments', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const files = formData.getAll('files') as File[];

    if (!files || files.length === 0) {
      return c.json({ error: 'No files provided' }, 400);
    }

    // Validate max count
    if (files.length > 6) {
      return c.json({ error: 'Maximum 6 files allowed' }, 400);
    }

    const uploadedFiles: Array<{
      url: string;
      filename: string;
      size: number;
      type: string;
    }> = [];

    for (const file of files) {
      // Validate file type
      if (!ALL_ALLOWED_TYPES.includes(file.type)) {
        return c.json({
          error: `Invalid file type for ${file.name}. Only images and documents are allowed.`,
          allowedTypes: ALL_ALLOWED_TYPES
        }, 400);
      }

      // Validate file size
      if (file.size > MAX_ATTACHMENT_SIZE) {
        return c.json({
          error: `File ${file.name} is too large. Maximum size is ${MAX_ATTACHMENT_SIZE / (1024 * 1024)}MB`
        }, 400);
      }

      // Generate unique filename
      const filename = generateFilename(file.name);
      const filepath = join(ATTACHMENTS_DIR, filename);

      // Save file
      const arrayBuffer = await file.arrayBuffer();
      await writeFile(filepath, Buffer.from(arrayBuffer));

      // Add to result
      uploadedFiles.push({
        url: `/uploads/attachments/${filename}`,
        filename: file.name,
        size: file.size,
        type: file.type,
      });
    }

    console.log('[Upload] Multiple attachments uploaded:', {
      userId: c.get('user').id,
      count: uploadedFiles.length,
      totalSize: uploadedFiles.reduce((sum, f) => sum + f.size, 0),
    });

    return c.json({ files: uploadedFiles });
  } catch (error: any) {
    console.error('[Upload] Error uploading attachments:', error);
    return c.json({ error: error.message || 'Failed to upload files' }, 500);
  }
});

export default app;
