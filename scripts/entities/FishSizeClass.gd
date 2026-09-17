extends Resource
class_name FishSizeClass

## One weight-banded behavior profile for a Fish species -- lets a trophy
## specimen prefer different conditions than an average specimen of the
## SAME species (e.g. a 10 lb largemouth might favor a spinner on a sunny
## day, while a 12 lb largemouth from the same lake only really goes for a
## jerkbait worked through deeper water). A Fish with no size classes
## defined (the common case -- most species don't need this) just uses
## its own flat preferred_weather/preferred_lure_types/preferred_depth_ft
## fields for every specimen regardless of weight; see Fish.resolve_profile.

@export var min_weight_lb: float = 0.0
@export var max_weight_lb: float = 999.0
@export var preferred_weather: Array[StringName] = []
@export var preferred_lure_types: Array[StringName] = []

## Water depth this size class bites best in, in feet.
@export var preferred_depth_ft: Vector2 = Vector2(0.0, 999.0)

@export_range(0.0, 1.0) var bite_affinity_strength: float = 0.5
