extends Resource
class_name Fish

## One fish species AS IT APPEARS IN ONE REGION. Instances live as .tres
## files under resources/fish/ so adding a species (or retuning it) is a
## data change, not a code change.
##
## Deliberately region-scoped rather than one global "Largemouth Bass"
## shared everywhere: a real largemouth's realistic weight range in
## Indiana (state record ~12 lb) is nothing like Georgia's (~20+ lb), so
## the same species gets a separate .tres per region with different
## min/max_weight_lb -- e.g. resources/fish/kentucky_largemouth_bass.tres
## vs a hypothetical georgia_largemouth_bass.tres later. FishingLocation
## just points at whichever set of these belongs to it.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName
@export var display_name: String = "Unknown Fish"
@export var sprite: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export var location_id: StringName = &"pond"

## Coins awarded scale with the weight rolled at catch time (see
## FishingController.roll_catch_weight), so a bigger specimen of the same
## species is worth more -- this is what makes "just one more cast" chasing
## a bigger fish feel worthwhile even for a species already caught.
@export var base_coin_value: int = 1

## Realistic weight range for THIS region -- max_weight_lb should be tuned
## against real state-record data for the species+region pair, not a round
## number. See size_skew for why "max" doesn't mean "common".
@export var min_weight_lb: float = 0.5
@export var max_weight_lb: float = 3.0

## How hard the roll is pulled toward min_weight_lb. The actual roll is
## min + (max-min) * pow(randf(), size_skew) -- at skew=1 that's a plain
## uniform roll; every point above 1 makes big fish exponentially rarer.
## Real fishing is nowhere near uniform (you'll land a couple dozen
## "normal" fish before anything near-record shows up), so leave this
## comfortably above 1 for anything but the tamest species. Tune per
## species: a trophy fish (already rare to even hook) can use a gentler
## skew than an everyday species whose absolute top end should feel like
## a real event.
@export var size_skew: float = 4.0

## Lower = shows up more often in FishingController's weighted species roll,
## before any weather/lure affinity adjustment below.
## Legendary fish should be rare enough that landing one feels like an event.
@export var catch_weight: float = 1.0

## Weather/lure/depth preference -- empty array (or the full 0-999 depth
## range) means "doesn't care" for that one condition. When everything
## matches, a matching current weather/equipped lure/water depth
## multiplies this species' effective catch_weight up; a mismatch
## multiplies it down, scaled by bite_affinity_strength. This is what
## makes a picky species realistically go quiet under the wrong
## conditions instead of biting at a flat rate no matter what.
##
## These flat fields are the fallback used for any specimen whose rolled
## weight doesn't fall inside one of size_classes below -- and the only
## fields used at all if size_classes is empty.
@export var preferred_weather: Array[StringName] = []
@export var preferred_lure_types: Array[StringName] = []
@export var preferred_depth_ft: Vector2 = Vector2(0.0, 999.0)

## 0 = doesn't care about weather/lure/depth match at all (catch_weight is
## fixed). 1 = extremely picky -- a full mismatch should make this species
## very unlikely to bite at all, not just "somewhat less likely".
@export_range(0.0, 1.0) var bite_affinity_strength: float = 0.5

## Optional per-weight-band overrides of the four fields above -- e.g. a
## trophy-weight band of the same species preferring completely different
## conditions than an average one. Leave empty for the common case of one
## flat preference profile for the whole species.
@export var size_classes: Array[FishSizeClass] = []

## Returns the preference profile that applies to a specimen of this
## species at the given rolled weight -- whichever size_classes entry
## contains that weight, or this Fish's own flat fields if none matches
## (including when size_classes is empty).
func resolve_profile(weight_lb: float) -> Dictionary:
	for size_class in size_classes:
		if weight_lb >= size_class.min_weight_lb and weight_lb <= size_class.max_weight_lb:
			return {
				"preferred_weather": size_class.preferred_weather,
				"preferred_lure_types": size_class.preferred_lure_types,
				"preferred_depth_ft": size_class.preferred_depth_ft,
				"bite_affinity_strength": size_class.bite_affinity_strength,
			}
	return {
		"preferred_weather": preferred_weather,
		"preferred_lure_types": preferred_lure_types,
		"preferred_depth_ft": preferred_depth_ft,
		"bite_affinity_strength": bite_affinity_strength,
	}
