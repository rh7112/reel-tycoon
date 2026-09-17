extends Control

## "Lures" tab -- buy/equip lures, now tracked as quantities
## (GameManager.owned_lure_counts) rather than a boolean owned-or-not,
## since consumables get used up and hard lures can be lost to a snag
## (see Lure.gd / FishingController._roll_lure_loss). Buying is always
## available even with some already in stock -- that's how restocking
## works. Only `type` and effective_depth_ft actually affect bite odds
## today; color/size are shown as real attributes of what you own even
## though they're display-only for now.

var _list: VBoxContainer

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)
	refresh()

func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	for lure in Lures.ALL:
		_list.add_child(_build_row(lure))

func _build_row(lure: Lure) -> Control:
	var row := VBoxContainer.new()
	var count: int = GameManager.get_lure_count(lure.id)
	var equipped: bool = GameManager.equipped_lure == lure.id

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.text = "%s x%d%s" % [lure.display_name, count, "  (equipped)" if equipped else ""]
	row.add_child(title)

	var depth_info := Label.new()
	depth_info.text = "%s -- works %d-%dft deep" % [lure.type.capitalize(), int(lure.effective_depth_ft.x), int(lure.effective_depth_ft.y)]
	row.add_child(depth_info)

	var risk_info := Label.new()
	if lure.is_consumable:
		risk_info.text = "Consumable -- roughly %d%% chance of using one up per cast, any water" % int(round(lure.base_loss_chance * 100.0))
	else:
		risk_info.text = "Hard lure -- only lost to a snag/bite-off, riskier in shallow or heavy-cover water"
	row.add_child(risk_info)

	var buy_button := Button.new()
	if lure.is_consumable:
		buy_button.text = "Buy a pack of %d for %d coins" % [lure.pack_size, lure.pack_cost]
	else:
		buy_button.text = "Buy for %d coins" % lure.pack_cost
	buy_button.disabled = Economy.coins < lure.pack_cost
	buy_button.pressed.connect(func() -> void:
		if Economy.spend_coins(lure.pack_cost):
			GameManager.add_lure_count(lure.id, lure.pack_size)
			GameManager.save()
			refresh())
	row.add_child(buy_button)

	if count > 0 and not equipped:
		var equip_button := Button.new()
		equip_button.text = "Equip"
		equip_button.pressed.connect(func() -> void:
			GameManager.equip_lure(lure.id)
			GameManager.save()
			refresh())
		row.add_child(equip_button)

	row.add_child(HSeparator.new())
	return row
