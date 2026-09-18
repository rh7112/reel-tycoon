extends Resource
class_name Lure

## A purchasable lure. `type` is the only field that affects bite odds
## right now -- it's matched against Fish.preferred_lure_types (see
## FishingController._weather_lure_multiplier). `color` and `size` are
## real, ownable, displayed attributes (so "buy the chartreuse one" is a
## real choice), but don't yet feed into the catch math -- that's a
## natural extension once the type-matching system is proven out, not
## added now to keep one axis of "does this actually feel meaningful"
## provable at a time.
##
## Names here are original/generic (spinner, jig, frog-style topwater,
## crankbait, etc.) -- no real lure brand or product names, by design.

@export var id: StringName
@export var display_name: String = "Lure"
@export var type: StringName = &"generic" # matched against Fish.preferred_lure_types
@export var color: Color = Color.WHITE
@export var size: StringName = &"medium" # &"small" / &"medium" / &"large" -- cosmetic/display only for now
@export var icon: Texture2D

## Soft/live bait (worm, dough ball) is consumed with some baseline
## chance every cast, regardless of where you're fishing -- it falls
## off/gets nibbled away even with no snag involved. Hard lures
## (crankbait, jerkbait, spinner, topwater) are NOT consumed by normal
## casting -- they're only lost outright to a snag/bite-off (see
## snag_risk), which is why they're bought individually rather than in
## a pack. See GameManager.owned_lure_counts / FishingController's
## per-cast loss roll for how this is actually applied.
@export var is_consumable: bool = false

## How many units one purchase grants. 1 for hard lures (each purchase
## is one physical lure); >1 for consumables bought in bulk (Ryan's
## real-world pricing example: worms ~$5 for a pack of 20).
@export var pack_size: int = 1
@export var pack_cost: int = 0

## Consumables only: per-cast chance of using up one unit, independent
## of location/conditions -- bait just comes off sometimes.
@export_range(0.0, 1.0) var base_loss_chance: float = 0.0

## Hard lures only: baseline per-cast chance of a snag/bite-off costing
## the lure outright, before FishingLocation.cover_density and depth
## (shallower/bank-adjacent structure) scale it up or down -- see
## FishingController._lure_loss_chance. 0 for consumables.
@export_range(0.0, 1.0) var snag_risk: float = 0.0

## How this bait is fished -- decides which of FishingController's two
## sub-loops applies. &"bobber": a suspended/still bait (worm, dough
## balls/catfish bait) -- cast it out and wait; the bobber visibly dips
## when something takes it. &"retrieve": an actively worked lure
## (spinner, crankbait, jerkbait, topwater) -- you have to hold the
## button to reel it in, and a strike only counts if you actually
## release and tap again to set the hook; just continuing to hold does
## nothing. You're not bobber-fishing a jerkbait.
@export var presentation_style: StringName = &"bobber"

## The water depth (feet) this lure actually works at -- a deep-diving
## crankbait outside its dive range is just scraping bottom or riding the
## surface uselessly, regardless of whether the species on the other end
## would otherwise go for that lure type. Checked before species
## preference in FishingController -- see its header comment.
@export var effective_depth_ft: Vector2 = Vector2(0.0, 999.0)

## The lightest fish that can physically take this lure, in lb -- a 0.2lb
## bluegill cannot fit a 4" jerkbait in its mouth no matter how well
## everything else lines up. 0 means no real minimum (a worm or dough
## ball works on anything from a bluegill to a catfish). See
## FishingController._lure_size_multiplier -- being even moderately
## undersized for a lure craters the odds, not just discounts them a bit.
@export var min_target_weight_lb: float = 0.0
