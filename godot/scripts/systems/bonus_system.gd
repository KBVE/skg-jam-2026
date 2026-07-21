class_name BonusSystem
extends System
## Pop-count bonuses: +BONUS_POINTS every BONUS_POINTS_EVERY pops, and
## +BONUS_TIME every BONUS_TIME_EVERY pops. Reads/writes the run stats singleton.

var _pts_marks := 0
var _time_marks := 0


func reset() -> void:
	_pts_marks = 0
	_time_marks = 0


func query() -> QueryBuilder:
	return q.with_all([C_RunStats])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	if entities.is_empty():
		return
	var stats := entities[0].get_component(C_RunStats) as C_RunStats

	var pmarks := stats.pops / Config.BONUS_POINTS_EVERY
	if pmarks > _pts_marks:
		stats.score += (pmarks - _pts_marks) * Config.BONUS_POINTS
		_pts_marks = pmarks

	var tmarks := stats.pops / Config.BONUS_TIME_EVERY
	if tmarks > _time_marks:
		stats.time_delta += (tmarks - _time_marks) * Config.BONUS_TIME
		_time_marks = tmarks
