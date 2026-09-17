class_name CardRarity
extends RefCounted

## Card rarity, derived from a catch's percentile within that SPECIFIC
## region-scoped Fish's own [min_weight_lb, max_weight_lb] range -- not a
## fixed lb scale. A Northern largemouth's Legendary (top of its ~12lb
## regional ceiling) and a Southern largemouth's Legendary (top of a much
## higher regional ceiling) both mean the same thing -- "an exceptional
## catch for this water" -- even though the raw weights differ a lot.
## This is what makes card rarity comparable across regions with wildly
## different real-world size records.
##
## Named CardRarity, not Rarity, specifically to avoid colliding with
## Fish.gd's own nested `enum Rarity` (species-level "how rare is this
## species to encounter at all", a completely different, older concept)
## -- a global class_name and a nested enum sharing a bare name is a real
## Godot parser error, not just a style nit (confirmed live: "Cannot
## assign a value of type Fish.Rarity to variable ... with specified
## type Rarity").

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

## max_percentile is the upper bound of each tier's slice of the range --
## e.g. COMMON covers ratio 0.0-0.40, UNCOMMON covers 0.40-0.70, etc.
const TIER_INFO: Array[Dictionary] = [
	{"tier": Tier.COMMON, "name": "Common", "color": Color(0.65, 0.65, 0.68, 1), "max_percentile": 0.40},
	{"tier": Tier.UNCOMMON, "name": "Uncommon", "color": Color(0.3, 0.75, 0.35, 1), "max_percentile": 0.70},
	{"tier": Tier.RARE, "name": "Rare", "color": Color(0.25, 0.5, 0.9, 1), "max_percentile": 0.90},
	{"tier": Tier.EPIC, "name": "Epic", "color": Color(0.6, 0.25, 0.85, 1), "max_percentile": 0.98},
	{"tier": Tier.LEGENDARY, "name": "Legendary", "color": Color(0.95, 0.7, 0.1, 1), "max_percentile": 1.0},
]

static func tier_for_ratio(weight_ratio: float) -> Tier:
	for info in TIER_INFO:
		if weight_ratio <= info.max_percentile:
			return info.tier
	return Tier.LEGENDARY

static func name_for_tier(tier: Tier) -> String:
	return TIER_INFO[tier].name

static func color_for_tier(tier: Tier) -> Color:
	return TIER_INFO[tier].color
