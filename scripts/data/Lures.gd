class_name Lures
extends RefCounted

## Static registry of every purchasable lure, keyed by id -- lets
## FishingController/shop UI resolve a StringName (from GameManager,
## which only ever stores ids, never Resource references, to keep saves
## plain data) to the actual Lure resource without scanning the
## filesystem at runtime.

const ALL: Array[Lure] = [
	preload("res://resources/lures/night_crawler_jig.tres"),
	preload("res://resources/lures/dough_ball_bait.tres"),
	preload("res://resources/lures/hopper_topwater.tres"),
	preload("res://resources/lures/flash_spinner.tres"),
	preload("res://resources/lures/deep_diver_crank.tres"),
	preload("res://resources/lures/suspending_jerkbait.tres"),
]

static func get_by_id(id: StringName) -> Lure:
	if id == &"":
		return null
	for lure in ALL:
		if lure.id == id:
			return lure
	return null
