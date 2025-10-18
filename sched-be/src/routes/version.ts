import { Hono } from 'hono';

const app = new Hono();

app.get('/current', (c) => {
  return c.json({
    version: '1.0.11',
    buildNumber: 30,
    minVersion: '1.0.0',
    forceUpdate: false,
    downloadUrl: {
      android: 'https://appdistribution.firebase.google.com/testerapps/1:874457674237:android:81596c5009b03f9a9fa994/releases/3r29h36k36cgg',
      ios: '',
      web: '',
      macos: '',
      windows: '',
      linux: '',
    },
    releaseNotes: {
      'pt-BR': 'Versão 1.0.10 - CORREÇÃO CRÍTICA: resolvido problema intermitente de loading infinito após criar agendamentos. Agora funciona 100% das vezes. Corrigida navegação automática após criar booking.',
      'en': 'Version 1.0.10 - CRITICAL FIX: resolved intermittent infinite loading issue after creating bookings. Now works 100% of the time. Fixed automatic navigation after booking creation.',
    },
    releaseDate: '2025-10-18T14:54:51-03:00',
    critical: false,
  });
});

export default app;
