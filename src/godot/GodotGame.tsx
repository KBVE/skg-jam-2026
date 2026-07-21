import { useEffect, useRef, useState } from 'react';
import { installGodotBridge } from './bridge';

/** Inject a classic <script> once; resolve on load. */
function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[data-godot="${src}"]`)) {
      resolve();
      return;
    }
    const el = document.createElement('script');
    el.src = src;
    el.async = true;
    el.dataset.godot = src;
    el.onload = () => resolve();
    el.onerror = () => reject(new Error(`failed to load ${src}`));
    document.body.appendChild(el);
  });
}

// Config mirrors the exported index.html's GODOT_CONFIG (threaded pools included).
// `executable`/`mainPack` are RELATIVE (godot/...): Godot's loader normally
// derives its base from document.currentScript.src, but that is null for a
// dynamically-injected async <script>, so it would otherwise fetch index.wasm
// from the wrong place. Relative paths resolve against the document base URL,
// which works both at the local origin root and under itch.io's CDN subpath
// (absolute /godot/... would 403 there, hitting the CDN root instead).
const ENGINE_CONFIG = {
  executable: 'godot/index',
  mainPack: 'godot/index.pck',
  canvasResizePolicy: 2,
  ensureCrossOriginIsolationHeaders: true,
  experimentalVK: false,
  focusCanvas: true,
  gdextensionLibs: [],
  emscriptenPoolSize: 8,
  godotPoolSize: 4,
  args: [],
} as const;

/** Mounts the Godot WASM game onto its own canvas (the bottom render layer). */
export function GodotGame() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const startedRef = useRef(false); // guards StrictMode double-mount
  const [progress, setProgress] = useState(0);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;

    // Bridge must exist before the engine boots (Godot looks it up on _ready).
    installGodotBridge();

    // NOTE: no `cancelled` flag here on purpose. `startedRef` already guarantees
    // a single boot across StrictMode's mount→cleanup→mount cycle; cancelling on
    // the interim cleanup would abort the only boot before startGame is called.
    loadScript('godot/index.js')
      .then(async () => {
        const Engine = window.Engine;
        if (!Engine) throw new Error('Godot Engine loader not found on window');
        const engine = new Engine({ ...ENGINE_CONFIG });
        await engine.startGame({
          canvas: canvasRef.current!,
          onProgress: (current: number, total: number) => {
            if (total > 0) setProgress(Math.round((current / total) * 100));
          },
        });
        setReady(true);
      })
      .catch((e: unknown) => {
        setError(e instanceof Error ? e.message : String(e));
      });
  }, []);

  return (
    <div className="layer godot-layer">
      <canvas ref={canvasRef} id="godot-canvas" />
      {!ready && !error && (
        <div className="godot-overlay">Loading Godot… {progress}%</div>
      )}
      {error && <div className="godot-overlay godot-error">Godot failed: {error}</div>}
    </div>
  );
}
