class_name RodTiers
extends RefCounted

## Rod upgrade tiers -- the first thing coins are actually spendable on.
## Controls reel *rates* only now -- safe-band *width* moved to per-region
## mastery (FishingLocation.gd), since that's the axis that's supposed to
## reset when arriving somewhere new while gear stays permanent.
##
## Kept as a plain const table here rather than a Resource-per-tier like
## Fish/FishingLocation: those are content meant to grow to dozens of
## entries over time, edited without touching code. These four tiers are
## few, and every field here is tightly coupled to the exact tuning
## constants FishingController is still being playtested/retuned with --
## a code table is easier to iterate on together with that script for now.
## Worth revisiting as a Resource if this grows much past this size.

const TIERS: Array[Dictionary] = [
	{
		"name": "Old Bamboo Rod",
		"upgrade_cost": 0,
		"tension_rise_rate": 0.9,
		"tension_fall_rate": 0.6,
		"progress_fill_rate": 0.35,
		"bite_window": 1.1,
	},
	{
		"name": "Fiberglass Rod",
		"upgrade_cost": 50,
		"tension_rise_rate": 0.85,
		"tension_fall_rate": 0.55,
		"progress_fill_rate": 0.40,
		"bite_window": 1.3,
	},
	{
		"name": "Carbon Rod",
		"upgrade_cost": 200,
		"tension_rise_rate": 0.8,
		"tension_fall_rate": 0.5,
		"progress_fill_rate": 0.45,
		"bite_window": 1.5,
	},
	{
		"name": "Pro Tournament Rod",
		"upgrade_cost": 750,
		"tension_rise_rate": 0.75,
		"tension_fall_rate": 0.45,
		"progress_fill_rate": 0.5,
		"bite_window": 1.8,
	},
]

static func get_tier(index: int) -> Dictionary:
	return TIERS[clamp(index, 0, TIERS.size() - 1)]

static func is_max_tier(index: int) -> bool:
	return index >= TIERS.size() - 1
