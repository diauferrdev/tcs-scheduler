// Test audio duration extraction
import { join } from 'path';

const AUDIO_MIME_TYPES = [
  'audio/mp4',
  'audio/mpeg',
  'audio/wav',
  'audio/ogg',
  'audio/aac',
  'audio/webm',
  'audio/x-m4a',
];

async function extractAudioDuration(fileUrl: string, mimeType: string): Promise<number | null> {
  if (!AUDIO_MIME_TYPES.includes(mimeType)) {
    return null;
  }

  try {
    const UPLOAD_BASE_DIR = join(process.cwd(), 'uploads');
    let relativePath = fileUrl;
    if (relativePath.includes('://')) {
      const urlObj = new URL(relativePath);
      relativePath = urlObj.pathname;
    }
    relativePath = relativePath.replace('/uploads/', '');
    const filepath = join(UPLOAD_BASE_DIR, relativePath);

    console.log(`Testing file: ${filepath}`);

    const proc = Bun.spawn(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', filepath], {
      stdout: 'pipe',
      stderr: 'pipe',
    });

    const output = await new Response(proc.stdout).text();
    await proc.exited;

    const durationSeconds = parseFloat(output.trim());

    if (!isNaN(durationSeconds) && durationSeconds > 0) {
      const durationMs = Math.round(durationSeconds * 1000);
      console.log(`✅ Duration extracted: ${durationMs}ms (${durationSeconds}s)`);
      return durationMs;
    }

    console.log('⚠️ No duration found');
    return null;
  } catch (error) {
    console.error('❌ Error:', error);
    return null;
  }
}

// Test with actual uploaded file
const testUrl = 'https://api.ppspsched.lat/uploads/attachments/eb308367-5676-44d9-aa2c-9888023742dd.m4a';
const testMimeType = 'audio/mp4';

console.log(`\nTesting audio duration extraction:`);
console.log(`URL: ${testUrl}`);
console.log(`MIME: ${testMimeType}\n`);

const duration = await extractAudioDuration(testUrl, testMimeType);
console.log(`\nFinal result: ${duration}ms`);
