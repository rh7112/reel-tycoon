extends Control

## Single overlay hosting Rod / Region / Lures / Records / Ranks as
## manually-switched tabs (plain visibility toggling between five Control
## children, not Godot's TabContainer -- simpler to reason about given
## every tab's actual content is built in code, not laid out in the
## scene) rather than five separate top-bar buttons competing for a
## phone's limited width.

@onready var controller: FishingController = get_parent()

@onready var _rod_tab: Control = %RodTab
@onready var _region_tab: RegionPanel = %RegionTab
@onready var _lure_tab: Control = %LureTab
@onready var _records_tab: Control = %RecordsTab
@onready var _ranks_tab: Control = %RanksTab

var _tabs: Array[Control]
var _tab_buttons: Array[Button]

func _ready() -> void:
	hide()
	_tabs = [_rod_tab, _region_tab, _lure_tab, _records_tab, _ranks_tab]
	_tab_buttons = [%RodTabButton, %RegionTabButton, %LureTabButton, %RecordsTabButton, %RanksTabButton]

	for i in _tab_buttons.size():
		_tab_buttons[i].toggle_mode = true
		_tab_buttons[i].pressed.connect(_show_tab.bind(_tabs[i]))
	%CloseMenuButton.pressed.connect(hide)

	_region_tab.travel_requested.connect(_on_travel_requested)

func open() -> void:
	show()
	_show_tab(_rod_tab)

func _show_tab(tab: Control) -> void:
	for i in _tabs.size():
		var is_active: bool = _tabs[i] == tab
		_tabs[i].visible = is_active
		# button_pressed (not .pressed()) just sets the toggled-on visual
		# state -- doesn't re-fire the pressed signal, so this can't loop.
		_tab_buttons[i].button_pressed = is_active
	if tab.has_method("refresh"):
		tab.refresh()

func _on_travel_requested(region: FishingLocation) -> void:
	controller.set_location(region)
