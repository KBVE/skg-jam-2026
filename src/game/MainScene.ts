import Phaser from 'phaser';
import { bus } from '../bus';
import type { PopPayload } from './events';

/**
 * Transparent FX overlay above the Godot canvas. Draws a floating "+N" that
 * rises and fades at each pop's screen position (input passes through — the
 * overlay is pointer-events:none in CSS).
 */
export class MainScene extends Phaser.Scene {
  private off?: () => void;

  constructor() {
    super({ key: 'MainScene' });
  }

  create(): void {
    this.off = bus.on('game:pop', (p: unknown) => this.spawnPop(p as PopPayload));
    this.events.once('shutdown', () => this.off?.());
  }

  private spawnPop(p: PopPayload): void {
    if (!p || (p.x === 0 && p.y === 0)) return;
    const color = p.points >= 10 ? '#fbbf24' : '#ffffff';
    const label = this.add
      .text(p.x, p.y, `+${p.points}`, {
        color,
        fontFamily: 'system-ui, sans-serif',
        fontSize: p.points >= 10 ? '22px' : '16px',
        fontStyle: 'bold',
      })
      .setOrigin(0.5)
      .setDepth(10);
    this.tweens.add({
      targets: label,
      y: p.y - 42,
      alpha: 0,
      duration: 650,
      ease: 'Cubic.easeOut',
      onComplete: () => label.destroy(),
    });
  }
}
