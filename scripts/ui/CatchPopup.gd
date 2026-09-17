extends Control

## Modal shown on every successful catch (FishingController.catch_result)
## -- the player has to dismiss it (confirm_catch) before casting again.
## Folds in what used to be a separate floating "+coins" popup, per the
## design note on issue #9: one moment to look at, not two competing ones.
## A missed/escaped fish does NOT show this -- FishingController keeps
## its brief auto-pause for that case, there's nothing worth a popup.

@onready var controller: FishingController = get_parent()

func _ready() -> void:
	hide()
	controller.catch_result.connect(_on_catch_result)
	%CatchContinueButton.pressed.connect(_on_continue_pressed)

func _on_catch_result(fish: Fish, weight_lb: float, coins: int, rarity_tier: CardRarity.Tier) -> void:
	%CatchTitleLabel.text = "%s Catch!" % CardRarity.name_for_tier(rarity_tier)
	%CatchTitleLabel.add_theme_color_override("font_color", CardRarity.color_for_tier(rarity_tier))
	%CatchDetailLabel.text = "%.1flb %s\n+%d coins" % [weight_lb, fish.display_name, coins]
	show()

func _on_continue_pressed() -> void:
	hide()
	controller.confirm_catch()
