import { bus } from '../bus';

/**
 * JS side of the Godot <-> React/Phaser bridge.
 *
 * The React app installs `window.__godotBridge` BEFORE the engine starts.
 * Godot's JsBridge autoload looks it up via JavaScriptBridge.get_interface and:
 *   - calls `emit(event, payloadJson)`      -> we fan out onto the shared bus
 *   - calls `setHandler(cb)`                -> registers its GDScript callback
 * We call `send(cmd, payload)` -> `handler(cmd, json)` -> GDScript `_on_js(args)`.
 *
 * Godot's create_callback delivers JS call arguments as a single Godot Array,
 * so we must pass cmd/json as TWO positional args (args[0], args[1]) — not one
 * packed array.
 */

type GodotHandler = (cmd: string, payloadJson: string) => void;

export interface GodotBridge {
  ready: boolean;
  emit(event: string, payloadJson: string): void;
  setHandler(cb: GodotHandler): void;
  send(cmd: string, payload?: unknown): void;
}

declare global {
  interface Window {
    __godotBridge?: GodotBridge;
    // Godot's index.js attaches the loader class here.
    Engine?: new (config: Record<string, unknown>) => GodotEngine;
  }
}

export interface GodotEngine {
  startGame(override: Record<string, unknown>): Promise<void>;
  requestQuit?(): void;
}

let handler: GodotHandler | null = null;
const pending: Array<[string, unknown]> = [];

function drain(): void {
  if (!handler) return;
  while (pending.length) {
    const [cmd, payload] = pending.shift()!;
    handler(cmd, JSON.stringify(payload ?? {}));
  }
}

/** Install the bridge singleton. Idempotent; call before engine start. */
export function installGodotBridge(): GodotBridge {
  if (window.__godotBridge) return window.__godotBridge;

  const bridge: GodotBridge = {
    ready: false,

    // Godot -> JS
    emit(event, payloadJson) {
      let payload: unknown = null;
      try {
        payload = payloadJson ? JSON.parse(payloadJson) : null;
      } catch {
        payload = payloadJson; // non-JSON: pass raw
      }
      if (event === 'godot:ready') bridge.ready = true;
      bus.emit(event, payload);
    },

    // Godot registers its GDScript callback here.
    setHandler(cb) {
      handler = cb;
      drain(); // flush anything queued before the engine was live
    },

    // JS -> Godot
    send(cmd, payload) {
      if (!handler) {
        pending.push([cmd, payload]); // engine not ready yet
        return;
      }
      handler(cmd, JSON.stringify(payload ?? {}));
    },
  };

  window.__godotBridge = bridge;
  return bridge;
}

/** Convenience for React/Phaser to command Godot. */
export function godotSend(cmd: string, payload?: unknown): void {
  (window.__godotBridge ?? installGodotBridge()).send(cmd, payload);
}
