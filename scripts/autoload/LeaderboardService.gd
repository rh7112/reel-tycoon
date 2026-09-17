extends Node

## Abstraction over "how do we compare to other players". Right now this
## is LOCAL ONLY -- there is no backend yet, so get_top()/is_connected_to_
## real_leaderboard() can only ever reflect this one device, never actual
## competitors. This lives in its own file specifically so that plugging
## in a real backend later (the same one WeatherService.gd's header notes
## global weather needs) means changing this file, not every screen that
## reads a leaderboard. The UI (LeaderboardPanel.gd) is required to show
## an honest "connect to compare" message rather than ever inventing fake
## competitor rows to make a single-player leaderboard look populated.

const CATEGORY_TOTAL_COINS := &"total_coins"
const CATEGORY_BIGGEST_FISH_LB := &"biggest_fish_lb"

const CATEGORIES: Array[Dictionary] = [
	{"id": CATEGORY_TOTAL_COINS, "display_name": "Coins on hand"},
	{"id": CATEGORY_BIGGEST_FISH_LB, "display_name": "Biggest fish (lb)"},
]

func get_my_score(category: StringName) -> float:
	match category:
		CATEGORY_TOTAL_COINS:
			return float(Economy.coins)
		CATEGORY_BIGGEST_FISH_LB:
			var best: float = 0.0
			for record in GameManager.fish_records.values():
				best = max(best, record.max_weight_lb)
			return best
	return 0.0

## Always just the local player (an empty array if nothing qualifies yet)
## -- see header. Never fabricates other players' scores.
func get_top(category: StringName, _limit: int = 10) -> Array:
	var my_score := get_my_score(category)
	if my_score <= 0.0:
		return []
	return [{"name": "You", "score": my_score}]

func is_connected_to_real_leaderboard() -> bool:
	return false
