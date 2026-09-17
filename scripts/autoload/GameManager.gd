extends Node

## Owns everything that isn't currency (Economy) or raw persistence
## (SaveManager): gear tier, unlocked locations, the fish almanac, and the
## idle/offline-earnings calculation that's the main reason a player opens
## an idle game every day.

signal offline_earnings_ready(amount: int, seconds_away: float)

const MAX_OFFLINE_SECONDS := 8.0 * 60.0 * 60.0 # cap at 8h so a week-long
	# absence doesn't hand out a absurd lump sum -- keeps the "come back
	# tomorrow" incentive intact instead of making returns worthless after
	# one long gap.

var rod_tier: int = 0
var unlocked_locations: Array[StringName] = [&"pond"]
var current_location: StringName = &"pond"

## Species id (Fish.id) -> count ever caught. Backs the almanac/collection
## screen -- the completionist hook, separate from the coin economy.
var fish_caught: Dictionary = {}

## Coins earned per second while away, from whatever idle-producing gear
## the player has bought (boats/nets -- not modeled yet beyond this rate).
## Placeholder curve until the real gear-upgrade tree exists.
var idle_coin_rate: float = 0.0

var _last_active_unix: float = 0.0

func _ready() -> void:
	_load()
	_apply_offline_earnings()

func record_catch(fish_id: StringName) -> void:
	fish_caught[fish_id] = fish_caught.get(fish_id, 0) + 1

func unlock_location(location_id: StringName) -> void:
	if not unlocked_locations.has(location_id):
		unlocked_locations.append(location_id)

func _apply_offline_earnings() -> void:
	if _last_active_unix <= 0.0 or idle_coin_rate <= 0.0:
		return
	var seconds_away: float = clamp(Time.get_unix_time_from_system() - _last_active_unix, 0.0, MAX_OFFLINE_SECONDS)
	if seconds_away < 1.0:
		return
	var amount := int(seconds_away * idle_coin_rate)
	if amount <= 0:
		return
	# Not auto-granted -- the fishing scene shows a claim popup (with the
	# 2x-via-rewarded-ad choice) rather than silently crediting coins, so
	# the offline-earnings moment stays a visible, satisfying beat instead
	# of a number that just quietly changed.
	offline_earnings_ready.emit(amount, seconds_away)

func claim_offline_earnings(amount: int) -> void:
	Economy.add_coins(amount)

func save() -> void:
	var data := {
		"economy": Economy.to_save_dict(),
		"rod_tier": rod_tier,
		"unlocked_locations": unlocked_locations,
		"current_location": String(current_location),
		"fish_caught": fish_caught,
		"idle_coin_rate": idle_coin_rate,
		"last_active_unix": Time.get_unix_time_from_system(),
	}
	SaveManager.save_game(data)

func _load() -> void:
	var data := SaveManager.load_game()
	if data.is_empty():
		return
	Economy.load_from_dict(data.get("economy", {}))
	rod_tier = data.get("rod_tier", 0)
	unlocked_locations.assign(data.get("unlocked_locations", [&"pond"]))
	current_location = StringName(data.get("current_location", "pond"))
	fish_caught = data.get("fish_caught", {})
	idle_coin_rate = data.get("idle_coin_rate", 0.0)
	_last_active_unix = data.get("last_active_unix", 0.0)

func _notification(what: int) -> void:
	# Save on every path the OS can use to kill a mobile app -- backgrounding
	# is the common case on phones, not just an explicit quit.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
