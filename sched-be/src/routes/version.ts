import { Hono } from 'hono';

const app = new Hono();

const versionData = {
  version: '1.2.11',
  buildNumber: 117,
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
    'pt-BR': 'Melhorias na interface de bug reports: layout otimizado, botão de upvote reposicionado, rollback automático de anexos em caso de falha, e grid compacto de arquivos.',
    'en': 'Bug report UI improvements: optimized layout, repositioned upvote button, automatic attachment rollback on failure, and compact file grid.',
  },
  releaseDate: '2025-11-03T07:34:26-03:00',
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
