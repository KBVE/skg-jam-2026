import Phaser from 'phaser';
import { bus } from '../bus';
import { godotSend } from '../godot/bridge';

/**
 * Phaser UI overlay scene (transparent). Two roles in the harness:
 *   - subscribes to the shared bus and mirrors Godot's heartbeat as 2D text
 *   - forwards pointer input to Godot via the bridge (godotSend 'pointer')
 */
export class MainScene extends Phaser.Scene {
  private label!: Phaser.GameObjects.Text;
  private ticks = 0;
  private off?: () => void;

  constructor() {
    super({ key: 'MainScene' });
  }

  create(): void {
    const { width } = this.scale;

    this.label = this.add
      .text(width / 2, 24, 'Phaser overlay • godot ticks: 0', { color: '#7dd3fc' })
      .setOrigin(0.5, 0);

    // Godot -> bus -> Phaser text.
    this.off = bus.on('godot:tick', () => {
      this.ticks += 1;
      this.label.setText(`Phaser overlay • godot ticks: ${this.ticks}`);
    });

    // Phaser overlay -> Godot (input forwarding).
    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => {
      godotSend('pointer', { x: Math.round(p.x), y: Math.round(p.y) });
    });

    this.events.once('shutdown', () => this.off?.());
  }
}
