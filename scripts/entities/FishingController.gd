extends Control
class_name FishingController

## Drives the entire cast -> wait -> bite -> reel loop for one fishing spot.
## This is the single riskiest part of the whole game to get right -- if
## the reel mini-game doesn't feel good, no amount of economy/progression
## on top of it will make the game "addicting". Everything else in this
## repo exists to support this loop, so it's built as a plain state machine
## rather than reaching for a plugin, to keep it easy to feel out and retune.

enum State { IDLE, CASTING, WAITING_FOR_BITE, BITE_WINDOW, REELING, RESULT }

## Reel-mechanic tuning. A harder/rarer fish gets a faster-draining tension
## bar and a narrower safe band -- see _start_reeling.
const SAFE_BAND: Vector2 = Vector2(0.35, 0.75)
const TENSION_RISE_RATE: float = 0.9   # per second, while holding Reel
const TENSION_FALL_RATE: float = 0.6   # per second, while not holding
const PROGRESS_FILL_RATE: float = 0.35 # per second, only while tension is in the safe band
const BITE_REACTION_WINDOW: float = 1.1 # seconds to tap after a bite before the fish gets away

@export var location: FishingLocation

var _state: State = State.IDLE
var _tension: float = 0.5
var _progress: float = 0.0
var _bite_timer: float = 0.0
var _pending_fish: Fish
var _pending_size_cm: float = 0.0
var _holding_reel: bool = false

signal state_changed(new_state: State)
signal tension_updated(tension: float, progress: float)
signal catch_result(fish: Fish, size_cm: float, coins_awarded: int)
signal fish_escaped()

func _ready() -> void:
	_set_state(State.IDLE)

func get_state() -> State:
	return _state

func cast() -> void:
	if _state != State.IDLE:
		return
	_set_state(State.CASTING)
	# Cast animation/travel time is cosmetic for now -- tune once real art
	# and a rod-tier-based cast distance stat exist.
	await get_tree().create_timer(0.6).timeout
	_start_waiting()

func _start_waiting() -> void:
	_set_state(State.WAITING_FOR_BITE)
	# Lower rod tier waits longer -- this is the one place gear progression
	# should be felt turn-to-turn, not just in bigger numbers.
	var wait_time := randf_range(1.5, 4.0)
	await get_tree().create_timer(wait_time).timeout
	if _state == State.WAITING_FOR_BITE:
		_start_bite_window()

func _start_bite_window() -> void:
	_set_state(State.BITE_WINDOW)
	_bite_timer = BITE_REACTION_WINDOW

## Call from the Cast/Reel button's pressed signal during BITE_WINDOW to
## hook the fish; missing the window loses it. Same input trigger the
## player already has their thumb on, so there's no new button to teach.
func on_action_pressed() -> void:
	match _state:
		State.BITE_WINDOW:
			_start_reeling()
		State.REELING:
			_holding_reel = true

func on_action_released() -> void:
	if _state == State.REELING:
		_holding_reel = false

func _start_reeling() -> void:
	_pending_fish = _roll_fish()
	if _pending_fish == null:
		_set_state(State.IDLE)
		return
	_pending_size_cm = randf_range(_pending_fish.min_size_cm, _pending_fish.max_size_cm)
	_tension = 0.5
	_progress = 0.0
	_set_state(State.REELING)

func _process(delta: float) -> void:
	match _state:
		State.BITE_WINDOW:
			_bite_timer -= delta
			if _bite_timer <= 0.0:
				_set_state(State.IDLE)
				fish_escaped.emit()
		State.REELING:
			_tick_reel(delta)

func _tick_reel(delta: float) -> void:
	_tension += (TENSION_RISE_RATE if _holding_reel else -TENSION_FALL_RATE) * delta
	_tension = clamp(_tension, 0.0, 1.0)

	if _tension <= 0.0:
		_finish_reel(false) # fish swam off, line went slack
		return
	if _tension >= 1.0:
		_finish_reel(false) # line snapped, pulled too hard
		return

	if _tension >= SAFE_BAND.x and _tension <= SAFE_BAND.y:
		_progress += PROGRESS_FILL_RATE * delta

	tension_updated.emit(_tension, _progress)

	if _progress >= 1.0:
		_finish_reel(true)

func _finish_reel(success: bool) -> void:
	if success:
		var coins := _award_catch(_pending_fish, _pending_size_cm)
		GameManager.record_catch(_pending_fish.id)
		catch_result.emit(_pending_fish, _pending_size_cm, coins)
	else:
		fish_escaped.emit()
	_pending_fish = null
	_set_state(State.RESULT)
	await get_tree().create_timer(0.9).timeout
	_set_state(State.IDLE)

## Size scales value continuously within the species' range (see Fish.gd),
## so even a common species stays worth chasing if a bigger one shows up.
func _award_catch(fish: Fish, size_cm: float) -> int:
	var size_ratio: float = 1.0
	if fish.max_size_cm > fish.min_size_cm:
		size_ratio = 1.0 + (size_cm - fish.min_size_cm) / (fish.max_size_cm - fish.min_size_cm)
	var coins := int(round(fish.base_coin_value * size_ratio))
	Economy.add_coins(coins)
	return coins

func _roll_fish() -> Fish:
	if location == null or location.species.is_empty():
		push_warning("FishingController: no location/species set, cannot roll a catch")
		return null
	var total_weight: float = 0.0
	for fish in location.species:
		total_weight += max(fish.catch_weight, 0.0)
	if total_weight <= 0.0:
		return location.species[0]
	var roll := randf() * total_weight
	var running: float = 0.0
	for fish in location.species:
		running += max(fish.catch_weight, 0.0)
		if roll <= running:
			return fish
	return location.species[-1]

func _set_state(new_state: State) -> void:
	_state = new_state
	state_changed.emit(_state)
