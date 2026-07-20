import { useEffect, useRef } from 'react';
import { LaserEventBus } from '@kbve/laser';

/**
 * One app-wide event bus shared by all three layers:
 *   Godot (via src/godot/bridge.ts) -> emits
 *   React (useBusEvent) + Phaser (MainScene) -> subscribe
 *
 * Reuses Laser's LaserEventBus class (see docs/api.md). `on()` returns an
 * unsubscribe fn; `emit(event, payload)` delivers a single payload arg.
 */
export const bus = new LaserEventBus();

/** Subscribe a React component to a bus event for its lifetime. */
export function useBusEvent<T = unknown>(
  event: string,
  handler: (payload: T) => void,
): void {
  // Ref keeps the latest handler without re-subscribing every render.
  const ref = useRef(handler);
  ref.current = handler;
  useEffect(() => {
    const off = bus.on(event, (p: T) => ref.current(p));
    return off;
  }, [event]);
}
