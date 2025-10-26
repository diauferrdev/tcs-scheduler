import { Hono } from 'hono';

const app = new Hono();

const versionData = {
  version: '1.1.14',
  buildNumber: 52,
  minVersion: '1.0.0',
  forceUpdate: false,
  downloadUrl: {
    android: 'https://appdistribution.firebase.google.com/testerapps/1:874457674237:android:81596c5009b03f9a9fa994/releases/3r29h36k36cgg',
    ios: '',
    web: 'https://ppspsched.lat',
    macos: '',
    windows: '',
    linux: '',
  },
  releaseNotes: {
    'pt-BR': 'Versão 1.1.8 - Correções de estabilidade e melhorias de performance. WebSocket tempo real funcionando corretamente.',
    'en': 'Version 1.1.8 - Stability fixes and performance improvements. Real-time WebSocket working correctly.',
  },
  releaseDate: '2025-10-26T05:34:43-03:00',
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
