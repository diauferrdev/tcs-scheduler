import { defineConfig } from '@rsbuild/core';
import { pluginReact } from '@rsbuild/plugin-react';

export default defineConfig({
  plugins: [pluginReact()],
  html: {
    template: './index.html',
  },
  server: {
    publicDir: {
      name: 'public',
      copyOnBuild: true,
    },
  },
  output: {
    copy: [
      { from: 'public', to: '.' }
    ]
  },
  dev: {
    hmr: true,
    liveReload: true,
  },
});
