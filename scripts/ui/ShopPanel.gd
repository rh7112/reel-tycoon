extends Control

## Rod-upgrade shop -- the first real thing coins buy. Self-contained: the
## HUD only needs to call show()/hide() via the ShopButton, everything
## else (pricing, affordability, applying the upgrade) lives here.

@onready var _title_label: Label = %ShopTitleLabel
@onready var _info_label: Label = %ShopInfoLabel
@onready var _upgrade_button: Button = %UpgradeButton

func _ready() -> void:
	hide()
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	%CloseShopButton.pressed.connect(hide)
	Economy.coins_changed.connect(func(_amount: int) -> void: if visible: _refresh())

func open() -> void:
	_refresh()
	show()

func _refresh() -> void:
	var current: Dictionary = RodTiers.get_tier(GameManager.rod_tier)
	_title_label.text = "Current rod: %s" % current.name

	if RodTiers.is_max_tier(GameManager.rod_tier):
		_info_label.text = "You've got the best rod there is -- for now."
		_upgrade_button.text = "Maxed Out"
		_upgrade_button.disabled = true
		return

	var next: Dictionary = RodTiers.get_tier(GameManager.rod_tier + 1)
	_info_label.text = "Next: %s\nWider safe zone, faster reel-in, more time to react to a bite." % next.name
	_upgrade_button.text = "Upgrade for %d coins" % next.upgrade_cost
	_upgrade_button.disabled = Economy.coins < next.upgrade_cost

func _on_upgrade_pressed() -> void:
	var next: Dictionary = RodTiers.get_tier(GameManager.rod_tier + 1)
	if not Economy.spend_coins(next.upgrade_cost):
		return
	GameManager.rod_tier += 1
	GameManager.save()
	_refresh()
