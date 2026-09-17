class_name SponsorshipTiers
extends RefCounted

## Sponsorships -- a straight upgrade ladder (like RodTiers/BoatTiers,
## not owned-options like lures/tackle) that multiplies coins earned
## per catch. Fictional, generic names -- no real brand tie-ins, same
## rule already followed for lures.

const TIERS: Array[Dictionary] = [
	{"name": "Unsponsored", "cost": 0, "coin_mult": 1.0},
	{"name": "Local Bait Shop", "cost": 300, "coin_mult": 1.15},
	{"name": "Regional Tackle Co.", "cost": 900, "coin_mult": 1.35},
	{"name": "Statewide Outdoors", "cost": 2500, "coin_mult": 1.6},
	{"name": "National Angling Network", "cost": 7000, "coin_mult": 2.0},
]

static func get_tier(index: int) -> Dictionary:
	return TIERS[clamp(index, 0, TIERS.size() - 1)]

static func is_max_tier(index: int) -> bool:
	return index >= TIERS.size() - 1
