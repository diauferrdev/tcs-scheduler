{{flutter_js}}
{{flutter_build_config}}

// Custom Flutter Bootstrap with Loading Progress
const splash = document.getElementById('web-splash');
const loadingText = document.getElementById('loading-text');

console.log('[Flutter Bootstrap] Starting initialization...');

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    console.log('[Flutter Bootstrap] Entrypoint loaded, initializing engine...');
    if (loadingText) {
      loadingText.textContent = 'Initializing...';
    }

    const appRunner = await engineInitializer.initializeEngine();

    console.log('[Flutter Bootstrap] Engine initialized, running app...');
    if (loadingText) {
      loadingText.textContent = 'Starting...';
    }

    await appRunner.runApp();

    console.log('[Flutter Bootstrap] App running successfully!');
  }
});
