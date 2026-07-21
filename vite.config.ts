import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Threaded Godot web exports use SharedArrayBuffer, which requires cross-origin
// isolation. These headers make `crossOriginIsolated === true` in dev + preview.
// Prod hosts must send the same headers (see docs/godot.md).
const crossOriginIsolation = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
};

// https://vite.dev/config/
export default defineConfig({
  // itch.io serves the game from a CDN subpath, so emit relative asset URLs
  // ("./assets/...") instead of absolute ("/assets/...") which 403 there.
  base: './',
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    headers: crossOriginIsolation,
  },
  preview: {
    headers: crossOriginIsolation,
  },
  optimizeDeps: {
    include: ['phaser', 'three', '@react-three/fiber', '@react-three/drei'],
  },
});
