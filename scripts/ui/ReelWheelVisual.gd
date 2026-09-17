extends Node2D

## Drawn per equipped reel type (see ReelTypes.gd) rather than one
## generic wheel -- redraws (queue_redraw) when the type changes, same
## pattern as DockVisual.gd. Rotated by FishingHUD while REELING.

const RADIUS: float = 16.0

var reel_type: StringName = &"spinning":
	set(value):
		if reel_type != value:
			reel_type = value
			queue_redraw()

func _draw() -> void:
	match reel_type:
		&"push_button":
			_draw_push_button()
		&"baitcaster":
			_draw_baitcaster()
		_:
			_draw_spinning()

## Rounded housing with a thumb-bar on top -- a spincast reel is mostly
## enclosed, no exposed spool.
func _draw_push_button() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.6, 0.15, 0.15, 1.0))
	draw_circle(Vector2.ZERO, RADIUS * 0.4, Color(0.85, 0.85, 0.85, 1.0))
	draw_rect(Rect2(-4.0, -RADIUS - 6.0, 8.0, 8.0), Color(0.15, 0.15, 0.15, 1.0)) # thumb-bar

## Exposed spool + a bail arm loop, hung underneath the rod.
func _draw_spinning() -> void:
	draw_circle(Vector2.ZERO, RADIUS * 0.7, Color(0.55, 0.55, 0.6, 1.0)) # spool
	draw_circle(Vector2.ZERO, RADIUS * 0.25, Color(0.25, 0.25, 0.3, 1.0))
	draw_arc(Vector2.ZERO, RADIUS, -PI * 0.9, PI * 0.1, 16, Color(0.75, 0.75, 0.8, 1.0), 3.0) # bail arm
	draw_line(Vector2(-RADIUS, -2.0), Vector2(-RADIUS - 10.0, -2.0), Color(0.3, 0.3, 0.35, 1.0), 3.0) # handle stub

## Compact round reel with a star-drag knob, mounted on top.
func _draw_baitcaster() -> void:
	draw_circle(Vector2.ZERO, RADIUS * 0.85, Color(0.35, 0.35, 0.4, 1.0))
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color(0.2, 0.2, 0.24, 1.0))
	for i in range(5):
		var angle: float = i * TAU / 5.0
		var tip := Vector2(cos(angle), sin(angle)) * RADIUS * 1.05
		draw_line(Vector2.ZERO, tip, Color(0.85, 0.68, 0.15, 1.0), 3.0) # star-drag knob spokes
