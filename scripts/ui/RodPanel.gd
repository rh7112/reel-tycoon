extends Control

## "Gear" tab of the menu -- rod tier (global/permanent power), reel
## type, line type, and line weight (see ReelTypes.gd/LineTypes.gd for
## what each actually does). Builds its own content in code rather than
## hand-placed scene nodes, matching every other tab, since the visible
## rows already depend on live game state.

const LINE_WEIGHT_OPTIONS: Array[int] = [6, 10, 15, 20, 30]
const POLARIZED_GLASSES_COST: int = 150

var _content: VBoxContainer

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	scroll.add_child(_content)
	refresh()

func refresh() -> void:
	for child in _content.get_children():
		child.queue_free()

	_build_rod_section()
	_content.add_child(HSeparator.new())
	_build_boat_section()
	_content.add_child(HSeparator.new())
	_build_owned_option_section(
		"Reel", ReelTypes.ALL, GameManager.owned_reel_types, GameManager.equipped_reel_type,
		GameManager.buy_reel_type, GameManager.equip_reel_type
	)
	_content.add_child(HSeparator.new())
	_build_owned_option_section(
		"Line", LineTypes.ALL, GameManager.owned_line_types, GameManager.equipped_line_type,
		GameManager.buy_line_type, GameManager.equip_line_type
	)
	_content.add_child(HSeparator.new())
	_build_line_weight_section()
	_content.add_child(HSeparator.new())
	_build_polarized_glasses_section()
	_content.add_child(HSeparator.new())
	_build_sponsorship_section()

func _build_rod_section() -> void:
	var current: Dictionary = RodTiers.get_tier(GameManager.rod_tier)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.text = "Current rod: %s" % current.name
	_content.add_child(title)

	if RodTiers.is_max_tier(GameManager.rod_tier):
		var maxed := Label.new()
		maxed.text = "You've got the best rod there is -- for now."
		_content.add_child(maxed)
		return

	var next: Dictionary = RodTiers.get_tier(GameManager.rod_tier + 1)
	var info := Label.new()
	info.text = "Next: %s -- faster reel-in, more time to react to a bite." % next.name
	_content.add_child(info)

	var upgrade_button := Button.new()
	upgrade_button.text = "Upgrade for %d coins" % next.upgrade_cost
	upgrade_button.disabled = Economy.coins < next.upgrade_cost
	upgrade_button.pressed.connect(func() -> void:
		if Economy.spend_coins(next.upgrade_cost):
			GameManager.rod_tier += 1
			GameManager.save()
			refresh())
	_content.add_child(upgrade_button)

## Boats are a linear upgrade ladder (unlike reel/line/lures below,
## which are tradeoff options) -- a bigger boat is genuinely just
## strictly better, gating how deep the player can set the depth
## stepper to (see BoatTiers.gd, FishingController.get_max_reachable_depth_ft).
func _build_boat_section() -> void:
	var current: Dictionary = BoatTiers.get_tier(GameManager.boat_tier)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.text = "Current boat: %s" % current.name
	_content.add_child(title)

	var region: FishingLocation = Regions.get_by_id(GameManager.current_location)
	if region != null:
		var depth_info := Label.new()
		var cap: float = min(region.max_depth_ft, float(current.max_depth_ft))
		depth_info.text = "Reaches %dft of %s's %dft" % [int(cap), region.display_name, int(region.max_depth_ft)]
		_content.add_child(depth_info)

	if BoatTiers.is_max_tier(GameManager.boat_tier):
		var maxed := Label.new()
		maxed.text = "Nothing bigger out there -- for now."
		_content.add_child(maxed)
		return

	var next: Dictionary = BoatTiers.get_tier(GameManager.boat_tier + 1)
	var info := Label.new()
	info.text = "Next: %s -- reaches deeper water, where bigger fish can be." % next.name
	_content.add_child(info)

	var upgrade_button := Button.new()
	upgrade_button.text = "Upgrade for %d coins" % next.cost
	upgrade_button.disabled = Economy.coins < next.cost
	upgrade_button.pressed.connect(func() -> void:
		if Economy.spend_coins(next.cost):
			GameManager.boat_tier += 1
			GameManager.save()
			refresh())
	_content.add_child(upgrade_button)

## Shared row-builder for reel type and line type -- both are "own one of
## several tradeoff options, equip whichever suits the moment" rather
## than a linear upgrade ladder, so they share the exact same UI shape.
func _build_owned_option_section(
	label: String, options: Array[Dictionary], owned: Array[StringName], equipped: StringName,
	buy: Callable, equip: Callable
) -> void:
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 24)
	header.text = label
	_content.add_child(header)

	for option in options:
		var row := HBoxContainer.new()
		var is_owned: bool = owned.has(option.id)
		var is_equipped: bool = equipped == option.id

		var name_label := Label.new()
		name_label.text = option.name + ("  (equipped)" if is_equipped else "")
		name_label.custom_minimum_size = Vector2(300, 0)
		row.add_child(name_label)

		if not is_owned:
			var buy_button := Button.new()
			buy_button.text = "Buy for %d coins" % option.cost
			buy_button.disabled = Economy.coins < option.cost
			buy_button.pressed.connect(func() -> void:
				if Economy.spend_coins(option.cost):
					buy.call(option.id)
					GameManager.save()
					refresh())
			row.add_child(buy_button)
		elif not is_equipped:
			var equip_button := Button.new()
			equip_button.text = "Equip"
			equip_button.pressed.connect(func() -> void:
				equip.call(option.id)
				GameManager.save()
				refresh())
			row.add_child(equip_button)

		_content.add_child(row)

func _build_line_weight_section() -> void:
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 24)
	header.text = "Line weight"
	_content.add_child(header)

	var info := Label.new()
	info.text = "Heavier handles bigger fish without snapping, but spooks line-shy species. Free to change -- it's what you spooled on, not a purchase."
	_content.add_child(info)

	var row := HBoxContainer.new()
	for weight in LINE_WEIGHT_OPTIONS:
		var button := Button.new()
		button.text = "%dlb" % weight
		button.toggle_mode = true
		button.button_pressed = (GameManager.line_weight_lb == weight)
		button.pressed.connect(func() -> void:
			GameManager.line_weight_lb = weight
			GameManager.save()
			refresh())
		row.add_child(button)
	_content.add_child(row)

## One-time gear purchase -- see GameManager.owns_polarized_glasses and
## FishingController.fish_sighted for what it actually does.
func _build_polarized_glasses_section() -> void:
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 24)
	header.text = "Polarized Glasses"
	_content.add_child(header)

	if GameManager.owns_polarized_glasses:
		var owned_label := Label.new()
		owned_label.text = "Owned -- you'll see a fish's rough size before it bites."
		_content.add_child(owned_label)
		return

	var info := Label.new()
	info.text = "See a fish's rough size (never the exact weight) swim toward your bait before it bites -- worth knowing if a small one isn't worth setting the hook for."
	_content.add_child(info)

	var buy_button := Button.new()
	buy_button.text = "Buy for %d coins" % POLARIZED_GLASSES_COST
	buy_button.disabled = Economy.coins < POLARIZED_GLASSES_COST
	buy_button.pressed.connect(func() -> void:
		if Economy.spend_coins(POLARIZED_GLASSES_COST):
			GameManager.owns_polarized_glasses = true
			GameManager.save()
			refresh())
	_content.add_child(buy_button)

## A straight upgrade ladder like rod/boat -- multiplies coins per
## catch (SponsorshipTiers.gd, applied in FishingController._award_catch).
func _build_sponsorship_section() -> void:
	var current: Dictionary = SponsorshipTiers.get_tier(GameManager.sponsorship_tier)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.text = "Sponsor: %s (x%.2f coins)" % [current.name, current.coin_mult]
	_content.add_child(title)

	if SponsorshipTiers.is_max_tier(GameManager.sponsorship_tier):
		var maxed := Label.new()
		maxed.text = "Top sponsorship reached -- for now."
		_content.add_child(maxed)
		return

	var next: Dictionary = SponsorshipTiers.get_tier(GameManager.sponsorship_tier + 1)
	var info := Label.new()
	info.text = "Next: %s -- x%.2f coins per catch." % [next.name, next.coin_mult]
	_content.add_child(info)

	var upgrade_button := Button.new()
	upgrade_button.text = "Upgrade for %d coins" % next.cost
	upgrade_button.disabled = Economy.coins < next.cost
	upgrade_button.pressed.connect(func() -> void:
		if Economy.spend_coins(next.cost):
			GameManager.sponsorship_tier += 1
			GameManager.save()
			refresh())
	_content.add_child(upgrade_button)
