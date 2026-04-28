import { Hono } from 'hono';

const app = new Hono();

const versionData = {
  version: '1.2.13',
  buildNumber: 119,
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
    'pt-BR': 'Manager/Admin agora podem registrar eventos passados de qualquer tipo (Innovation Exchange, Hackathon).',
    'en': 'Manager/Admin can now register past events of any engagement type (Innovation Exchange, Hackathon).',
  },
  releaseDate: '2026-04-28T15:30:00-03:00',
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
