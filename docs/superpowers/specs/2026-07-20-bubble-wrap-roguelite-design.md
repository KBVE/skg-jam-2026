# Bubble-Wrap Roguelite — Design Spec

Date: 2026-07-20
Status: Approved design → implementation planning

## 1. Concept

A short, satisfying bubble-wrap popping roguelite. Each run is time-limited (~60s)
but the timer can be extended through play. Click to pop bubbles; clear a sheet and
pick 1 of 3 upgrade cards; the next sheet is fresh and harder. Run ends when time
hits zero. Score banks into persistent currency spent on permanent meta-unlocks
between runs.

Feel target: fast, juicy, "one more run."

## 2. Stack & layer split (builds on the merged harness)

| Layer | Owns |
|-------|------|
| **Godot 4.7 + GECS** | All gameplay: bubbles, popping, power-up systems, per-sheet layout, run timer + score. Rebuilds its ECS world each run; keeps nothing between runs. |
| **React 19 + localStorage** | Meta-progression (currency, permanent unlocks, shop), the 3-choice in-run upgrade cards, HUD (score/time/combo/loadout), screen routing. Persistence lives here. |
| **Phaser (transparent overlay)** | Pop juice only — particle bursts + floating "+N" text on each pop. `pointer-events:none` during play. |

Communication over the existing shared `LaserEventBus` + Godot `JavaScriptBridge`
(see [`docs/godot.md`](../../godot.md)).

**Input:** during `PLAYING` the Phaser overlay and React HUD are `pointer-events:none`,
so clicks land on the **Godot canvas natively** — Godot maps click → grid cell → bubble
(no per-click bridge round-trip). React upgrade cards / shop capture pointer only when shown.

## 3. Run loop & state machine (authoritative in Godot)

```
IDLE ──start_run──▶ PLAYING ──sheet cleared──▶ SHEET_CLEAR (paused)
  ▲                   │                              │
  │                   │ time ≤ 0                     │ pick_upgrade
  │                   ▼                              ▼
  └── shop ◀── GAME_OVER ◀──────────────────────  PLAYING (next sheet, harder)
```

- `IDLE` — menu/shop shown (React). Godot idle.
- `PLAYING` — sheet active, clicks pop, timer counts down.
- `SHEET_CLEAR` — sheet emptied of poppable bubbles → Godot pauses gameplay systems,
  emits 3 upgrade choices; React shows cards; player picks → apply → next sheet.
- `GAME_OVER` — timer reached 0 → emit final score + earned currency; React banks it,
  shows game-over + shop.

Godot emits `game:state` on every transition; React routes screens off it.

## 4. GECS model

Per the GECS performance guide: component-based `.with_all` queries, lightweight
components, **tag components for rare states**, early-exit systems, CommandBuffer for
batch removals.

### Components
- `C_Bubble { hp: int }` — every bubble. `hp` 1 = plain, 2–3 = tough.
- `C_Cell { row: int, col: int }` — grid coordinate.
- Rare-state **tags** (absent on plain bubbles → cheap archetypes):
  `C_Gold`, `C_Clock`, `C_Chain`, `C_Mine`.
- `C_Popped {}` — transient tag added when a bubble is destroyed this frame; drives
  scoring + FX emit, then the entity is removed (CommandBuffer).
- `C_Loadout { ricochet: int, area: int, autoclick: int }` — single **run singleton
  entity**, not per-bubble. Holds the current run's stacked power-ups.

### Systems (run under `ECS.process`, gated by state == PLAYING)
- `PopSystem` — resolves a queued click: find bubble at cell, apply **area** (pop radius
  = `area` rings), **ricochet** (bounce chain to `ricochet` extra neighbors), decrement
  `hp`; hp ≤ 0 → add `C_Popped`.
- `AutoClickSystem` — timer; every interval (rate ∝ `autoclick`) pops a random remaining
  bubble. Early-exit when `autoclick == 0`.
- `BonusSystem` — on pops: +10 score per 3 pops, +0.1s per 10 pops (running counters).
- `ChainSystem` — a popped `C_Chain` bubble pops all grid-connected bubbles.
- `MineSystem` — a popped `C_Mine` applies penalty (−time or −score).
- `ScoreSystem` — consumes `C_Popped`: award points by kind, emit `game:pop`, remove entity.
- `TimerSystem` — counts run time down; ≤ 0 → transition `GAME_OVER`.
- `SheetSystem` — early-exits unless zero poppable bubbles remain → transition `SHEET_CLEAR`.

### Board
`board.gd` spawns a sheet: a grid (scales with sheet index) of bubble entities, each a
`Node2D` with a `ColorRect`/`Sprite2D` child at its cell's world position. Weighted spawn
table ramps difficulty by sheet index (more tough/mines deeper). Click→cell mapping and
"bubble at cell" lookup live here.

## 5. Bridge protocol (`game:*`)

**JS → Godot**
- `game:start_run { loadout }` — `loadout = { baseTime, ricochet, area, autoclick, pool: string[] }` built from meta.
- `game:pick_upgrade { id }` — during `SHEET_CLEAR`; applies to `C_Loadout`, resumes.
- `game:restart` — from `GAME_OVER` → new run.
- `game:debug_pop { n }` — **dev-only** (behind a debug flag); pops N bubbles for automated tests.

**Godot → JS**
- `game:ready`
- `game:state { state }` — IDLE | PLAYING | SHEET_CLEAR | GAME_OVER
- `game:pop { cell, kind, combo, points }` — per pop (FX + combo readout)
- `game:score { score }`
- `game:time { remaining }`
- `game:sheet_clear { sheet, choices: string[] }` — 3 upgrade ids drawn from `pool`
- `game:run_over { score, currencyEarned }`

All payloads JSON per the existing bridge contract.

## 6. Meta-progression (React + localStorage)

- Store key `bubbleroguelite.meta.v1` = `{ currency: int, unlocked: string[], startBonuses: { baseTime: int, ricochet: int, area: int, autoclick: int } }`.
- `src/meta/store.ts` — load/save, `bank(currency)`, `buy(unlockId)`, `buildLoadout()`.
- `src/meta/catalog.ts` — power-up + unlock metadata (id, name, description, cost, effect); the single source for names/costs shared by cards + shop.
- **Shop** (React, shown in IDLE/GAME_OVER): spend currency on permanent unlocks.
- **Currency earned** = `floor(score / 100)` (tunable).
- Flow: shop → Start → `buildLoadout()` → `game:start_run` → play → `game:run_over` →
  `bank(currencyEarned)` → shop.

### Two upgrade tiers (distinct)
- **In-run cards** (between sheets, ephemeral): `P_RICOCHET` (+1 bounce), `P_AREA`
  (+1 radius ring), `P_AUTOCLICK` (+1 auto rate). Drawn from the run's `pool`.
- **Meta unlocks** (shop, permanent): e.g. `U_BASE_TIME` (+5s), `U_START_RICOCHET/AREA/AUTOCLICK`
  (+1 starting), and expanding the card `pool`. ~5–6 to start.

## 7. Content & tuning (defaults, all tunable)

Tuning lives authoritatively in Godot `scripts/game/config.gd`; React only mirrors
power-up **metadata** (names/costs) in `catalog.ts`.

- Base time 60s; +0.1s / 10 pops; clock bubble +2s.
- Grid scales by sheet: start ~8×6, grow density/size with sheet index.
- Bubble mix (weighted, ramps by sheet): mostly plain, some tough, few gold/clock/chain,
  rare mine.
- Scoring: plain +1, tough +3, gold +10, chain combo bonus; +10 per 3 pops.
- Penalty (mine): −2s (tunable; keep mild to avoid frustration).

## 8. Juice / FX

- Phaser overlay: particle burst + floating "+N" on `game:pop`.
- Godot: bubble pop tween (scale-down + fade) before removal.
- React HUD: time bar (color shifts as it drains), score counter, combo, current loadout icons.
- Audio (stretch): pop SFX with slight pitch variance.

## 9. Files

**Godot** (`godot/`)
- `scenes/Game.tscn` — `Node2D` + `Camera2D` + board node + `RunController`.
- `scripts/game/run_controller.gd` — state machine, world setup, `ECS.process`, bridge wiring.
- `scripts/game/board.gd` — sheet spawn, grid↔world, pick-at-position.
- `scripts/game/config.gd` — tuning constants.
- `scripts/components/` — `c_bubble.gd`, `c_cell.gd`, `c_gold.gd`, `c_clock.gd`, `c_chain.gd`, `c_mine.gd`, `c_popped.gd`, `c_loadout.gd`.
- `scripts/systems/` — `pop_system.gd`, `auto_click_system.gd`, `bonus_system.gd`, `chain_system.gd`, `mine_system.gd`, `score_system.gd`, `timer_system.gd`, `sheet_system.gd`.
- Set `run/main_scene` → `Game.tscn`. Retire the spin-cube demo (move `Main`/`C_Spin`/`SpinSystem` to an `examples/` or delete). Reuse `JsBridge` autoload + `ECS` autoload.

**JS/React** (`src/`)
- `src/game/events.ts` — typed `game:*` event + payload types.
- `src/meta/store.ts`, `src/meta/catalog.ts` — persistence + power-up/unlock metadata.
- `src/components/Hud.tsx`, `UpgradeCards.tsx`, `Shop.tsx`, `GameOver.tsx`.
- `src/App.tsx` — route screens off `game:state`; `GodotGame` stays the bottom layer; overlays conditional.
- `src/godot/bridge.ts` — reuse; add typed `game:*` helpers.
- Phaser `MainScene` — pop FX on `game:pop`; manage `pointer-events`.

## 10. Milestones (implementation phasing)

Full game is decomposed into shippable milestones; each verified before the next.

1. **M1 — Core run.** Godot grid of plain bubbles, native click→pop, timer, score.
   Bridge: `start_run`/`state`/`score`/`time`/`run_over`. React HUD (time+score) + start/restart.
2. **M2 — Bubble variety + bonuses.** tough/gold/clock/chain/mine + `Bonus/Chain/Mine` systems.
3. **M3 — In-run upgrades.** `sheet_clear` → React 3-card overlay → `pick_upgrade` → `PopSystem`
   uses `C_Loadout` (ricochet/area) + `AutoClickSystem`.
4. **M4 — Meta-progression.** localStorage store, shop screen, currency banking, loadout from meta.
5. **M5 — Juice.** Phaser FX, Godot tweens, HUD polish, audio.

## 11. Verification (per milestone)

Extend the existing headless-Chrome harness (`scratchpad/godot-verify.mjs`):
- `game:start_run` → drive pops (dev `game:debug_pop`, or synthesized canvas clicks) →
  assert `game:score`/`game:time` update → time to 0 → `game:run_over`.
- Card flow: clear sheet → `game:sheet_clear` → React renders 3 cards → programmatic pick →
  `game:pick_upgrade` ack → next sheet, loadout applied.
- Meta: `game:run_over` banks currency → `localStorage` updated → shop reflects → **survives reload**.
- Screenshot per milestone (all layers composited).
- `npm run build:godot` + `npm run build` clean each milestone.

## 12. Out of scope (MVP)
- Multiplayer/networking (gecs net module unused).
- Accounts/cloud saves (localStorage only).
- Mobile-specific input tuning (mouse/tap assumed).
- WebGPU (stay WebGL2).
