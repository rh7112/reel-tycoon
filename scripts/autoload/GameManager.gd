extends Node

## Owns everything that isn't currency (Economy) or raw persistence
## (SaveManager): gear tier, region unlocks/mastery, owned lures, the fish
## records/almanac, and the idle/offline-earnings calculation that's the
## main reason a player opens an idle game every day.

signal offline_earnings_ready(amount: int, seconds_away: float)

const MAX_OFFLINE_SECONDS := 8.0 * 60.0 * 60.0 # cap at 8h so a week-long
	# absence doesn't hand out a absurd lump sum -- keeps the "come back
	# tomorrow" incentive intact instead of making returns worthless after
	# one long gap.

var rod_tier: int = 0
var unlocked_locations: Array[StringName] = [&"pond"]
var current_location: StringName = &"pond"

## Region id -> mastery level (int). Missing key == level 0 (the region's
## own starting_safe_band_width). See FishingLocation.gd for why this is
## deliberately separate from rod_tier.
var region_mastery: Dictionary = {}

var owned_lures: Array[StringName] = []
var equipped_lure: StringName = &""

## One-time gear purchase -- lets the player see an approaching fish's
## rough size (a shadow, bucketed small/medium/large/trophy, never an
## exact weight -- real polarized glasses give an impression, not a
## readout) before it bites, via FishingController.fish_sighted.
var owns_polarized_glasses: bool = false

## Tackle -- see ReelTypes.gd/LineTypes.gd for what each id actually does.
## Reel/line TYPE are owned/equipped like lures (a real tradeoff between
## options, not a strict upgrade ladder). Line WEIGHT is a free choice,
## not something bought -- it's "what pound test did you spool on today,"
## a strategic pick with real trade-offs (heavier = handles big fish
## without snapping, but spookier to line-shy species), not a gear tier.
var owned_reel_types: Array[StringName] = [&"spinning"]
var equipped_reel_type: StringName = &"spinning"
var owned_line_types: Array[StringName] = [&"monofilament"]
var equipped_line_type: StringName = &"monofilament"
var line_weight_lb: int = 10

## Species id (Fish.id) -> {count, min_weight_lb, max_weight_lb, display_name}.
## Personal-best tracking, independent of any one card -- "smallest and
## biggest I've ever landed of this species," regardless of rarity tier.
var fish_records: Dictionary = {}

## "{species_id}:{rarity_tier}" -> {species_id, region_id, display_name,
## rarity_tier, count, best_weight_lb}. The actual collection/binder --
## every catch produces a card at whatever rarity its rolled weight
## lands in (see CardRarity.gd), and duplicates at the same species+tier just
## increment count. This is also what gates a region's "complete the set"
## unlock requirement -- see has_completed_region.
var cards: Dictionary = {}

## Coins earned per second while away, from whatever idle-producing gear
## the player has bought (boats/nets -- not modeled yet beyond this rate).
## Placeholder curve until the real gear-upgrade tree exists.
var idle_coin_rate: float = 0.0

var _last_active_unix: float = 0.0

func _ready() -> void:
	_load()
	_apply_offline_earnings()

## Call once per successful catch. Updates the count and the personal
## best/smallest for this species -- the actual leaderboard-worthy numbers.
func record_catch(fish: Fish, weight_lb: float) -> void:
	# Keyed by a plain String, not the raw StringName -- after a save/load
	# round trip through JSON (which only knows plain string keys), a
	# StringName key here would risk not matching fish.id on lookup.
	var key := String(fish.id)
	var record: Dictionary = fish_records.get(key, {})
	if record.is_empty():
		record = {
			"display_name": fish.display_name,
			"count": 0,
			"min_weight_lb": weight_lb,
			"max_weight_lb": weight_lb,
		}
	record.count += 1
	record.min_weight_lb = min(record.min_weight_lb, weight_lb)
	record.max_weight_lb = max(record.max_weight_lb, weight_lb)
	fish_records[key] = record

## Called once per successful catch, alongside record_catch -- produces
## (or adds a duplicate to) this catch's card. weight_ratio must be the
## same 0..1 value used to determine the catch's coin value, so a card's
## rarity always matches what the player actually experienced.
func record_card(fish: Fish, weight_lb: float, weight_ratio: float) -> void:
	var tier: CardRarity.Tier = CardRarity.tier_for_ratio(weight_ratio)
	var key := "%s:%d" % [fish.id, tier]
	var card: Dictionary = cards.get(key, {})
	if card.is_empty():
		card = {
			"species_id": String(fish.id),
			"region_id": String(fish.location_id),
			"display_name": fish.display_name,
			"rarity_tier": tier,
			"count": 0,
			"best_weight_lb": weight_lb,
		}
	card.count += 1
	card.best_weight_lb = max(card.best_weight_lb, weight_lb)
	cards[key] = card

## True once the player owns at least one card (any rarity) of every
## species native to `region` -- the "complete the set" unlock
## requirement a later region can point back at via
## FishingLocation.requires_complete_region.
func has_completed_region(region: FishingLocation) -> bool:
	if region == null or region.species.is_empty():
		return false
	for fish in region.species:
		var has_any := false
		for key in cards.keys():
			if cards[key].species_id == String(fish.id):
				has_any = true
				break
		if not has_any:
			return false
	return true

func unlock_location(location_id: StringName) -> void:
	if not unlocked_locations.has(location_id):
		unlocked_locations.append(location_id)

func get_region_mastery(region_id: StringName) -> int:
	return region_mastery.get(region_id, 0)

func upgrade_region_mastery(region_id: StringName) -> void:
	region_mastery[region_id] = get_region_mastery(region_id) + 1

func owns_lure(lure_id: StringName) -> bool:
	return owned_lures.has(lure_id)

func buy_lure(lure_id: StringName) -> void:
	if not owns_lure(lure_id):
		owned_lures.append(lure_id)

func equip_lure(lure_id: StringName) -> void:
	if owns_lure(lure_id):
		equipped_lure = lure_id

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
		"region_mastery": region_mastery,
		"owned_lures": owned_lures,
		"equipped_lure": String(equipped_lure),
		"fish_records": fish_records,
		"cards": cards,
		"owns_polarized_glasses": owns_polarized_glasses,
		"owned_reel_types": owned_reel_types,
		"equipped_reel_type": String(equipped_reel_type),
		"owned_line_types": owned_line_types,
		"equipped_line_type": String(equipped_line_type),
		"line_weight_lb": line_weight_lb,
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
	region_mastery = data.get("region_mastery", {})
	owned_lures.assign(data.get("owned_lures", []))
	equipped_lure = StringName(data.get("equipped_lure", ""))
	fish_records = data.get("fish_records", {})
	cards = data.get("cards", {})
	owns_polarized_glasses = data.get("owns_polarized_glasses", false)
	owned_reel_types.assign(data.get("owned_reel_types", [&"spinning"]))
	equipped_reel_type = StringName(data.get("equipped_reel_type", "spinning"))
	owned_line_types.assign(data.get("owned_line_types", [&"monofilament"]))
	equipped_line_type = StringName(data.get("equipped_line_type", "monofilament"))
	line_weight_lb = data.get("line_weight_lb", 10)
	idle_coin_rate = data.get("idle_coin_rate", 0.0)
	_last_active_unix = data.get("last_active_unix", 0.0)

func _notification(what: int) -> void:
	# Save on every path the OS can use to kill a mobile app -- backgrounding
	# is the common case on phones, not just an explicit quit.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
