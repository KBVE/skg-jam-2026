import { useRef, useState } from 'react';
import { useBusEvent } from '../bus';
import type { DebugToastPayload } from '../game/events';

/**
 * On-screen debug toast stack. Godot (or any layer) fires `game:debug_toast` with
 * `{ text, key? }`; each shows a small toast top-right that auto-dismisses.
 *
 * Debounced by `key` (defaults to the text): a repeat of the same key within
 * DEBOUNCE_MS is dropped, so a message fired every frame won't spam the user.
 */
const DEBOUNCE_MS = 800;   // min gap between two toasts sharing a key
const DISMISS_MS = 2600;   // how long a toast stays on screen
const MAX_TOASTS = 5;      // cap the visible stack

interface Toast {
  id: number;
  text: string;
}

export function DebugToast() {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const lastSeen = useRef<Map<string, number>>(new Map());
  const nextId = useRef(0);

  useBusEvent<DebugToastPayload>('game:debug_toast', (p) => {
    if (!p || typeof p.text !== 'string') return;
    const key = p.key ?? p.text;
    const now = performance.now();
    const prev = lastSeen.current.get(key) ?? -Infinity;
    if (now - prev < DEBOUNCE_MS) return; // debounce: drop the repeat
    lastSeen.current.set(key, now);

    const id = nextId.current++;
    setToasts((cur) => [...cur, { id, text: p.text }].slice(-MAX_TOASTS));
    window.setTimeout(() => {
      setToasts((cur) => cur.filter((t) => t.id !== id));
    }, DISMISS_MS);
  });

  if (toasts.length === 0) return null;

  return (
    <div className="debug-toasts">
      {toasts.map((t) => (
        <div key={t.id} className="debug-toast">{t.text}</div>
      ))}
    </div>
  );
}
