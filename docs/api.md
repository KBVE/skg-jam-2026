# @kbve/laser API Notes

Notes on `@kbve/laser` (Phaser 4 + React Three Fiber layer for React 19).

**As of `0.1.6` the package ships real types** (`index.d.ts` + `ecs.d.ts` + `mecs.d.ts`),
so the old `declare module '@kbve/laser'` ambient shim in `vite-env.d.ts` has been
**removed** — imports are fully typed. These notes stay as a usage guide; the shipped
types now confirm the gotchas below (e.g. `LaserGameConfig.scenes`, `transparent`).

> History: `0.1.5` shipped no `.d.ts` despite declaring one; we used an ambient shim.
> `0.1.6` (Jul 2026) added the real declarations + a much larger export surface
> (net/protocol, ecs, i18n, promo, physics, webgl helpers).

> See also [`godot.md`](./godot.md) — the Godot (WASM) ⇄ Phaser ⇄ React harness that
> builds on this laser layer (shared `LaserEventBus`, `transparent` Phaser overlay).

## Install / peer deps

```bash
npm install @kbve/laser
```

Peer deps (all optional in package.json, but install what you use):
`react >=18`, `react-dom >=18`, `phaser >=4.1`, `three >=0.160`,
`@react-three/fiber >=9`, `@react-three/drei >=10`, `bitecs >=0.4`,
`@phaserjs/rapier-connector >=1`.

## Exports used

| Export | Kind | Notes |
|---|---|---|
| `PhaserGame` | component (forwardRef) | Mounts a Phaser game. Ref exposes `{ game, status }`. |
| `usePhaserGame()` | hook | Returns `{ game, status }`. **Throws** if used outside `<PhaserGame>`. |
| `usePhaserEvent(evt, cb, sceneKey?)` | hook | Subscribes to a Phaser `EventEmitter`. Must be inside `<PhaserGame>`. |
| `Stage` | component | R3F `<Canvas>` wrapper. Injects an `ambientLight intensity={1.5}`. |
| `useGameLoop(cb)` | hook | R3F `useFrame` wrapper. `cb(delta, elapsedTime)`. Must be inside `<Stage>`. |
| `INVARIANT_EVENT` | const | String `"laser:invariant"`. Generic cross-layer event name. |
| `LaserEventBus` | class | Event bus **class** (not a singleton). `emit`/`on` are instance methods. |
| `laserEvents` | instance | Singleton bus instance laser uses internally (emits `game:ready`, `game:destroy`). |
| `GameClient` | export | (unexplored) |

Full export list also includes a large ECS/game-state surface (bitecs components:
`Health`, `Active`, `Owner`, `Kind`, `EntityStore`, action/event constants
`ACTION_*`, `EPHEMERAL_*`, `PB_*`, i18n `I18nProvider`/`I18nStore`, ad `AdCard`/
`AdRegistry`, etc.) — not yet documented here.

## Gotchas (each cost a real bug during scaffold)

1. **`PhaserGame` config is a CUSTOM shape, NOT raw `Phaser.Types.Core.GameConfig`.**
   It forwards a whitelist and reads different key names:

   ```ts
   {
     scenes: Phaser.Scene[],        // NOT `scene` — a `scene:` key is silently dropped → no scene boots
     width?: number,                // top-level, default 800
     height?: number,               // top-level, default 600
     backgroundColor?: string,
     transparent?: boolean,
     // optional passthroughs (only forwarded if present):
     physics?, plugins?, scale?, input?, render?, pixelArt?, dom?, audio?, callbacks?, fps?,
   }
   ```

   `type` is forced to `Phaser.AUTO` internally — passing `type` does nothing.
   When `scale` is provided, its `width`/`height` win over the top-level defaults.

2. **`useGameLoop` callback signature is `(delta, elapsedTime)`** — delta first
   (derived from R3F `useFrame((state, delta) => cb(delta, state.clock.elapsedTime))`).

3. **`usePhaserEvent` / `usePhaserGame` require a `<PhaserGame>` ancestor.**
   `PhaserGame` renders `<Provider>{ canvasDiv, children }</Provider>`, so any component
   calling these hooks (HUD, event listeners) must be a **child** of `<PhaserGame>`,
   not a sibling. Sibling → `usePhaserGame must be used within a <PhaserGame> component`.

4. **`usePhaserEvent` listens on `game.events`** (or `scene.events` when `sceneKey`
   given) — NOT on `LaserEventBus`/`laserEvents`. To send a Phaser→React event, emit
   from a scene with `this.game.events.emit(name, payload)`.

5. **`LaserEventBus` is a class, not an instance** — `LaserEventBus.emit(...)` throws
   (emit is on the prototype). Use `new LaserEventBus()`, or the exported `laserEvents`
   singleton, or just use `game.events` (see #4).

## Minimal working wiring

```ts
// game/config.ts
export const gameConfig = {
  scenes: [MainScene],
  backgroundColor: '#0b0d10',
  scale: { mode: Phaser.Scale.RESIZE, autoCenter: Phaser.Scale.CENTER_BOTH, width: '100%', height: '100%' },
};
```

```ts
// scene emits heartbeat React can hear
this.time.addEvent({
  delay: 500, loop: true,
  callback: () => this.game.events.emit(INVARIANT_EVENT, { t: this.time.now }),
});
```

```tsx
// App — hooks live INSIDE <PhaserGame>; <Stage> overlays the canvas
<PhaserGame config={gameConfig} className="layer" style={fill}>
  <div className="layer layer-3d">
    <Stage camera={{ position: [0, 0, 5] }}>
      <Cube /> {/* uses useGameLoop((delta) => ...) */}
    </Stage>
  </div>
  <Hud /> {/* uses usePhaserEvent(INVARIANT_EVENT, ...) */}
</PhaserGame>
```

## R3F + React 19 note

Even with laser's own types, `@react-three/fiber`'s **global JSX augmentation**
(`mesh`, `boxGeometry`, lights, …) only enters the type graph when the module is
imported for its side effects. Add `import type {} from '@react-three/fiber'` in any
file using R3F intrinsic elements (see [`src/legacy/R3FExample.tsx`](../src/legacy/R3FExample.tsx)).

## Verified

`npm run build` (tsc + vite) clean. Headless Chrome (SwiftShader): both Phaser
(`webgl`) and R3F (`webgl2`) canvases render; scene boots; `usePhaserEvent` HUD ticks
increment via the `game.events` heartbeat; zero page errors.
