extends Node2D

## Drawn per presentation style (see Lure.gd) -- a bobber only makes
## sense for a suspended/still bait; a retrieve lure (spinner/crankbait/
## jerkbait/topwater) has no bobber at all in real fishing, so it's
## drawn as a small neutral lure marker instead. Same node either way --
## this is still what the fishing line's endpoint tracks and what the
## bite/submerge/wiggle animations move, only the drawing changes.
## Redraws (queue_redraw) on style change, same pattern as DockVisual.gd.

const RADIUS: float = 13.0

var style: StringName = &"bobber":
	set(value):
		if style != value:
			style = value
			queue_redraw()

func _draw() -> void:
	if style == &"bobber":
		_draw_bobber()
	else:
		_draw_lure_marker()

func _draw_bobber() -> void:
	draw_circle(Vector2(0.0, -RADIUS * 0.5), RADIUS, Color(0.95, 0.95, 0.9, 1.0))
	draw_circle(Vector2(0.0, RADIUS * 0.5), RADIUS, Color(0.9, 0.15, 0.15, 1.0))
	draw_circle(Vector2.ZERO, RADIUS * 0.15, Color(0.15, 0.1, 0.05, 1.0))

## A small metallic diamond -- reads as "a lure", not "a bobber".
func _draw_lure_marker() -> void:
	var points := PackedVector2Array([
		Vector2(0.0, -RADIUS), Vector2(RADIUS * 0.55, 0.0),
		Vector2(0.0, RADIUS), Vector2(-RADIUS * 0.55, 0.0),
	])
	draw_colored_polygon(points, Color(0.75, 0.78, 0.8, 1.0))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0.3, 0.3, 0.32, 1.0), 1.5)
