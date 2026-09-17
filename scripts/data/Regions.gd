class_name Regions
extends RefCounted

## Static registry of every region, in intended real-world progression
## order. Backs the travel/map tab and lets code check "what's unlocked"
## without scanning the filesystem.
##
## Roadmap beyond what's built so far (see README for the full list Ryan
## laid out -- Tennessee, Georgia, Canada, Texas, then saltwater/
## international/planetary much later): add a region here the same way
## pond/northern_lake/kentucky_lake were built -- a FishingLocation.tres
## plus its own species .tres files with region-realistic weight ranges.

const ALL: Array[FishingLocation] = [
	preload("res://resources/locations/pond.tres"),
	preload("res://resources/locations/northern_lake.tres"),
	preload("res://resources/locations/kentucky_lake.tres"),
]

static func get_by_id(id: StringName) -> FishingLocation:
	for region in ALL:
		if region.id == id:
			return region
	return null

static func in_order() -> Array[FishingLocation]:
	var sorted: Array[FishingLocation] = ALL.duplicate()
	sorted.sort_custom(func(a: FishingLocation, b: FishingLocation) -> bool: return a.order < b.order)
	return sorted
