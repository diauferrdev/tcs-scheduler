import { Hono } from 'hono';

const app = new Hono();

app.get('/current', (c) => {
  return c.json({
    version: '1.0.1',
    buildNumber: 2,
    minVersion: '1.0.0',
    forceUpdate: false,
    downloadUrl: {
      android: 'https://appdistribution.firebase.google.com/testerapps/1:874457674237:android:1ed8bb845b3e949d9fa994/releases/59bpp77qqkbf0',
      ios: '',
      web: '',
      macos: '',
      windows: '',
      linux: '',
    },
    releaseNotes: {
      'pt-BR': 'Testing',
      'en': 'Version 1.0.1 - Improvements and fixes.',
    },
    releaseDate: '2025-10-12T01:22:58-03:00',
    critical: false,
  });
});

export default app;
