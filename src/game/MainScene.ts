import Phaser from 'phaser';
import { INVARIANT_EVENT } from '@kbve/laser';

/**
 * Minimal Phaser 4 scene. Bouncing box + a heartbeat emitted on the game's
 * EventEmitter, which Laser's usePhaserEvent(INVARIANT_EVENT) subscribes to.
 */
export class MainScene extends Phaser.Scene {
  constructor() {
    super({ key: 'MainScene' });
  }

  create(): void {
    const { width, height } = this.scale;

    this.add
      .text(width / 2, 40, 'Phaser layer', { color: '#7dd3fc' })
      .setOrigin(0.5);

    const box = this.add.rectangle(width / 2, height / 2, 64, 64, 0x38bdf8);
    this.tweens.add({
      targets: box,
      y: height - 120,
      duration: 900,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    });

    // Heartbeat on the game EventEmitter → reaches usePhaserEvent in React.
    this.time.addEvent({
      delay: 500,
      loop: true,
      callback: () => this.game.events.emit(INVARIANT_EVENT, { t: this.time.now }),
    });
  }
}
