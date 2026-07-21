class_name GameEvents
extends RefCounted
## Central registry of in-engine gameplay event names for GECS's observer bus
## (World.emit_event / Observer.on_event). StringName constants keep raw &"pop"
## literals from scattering. Payload shape + entity are documented per event.
##
## Emit:    ECS.world.emit_event(GameEvents.POP, bubble_entity, {...})
##          ECS.world.emit_event(GameEvents.SHEET_CLEAR, null, {...})   # broadcast
## Consume: an Observer with  q.on_event(GameEvents.POP)  in query()/sub_observers().

# Entity-scoped (emitted with the bubble entity):
const POP := &"pop"          # {kind: String, points: int, x: float, y: float}
const CHAIN := &"chain"      # {origin_cell: Vector2i}
const HIT := &"hit"          # {hp: int, max_hp: int}  — partial hit (survived)

# Broadcast (emitted with entity = null; reaches every on_event subscriber):
const STATE_CHANGED := &"state_changed"      # {state: String}
const SHEET_CLEAR := &"sheet_clear"          # {sheet: int, choices: Array}
const UPGRADE_PICKED := &"upgrade_picked"    # {ricochet: int, area: int, autoclick: int}
const SCORE_CHANGED := &"score_changed"      # {score: int}
const TIME_CHANGED := &"time_changed"        # {remaining: float}
const RUN_OVER := &"run_over"                # {score: int, currencyEarned: int}
