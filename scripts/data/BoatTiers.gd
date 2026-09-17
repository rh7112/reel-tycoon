class_name BoatTiers
extends RefCounted

## What the player fishes from -- a linear progression (unlike lures/
## tackle, this genuinely is "strictly better", so it's an upgrade
## ladder like RodTiers, not an owned-options set). Each tier caps how
## deep FishingController.set_depth will let the player fish
## (max_depth_ft, combined with the region's own range -- whichever is
## smaller wins), matching Ryan's ask: a rickety dock keeps you in the
## shallows, a real boat gets you out to where the bigger fish are.
## 999.0 on the later tiers means "no cap of its own" -- every region
## built so far tops out well under that.

const TIERS: Array[Dictionary] = [
	{"name": "Rickety Dock", "cost": 0, "max_depth_ft": 10.0},
	{"name": "Kayak", "cost": 200, "max_depth_ft": 18.0},
	{"name": "Jon Boat", "cost": 600, "max_depth_ft": 28.0},
	{"name": "Cheap Bass Boat", "cost": 1800, "max_depth_ft": 999.0},
	{"name": "Tournament Bass Boat", "cost": 6000, "max_depth_ft": 999.0},
]

static func get_tier(index: int) -> Dictionary:
	return TIERS[clamp(index, 0, TIERS.size() - 1)]

static func is_max_tier(index: int) -> bool:
	return index >= TIERS.size() - 1
