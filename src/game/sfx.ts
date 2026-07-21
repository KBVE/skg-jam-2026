// Synthesized pop blip via WebAudio — no asset files (COEP-safe, self-contained).
let ctx: AudioContext | null = null;
let last = 0;

export function playPop(points = 1): void {
  const now = performance.now();
  if (now - last < 35) return; // throttle bursts
  last = now;
  try {
    ctx ??= new AudioContext();
    if (ctx.state === 'suspended') void ctx.resume();
    const t = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const freq = 320 + Math.min(points, 20) * 22 + Math.random() * 40;
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(freq, t);
    osc.frequency.exponentialRampToValueAtTime(freq * 1.5, t + 0.06);
    gain.gain.setValueAtTime(0.06, t);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.12);
    osc.connect(gain).connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 0.13);
  } catch {
    /* audio unavailable — silent */
  }
}
