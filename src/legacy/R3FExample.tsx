// PARKED: original R3F demo from the first scaffold (PR #1).
// Godot now owns the 3D/game layer, so this is no longer mounted in App.
// Kept (with deps) as a reference for laser's <Stage> + useGameLoop usage.
// See docs/api.md for the laser API.
import type {} from '@react-three/fiber';
import { useState } from 'react';
import { Stage, useGameLoop } from '@kbve/laser';

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

export function R3FExample() {
  return (
    <div className="layer layer-3d">
      <Stage camera={{ position: [0, 0, 5] }}>
        <directionalLight position={[4, 4, 4]} />
        <Cube />
      </Stage>
    </div>
  );
}
