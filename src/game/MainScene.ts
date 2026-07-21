import Phaser from 'phaser';

/**
 * Transparent FX overlay. Pop particles / floating text land here in a later
 * milestone (M5). Input passes through to the Godot canvas beneath — the
 * overlay is pointer-events:none in CSS.
 */
export class MainScene extends Phaser.Scene {
  constructor() {
    super({ key: 'MainScene' });
  }

  create(): void {
    // FX only for now.
  }
}
