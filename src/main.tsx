import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
// Bundled fonts (served same-origin so they survive the game's cross-origin
// isolation / COEP headers — Google Fonts CDN would be blocked under require-corp).
import '@fontsource/fredoka/500.css';
import '@fontsource/fredoka/600.css';
import '@fontsource/fredoka/700.css';
import '@fontsource-variable/nunito';
import './index.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
