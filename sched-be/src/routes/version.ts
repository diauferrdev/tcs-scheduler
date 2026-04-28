import { Hono } from 'hono';

const app = new Hono();

const versionData = {
  version: '1.2.14',
  buildNumber: 120,
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
