extends Node2D

## Classic two-tone bobber, drawn rather than needing a sprite yet --
## two overlapping circles (white top, red bottom) read clearly as "bobber"
## even at this placeholder-art stage. Purely static, so a single
## automatic initial _draw() is enough; nothing here ever changes.

const RADIUS: float = 13.0

func _draw() -> void:
	draw_circle(Vector2(0.0, -RADIUS * 0.5), RADIUS, Color(0.95, 0.95, 0.9, 1.0))
	draw_circle(Vector2(0.0, RADIUS * 0.5), RADIUS, Color(0.9, 0.15, 0.15, 1.0))
	draw_circle(Vector2.ZERO, RADIUS * 0.15, Color(0.15, 0.1, 0.05, 1.0))
