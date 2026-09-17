extends Node2D

## A dark, flattened ellipse standing in for a fish shadow seen through
## polarized glasses -- drawn once at a fixed base size; FishingHUD
## scales the whole node non-uniformly per sighting (see
## FishingController.fish_sighted's size_bucket) rather than redrawing.

const BASE_RADIUS: float = 22.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, BASE_RADIUS, Color(0.05, 0.05, 0.05, 0.4))
