# Godot ⇄ Phaser ⇄ React harness

Hybrid stack: **Godot 4.7 (WASM)** is the game surface, **Phaser 4** is a transparent
2D UI overlay, **React 19** is the DOM shell. All three communicate over one shared
`LaserEventBus` plus a Godot `JavaScriptBridge`.

Companion to [`api.md`](./api.md) (the `@kbve/laser` reference).

## Layer stack (bottom → top)

| z | Layer | File | Renderer |
|---|-------|------|----------|
| 0 | Godot game canvas | [`src/godot/GodotGame.tsx`](../src/godot/GodotGame.tsx) | WebGL2 (GL Compatibility) |
| 1 | Phaser UI overlay (`transparent`) | [`src/game/`](../src/game/) | WebGL2 |
| 2 | React DOM HUD + controls | [`src/App.tsx`](../src/App.tsx) | DOM |

## Data flow

```
Godot (_process heartbeat / acks)
  └─ JsBridge.emit_event(event, json)          [GDScript]
       └─ window.__godotBridge.emit(event, json)   [src/godot/bridge.ts]
            └─ bus.emit(event, payload)             [src/bus.ts]
                 ├─ React  : useBusEvent('godot:tick' | 'godot:ack')
                 └─ Phaser : bus.on('godot:tick')   [MainScene]

React/Phaser
  └─ godotSend(cmd, payload)                    [src/godot/bridge.ts]
       └─ handler(cmd, json)                    (Godot callback via create_callback)
            └─ JsBridge._on_js(args)            [GDScript] → Main.handle_command
```

Events: `godot:ready`, `godot:tick` (`{frame, rot, speed}`), `godot:ack` (`{cmd, ...}`).
Commands: `set_speed {value}`, `set_color {value:'#hex'}`, `pointer {x,y}` (Phaser input forwarding).

## The bridge (critical details)

- **Install order:** `installGodotBridge()` runs **before** `engine.startGame`, because
  Godot's `JsBridge` autoload looks up `window.__godotBridge` on `_ready`.
- **`create_callback` arg shape:** Godot delivers JS call arguments as a single Godot
  Array. So JS calls `handler(cmd, json)` (two positional args) → GDScript reads
  `args[0]` / `args[1]`. Do **not** pack them into one array.
- **Pre-ready sends** are queued in `bridge.ts` and drained when Godot calls `setHandler`.

## Threaded export → cross-origin isolation (required)

The Web preset uses `variant/thread_support=true`, so the engine needs `SharedArrayBuffer`,
which needs the page to be **cross-origin isolated**:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

- **Dev + preview:** set in [`vite.config.ts`](../vite.config.ts) (`server.headers` / `preview.headers`).
  Verify with `self.crossOriginIsolated === true` in the console.
- **Production:** the host MUST send the same two headers on every response. Examples:
  - Netlify — a `public/_headers` file with `/*` → the two headers.
  - Cloudflare Pages — `_headers`, or a Worker/Transform Rule.
  - Nginx/Apache/`vite preview` — add response headers globally.
  Without them the threaded build fails to boot (`SharedArrayBuffer is not defined`).

To go header-free instead, re-export with `thread_support=false` (single-thread); no headers
needed, slightly slower engine.

## Engine loader gotcha (dynamic script)

Godot's `index.js` derives its asset base from `document.currentScript.src`, which is **null
for a dynamically-injected async `<script>`**. So `GodotGame` sets **absolute** paths:
`executable: '/godot/index'`, `mainPack: '/godot/index.pck'`. Otherwise the loader fetches
`/index.wasm`, gets the SPA `index.html` fallback, and dies with
`WebAssembly.instantiateStreaming(): expected magic word ...`.

## Build / export workflow

```bash
# Prereqs: Godot 4.7.1 editor + matching Web export templates
npm run build:godot   # godot --headless --path godot --import && --export-release "Web" -> public/godot/
npm run dev           # or: npm run build && npm run preview
```

- Godot **source** lives in [`godot/`](../godot/) (committed).
- Export **output** lands in `public/godot/` (**gitignored** — `index.wasm` is ~37 MB;
  regenerate with `build:godot`).
- Editor cache `godot/.godot/` is gitignored too.

## Verified

`npm run build` clean. Headless Chrome (SwiftShader, COEP-compatible): `crossOriginIsolated
=== true`, Godot v4.7.1 boots on `#godot-canvas` (WebGL2), Phaser overlay renders transparent,
`godot:tick` increments both the React HUD and the Phaser overlay in sync, and a React
`set_speed` click round-trips back as a `godot:ack`. Screenshot shows all three layers composited.
