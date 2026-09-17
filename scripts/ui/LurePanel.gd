extends Control

## "Lures" tab -- buy/equip lures. Only `type` and effective_depth_ft
## actually affect bite odds today (see Lure.gd/FishingController); color
## and size are shown here as real attributes of what you own even though
## they're display-only for now.

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
	var owned: bool = GameManager.owns_lure(lure.id)
	var equipped: bool = GameManager.equipped_lure == lure.id

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.text = lure.display_name + ("  (equipped)" if equipped else "")
	row.add_child(title)

	var depth_info := Label.new()
	depth_info.text = "%s -- works %d-%dft deep" % [lure.type.capitalize(), int(lure.effective_depth_ft.x), int(lure.effective_depth_ft.y)]
	row.add_child(depth_info)

	if not owned:
		var buy_button := Button.new()
		buy_button.text = "Buy for %d coins" % lure.cost
		buy_button.disabled = Economy.coins < lure.cost
		buy_button.pressed.connect(func() -> void:
			if Economy.spend_coins(lure.cost):
				GameManager.buy_lure(lure.id)
				GameManager.save()
				refresh())
		row.add_child(buy_button)
	elif not equipped:
		var equip_button := Button.new()
		equip_button.text = "Equip"
		equip_button.pressed.connect(func() -> void:
			GameManager.equip_lure(lure.id)
			GameManager.save()
			refresh())
		row.add_child(equip_button)

	row.add_child(HSeparator.new())
	return row
