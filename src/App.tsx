import { PhaserGame } from '@kbve/laser';
import { GodotGame } from './godot/GodotGame';
import { Hud } from './components/Hud';
import { gameConfig } from './game/config';

const fill = { position: 'absolute', inset: 0 } as const;

/**
 * Layer stack (bottom -> top):
 *   1. Godot WASM canvas — the game (bubbles), takes clicks natively
 *   2. Phaser overlay    — transparent FX, pointer-events:none
 *   3. React DOM HUD      — score/time + start/restart, routed off game:state
 */
export default function App() {
  return (
    <div className="app">
      <GodotGame />

      <div className="layer phaser-overlay">
        <PhaserGame config={gameConfig} className="layer" style={fill} />
      </div>

      <Hud />
    </div>
  );
}
