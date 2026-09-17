extends Node

## Single source of truth for currency. UI listens to the signals below
## rather than polling -- keeps the coin counter, shop buttons, etc. all in
## sync without every screen needing a reference to every other screen.

signal coins_changed(new_amount: int)
signal gems_changed(new_amount: int)

var coins: int = 0
var gems: int = 0

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

## Returns false (and spends nothing) if the player can't afford it --
## callers should check this before playing an "unlocked!" animation.
func spend_coins(amount: int) -> bool:
	if amount > coins:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

func add_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit(gems)

func spend_gems(amount: int) -> bool:
	if amount > gems:
		return false
	gems -= amount
	gems_changed.emit(gems)
	return true

func to_save_dict() -> Dictionary:
	return {"coins": coins, "gems": gems}

func load_from_dict(data: Dictionary) -> void:
	coins = data.get("coins", 0)
	gems = data.get("gems", 0)
	coins_changed.emit(coins)
	gems_changed.emit(gems)
