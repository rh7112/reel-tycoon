extends Control

## "Ranks" tab -- deliberately honest about what it can't show yet: with
## no backend (see LeaderboardService.gd's header), this can only ever be
## a leaderboard of one. Shows that plainly rather than inventing fake
## competitor rows to make it look populated.

var _list: VBoxContainer

func _ready() -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	if not LeaderboardService.is_connected_to_real_leaderboard():
		var notice := Label.new()
		notice.text = "Not connected to other players yet -- showing your own bests only."
		container.add_child(notice)
		container.add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	container.add_child(_list)
	refresh()

func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	for category in LeaderboardService.CATEGORIES:
		var header := Label.new()
		header.add_theme_font_size_override("font_size", 20)
		header.text = category.display_name
		_list.add_child(header)

		var top: Array = LeaderboardService.get_top(category.id)
		if top.is_empty():
			var none_label := Label.new()
			none_label.text = "  (nothing yet)"
			_list.add_child(none_label)
		else:
			for entry in top:
				var entry_label := Label.new()
				entry_label.text = "  %s -- %.1f" % [entry.name, entry.score]
				_list.add_child(entry_label)
