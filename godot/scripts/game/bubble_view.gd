class_name BubbleView
extends Node2D
## Draws a single bubble-wrap dome centered on its own origin, so pop tweens
## (scale) pivot from the center. Positioned at its cell center by the Board.

var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func darken() -> void:
	color = color.darkened(0.22)
	queue_redraw()


func _draw() -> void:
	var r := Config.BUBBLE_RADIUS
	# Base + rim (slightly darker, translucent plastic).
	draw_circle(Vector2.ZERO, r, Color(color.darkened(0.18), 0.92))
	# Top-lit dome.
	draw_circle(Vector2(0.0, -r * 0.12), r * 0.82, color)
	# Specular highlight + sparkle.
	draw_circle(Vector2(-r * 0.30, -r * 0.34), r * 0.22, Color(1, 1, 1, 0.6))
	draw_circle(Vector2(-r * 0.16, -r * 0.18), r * 0.09, Color(1, 1, 1, 0.45))
