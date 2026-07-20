import Phaser from 'phaser';
import { MainScene } from './MainScene';

/**
 * Laser's <PhaserGame> takes a CUSTOM config shape (not raw Phaser GameConfig).
 * It reads: `scenes` (Scene[]), top-level `width`/`height`/`backgroundColor`/
 * `transparent`, and optional passthrough `physics`/`plugins`/`scale`/`input`/
 * `render`/`pixelArt`/`dom`/`audio`/`callbacks`/`fps`. `type` is forced to AUTO.
 */
export const gameConfig = {
  scenes: [MainScene],
  backgroundColor: '#0b0d10',
  physics: {
    default: 'arcade' as const,
    arcade: { gravity: { x: 0, y: 0 }, debug: false },
  },
  scale: {
    mode: Phaser.Scale.RESIZE,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: '100%',
    height: '100%',
  },
};
