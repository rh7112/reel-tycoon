extends Node2D

## What's under the player's feet -- positioned at the bottom of the
## screen (not out near the water) so it actually reads as "the ground/
## deck you're standing on", not scenery out in the distance.
##
## Tier 0 (dock/shore) reacts to depth too, per Ryan's request: shallow
## water reads as standing on the bank (sand/dirt); past a threshold the
## view becomes a dock reaching out over deeper water. A boat (tier 1+)
## doesn't need this -- the water darkening with depth
## (FishingHUD._refresh_region_visuals) already sells "fishing deeper"
## on its own, so boats just show their own deck color, flat.
##
## Drawn as a full-width strip (draw coordinates run well past this
## node's own position on both sides) rather than a small emblem, since
## it's meant to read as ground/floor, not a scene object.

const STRIP_HALF_WIDTH: float = 400.0
const STRIP_HEIGHT: float = 100.0
const SHORE_TO_DOCK_DEPTH_FRACTION: float = 0.45 # past this, shore -> dock

var tier: int = 0:
	set(value):
		if tier != value:
			tier = value
			queue_redraw()

var depth_fraction: float = 0.0:
	set(value):
		if depth_fraction != value:
			depth_fraction = value
			if tier == 0:
				queue_redraw() # only tier 0 cares about depth

func _draw() -> void:
	match tier:
		0:
			if depth_fraction < SHORE_TO_DOCK_DEPTH_FRACTION:
				_draw_sand()
			else:
				_draw_dock_planks()
		1:
			_draw_deck(Color(0.75, 0.45, 0.1, 1.0))
		2:
			_draw_deck(Color(0.5, 0.52, 0.54, 1.0))
		3:
			_draw_deck(Color(0.8, 0.8, 0.83, 1.0))
		_:
			_draw_deck(Color(0.1, 0.1, 0.12, 1.0))

func _draw_sand() -> void:
	draw_rect(Rect2(-STRIP_HALF_WIDTH, 0.0, STRIP_HALF_WIDTH * 2.0, STRIP_HEIGHT), Color(0.78, 0.68, 0.45, 1.0))
	# a few scattered pebble/dirt flecks so it doesn't read as a flat color bar
	var flecks := [-320.0, -210.0, -90.0, 40.0, 150.0, 260.0, 340.0]
	for x in flecks:
		draw_circle(Vector2(x, 55.0 + fmod(x, 23.0)), 4.0, Color(0.6, 0.5, 0.32, 1.0))

func _draw_dock_planks() -> void:
	draw_rect(Rect2(-STRIP_HALF_WIDTH, 0.0, STRIP_HALF_WIDTH * 2.0, STRIP_HEIGHT), Color(0.42, 0.28, 0.16, 1.0))
	var seam_count: int = 9
	for i in range(seam_count):
		var x: float = -STRIP_HALF_WIDTH + (float(i) + 0.5) * (STRIP_HALF_WIDTH * 2.0 / seam_count)
		draw_line(Vector2(x, 0.0), Vector2(x, STRIP_HEIGHT), Color(0.3, 0.2, 0.12, 1.0), 3.0)

func _draw_deck(deck_color: Color) -> void:
	draw_rect(Rect2(-STRIP_HALF_WIDTH, 0.0, STRIP_HALF_WIDTH * 2.0, STRIP_HEIGHT), deck_color)
	draw_line(Vector2(-STRIP_HALF_WIDTH, 0.0), Vector2(STRIP_HALF_WIDTH, 0.0), Color(0.15, 0.15, 0.17, 0.6), 3.0)
