import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
  },
  // Phaser 4 + three are big; keep them out of pre-bundle churn.
  optimizeDeps: {
    include: ['phaser', 'three', '@react-three/fiber', '@react-three/drei'],
  },
});
