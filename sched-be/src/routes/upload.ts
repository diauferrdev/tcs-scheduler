import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth';
import type { AppContext } from '../lib/context';
import { prisma } from '../lib/prisma';
import { writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import { join } from 'path';
import { randomUUID } from 'crypto';

const app = new Hono<AppContext>();

// ==================== CONFIGURATION ====================

// Allowed file types
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml'];
const ALLOWED_VIDEO_TYPES = ['video/mp4', 'video/webm', 'video/ogg', 'video/quicktime', 'video/x-msvideo'];
const ALLOWED_AUDIO_TYPES = ['audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/aac', 'audio/webm', 'audio/x-m4a'];
const ALLOWED_DOCUMENT_TYPES = [
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
  'text/csv',
];
// General files - permite qualquer tipo de arquivo (exe, zip, apk, etc)
const ALLOWED_FILE_TYPES = [
  'application/zip',
  'application/x-zip-compressed',
  'application/x-rar-compressed',
  'application/x-7z-compressed',
  'application/x-tar',
  'application/gzip',
  'application/vnd.android.package-archive', // APK
  'application/x-msdownload', // EXE
  'application/x-executable',
  'application/octet-stream', // Binários genéricos
  'application/json',
  'application/xml',
  'text/xml',
];
const ALLOWED_ATTACHMENT_TYPES = [...ALLOWED_IMAGE_TYPES, ...ALLOWED_DOCUMENT_TYPES, ...ALLOWED_VIDEO_TYPES, ...ALLOWED_AUDIO_TYPES, ...ALLOWED_FILE_TYPES];

// Max file sizes (in bytes)
const MAX_AVATAR_SIZE = 10 * 1024 * 1024; // 10MB
const MAX_IMAGE_SIZE = 30 * 1024 * 1024; // 30MB
const MAX_VIDEO_SIZE = 300 * 1024 * 1024; // 300MB
const MAX_AUDIO_SIZE = 50 * 1024 * 1024; // 50MB
const MAX_DOCUMENT_SIZE = 20 * 1024 * 1024; // 20MB
const MAX_FILE_SIZE = 1024 * 1024 * 1024; // 1GB - Arquivos gerais
const MAX_ATTACHMENT_SIZE = 1024 * 1024 * 1024; // 1GB - Aumentado para suportar arquivos gerais

// Upload directories
const UPLOAD_BASE_DIR = join(process.cwd(), 'uploads');
const AVATARS_DIR = join(UPLOAD_BASE_DIR, 'avatars');
const IMAGES_DIR = join(UPLOAD_BASE_DIR, 'images');
const VIDEOS_DIR = join(UPLOAD_BASE_DIR, 'videos');
const AUDIO_DIR = join(UPLOAD_BASE_DIR, 'audio');
const DOCUMENTS_DIR = join(UPLOAD_BASE_DIR, 'documents');
const FILES_DIR = join(UPLOAD_BASE_DIR, 'files'); // Arquivos gerais
const ATTACHMENTS_DIR = join(UPLOAD_BASE_DIR, 'attachments');

// ==================== HELPER FUNCTIONS ====================

async function ensureUploadDirs() {
  const dirs = [UPLOAD_BASE_DIR, AVATARS_DIR, IMAGES_DIR, VIDEOS_DIR, AUDIO_DIR, DOCUMENTS_DIR, FILES_DIR, ATTACHMENTS_DIR];
  for (const dir of dirs) {
    if (!existsSync(dir)) {
      await mkdir(dir, { recursive: true });
    }
  }
}

function getFileExtension(filename: string): string {
  const parts = filename.split('.');
  return parts.length > 1 ? parts.pop()!.toLowerCase() : '';
}

function generateFilename(originalFilename: string): string {
  const ext = getFileExtension(originalFilename);
  const uuid = randomUUID();
  return ext ? `${uuid}.${ext}` : uuid;
}

// ==================== UPLOAD ROUTES ====================

/**
 * Upload avatar image for user profile
 * POST /api/upload/avatar
 */
app.post('/avatar', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const file = formData.get('file') as File;

    if (!file) {
      return c.json({ error: 'No file provided' }, 400);
    }

    if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
      return c.json({
        error: 'Invalid file type. Only images are allowed for avatars.',
        allowedTypes: ALLOWED_IMAGE_TYPES
      }, 400);
    }

    if (file.size > MAX_AVATAR_SIZE) {
      return c.json({
        error: `File too large. Maximum size is ${MAX_AVATAR_SIZE / (1024 * 1024)}MB`
      }, 400);
    }

    const filename = generateFilename(file.name);
    const filepath = join(AVATARS_DIR, filename);

    const arrayBuffer = await file.arrayBuffer();
    await writeFile(filepath, Buffer.from(arrayBuffer));

    const url = `https://api.ppspsched.lat/uploads/avatars/${filename}`;

    // Update user's avatarUrl in database
    const userId = c.get('user').id;

    await prisma.user.update({
      where: { id: userId },
      data: { avatarUrl: url },
    });

    console.log('[Upload] Avatar uploaded:', {
      userId,
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
 * Upload image file
 * POST /api/upload/image
 */
app.post('/image', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const file = formData.get('file') as File;

    if (!file) {
      return c.json({ error: 'No file provided' }, 400);
    }

    if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
      return c.json({
        error: 'Invalid file type. Only images are allowed.',
        allowedTypes: ALLOWED_IMAGE_TYPES
      }, 400);
    }

    if (file.size > MAX_IMAGE_SIZE) {
      return c.json({
        error: `File too large. Maximum size is ${MAX_IMAGE_SIZE / (1024 * 1024)}MB`
      }, 400);
    }

    const filename = generateFilename(file.name);
    const filepath = join(IMAGES_DIR, filename);

    const arrayBuffer = await file.arrayBuffer();
    await writeFile(filepath, Buffer.from(arrayBuffer));

    const url = `https://api.ppspsched.lat/uploads/images/${filename}`;

    console.log('[Upload] Image uploaded:', {
      userId: c.get('user').id,
      filename,
      size: file.size,
      type: file.type,
    });

    return c.json({
      url,
      filename: file.name,
      size: file.size,
      type: file.type,
    });
  } catch (error: any) {
    console.error('[Upload] Error uploading image:', error);
    return c.json({ error: error.message || 'Failed to upload image' }, 500);
  }
});

/**
 * Upload video file
 * POST /api/upload/video
 */
app.post('/video', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const file = formData.get('file') as File;

    if (!file) {
      return c.json({ error: 'No file provided' }, 400);
    }

    if (!ALLOWED_VIDEO_TYPES.includes(file.type)) {
      return c.json({
        error: 'Invalid file type. Only videos are allowed.',
        allowedTypes: ALLOWED_VIDEO_TYPES
      }, 400);
    }

    if (file.size > MAX_VIDEO_SIZE) {
      return c.json({
        error: `File too large. Maximum size is ${MAX_VIDEO_SIZE / (1024 * 1024)}MB`
      }, 400);
    }

    const filename = generateFilename(file.name);
    const filepath = join(VIDEOS_DIR, filename);

    const arrayBuffer = await file.arrayBuffer();
    await writeFile(filepath, Buffer.from(arrayBuffer));

    const url = `https://api.ppspsched.lat/uploads/videos/${filename}`;

    console.log('[Upload] Video uploaded:', {
      userId: c.get('user').id,
      filename,
      size: file.size,
      type: file.type,
    });

    return c.json({
      url,
      filename: file.name,
      size: file.size,
      type: file.type,
    });
  } catch (error: any) {
    console.error('[Upload] Error uploading video:', error);
    return c.json({ error: error.message || 'Failed to upload video' }, 500);
  }
});

/**
 * Upload document file
 * POST /api/upload/document
 */
app.post('/document', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const file = formData.get('file') as File;

    if (!file) {
      return c.json({ error: 'No file provided' }, 400);
    }

    if (!ALLOWED_DOCUMENT_TYPES.includes(file.type)) {
      return c.json({
        error: 'Invalid file type. Only documents are allowed.',
        allowedTypes: ALLOWED_DOCUMENT_TYPES
      }, 400);
    }

    if (file.size > MAX_DOCUMENT_SIZE) {
      return c.json({
        error: `File too large. Maximum size is ${MAX_DOCUMENT_SIZE / (1024 * 1024)}MB`
      }, 400);
    }

    const filename = generateFilename(file.name);
    const filepath = join(DOCUMENTS_DIR, filename);

    const arrayBuffer = await file.arrayBuffer();
    await writeFile(filepath, Buffer.from(arrayBuffer));

    const url = `https://api.ppspsched.lat/uploads/documents/${filename}`;

    console.log('[Upload] Document uploaded:', {
      userId: c.get('user').id,
      filename,
      size: file.size,
      type: file.type,
    });

    return c.json({
      url,
      filename: file.name,
      size: file.size,
      type: file.type,
    });
  } catch (error: any) {
    console.error('[Upload] Error uploading document:', error);
    return c.json({ error: error.message || 'Failed to upload document' }, 500);
  }
});

/**
 * Upload general file (exe, zip, apk, etc - up to 1GB)
 * POST /api/upload/file
 */
app.post('/file', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const file = formData.get('file') as File;

    if (!file) {
      return c.json({ error: 'No file provided' }, 400);
    }

    // Aceita qualquer tipo de arquivo
    if (file.size > MAX_FILE_SIZE) {
      return c.json({
        error: `File too large. Maximum size is ${MAX_FILE_SIZE / (1024 * 1024 * 1024)}GB`
      }, 400);
    }

    const filename = generateFilename(file.name);
    const filepath = join(FILES_DIR, filename);

    const arrayBuffer = await file.arrayBuffer();
    await writeFile(filepath, Buffer.from(arrayBuffer));

    const url = `https://api.ppspsched.lat/uploads/files/${filename}`;

    console.log('[Upload] File uploaded:', {
      userId: c.get('user').id,
      filename,
      size: file.size,
      type: file.type,
    });

    return c.json({
      url,
      filename: file.name,
      size: file.size,
      type: file.type,
    });
  } catch (error: any) {
    console.error('[Upload] Error uploading file:', error);
    return c.json({ error: error.message || 'Failed to upload file' }, 500);
  }
});

/**
 * Upload audio file
 * POST /api/upload/audio
 */
app.post('/audio', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const file = formData.get('file') as File;

    if (!file) {
      return c.json({ error: 'No file provided' }, 400);
    }

    if (!ALLOWED_AUDIO_TYPES.includes(file.type)) {
      return c.json({
        error: 'Invalid file type. Only audio files are allowed.',
        allowedTypes: ALLOWED_AUDIO_TYPES
      }, 400);
    }

    if (file.size > MAX_AUDIO_SIZE) {
      return c.json({
        error: `File too large. Maximum size is ${MAX_AUDIO_SIZE / (1024 * 1024)}MB`
      }, 400);
    }

    const filename = generateFilename(file.name);
    const filepath = join(AUDIO_DIR, filename);

    const arrayBuffer = await file.arrayBuffer();
    await writeFile(filepath, Buffer.from(arrayBuffer));

    const url = `https://api.ppspsched.lat/uploads/audio/${filename}`;

    console.log('[Upload] Audio uploaded:', {
      userId: c.get('user').id,
      filename,
      size: file.size,
      type: file.type,
    });

    // Duration will be extracted later by ticket.service.ts using ffprobe
    return c.json({
      url,
      filename: file.name,
      size: file.size,
      type: file.type,
    });
  } catch (error: any) {
    console.error('[Upload] Error uploading audio:', error);
    return c.json({ error: error.message || 'Failed to upload audio' }, 500);
  }
});

/**
 * Upload single attachment for booking
 * POST /api/upload/attachment
 */
app.post('/attachment', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    console.log('[Upload] Processing attachment upload request');
    const formData = await c.req.formData();
    console.log('[Upload] FormData keys:', Array.from(formData.keys()));

    const file = formData.get('file') as File;
    console.log('[Upload] File:', file ? {
      name: file.name,
      type: file.type,
      size: file.size
    } : 'null');

    if (!file) {
      console.log('[Upload] ERROR: No file provided');
      return c.json({ error: 'No file provided' }, 400);
    }

    if (!ALLOWED_ATTACHMENT_TYPES.includes(file.type)) {
      console.log('[Upload] ERROR: Invalid file type:', file.type);
      console.log('[Upload] Allowed types:', ALLOWED_ATTACHMENT_TYPES);
      return c.json({
        error: 'Invalid file type. Only images, documents, videos, and audio files are allowed.',
        allowedTypes: ALLOWED_ATTACHMENT_TYPES,
        receivedType: file.type
      }, 400);
    }

    if (file.size > MAX_ATTACHMENT_SIZE) {
      console.log('[Upload] ERROR: File too large:', file.size, 'Max:', MAX_ATTACHMENT_SIZE);
      return c.json({
        error: `File too large. Maximum size is ${MAX_ATTACHMENT_SIZE / (1024 * 1024)}MB`
      }, 400);
    }

    const filename = generateFilename(file.name);
    const filepath = join(ATTACHMENTS_DIR, filename);

    const arrayBuffer = await file.arrayBuffer();
    await writeFile(filepath, Buffer.from(arrayBuffer));

    // Return absolute URL with API domain
    const url = `https://api.ppspsched.lat/uploads/attachments/${filename}`;

    console.log('[Upload] Attachment uploaded:', {
      userId: c.get('user').id,
      filename,
      size: file.size,
      type: file.type,
      url,
    });

    // Duration will be extracted later by ticket.service.ts using ffprobe
    return c.json({
      url,
      filename: file.name,
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
 */
app.post('/attachments', authMiddleware, async (c) => {
  try {
    await ensureUploadDirs();

    const formData = await c.req.formData();
    const files = formData.getAll('files') as File[];

    if (!files || files.length === 0) {
      return c.json({ error: 'No files provided' }, 400);
    }

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
      if (!ALLOWED_ATTACHMENT_TYPES.includes(file.type)) {
        return c.json({
          error: `Invalid file type for ${file.name}. Only images, documents, videos, and audio files are allowed.`,
          allowedTypes: ALLOWED_ATTACHMENT_TYPES
        }, 400);
      }

      if (file.size > MAX_ATTACHMENT_SIZE) {
        return c.json({
          error: `File ${file.name} is too large. Maximum size is ${MAX_ATTACHMENT_SIZE / (1024 * 1024)}MB`
        }, 400);
      }

      const filename = generateFilename(file.name);
      const filepath = join(ATTACHMENTS_DIR, filename);

      const arrayBuffer = await file.arrayBuffer();
      await writeFile(filepath, Buffer.from(arrayBuffer));

      uploadedFiles.push({
        url: `https://api.ppspsched.lat/uploads/attachments/${filename}`,
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
