class_name ReelTypes
extends RefCounted

## Reel types -- owned/equipped like lures (a real tradeoff between
## options, not a strict upgrade ladder). Push-button is simple and
## cheap but carries its own snap-off risk; spinning is the reliable
## all-rounder; baitcaster rewards precision and pairs best with
## heavier lure presentations, worse with light finesse ones -- see
## FishingController._lure_reel_match_bonus for how preferred_lure_types
## is used.

const ALL: Array[Dictionary] = [
	{
		"id": &"push_button",
		"name": "Push-Button Reel",
		"cost": 0,
		"tension_rise_mult": 1.0,
		"tension_fall_mult": 1.0,
		"progress_fill_mult": 0.9,
		"snap_chance_per_sec": 0.03,
		"preferred_lure_types": [],
	},
	{
		"id": &"spinning",
		"name": "Spinning Reel",
		"cost": 60,
		"tension_rise_mult": 1.0,
		"tension_fall_mult": 1.0,
		"progress_fill_mult": 1.0,
		"snap_chance_per_sec": 0.0,
		"preferred_lure_types": [&"spinner", &"worm", &"frog"],
	},
	{
		"id": &"baitcaster",
		"name": "Baitcaster Reel",
		"cost": 150,
		"tension_rise_mult": 1.1,
		"tension_fall_mult": 0.85,
		"progress_fill_mult": 1.15,
		"snap_chance_per_sec": 0.0,
		"preferred_lure_types": [&"crankbait", &"jerkbait"],
	},
]

static func get_by_id(id: StringName) -> Dictionary:
	for reel in ALL:
		if reel.id == id:
			return reel
	return ALL[1] # spinning -- the safe default every save already starts owning
