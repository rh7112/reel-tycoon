extends Resource
class_name FishingLocation

## One unlockable fishing spot (pond -> lake -> river -> ocean -> deep sea).
## Each location gates a new roster of Fish species behind a coin cost, so
## "unlock the next spot" is always the next visible goal.

@export var id: StringName
@export var display_name: String = "New Spot"
@export var background: Texture2D
@export var unlock_cost: int = 0
@export var min_rod_tier_required: int = 0
@export var species: Array[Fish] = []
