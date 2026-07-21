class_name BubbleView
extends Node2D
## Draws a single bubble-wrap dome centered on its own origin, so pop tweens
## (scale) pivot from the center. Positioned at its cell center by the Board.

var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()

var radius := Config.BUBBLE_RADIUS   # grows for multi-cell bubbles (see set_span)


func darken() -> void:
	color = color.darkened(0.22)
	queue_redraw()


## Scale the dome to a w*h footprint. 1x1 keeps the default radius; a boss fills
## its region (shortest side), leaving a small gap so cells stay readable.
func set_span(w: int, h: int) -> void:
	if w <= 1 and h <= 1:
		return
	radius = min(w, h) * Config.CELL * 0.5 * 0.9
	queue_redraw()


func _draw() -> void:
	var r := radius
	# Base + rim (slightly darker, translucent plastic).
	draw_circle(Vector2.ZERO, r, Color(color.darkened(0.18), 0.92))
	# Top-lit dome.
	draw_circle(Vector2(0.0, -r * 0.12), r * 0.82, color)
	# Specular highlight + sparkle.
	draw_circle(Vector2(-r * 0.30, -r * 0.34), r * 0.22, Color(1, 1, 1, 0.6))
	draw_circle(Vector2(-r * 0.16, -r * 0.18), r * 0.09, Color(1, 1, 1, 0.45))
