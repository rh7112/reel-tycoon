extends Control
class_name RegionPanel

## "Region" tab -- travel between unlocked regions, unlock new ones, and
## upgrade the CURRENT region's mastery (the safe-band-width progression
## that resets to each region's own starting_safe_band_width on arrival --
## see FishingLocation.gd's header for why this is separate from rod tier).

signal travel_requested(region: FishingLocation)

var _list: VBoxContainer

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	refresh()

func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	for region in Regions.in_order():
		_list.add_child(_build_row(region))

func _build_row(region: FishingLocation) -> Control:
	var row := VBoxContainer.new()
	var is_current: bool = region.id == GameManager.current_location
	var is_unlocked: bool = GameManager.unlocked_locations.has(region.id)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 24)
	title.text = region.display_name + ("  <- here now" if is_current else "")
	row.add_child(title)

	if not is_unlocked:
		var info := Label.new()
		info.text = "Locked -- %d coins, rod tier %d+" % [region.unlock_cost, region.min_rod_tier_required]
		row.add_child(info)

		var needs_complete_set: bool = region.requires_complete_region != &""
		var has_complete_set: bool = true
		if needs_complete_set:
			var prerequisite := Regions.get_by_id(region.requires_complete_region)
			has_complete_set = GameManager.has_completed_region(prerequisite)
			var set_info := Label.new()
			set_info.text = "Also needs: a card of every species at %s" % (prerequisite.display_name if prerequisite != null else "the previous region")
			if not has_complete_set:
				set_info.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
			row.add_child(set_info)

		var unlock_button := Button.new()
		unlock_button.text = "Unlock"
		unlock_button.disabled = (
			Economy.coins < region.unlock_cost
			or GameManager.rod_tier < region.min_rod_tier_required
			or not has_complete_set
		)
		unlock_button.pressed.connect(func() -> void:
			if Economy.spend_coins(region.unlock_cost):
				GameManager.unlock_location(region.id)
				GameManager.save()
				refresh())
		row.add_child(unlock_button)
	elif is_current:
		var mastery: int = GameManager.get_region_mastery(region.id)
		var progress := Label.new()
		progress.text = "Mastery %d/%d -- safe zone %d%% of the bar" % [
			mastery, region.mastery_levels, int(region.safe_band_width_for_mastery(mastery) * 100.0)
		]
		row.add_child(progress)

		if mastery < region.mastery_levels:
			var cost: int = region.mastery_cost_for_level(mastery)
			var upgrade_button := Button.new()
			upgrade_button.text = "Upgrade mastery for %d coins" % cost
			upgrade_button.disabled = Economy.coins < cost
			upgrade_button.pressed.connect(func() -> void:
				if Economy.spend_coins(cost):
					GameManager.upgrade_region_mastery(region.id)
					GameManager.save()
					refresh())
			row.add_child(upgrade_button)
		else:
			var maxed := Label.new()
			maxed.text = "Mastery maxed for this region!"
			row.add_child(maxed)
	else:
		var travel_button := Button.new()
		travel_button.text = "Travel here"
		travel_button.pressed.connect(func() -> void:
			GameManager.current_location = region.id
			GameManager.save()
			travel_requested.emit(region)
			refresh())
		row.add_child(travel_button)

	row.add_child(HSeparator.new())
	return row
