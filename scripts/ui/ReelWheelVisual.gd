extends Node2D

## A simple 4-spoke wheel, drawn rather than needing a sprite -- rotated
## by FishingHUD while REELING so the reel visibly spins during the part
## of the loop where that actually matters.

const RADIUS: float = 16.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.55, 0.55, 0.6, 1.0))
	draw_circle(Vector2.ZERO, RADIUS * 0.35, Color(0.25, 0.25, 0.3, 1.0))
	for i in range(4):
		var angle: float = i * PI / 2.0
		var spoke_end := Vector2(cos(angle), sin(angle)) * RADIUS
		draw_line(Vector2.ZERO, spoke_end, Color(0.3, 0.3, 0.35, 1.0), 3.0)
