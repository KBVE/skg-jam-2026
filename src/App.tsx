import { useState } from 'react';
// Pull in R3F's global JSX augmentation (mesh, boxGeometry, lights, …).
// Needed because Laser re-exports <Stage> but ships no types, so the
// @react-three/fiber module would otherwise never enter the type graph.
import type {} from '@react-three/fiber';
import {
  PhaserGame,
  Stage,
  useGameLoop,
  usePhaserEvent,
  INVARIANT_EVENT,
} from '@kbve/laser';
import { gameConfig } from './game/config';

const fill = { position: 'absolute', inset: 0 } as const;

/** Spinning cube driven by Laser's frame-synced loop. cb(delta, elapsed). */
function Cube() {
  const [r, setR] = useState(0);
  useGameLoop((delta: number) => setR((v) => v + delta));
  return (
    <mesh rotation={[r, r * 0.6, 0]}>
      <boxGeometry args={[1.4, 1.4, 1.4]} />
      <meshStandardMaterial color="#f97316" />
    </mesh>
  );
}

/**
 * HUD mirrors the Phaser heartbeat. usePhaserEvent taps game.events, so it
 * MUST render inside <PhaserGame> (it calls usePhaserGame() context).
 */
function Hud() {
  const [ticks, setTicks] = useState(0);
  usePhaserEvent(INVARIANT_EVENT, () => setTicks((n) => n + 1));
  return <div className="hud">Phaser → React ticks: {ticks}</div>;
}

export default function App() {
  return (
    <div className="app">
      <PhaserGame config={gameConfig} className="layer" style={fill}>
        {/* 3D layer — R3F via Laser <Stage>, overlaid on the Phaser canvas */}
        <div className="layer layer-3d">
          <Stage camera={{ position: [0, 0, 5] }}>
            <directionalLight position={[4, 4, 4]} />
            <Cube />
          </Stage>
        </div>

        <Hud />
      </PhaserGame>
    </div>
  );
}
