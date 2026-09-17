extends Resource
class_name Fish

## One fish species. Instances live as .tres files under resources/fish/ so
## adding a new species is a data change, not a code change -- the fishing
## loop and economy never need to know how many species exist.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName
@export var display_name: String = "Unknown Fish"
@export var sprite: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export var location_id: StringName = &"pond"

## Coins awarded scale with the size rolled at catch time (see
## FishingController.roll_catch_size), so a bigger specimen of the same
## species is worth more -- this is what makes "just one more cast" chasing
## a bigger fish feel worthwhile even for a species already caught.
@export var base_coin_value: int = 1
@export var min_size_cm: float = 5.0
@export var max_size_cm: float = 20.0

## Lower = shows up more often in FishingController's weighted species roll.
## Legendary fish should be rare enough that landing one feels like an event.
@export var catch_weight: float = 1.0
