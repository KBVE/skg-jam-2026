# Bubble Roguelite — M1 Core Run — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A playable core loop — a Godot grid of poppable bubbles, native click-to-pop, a countdown timer, live score, and a React HUD with start/restart — all wired over the existing bridge.

**Architecture:** Godot 4.7 + GECS owns the run (bubbles as entities, pop/score via systems, timer + state in a RunController). React owns the HUD + start/restart and routes off `game:state`. Phaser overlay stays FX-only and `pointer-events:none` so clicks reach the Godot canvas natively.

**Tech Stack:** Godot 4.7 (GL Compatibility/WebGL2, threaded export), GECS 9.1.0, React 19 + Vite, `@kbve/laser` bus, JavaScriptBridge.

## Global Constraints

- Godot rendering: `gl_compatibility` (WebGL2); threaded web export; export → `public/godot/` (gitignored).
- Bridge events are `game:*`, JSON payloads, over `window.__godotBridge` ↔ shared `bus` (docs/godot.md).
- GECS: `.with_all` component queries, lightweight components, early-exit systems (docs perf guide).
- `ECS.world` must be added to the tree BEFORE assignment (setter auto-parents to "Root" otherwise).
- Bridge `create_callback` delivers JS args as `handler(cmd, json)` (two positional args).
- Retire the spin-cube demo; `run/main_scene` → `Game.tscn`.
- No Claude co-author trailer in commits.

---

## File Structure

**Godot (`godot/`)**
- `scenes/Game.tscn` — Node2D root, Camera2D, `Board` (Node2D), script = run_controller.gd. New main scene.
- `scripts/game/config.gd` — tuning constants (static).
- `scripts/game/run_controller.gd` — state machine, world setup, input→pop, timer, bridge wiring, HUD emits.
- `scripts/game/board.gd` — spawn sheet, grid↔world mapping, entity-at-cell lookup.
- `scripts/components/c_bubble.gd` — `hp: int`.
- `scripts/components/c_cell.gd` — `row: int, col: int`.
- `scripts/components/c_popped.gd` — transient tag.
- `scripts/components/c_run_stats.gd` — `score: int, pops: int` (singleton entity).
- `scripts/systems/score_system.gd` — consume `C_Popped` → award score → emit `game:pop` → remove entity.
- Delete: `scripts/Main.gd`, `scenes/Main.tscn`, `scripts/components/c_spin.gd`, `scripts/systems/spin_system.gd` (spin demo).

**JS/React (`src/`)**
- `src/game/events.ts` — typed `game:*` event names + payload types + `GameState`.
- `src/components/Hud.tsx` — score + time bar + start/restart, routed off `game:state`.
- `src/App.tsx` — mount `GodotGame` + Phaser overlay (FX-only) + `<Hud/>`; remove old tick/ack demo controls.
- `src/game/MainScene.ts` — strip pointer-forwarding + tick text; keep as empty FX-ready overlay (`pointer-events:none`).
- `src/index.css` — overlay `pointer-events:none`; HUD styles.

---

## Task 1: Retire the spin-cube demo, add the 2D Game scene skeleton

**Files:**
- Create: `godot/scenes/Game.tscn`, `godot/scripts/game/config.gd`, `godot/scripts/game/run_controller.gd`
- Modify: `godot/project.godot` (`run/main_scene`)
- Delete: `godot/scenes/Main.tscn`, `godot/scripts/Main.gd`, `godot/scripts/components/c_spin.gd`, `godot/scripts/systems/spin_system.gd`

**Interfaces:**
- Produces: `RunController` autoruns as main scene; `Config` static constants.

- [ ] **Step 1: config.gd**
```gdscript
class_name Config
extends RefCounted

const BASE_TIME := 60.0
const GRID_COLS := 8
const GRID_ROWS := 6
const CELL := 72.0          # px between cell centers
const BUBBLE_RADIUS := 30.0
const SCORE_PLAIN := 1
```

- [ ] **Step 2: Game.tscn** (Node2D + Camera2D centered on the grid + Board node)
```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/game/run_controller.gd" id="1"]
[node name="Game" type="Node2D"]
script = ExtResource("1")
[node name="Camera3D_placeholder" type="Node" parent="."]
[node name="Camera2D" type="Camera2D" parent="."]
[node name="Board" type="Node2D" parent="."]
```
(Camera2D position is set in code to the grid center; the placeholder node is removed — see Step 3. Keep only Camera2D + Board.)

Final scene nodes: `Game` (Node2D, script), `Camera2D`, `Board` (Node2D).

- [ ] **Step 3: run_controller.gd skeleton** (state enum + bridge target + Camera centering; systems added in Task 4)
```gdscript
extends Node2D
## Owns the run: state machine, timer, input, and bridge HUD emits.

enum State { IDLE, PLAYING, SHEET_CLEAR, GAME_OVER }

var _state: int = State.IDLE
var _time_left := 0.0
var _sheet := 0

@onready var _camera: Camera2D = $Camera2D
@onready var _board: Node2D = $Board


func _ready() -> void:
	JsBridge.register_target(self)
	# Center camera on the grid.
	_camera.position = Vector2(
		(Config.GRID_COLS - 1) * Config.CELL * 0.5,
		(Config.GRID_ROWS - 1) * Config.CELL * 0.5,
	)
	_set_state(State.IDLE)


func _set_state(s: int) -> void:
	_state = s
	JsBridge.emit_event("game:state", {"state": State.keys()[s]})


func handle_command(cmd: String, payload: Dictionary) -> void:
	match cmd:
		"start_run":
			_start_run(payload)
		"restart":
			_start_run(payload)


func _start_run(_payload: Dictionary) -> void:
	_sheet = 0
	_time_left = Config.BASE_TIME
	_set_state(State.PLAYING)
	# board spawn + systems wired in later tasks
```

- [ ] **Step 4: project.godot main scene**
Change `run/main_scene="res://scenes/Main.tscn"` → `run/main_scene="res://scenes/Game.tscn"`.

- [ ] **Step 5: delete spin demo files**
```bash
git rm godot/scenes/Main.tscn godot/scripts/Main.gd godot/scripts/components/c_spin.gd godot/scripts/systems/spin_system.gd godot/scripts/Main.gd.uid godot/scripts/components/c_spin.gd.uid godot/scripts/systems/spin_system.gd.uid
```

- [ ] **Step 6: import + verify no errors**
Run: `godot --headless --path godot --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v update_scripts`
Expected: no output.

- [ ] **Step 7: Commit**
```bash
git add -A && git commit -m "feat(game): replace spin demo with 2D Game scene skeleton"
```

---

## Task 2: Bubble components + Board sheet spawn

**Files:**
- Create: `godot/scripts/components/c_bubble.gd`, `c_cell.gd`, `godot/scripts/game/board.gd`
- Modify: `godot/scenes/Game.tscn` (attach board.gd to Board node)

**Interfaces:**
- Produces: `Board.spawn_sheet(world, sheet_index)`, `Board.cell_at(world_pos) -> Vector2i` (col,row) or `Vector2i(-1,-1)`, `Board.entity_at(cell) -> Entity`.
- Consumes: `Config`.

- [ ] **Step 1: c_bubble.gd**
```gdscript
class_name C_Bubble
extends Component
@export var hp: int = 1
```

- [ ] **Step 2: c_cell.gd**
```gdscript
class_name C_Cell
extends Component
@export var col: int = 0
@export var row: int = 0
```

- [ ] **Step 3: board.gd** (spawns plain bubbles; each entity has a ColorRect child "Mesh" for visuals + click hit test by grid math)
```gdscript
class_name Board
extends Node2D

var _by_cell := {}   # Vector2i -> Entity


func clear() -> void:
	_by_cell.clear()


func cell_center(col: int, row: int) -> Vector2:
	return Vector2(col * Config.CELL, row * Config.CELL)


func cell_at(world_pos: Vector2) -> Vector2i:
	var c := int(round(world_pos.x / Config.CELL))
	var r := int(round(world_pos.y / Config.CELL))
	if c < 0 or c >= Config.GRID_COLS or r < 0 or r >= Config.GRID_ROWS:
		return Vector2i(-1, -1)
	# reject clicks outside the bubble radius
	if world_pos.distance_to(cell_center(c, r)) > Config.BUBBLE_RADIUS:
		return Vector2i(-1, -1)
	return Vector2i(c, r)


func entity_at(cell: Vector2i) -> Entity:
	return _by_cell.get(cell, null)


func remove_cell(cell: Vector2i) -> void:
	_by_cell.erase(cell)


func spawn_sheet(world: World, _sheet_index: int) -> void:
	clear()
	for r in Config.GRID_ROWS:
		for c in Config.GRID_COLS:
			var e := Entity.new()
			e.name = "Bubble_%d_%d" % [c, r]
			e.add_component(C_Bubble.new())
			var cell := C_Cell.new()
			cell.col = c
			cell.row = r
			e.add_component(cell)
			var rect := ColorRect.new()
			rect.name = "Mesh"
			rect.color = Color(0.22, 0.74, 0.97)
			rect.size = Vector2(Config.BUBBLE_RADIUS * 2, Config.BUBBLE_RADIUS * 2)
			rect.position = cell_center(c, r) - Vector2(Config.BUBBLE_RADIUS, Config.BUBBLE_RADIUS)
			e.add_child(rect)
			world.add_entity(e)
			# Reparent visual into the board so it renders in 2D space.
			add_child(e)
			_by_cell[Vector2i(c, r)] = e
```
Note: `world.add_entity(e)` registers the entity + parents it under the World node. We ALSO need the ColorRect visible in 2D; simplest is to keep the ColorRect as a child of the entity and let the entity live under the World (which is under Game/Node2D), so the ColorRect inherits the 2D canvas transform. Verify visually in Task 5; if the World node breaks CanvasItem transform, move the ColorRect to be a direct child of Board at `cell_center` and store it on the entity via `set_meta("rect", rect)` instead.

- [ ] **Step 4: attach board.gd to the Board node in Game.tscn**
Edit `Game.tscn`: add board script ext_resource and `script = ...` on the Board node.

- [ ] **Step 5: import + verify**
Run: `godot --headless --path godot --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v update_scripts`
Expected: no output.

- [ ] **Step 6: Commit**
```bash
git add -A && git commit -m "feat(game): bubble components + board sheet spawn"
```

---

## Task 3: Run stats singleton + ScoreSystem (pop → score → emit → remove)

**Files:**
- Create: `godot/scripts/components/c_popped.gd`, `c_run_stats.gd`, `godot/scripts/systems/score_system.gd`

**Interfaces:**
- Produces: `ScoreSystem` (queries `C_Popped`); `C_RunStats{score,pops}` singleton read by RunController.
- Consumes: `C_Bubble`, `C_Cell`, `Board.remove_cell`.

- [ ] **Step 1: c_popped.gd**
```gdscript
class_name C_Popped
extends Component
```

- [ ] **Step 2: c_run_stats.gd**
```gdscript
class_name C_RunStats
extends Component
@export var score: int = 0
@export var pops: int = 0
```

- [ ] **Step 3: score_system.gd**
```gdscript
class_name ScoreSystem
extends System

var stats_entity: Entity   # injected by RunController
var board: Board           # injected by RunController


func query() -> QueryBuilder:
	return q.with_all([C_Popped])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	if entities.is_empty():
		return
	var stats := stats_entity.get_component(C_RunStats) as C_RunStats
	for entity in entities:
		stats.score += Config.SCORE_PLAIN
		stats.pops += 1
		var cell := entity.get_component(C_Cell) as C_Cell
		if cell and board:
			board.remove_cell(Vector2i(cell.col, cell.row))
		JsBridge.emit_event("game:pop", {"points": Config.SCORE_PLAIN})
		ECS.world.remove_entity(entity)
```
(If `ECS.world.remove_entity` is not the exact API, use the world removal method confirmed at execution — check `godot/addons/gecs/ecs/world.gd` for `func remove_entity`.)

- [ ] **Step 4: import + verify**
Run: `godot --headless --path godot --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v update_scripts`
Expected: no output.

- [ ] **Step 5: Commit**
```bash
git add -A && git commit -m "feat(game): run stats + ScoreSystem"
```

---

## Task 4: Wire RunController — world, systems, input, timer, sheet refill, HUD emits

**Files:**
- Modify: `godot/scripts/game/run_controller.gd`

**Interfaces:**
- Consumes: `Board`, `World`, `SpinSystem`→`ScoreSystem`, `C_Bubble`, `C_Popped`, `C_RunStats`.
- Produces: emits `game:score`, `game:time`, `game:run_over`; handles `start_run`/`restart`; native click → pop.

- [ ] **Step 1: full run_controller.gd**
```gdscript
extends Node2D

enum State { IDLE, PLAYING, SHEET_CLEAR, GAME_OVER }

var _state: int = State.IDLE
var _time_left := 0.0
var _sheet := 0
var _world: World
var _stats: Entity
var _score_system: ScoreSystem
var _emit_accum := 0.0

@onready var _camera: Camera2D = $Camera2D
@onready var _board: Board = $Board


func _ready() -> void:
	JsBridge.register_target(self)
	_camera.position = Vector2(
		(Config.GRID_COLS - 1) * Config.CELL * 0.5,
		(Config.GRID_ROWS - 1) * Config.CELL * 0.5,
	)
	_world = World.new()
	_world.name = "World"
	add_child(_world)
	ECS.world = _world

	_stats = Entity.new()
	_stats.name = "RunStats"
	_stats.add_component(C_RunStats.new())
	_world.add_entity(_stats)

	_score_system = ScoreSystem.new()
	_score_system.stats_entity = _stats
	_score_system.board = _board
	_world.add_system(_score_system)

	_set_state(State.IDLE)


func _set_state(s: int) -> void:
	_state = s
	JsBridge.emit_event("game:state", {"state": State.keys()[s]})


func handle_command(cmd: String, payload: Dictionary) -> void:
	match cmd:
		"start_run", "restart":
			_start_run(payload)


func _start_run(_payload: Dictionary) -> void:
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	stats.score = 0
	stats.pops = 0
	_sheet = 0
	_time_left = Config.BASE_TIME
	_board.spawn_sheet(_world, _sheet)
	_set_state(State.PLAYING)
	_emit_score()
	_emit_time()


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos := _camera.get_global_mouse_position()
		var cell := _board.cell_at(world_pos)
		if cell.x < 0:
			return
		var e := _board.entity_at(cell)
		if e == null:
			return
		var bubble := e.get_component(C_Bubble) as C_Bubble
		bubble.hp -= 1
		if bubble.hp <= 0:
			e.add_component(C_Popped.new())


func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return
	ECS.process(delta)

	# Sheet cleared -> refill (M1 has no upgrade cards yet).
	if _board._by_cell.is_empty():
		_sheet += 1
		_board.spawn_sheet(_world, _sheet)

	_time_left -= delta
	_emit_accum += delta
	if _emit_accum >= 0.1:
		_emit_accum = 0.0
		_emit_time()
		_emit_score()
	if _time_left <= 0.0:
		_end_run()


func _emit_score() -> void:
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	JsBridge.emit_event("game:score", {"score": stats.score})


func _emit_time() -> void:
	JsBridge.emit_event("game:time", {"remaining": max(0.0, _time_left)})


func _end_run() -> void:
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	_set_state(State.GAME_OVER)
	JsBridge.emit_event("game:run_over", {
		"score": stats.score,
		"currencyEarned": int(floor(stats.score / 100.0)),
	})
```

- [ ] **Step 2: import + export + verify no errors**
Run: `npm run build:godot 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" | grep -v first_scan; echo done`
Expected: `done` with no error lines; `public/godot/index.wasm` present.

- [ ] **Step 3: Commit**
```bash
git add -A && git commit -m "feat(game): wire run controller (world, input, timer, sheet refill)"
```

---

## Task 5: React HUD + events + overlay input passthrough

**Files:**
- Create: `src/game/events.ts`, `src/components/Hud.tsx`
- Modify: `src/App.tsx`, `src/game/MainScene.ts`, `src/game/config.ts`, `src/index.css`

**Interfaces:**
- Consumes: `bus`, `useBusEvent`, `godotSend` from existing modules.
- Produces: HUD reads `game:state|score|time`; buttons call `godotSend('start_run'|'restart', {})`.

- [ ] **Step 1: events.ts**
```ts
export type GameState = 'IDLE' | 'PLAYING' | 'SHEET_CLEAR' | 'GAME_OVER';
export interface ScorePayload { score: number }
export interface TimePayload { remaining: number }
export interface RunOverPayload { score: number; currencyEarned: number }
export interface StatePayload { state: GameState }
```

- [ ] **Step 2: Hud.tsx**
```tsx
import { useState } from 'react';
import { useBusEvent } from '../bus';
import { godotSend } from '../godot/bridge';
import type { GameState, ScorePayload, TimePayload, RunOverPayload, StatePayload } from '../game/events';

export function Hud() {
  const [state, setState] = useState<GameState>('IDLE');
  const [score, setScore] = useState(0);
  const [time, setTime] = useState(60);
  const [last, setLast] = useState<RunOverPayload | null>(null);

  useBusEvent<StatePayload>('game:state', (p) => setState(p.state));
  useBusEvent<ScorePayload>('game:score', (p) => setScore(p.score));
  useBusEvent<TimePayload>('game:time', (p) => setTime(p.remaining));
  useBusEvent<RunOverPayload>('game:run_over', (p) => setLast(p));

  const playing = state === 'PLAYING';
  return (
    <div className="hud">
      {playing && (
        <>
          <div className="hud-time"><div className="hud-time-bar" style={{ width: `${(time / 60) * 100}%` }} /></div>
          <div className="hud-score">{score}</div>
        </>
      )}
      {state === 'IDLE' && (
        <div className="panel">
          <h1>Bubble Roguelite</h1>
          <button onClick={() => godotSend('start_run', {})}>Start</button>
        </div>
      )}
      {state === 'GAME_OVER' && (
        <div className="panel">
          <h1>Time!</h1>
          <p>Score: {last?.score ?? score}</p>
          <button onClick={() => godotSend('restart', {})}>Play again</button>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 3: App.tsx** — mount GodotGame + FX overlay + HUD (drop old tick/ack demo)
```tsx
import { PhaserGame } from '@kbve/laser';
import { GodotGame } from './godot/GodotGame';
import { Hud } from './components/Hud';
import { gameConfig } from './game/config';

const fill = { position: 'absolute', inset: 0 } as const;

export default function App() {
  return (
    <div className="app">
      <GodotGame />
      <div className="layer phaser-overlay">
        <PhaserGame config={gameConfig} className="layer" style={fill} />
      </div>
      <Hud />
    </div>
  );
}
```

- [ ] **Step 4: MainScene.ts** — strip tick text + pointer forwarding (FX-ready empty scene)
```ts
import Phaser from 'phaser';

/** Transparent FX overlay. Pop particles land here in a later milestone. */
export class MainScene extends Phaser.Scene {
  constructor() {
    super({ key: 'MainScene' });
  }
  create(): void {
    // FX only; input passes through to the Godot canvas (pointer-events:none in CSS).
  }
}
```

- [ ] **Step 5: index.css** — overlay passthrough + HUD styles
Add: `.phaser-overlay { pointer-events: none; }` and HUD/panel/time-bar rules; `.hud` keeps `pointer-events:none` but `.hud button` and `.panel` get `pointer-events:auto`.

- [ ] **Step 6: build**
Run: `npm run build 2>&1 | tail -4`
Expected: `built` with no TS errors.

- [ ] **Step 7: Commit**
```bash
git add -A && git commit -m "feat(hud): React HUD + game events + overlay passthrough"
```

---

## Task 6: End-to-end verification (headless browser)

**Files:**
- Create: `scratchpad/m1-verify.mjs` (session scratchpad; not committed)

- [ ] **Step 1: verify script** — start_run via bridge, pop bubbles via synthesized canvas clicks OR a dev pop, assert score/time/run_over.

For M1, drive pops by dispatching real mouse clicks on the Godot canvas at computed cell centers. Compute canvas→cell using the same grid math. Simpler: temporarily lower `Config.BASE_TIME` is NOT needed — assert time counts down and run_over fires by waiting, but 60s is long for CI. Instead assert: after `start_run`, `game:state` → PLAYING, `game:time` decreasing, clicking canvas center increments `game:score`. Full run_over is asserted by a short-timer manual check (documented, not gated).

```js
// scratchpad/m1-verify.mjs — see godot-verify.mjs for the launch boilerplate.
// 1. goto dev, wait booted (overlay gone)
// 2. click "Start" (.panel button)
// 3. read game:state === PLAYING (HUD shows score+time)
// 4. click the Godot canvas at its center a few times; assert HUD score increases
// 5. assert HUD time value decreases across 2s
// 6. screenshot
```

- [ ] **Step 2: run verify**
Run: `cd scratchpad && node m1-verify.mjs`
Expected JSON: `state:"PLAYING"`, `scoreIncreased:true`, `timeDecreased:true`, no page errors.

- [ ] **Step 3: screenshot check** — grid of bubbles visible, HUD score + time bar overlaid, clicked bubbles gone.

- [ ] **Step 4: Commit any fixes, then open PR**
```bash
git add -A && git commit -m "test(game): M1 core-run headless verification"
git push -u origin feat/bubble-roguelite
gh pr create --base main --title "feat: bubble roguelite M1 — core run" --body "..."
```

---

## Self-Review

- **Spec coverage (M1 slice):** grid of plain bubbles (T2), native click→pop (T4), timer (T4), score (T3/T4), bridge start_run/state/score/time/run_over (T3-T5), React HUD + start/restart (T5). Covered. (Bubble variety, upgrades, meta, juice = M2–M5, separate plans.)
- **Placeholders:** verify script body is described procedurally with concrete assertions; boilerplate reused from `godot-verify.mjs`. Acceptable (test harness, not shipped code).
- **Type consistency:** `game:*` event names + payload keys (`score`, `remaining`, `state`, `currencyEarned`) match between GDScript emits and `events.ts`. `Board` methods (`spawn_sheet`, `cell_at`, `entity_at`, `remove_cell`, `_by_cell`) consistent across board.gd, score_system.gd, run_controller.gd.
- **Risk flagged:** GECS `remove_entity` exact name + the ColorRect-under-World canvas-transform question are verified at execution (Task 2/3 notes).
