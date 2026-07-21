import { useState } from 'react';
import { useBusEvent } from '../bus';
import type { PopPayload } from '../game/events';

interface Pop {
  id: number;
  x: number;
  y: number;
  points: number;
}

let seq = 0;

/**
 * Floating "+N" score popups, rendered in the React (DOM) layer at each pop's
 * screen position (game:pop carries x,y from Godot). pointer-events:none so
 * clicks still reach the Godot canvas.
 */
export function PopPoints() {
  const [pops, setPops] = useState<Pop[]>([]);

  useBusEvent<PopPayload>('game:pop', (p) => {
    if (!p || (p.x === 0 && p.y === 0)) return;
    const id = ++seq;
    setPops((cur) => [...cur, { id, x: p.x, y: p.y, points: p.points }]);
    window.setTimeout(() => setPops((cur) => cur.filter((q) => q.id !== id)), 700);
  });

  return (
    <div className="pop-points">
      {pops.map((p) => (
        <span
          key={p.id}
          className={`pop-point${p.points >= 10 ? ' big' : ''}`}
          style={{ left: p.x, top: p.y }}
        >
          +{p.points}
        </span>
      ))}
    </div>
  );
}
