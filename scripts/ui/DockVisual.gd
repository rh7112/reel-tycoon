extends Node2D

## Drawn per-tier -- see BoatTiers.gd. Unlike Bobber/ReelWheel this
## genuinely redraws (queue_redraw) since the tier can change mid-
## session (buying a boat) and each tier is a completely different
## shape, not just a recolor/rescale of the same drawing.

var tier: int = 0:
	set(value):
		if tier != value:
			tier = value
			queue_redraw()

func _draw() -> void:
	match tier:
		0:
			_draw_dock()
		1:
			_draw_kayak()
		2:
			_draw_jon_boat()
		3:
			_draw_bass_boat(Color(0.85, 0.85, 0.88, 1.0), Color(0.75, 0.15, 0.15, 1.0))
		_:
			_draw_bass_boat(Color(0.12, 0.12, 0.14, 1.0), Color(0.85, 0.68, 0.15, 1.0))

## A few weathered, slightly-uneven planks on posts driven into the water.
func _draw_dock() -> void:
	var wood := Color(0.42, 0.28, 0.16, 1.0)
	var post := Color(0.3, 0.2, 0.12, 1.0)
	draw_rect(Rect2(-10.0, 60.0, 8.0, 60.0), post)
	draw_rect(Rect2(70.0, 60.0, 8.0, 70.0), post)
	for i in range(4):
		var y: float = float(i) * 9.0 - 4.0
		draw_rect(Rect2(-20.0, y, 110.0, 10.0), wood)

func _draw_kayak() -> void:
	var hull := Color(0.9, 0.55, 0.1, 1.0)
	var points := PackedVector2Array([
		Vector2(-60.0, 0.0), Vector2(-30.0, -14.0), Vector2(40.0, -14.0), Vector2(65.0, 0.0),
		Vector2(40.0, 14.0), Vector2(-30.0, 14.0),
	])
	draw_colored_polygon(points, hull)

func _draw_jon_boat() -> void:
	var hull := Color(0.62, 0.64, 0.66, 1.0)
	var points := PackedVector2Array([
		Vector2(-70.0, -18.0), Vector2(60.0, -18.0), Vector2(75.0, 0.0),
		Vector2(60.0, 18.0), Vector2(-70.0, 18.0),
	])
	draw_colored_polygon(points, hull)
	draw_rect(Rect2(50.0, -10.0, 20.0, 20.0), Color(0.15, 0.15, 0.16, 1.0)) # outboard motor

func _draw_bass_boat(hull_color: Color, accent: Color) -> void:
	var points := PackedVector2Array([
		Vector2(-85.0, -20.0), Vector2(-20.0, -26.0), Vector2(75.0, -8.0), Vector2(95.0, 0.0),
		Vector2(75.0, 8.0), Vector2(-20.0, 26.0), Vector2(-85.0, 20.0),
	])
	draw_colored_polygon(points, hull_color)
	draw_rect(Rect2(-30.0, -12.0, 30.0, 24.0), accent) # console
	draw_rect(Rect2(70.0, -10.0, 22.0, 20.0), Color(0.15, 0.15, 0.16, 1.0)) # outboard motor
