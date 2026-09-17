extends Control

## "Rod" tab of the menu -- rod tier upgrade, global and permanent (see
## RodTiers.gd). Builds its own content in code rather than hand-placed
## scene nodes, matching every other tab, since the visible rows already
## depend on live game state (current tier, affordability).

var _content: VBoxContainer

func _ready() -> void:
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_content)
	refresh()

func refresh() -> void:
	for child in _content.get_children():
		child.queue_free()

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
	info.text = "Next: %s\nFaster reel-in, more time to react to a bite." % next.name
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
