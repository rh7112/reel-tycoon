extends Control
class_name FishingController

## Drives the entire cast -> wait -> bite -> reel loop for one fishing spot.
##
## Catch selection: each cast rolls a *candidate specimen* (species +
## weight) from every species in the region, then weighs which candidate
## actually bites by how well current weather, the equipped lure's type,
## and the equipped lure's effective depth range line up with that exact
## specimen's preferences (Fish.resolve_profile -- a species can prefer
## different conditions at different weights). Rolling the specimen
## before deciding who bites -- rather than picking a species first and
## rolling its weight after -- is what lets "this individual 12 lb fish"
## have its own preferences instead of only ever a species-wide average.
##
## This is the single riskiest part of the whole game to get right -- if
## the reel mini-game doesn't feel good, no amount of economy/progression
## on top of it will make the game "addicting". Everything else in this
## repo exists to support this loop, so it's built as a plain state machine
## rather than reaching for a plugin, to keep it easy to feel out and retune.

enum State { IDLE, CASTING, WAITING_FOR_BITE, BITE_WINDOW, REELING, RESULT }

## Bigger specimens fight harder: the tension bar gets random jitter added
## on top of the normal rise/fall, scaled by how close the rolled weight
## is to that species' realistic max for this region (see _tick_reel).
## Units: fraction of the tension bar per second, at size_ratio == 1.0.
const MAX_SIZE_NOISE_AMPLITUDE: float = 1.4

## A lure fished at the wrong depth for its own design (a deep crankbait
## scraping bottom in 2ft of water) is treated as close to dead weight
## regardless of species preference -- see _affinity_multiplier.
const WRONG_DEPTH_LURE_MULTIPLIER: float = 0.05

@export var location: FishingLocation

var _state: State = State.IDLE
var _tension: float = 0.5
var _progress: float = 0.0
var _bite_timer: float = 0.0
var _pending_fish: Fish
var _pending_weight_lb: float = 0.0
var _current_depth_ft: float = 0.0
var _holding_reel: bool = false

signal state_changed(new_state: State)
signal tension_updated(tension: float, progress: float)
signal catch_result(fish: Fish, weight_lb: float, coins_awarded: int, rarity_tier: Rarity.Tier)
signal fish_escaped()

func _ready() -> void:
	# The scene's exported `location` is only the fresh-install default --
	# a returning player resumes wherever GameManager last saved them.
	var saved_location := Regions.get_by_id(GameManager.current_location)
	if saved_location != null:
		location = saved_location
	if location != null:
		# Real-weather regions hit the network -- start that now rather
		# than waiting for the first bite roll to need it. A cast takes a
		# few seconds anyway, usually enough for the request to land first.
		WeatherService.prime(location.id)
	_set_state(State.IDLE)

func get_state() -> State:
	return _state

## Exposed so the HUD can display current conditions (weather + this
## cast's rolled depth) -- otherwise the whole weather/lure/depth system
## is invisible and unlearnable to the player.
func get_current_depth_ft() -> float:
	return _current_depth_ft

## Called by MenuPanel when the player travels to a different region.
## Forces back to IDLE first -- switching mid-cast/mid-reel would leave
## _pending_fish pointing at a species that may not even exist in the new
## region's roster.
func set_location(new_location: FishingLocation) -> void:
	location = new_location
	WeatherService.prime(new_location.id)
	_pending_fish = null
	_holding_reel = false
	_set_state(State.IDLE)

## Rod tier controls reel *rates* (how forgiving the physics feel) --
## looked up fresh each time rather than cached, so a mid-session upgrade
## takes effect immediately without needing an extra refresh call.
func _tier_stats() -> Dictionary:
	return RodTiers.get_tier(GameManager.rod_tier)

## Region mastery controls the safe-band *width* -- separate progression
## axis from rod tier, and the one that resets (to this region's own
## starting_safe_band_width) whenever the player is somewhere new. See
## FishingLocation.gd's header for the full reasoning.
func get_safe_band() -> Vector2:
	if location == null:
		return Vector2(0.35, 0.75) # sane fallback if no region is assigned
	var mastery: int = GameManager.get_region_mastery(location.id)
	var width: float = location.safe_band_width_for_mastery(mastery)
	var half: float = width * 0.5
	return Vector2(0.5 - half, 0.5 + half)

func cast() -> void:
	if _state != State.IDLE:
		return
	_current_depth_ft = randf_range(location.min_depth_ft, location.max_depth_ft) if location != null else 5.0
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
	_bite_timer = _tier_stats().bite_window

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
	var candidate := _roll_candidate_catch()
	if candidate.is_empty():
		_set_state(State.IDLE)
		return
	_pending_fish = candidate.fish
	_pending_weight_lb = candidate.weight_lb
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
	var stats := _tier_stats()
	var noise_amplitude := _size_noise_amplitude(_pending_fish, _pending_weight_lb)
	var noise := randf_range(-noise_amplitude, noise_amplitude)
	_tension += (stats.tension_rise_rate if _holding_reel else -stats.tension_fall_rate) * delta + noise * delta
	_tension = clamp(_tension, 0.0, 1.0)

	if _tension <= 0.0:
		_finish_reel(false) # fish swam off, line went slack
		return
	if _tension >= 1.0:
		_finish_reel(false) # line snapped, pulled too hard
		return

	var safe_band := get_safe_band()
	if _tension >= safe_band.x and _tension <= safe_band.y:
		_progress += stats.progress_fill_rate * delta

	tension_updated.emit(_tension, _progress)

	if _progress >= 1.0:
		_finish_reel(true)

func _size_noise_amplitude(fish: Fish, weight_lb: float) -> float:
	if fish == null:
		return 0.0
	return _weight_ratio(fish, weight_lb) * MAX_SIZE_NOISE_AMPLITUDE

func _finish_reel(success: bool) -> void:
	if success:
		var ratio := _weight_ratio(_pending_fish, _pending_weight_lb)
		var coins := _award_catch(_pending_fish, ratio)
		var tier := Rarity.tier_for_ratio(ratio)
		GameManager.record_catch(_pending_fish, _pending_weight_lb)
		GameManager.record_card(_pending_fish, _pending_weight_lb, ratio)
		catch_result.emit(_pending_fish, _pending_weight_lb, coins, tier)
	else:
		fish_escaped.emit()
	_pending_fish = null
	_set_state(State.RESULT)
	await get_tree().create_timer(0.9).timeout
	_set_state(State.IDLE)

## 0..1 position within this species' own region-tuned weight range --
## the single number that drives both coin value AND card rarity (see
## Rarity.gd), so a catch's reward and its rarity always agree with each
## other about how good a catch it was.
func _weight_ratio(fish: Fish, weight_lb: float) -> float:
	if fish.max_weight_lb <= fish.min_weight_lb:
		return 0.0
	return clamp((weight_lb - fish.min_weight_lb) / (fish.max_weight_lb - fish.min_weight_lb), 0.0, 1.0)

## Coins scale continuously with rolled weight within the species' region
## range, so even a common species stays worth chasing if a bigger one
## shows up.
func _award_catch(fish: Fish, weight_ratio: float) -> int:
	var coins := int(round(fish.base_coin_value * (1.0 + weight_ratio)))
	Economy.add_coins(coins)
	return coins

## Rolls one candidate (species + weight) per species in the region, scores
## each by how well conditions suit THAT specific rolled specimen, then
## picks one weighted by score. Returns the picked fish and its
## already-rolled weight together (never re-rolls after picking), so the
## conditions that made a specimen likely to bite are the same specimen
## that actually comes out of the water.
func _roll_candidate_catch() -> Dictionary:
	if location == null or location.species.is_empty():
		push_warning("FishingController: no location/species set, cannot roll a catch")
		return {}

	var weather_id: StringName = WeatherService.get_weather(location.id)
	var lure: Lure = Lures.get_by_id(GameManager.equipped_lure)

	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0
	for fish in location.species:
		var weight_lb := _roll_weight(fish)
		var profile := fish.resolve_profile(weight_lb)
		var multiplier := _affinity_multiplier(profile, weather_id, lure, _current_depth_ft)
		var effective_weight: float = max(fish.catch_weight, 0.0) * multiplier
		candidates.append({"fish": fish, "weight_lb": weight_lb, "effective_weight": effective_weight})
		total_weight += effective_weight

	if total_weight <= 0.0:
		var fallback: Dictionary = candidates[randi() % candidates.size()]
		return {"fish": fallback.fish, "weight_lb": fallback.weight_lb}

	var roll := randf() * total_weight
	var running: float = 0.0
	for candidate in candidates:
		running += candidate.effective_weight
		if roll <= running:
			return {"fish": candidate.fish, "weight_lb": candidate.weight_lb}
	var last: Dictionary = candidates[-1]
	return {"fish": last.fish, "weight_lb": last.weight_lb}

## Realistic skew: min + (max-min) * pow(randf(), size_skew). At skew=1
## this is a plain uniform roll; every point above 1 makes big fish
## exponentially rarer, matching "you'll land two dozen normal fish before
## anything near-record shows up" rather than a flat chance across the
## whole range.
func _roll_weight(fish: Fish) -> float:
	return fish.min_weight_lb + (fish.max_weight_lb - fish.min_weight_lb) * pow(randf(), fish.size_skew)

func _affinity_multiplier(profile: Dictionary, weather_id: StringName, lure: Lure, depth_ft: float) -> float:
	var strength: float = profile.bite_affinity_strength
	if strength <= 0.0:
		return 1.0

	if lure != null:
		var lure_depth: Vector2 = lure.effective_depth_ft
		if depth_ft < lure_depth.x or depth_ft > lure_depth.y:
			return lerp(1.0, WRONG_DEPTH_LURE_MULTIPLIER, strength)

	var weather_match: bool = profile.preferred_weather.is_empty() or profile.preferred_weather.has(weather_id)
	var lure_match: bool = profile.preferred_lure_types.is_empty() or (lure != null and profile.preferred_lure_types.has(lure.type))
	var depth_range: Vector2 = profile.preferred_depth_ft
	var depth_match: bool = depth_ft >= depth_range.x and depth_ft <= depth_range.y

	var match_ratio: float = float(int(weather_match) + int(lure_match) + int(depth_match)) / 3.0
	var bad_multiplier: float = lerp(1.0, 0.05, strength)
	var good_multiplier: float = lerp(1.0, 3.0, strength)
	return lerp(bad_multiplier, good_multiplier, match_ratio)

func _set_state(new_state: State) -> void:
	_state = new_state
	state_changed.emit(_state)
