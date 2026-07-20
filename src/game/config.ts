import Phaser from 'phaser';
import { MainScene } from './MainScene';

/**
 * Laser's <PhaserGame> takes a CUSTOM config shape (see docs/api.md), reading
 * `scenes` (not `scene`) + top-level `width`/`height`/`backgroundColor`/`transparent`.
 *
 * `transparent: true` so this Phaser canvas overlays the Godot game beneath it.
 */
export const gameConfig = {
  scenes: [MainScene],
  transparent: true,
  scale: {
    mode: Phaser.Scale.RESIZE,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: '100%',
    height: '100%',
  },
};
