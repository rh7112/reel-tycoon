extends Resource
class_name FishingLocation

## One region/level (Home Pond -> Northern Lake -> Kentucky Lake -> ...).
## The name stayed "FishingLocation" from the original single-spot
## prototype, but this is now the "region" concept end to end -- unlocking
## one gates a real-world-flavored roster of species (each Fish.tres tuned
## with weight ranges realistic for THAT region, not a global species
## table) plus its own reel-difficulty progression, independent of every
## other region.
##
## Difficulty reset on arrival, by design (per Ryan): a brand-new region
## starts the catch-progress safe band narrow (starting_safe_band_width,
## default 15% of the bar) regardless of how mastered the previous region
## was -- GameManager.region_mastery tracks upgrade progress per region id,
## separately from the permanent, global rod tier (RodTiers.gd). Rod tier
## affects reel *rates* everywhere; region mastery affects how forgiving
## the *target* is, only in that region.

@export var id: StringName
@export var display_name: String = "New Region"

## Where this sits in the intended real-world progression -- used for
## sorting the travel/map screen and gating "next region" reveals. Not
## used for anything else, so gaps/reordering are safe.
@export var order: int = 0

@export var background: Texture2D
@export var theme_color: Color = Color(0.09, 0.29, 0.45, 1) # placeholder water tint until real art
@export var unlock_cost: int = 0
@export var min_rod_tier_required: int = 0
@export var species: Array[Fish] = []

## If set, unlocking this region ALSO requires owning a card (any
## rarity) of every species native to the named region -- the
## "complete the set before you move on" adventure-structure gate, on
## top of the coin cost above. See GameManager.has_completed_region.
@export var requires_complete_region: StringName = &""

## Realistic water-depth range for this whole region, in feet -- each cast
## rolls a fresh depth from this range (FishingController.cast), which
## then interacts with the chosen lure's effective_depth_ft and each
## fish's preferred_depth_ft. Deliberately NOT shared/global like weather:
## where your line happens to land is inherently a per-cast thing, not
## something that needs the same cross-player sync weather does.
@export var min_depth_ft: float = 1.0
@export var max_depth_ft: float = 15.0

## "Waves" as a condition folds into weather (&"windy") rather than being
## a separate tracked axis -- one less moving part, same practical effect.

## Safe-band width (as a fraction of the tension bar) a brand-new arrival
## starts with vs. what full mastery of this region unlocks. 0.15 means
## "the green zone is 15% of the bar" -- deliberately tight, so the first
## few casts in a new region feel like they did back at Home Pond even if
## the player has a maxed-out rod.
@export_range(0.0, 1.0) var starting_safe_band_width: float = 0.15
@export_range(0.0, 1.0) var max_safe_band_width: float = 0.65

## How many discrete purchases it takes to walk from starting to max width.
@export var mastery_levels: int = 5
@export var mastery_base_cost: int = 30
@export var mastery_cost_growth: float = 1.6

## Real-world coordinates for a region tied to an actual lake -- when set,
## WeatherService fetches REAL current weather for this exact spot instead
## of rolling a local random condition, so every player sees the same
## weather (it's the same real world, no backend of ours required). Leave
## both at 0 for a fictional region (Home Pond) -- (0,0) is the middle of
## the Atlantic, not a real lake, so it doubles safely as "not set"
## without a separate boolean flag.
@export var latitude: float = 0.0
@export var longitude: float = 0.0

func has_real_coordinates() -> bool:
	return latitude != 0.0 or longitude != 0.0

## Coin cost to go from mastery level `level` to `level + 1` in this region.
func mastery_cost_for_level(level: int) -> int:
	return int(round(mastery_base_cost * pow(mastery_cost_growth, level)))

## Interpolates the safe-band width for a given mastery level, clamped to
## [starting_safe_band_width, max_safe_band_width].
func safe_band_width_for_mastery(level: int) -> float:
	var t: float = clamp(float(level) / float(mastery_levels), 0.0, 1.0)
	return lerp(starting_safe_band_width, max_safe_band_width, t)
