/**
 * Script to fix existing bug report attachments with missing fileSize and fileType
 * Run with: bun run scripts/fix-attachments-metadata.ts
 */

import { prisma } from '../src/lib/prisma';
import { stat } from 'fs/promises';
import { join } from 'path';

/**
 * Detect MIME type from file extension
 */
function getFileTypeFromExtension(fileName: string): string {
  const ext = fileName.split('.').pop()?.toLowerCase();

  if (!ext) return 'application/octet-stream';

  // Images
  if (['jpg', 'jpeg'].includes(ext)) return 'image/jpeg';
  if (ext === 'png') return 'image/png';
  if (ext === 'gif') return 'image/gif';
  if (ext === 'webp') return 'image/webp';
  if (ext === 'svg') return 'image/svg+xml';

  // Videos
  if (ext === 'mp4') return 'video/mp4';
  if (ext === 'webm') return 'video/webm';
  if (ext === 'ogg') return 'video/ogg';
  if (ext === 'mov') return 'video/quicktime';
  if (ext === 'avi') return 'video/x-msvideo';

  // Documents
  if (ext === 'pdf') return 'application/pdf';
  if (ext === 'doc') return 'application/msword';
  if (ext === 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  if (ext === 'xls') return 'application/vnd.ms-excel';
  if (ext === 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (ext === 'txt') return 'text/plain';
  if (ext === 'csv') return 'text/csv';

  return 'application/octet-stream';
}

/**
 * Get file size from file system
 */
async function getFileSizeFromPath(fileUrl: string): Promise<number> {
  try {
    // Remove leading slash and construct full path
    const relativePath = fileUrl.startsWith('/') ? fileUrl.substring(1) : fileUrl;
    const fullPath = join(process.cwd(), relativePath);
    const stats = await stat(fullPath);
    return stats.size;
  } catch (error) {
    console.error(`Error getting file size for ${fileUrl}:`, error);
    return 0;
  }
}

async function main() {
  console.log('[Fix Attachments] Starting...\n');

  // Get all attachments with fileSize = 0 or fileType = 'application/octet-stream'
  const attachments = await prisma.bugAttachment.findMany({
    where: {
      OR: [
        { fileSize: 0 },
        { fileType: 'application/octet-stream' },
      ],
    },
  });

  console.log(`Found ${attachments.length} attachments to fix\n`);

  let successCount = 0;
  let errorCount = 0;

  for (const attachment of attachments) {
    try {
      const fileSize = await getFileSizeFromPath(attachment.fileUrl);
      const fileType = getFileTypeFromExtension(attachment.fileName);

      await prisma.bugAttachment.update({
        where: { id: attachment.id },
        data: {
          fileSize,
          fileType,
        },
      });

      console.log(`✓ Fixed: ${attachment.fileName}`);
      console.log(`  - Size: ${fileSize} bytes (${(fileSize / 1024).toFixed(2)} KB)`);
      console.log(`  - Type: ${fileType}\n`);

      successCount++;
    } catch (error) {
      console.error(`✗ Error fixing ${attachment.fileName}:`, error);
      errorCount++;
    }
  }

  console.log('\n[Fix Attachments] Complete!');
  console.log(`✓ Success: ${successCount}`);
  console.log(`✗ Errors: ${errorCount}`);

  await prisma.$disconnect();
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
