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

func _ready() -> void:
	hide()
	_tabs = [_rod_tab, _region_tab, _lure_tab, _records_tab, _ranks_tab]

	%RodTabButton.pressed.connect(_show_tab.bind(_rod_tab))
	%RegionTabButton.pressed.connect(_show_tab.bind(_region_tab))
	%LureTabButton.pressed.connect(_show_tab.bind(_lure_tab))
	%RecordsTabButton.pressed.connect(_show_tab.bind(_records_tab))
	%RanksTabButton.pressed.connect(_show_tab.bind(_ranks_tab))
	%CloseMenuButton.pressed.connect(hide)

	_region_tab.travel_requested.connect(_on_travel_requested)

func open() -> void:
	show()
	_show_tab(_rod_tab)

func _show_tab(tab: Control) -> void:
	for t in _tabs:
		t.visible = (t == tab)
	if tab.has_method("refresh"):
		tab.refresh()

func _on_travel_requested(region: FishingLocation) -> void:
	controller.set_location(region)
