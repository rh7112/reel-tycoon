extends Control

## "Records" tab -- the card binder. Every catch produces a card at
## whatever rarity tier its rolled weight lands in (GameManager.cards);
## this groups them by species and lists each rarity tier owned, with
## count and best weight at that tier, color-coded by Rarity.gd.

var _list: VBoxContainer

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_list)
	refresh()

func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	if GameManager.cards.is_empty():
		var empty := Label.new()
		empty.text = "No cards yet -- go catch something!"
		_list.add_child(empty)
		return

	var species_ids := _group_by_species()
	for species_id in species_ids.keys():
		_list.add_child(_build_species_block(species_id, species_ids[species_id]))

## Returns {species_id: [card, card, ...]} preserving each species'
## display_name for the header.
func _group_by_species() -> Dictionary:
	var grouped: Dictionary = {}
	for key in GameManager.cards.keys():
		var card: Dictionary = GameManager.cards[key]
		var species_id: String = card.species_id
		if not grouped.has(species_id):
			grouped[species_id] = []
		grouped[species_id].append(card)
	return grouped

func _build_species_block(_species_id: String, species_cards: Array) -> Control:
	var block := VBoxContainer.new()

	var header := Label.new()
	header.add_theme_font_size_override("font_size", 24)
	header.text = species_cards[0].display_name
	block.add_child(header)

	species_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rarity_tier < b.rarity_tier)
	for card in species_cards:
		var row := Label.new()
		row.add_theme_color_override("font_color", Rarity.color_for_tier(card.rarity_tier))
		row.text = "  %s x%d -- best %.1flb" % [Rarity.name_for_tier(card.rarity_tier), card.count, card.best_weight_lb]
		block.add_child(row)

	block.add_child(HSeparator.new())
	return block
