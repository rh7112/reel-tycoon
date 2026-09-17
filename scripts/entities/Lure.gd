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
@export var cost: int = 0
@export var icon: Texture2D

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
