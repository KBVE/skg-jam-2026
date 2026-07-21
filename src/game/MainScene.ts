import Phaser from 'phaser';

/**
 * Transparent Phaser overlay above the Godot canvas. Score "+N" popups now
 * render in the React layer (see PopPoints.tsx); this scene is kept as a
 * pointer-events:none FX surface for future particle work.
 */
export class MainScene extends Phaser.Scene {
  constructor() {
    super({ key: 'MainScene' });
  }

  create(): void {
    // Reserved for particle FX; input passes through to the Godot canvas.
  }
}
