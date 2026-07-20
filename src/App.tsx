import { useState } from 'react';
import { PhaserGame } from '@kbve/laser';
import { GodotGame } from './godot/GodotGame';
import { godotSend } from './godot/bridge';
import { useBusEvent } from './bus';
import { gameConfig } from './game/config';

const fill = { position: 'absolute', inset: 0 } as const;

/**
 * Layer stack (bottom -> top):
 *   1. Godot WASM canvas  — the game surface
 *   2. Phaser overlay     — transparent 2D UI, forwards pointer to Godot
 *   3. React DOM HUD      — ticks/ack readout + control buttons
 * All three talk over the shared bus (src/bus.ts) + the Godot bridge.
 */
export default function App() {
  const [ticks, setTicks] = useState(0);
  const [ack, setAck] = useState('—');

  useBusEvent('godot:tick', () => setTicks((n) => n + 1));
  useBusEvent<Record<string, unknown>>('godot:ack', (p) => setAck(JSON.stringify(p)));

  return (
    <div className="app">
      {/* 1. Godot game (bottom) */}
      <GodotGame />

      {/* 2. Phaser transparent UI overlay */}
      <div className="layer phaser-overlay">
        <PhaserGame config={gameConfig} className="layer" style={fill} />
      </div>

      {/* 3. React DOM HUD (top) */}
      <div className="hud">
        <div>Godot → React ticks: {ticks}</div>
        <div className="hud-ack">last ack: {ack}</div>
        <div className="controls">
          <button onClick={() => godotSend('set_speed', { value: 3 })}>Speed ×3</button>
          <button onClick={() => godotSend('set_speed', { value: 1 })}>Speed ×1</button>
          <button onClick={() => godotSend('set_color', { value: '#38bdf8' })}>Blue</button>
          <button onClick={() => godotSend('set_color', { value: '#f97316' })}>Orange</button>
        </div>
      </div>
    </div>
  );
}
