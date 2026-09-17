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

## How long a cast sits before something bites -- wide and slow on
## purpose. A near-instant bite every cast doesn't feel like fishing.
const MIN_WAIT_SECONDS: float = 4.0
const MAX_WAIT_SECONDS: float = 18.0

## How long before the bite the sighting preview fires, for players who
## own polarized glasses -- see _process/get_current_style.
const SIGHT_PREVIEW_SECONDS: float = 1.2

@export var location: FishingLocation

var _state: State = State.IDLE
var _tension: float = 0.5
var _progress: float = 0.0
var _wait_timer: float = 0.0
var _bite_timer: float = 0.0
var _pending_fish: Fish
var _pending_weight_lb: float = 0.0
var _sighted: bool = false
var _current_depth_ft: float = 0.0
var _holding_reel: bool = false

signal state_changed(new_state: State)
signal tension_updated(tension: float, progress: float)
signal catch_result(fish: Fish, weight_lb: float, coins_awarded: int, rarity_tier: CardRarity.Tier)
signal fish_escaped()

## Only fires for a player who owns polarized glasses -- a rough size
## impression (never the exact weight) of what's about to bite, shortly
## before it does. size_bucket is one of "small"/"medium"/"large"/"trophy".
signal fish_sighted(size_bucket: String)

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
		_current_depth_ft = _default_depth_ft()
	_set_state(State.IDLE)

func get_state() -> State:
	return _state

## Exposed so the HUD can display/edit current conditions -- otherwise
## the whole weather/lure/depth system is invisible and unlearnable to
## the player. Depth is a player choice now, not rolled per cast (see
## set_depth) -- this just reports whatever's currently selected.
func get_current_depth_ft() -> float:
	return _current_depth_ft

## The deepest the player can currently fish this region -- whichever is
## smaller of the region's own real range and the current boat tier's
## cap (BoatTiers.gd). A rickety dock keeps you in the shallows even on
## a lake that goes much deeper than that.
func get_max_reachable_depth_ft() -> float:
	if location == null:
		return 999.0
	var boat_cap: float = BoatTiers.get_tier(GameManager.boat_tier).max_depth_ft
	return min(location.max_depth_ft, boat_cap)

func _default_depth_ft() -> float:
	if location == null:
		return 5.0
	return (location.min_depth_ft + get_max_reachable_depth_ft()) * 0.5

## Called by the depth control in the HUD. Clamped to whatever's
## actually reachable right now -- there's no fishing deeper than the
## lake gets, or deeper than the current boat can take you.
func set_depth(depth_ft: float) -> void:
	if location != null:
		_current_depth_ft = clamp(depth_ft, location.min_depth_ft, get_max_reachable_depth_ft())
	else:
		_current_depth_ft = depth_ft

## Called by MenuPanel when the player travels to a different region.
## Forces back to IDLE first -- switching mid-cast/mid-reel would leave
## _pending_fish pointing at a species that may not even exist in the new
## region's roster.
func set_location(new_location: FishingLocation) -> void:
	location = new_location
	WeatherService.prime(new_location.id)
	_current_depth_ft = _default_depth_ft()
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
	_holding_reel = false
	_set_state(State.CASTING)
	# Cast animation/travel time is cosmetic for now -- tune once real art
	# and a rod-tier-based cast distance stat exist.
	await get_tree().create_timer(0.6).timeout
	_start_waiting()

## Which of the two sub-loops this cast follows -- a still/suspended
## bait waits passively (the classic bobber-watch), an actively worked
## lure only advances toward a bite while the player holds the button to
## reel it in. A bare hook (no lure equipped) defaults to the passive
## style -- see Lure.gd's presentation_style for the full reasoning.
## Public so the HUD can branch its status text/visuals the same way
## without duplicating the "no lure equipped" fallback rule.
func get_current_style() -> StringName:
	var lure: Lure = Lures.get_by_id(GameManager.equipped_lure)
	return lure.presentation_style if lure != null else &"bobber"

## Rolls the candidate catch now, at the start of the wait, rather than
## at hook-time -- this is what lets polarized glasses show a real
## preview of the actual fish that's about to bite (see _process),
## instead of a fake placeholder rolled separately from the real one.
func _start_waiting() -> void:
	var candidate := _roll_candidate_catch()
	if candidate.is_empty():
		_set_state(State.IDLE)
		return
	_pending_fish = candidate.fish
	_pending_weight_lb = candidate.weight_lb
	_sighted = false
	_set_state(State.WAITING_FOR_BITE)
	_wait_timer = randf_range(MIN_WAIT_SECONDS, MAX_WAIT_SECONDS)

func _start_bite_window() -> void:
	_set_state(State.BITE_WINDOW)
	_bite_timer = _tier_stats().bite_window

## Call from the Cast/Reel button's pressed signal. Behavior depends on
## state AND, during WAITING_FOR_BITE, on the equipped lure's
## presentation_style:
## - Bobber style: a tap here means "bring the bait in early", not "set
##   the hook" -- there's nothing to hook yet, the bobber hasn't moved.
## - Retrieve style: a tap here means "start actively reeling" -- the
##   wait timer only counts down while held (see _process). If a bite
##   window opens while the player is already holding from the retrieve,
##   nothing extra happens here -- Godot only fires this on a fresh
##   press, so simply continuing to hold does NOT set the hook. They
##   have to actually release and tap again once BITE_WINDOW starts,
##   which is exactly the "hold to reel, tap to set the hook" skill
##   moment this is supposed to be.
func on_action_pressed() -> void:
	match _state:
		State.WAITING_FOR_BITE:
			if get_current_style() == &"bobber":
				_reel_in_early()
			else:
				_holding_reel = true
		State.BITE_WINDOW:
			_start_reeling()
		State.REELING:
			_holding_reel = true

func on_action_released() -> void:
	match _state:
		State.WAITING_FOR_BITE:
			if get_current_style() != &"bobber":
				_holding_reel = false # pauses the retrieve -- the wait timer just stops, doesn't reset
		State.REELING:
			_holding_reel = false

## Bobber style only: tap while the bait's still out to bring it in
## early instead of waiting out a spot that isn't producing.
func _reel_in_early() -> void:
	_pending_fish = null
	_set_state(State.IDLE)

## The candidate was already rolled back in _start_waiting -- this just
## starts the reel mini-game against it. No re-roll: whatever the
## player was shown (if they own polarized glasses) is exactly what's
## on the line.
func _start_reeling() -> void:
	if _pending_fish == null:
		_set_state(State.IDLE)
		return
	_tension = 0.5
	_progress = 0.0
	_set_state(State.REELING)

func _process(delta: float) -> void:
	match _state:
		State.WAITING_FOR_BITE:
			# Bobber style counts down unconditionally (passive wait);
			# retrieve style only counts down while actively held.
			if get_current_style() == &"bobber" or _holding_reel:
				_wait_timer -= delta
				if not _sighted and GameManager.owns_polarized_glasses and _wait_timer <= SIGHT_PREVIEW_SECONDS:
					_sighted = true
					fish_sighted.emit(_size_bucket(_pending_fish, _pending_weight_lb))
				if _wait_timer <= 0.0:
					_start_bite_window()
		State.BITE_WINDOW:
			_bite_timer -= delta
			if _bite_timer <= 0.0:
				_set_state(State.IDLE)
				fish_escaped.emit()
		State.REELING:
			_tick_reel(delta)

func _tick_reel(delta: float) -> void:
	var stats := _tier_stats()
	var reel: Dictionary = ReelTypes.get_by_id(GameManager.equipped_reel_type)
	var line: Dictionary = LineTypes.get_by_id(GameManager.equipped_line_type)

	# Instant snap-off -- a distinct failure mode from the tension bar
	# itself, matching a push-button reel's real weak drag, and a line
	# rated well under the fish's actual weight.
	var snap_chance: float = reel.snap_chance_per_sec + _line_weight_snap_bonus(_pending_weight_lb)
	if snap_chance > 0.0 and randf() < snap_chance * delta:
		_finish_reel(false)
		return

	var noise_amplitude: float = _size_noise_amplitude(_pending_fish, _pending_weight_lb) * line.noise_dampen_mult
	var noise := randf_range(-noise_amplitude, noise_amplitude)
	var rise_rate: float = stats.tension_rise_rate * reel.tension_rise_mult
	var fall_rate: float = stats.tension_fall_rate * reel.tension_fall_mult
	_tension += (rise_rate if _holding_reel else -fall_rate) * delta + noise * delta
	_tension = clamp(_tension, 0.0, 1.0)

	if _tension <= 0.0:
		_finish_reel(false) # fish swam off, line went slack
		return
	if _tension >= 1.0:
		_finish_reel(false) # line snapped, pulled too hard
		return

	var safe_band := get_safe_band()
	if _tension >= safe_band.x and _tension <= safe_band.y:
		var fill_rate: float = stats.progress_fill_rate * reel.progress_fill_mult * line.progress_fill_mult
		fill_rate *= _lure_reel_match_bonus(reel.preferred_lure_types)
		_progress += fill_rate * delta

	tension_updated.emit(_tension, _progress)

	if _progress >= 1.0:
		_finish_reel(true)

func _size_noise_amplitude(fish: Fish, weight_lb: float) -> float:
	if fish == null:
		return 0.0
	return _weight_ratio(fish, weight_lb) * MAX_SIZE_NOISE_AMPLITUDE

## Extra snap risk when the rolled fish is heavier than the spooled line
## is rated for -- "a 20lb fish on 10lb test" should be genuinely risky.
func _line_weight_snap_bonus(fish_weight_lb: float) -> float:
	var overage: float = fish_weight_lb - float(GameManager.line_weight_lb)
	return max(overage, 0.0) * 0.01

## A baitcaster paired with a crankbait (or spinning with a spinner/worm/
## frog) works better together than a mismatched pairing -- see
## ReelTypes.gd for why this isn't just "baitcaster is strictly better".
func _lure_reel_match_bonus(reel_preferred_lure_types: Array) -> float:
	if reel_preferred_lure_types.is_empty():
		return 1.0
	var lure: Lure = Lures.get_by_id(GameManager.equipped_lure)
	if lure == null:
		return 1.0
	return 1.15 if reel_preferred_lure_types.has(lure.type) else 0.9

## Line type's stealth (or lack of it) plus a line-weight visibility
## penalty (heavier = more visible), combined into one leniency value
## that nudges how punishing a weather/lure/depth mismatch is -- see
## _affinity_multiplier.
func _tackle_leniency() -> float:
	var line: Dictionary = LineTypes.get_by_id(GameManager.equipped_line_type)
	var visibility_penalty: float = clamp((float(GameManager.line_weight_lb) - 10.0) * 0.01, -0.05, 0.15)
	return line.affinity_leniency - visibility_penalty

func _finish_reel(success: bool) -> void:
	if success:
		var ratio := _weight_ratio(_pending_fish, _pending_weight_lb)
		var coins := _award_catch(_pending_fish, ratio)
		var tier := CardRarity.tier_for_ratio(ratio)
		GameManager.record_catch(_pending_fish, _pending_weight_lb)
		GameManager.record_card(_pending_fish, _pending_weight_lb, ratio)
		catch_result.emit(_pending_fish, _pending_weight_lb, coins, tier)
	else:
		fish_escaped.emit()
	_pending_fish = null
	_set_state(State.RESULT)
	await get_tree().create_timer(0.9).timeout
	_set_state(State.IDLE)

## Rough, non-numeric size impression for the sighting preview -- real
## polarized glasses give an impression, not a readout, so this never
## exposes the actual rolled weight or ratio to the player.
func _size_bucket(fish: Fish, weight_lb: float) -> String:
	var ratio := _weight_ratio(fish, weight_lb)
	if ratio < 0.25:
		return "small"
	if ratio < 0.6:
		return "medium"
	if ratio < 0.85:
		return "large"
	return "trophy"

## 0..1 position within this species' own region-tuned weight range --
## the single number that drives both coin value AND card rarity (see
## CardRarity.gd), so a catch's reward and its rarity always agree with each
## other about how good a catch it was.
func _weight_ratio(fish: Fish, weight_lb: float) -> float:
	if fish.max_weight_lb <= fish.min_weight_lb:
		return 0.0
	return clamp((weight_lb - fish.min_weight_lb) / (fish.max_weight_lb - fish.min_weight_lb), 0.0, 1.0)

## Coins scale continuously with rolled weight within the species' region
## range, so even a common species stays worth chasing if a bigger one
## shows up. Sponsorship (SponsorshipTiers.gd) multiplies the total.
func _award_catch(fish: Fish, weight_ratio: float) -> int:
	var coin_mult: float = SponsorshipTiers.get_tier(GameManager.sponsorship_tier).coin_mult
	var coins := int(round(fish.base_coin_value * (1.0 + weight_ratio) * coin_mult))
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
	var tackle_leniency := _tackle_leniency()

	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0
	for fish in location.species:
		var weight_lb := _roll_weight(fish)
		var profile := fish.resolve_profile(weight_lb)
		var multiplier := _affinity_multiplier(profile, weather_id, lure, _current_depth_ft, tackle_leniency)
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

func _affinity_multiplier(profile: Dictionary, weather_id: StringName, lure: Lure, depth_ft: float, tackle_leniency: float) -> float:
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
	# tackle_leniency (from line type + line weight -- see _tackle_leniency)
	# nudges how forgiving a mismatch is: a stealthy line softens it, a
	# heavy/visible one makes it worse.
	var bad_multiplier: float = clamp(lerp(1.0, 0.05, strength) + tackle_leniency, 0.01, 1.0)
	var good_multiplier: float = lerp(1.0, 3.0, strength)
	return lerp(bad_multiplier, good_multiplier, match_ratio)

func _set_state(new_state: State) -> void:
	_state = new_state
	state_changed.emit(_state)
