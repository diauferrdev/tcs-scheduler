import { Hono } from 'hono';
import { join } from 'path';

const app = new Hono();

// Single source of truth for the app version is the Flutter pubspec.yaml
// (format: `version: 1.2.14+120`). The backend reads it at startup so the
// /version endpoint never drifts from the shipped client. Falls back to the
// literals below if the file can't be read (e.g. backend deployed alone).
const FALLBACK_VERSION = '1.2.14';
const FALLBACK_BUILD = 120;

async function readPubspecVersion(): Promise<{ version: string; buildNumber: number }> {
  try {
    // version.ts -> src/routes; pubspec lives at ../../../sched-fe/pubspec.yaml
    const pubspecPath = join(import.meta.dir, '../../../sched-fe/pubspec.yaml');
    const content = await Bun.file(pubspecPath).text();
    const match = content.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)/m);
    if (match) {
      return { version: match[1], buildNumber: parseInt(match[2], 10) };
    }
    console.warn('[version] pubspec.yaml did not match expected version format, serving fallback version', {
      fallbackVersion: FALLBACK_VERSION,
      fallbackBuild: FALLBACK_BUILD,
    });
  } catch (error) {
    console.warn('[version] Could not read pubspec.yaml, serving fallback version', {
      fallbackVersion: FALLBACK_VERSION,
      fallbackBuild: FALLBACK_BUILD,
      error,
    });
  }
  return { version: FALLBACK_VERSION, buildNumber: FALLBACK_BUILD };
}

const { version, buildNumber } = await readPubspecVersion();

const versionData = {
  version,
  buildNumber,
  minVersion: '1.0.0',
  forceUpdate: false,
  downloadUrl: {
    android: 'https://appdistribution.firebase.google.com/testerapps/1:874457674237:android:81596c5009b03f9a9fa994/releases/3r29h36k36cgg',
    ios: '',
    web: 'https://pacesched.com',
    macos: '',
    windows: '',
    linux: '',
  },
  releaseNotes: {
    'pt-BR': 'Adicionada opção OTHERS no dropdown de Vertical.',
    'en': 'Added OTHERS option to the Vertical dropdown.',
  },
  releaseDate: '2026-04-28T17:35:00-03:00',
  critical: false,
};

// Endpoint usado pelo frontend: GET /version
app.get('/', (c) => {
  return c.json(versionData);
});

// Backward compatibility: GET /current
app.get('/current', (c) => {
  return c.json(versionData);
});

export default app;
