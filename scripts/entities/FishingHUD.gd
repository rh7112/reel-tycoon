extends Node

## Pure presentation layer -- everything it knows comes from
## FishingController's signals or Economy's, so the core loop stays
## testable/tunable without any UI node references baked into it.

@onready var controller: FishingController = get_parent()
var _current_state: FishingController.State = FishingController.State.IDLE

func _ready() -> void:
	controller.state_changed.connect(_on_state_changed)
	controller.tension_updated.connect(_on_tension_updated)
	controller.catch_result.connect(_on_catch_result)
	controller.fish_escaped.connect(_on_fish_escaped)
	Economy.coins_changed.connect(_on_coins_changed)

	%ActionButton.button_down.connect(_on_action_button_down)
	%ActionButton.button_up.connect(_on_action_button_up)

	_on_coins_changed(Economy.coins)
	_on_state_changed(controller.get_state())
	%ProgressFillBar.size.x = 0.0

func _on_action_button_down() -> void:
	match _current_state:
		FishingController.State.IDLE:
			controller.cast()
		FishingController.State.BITE_WINDOW, FishingController.State.REELING:
			controller.on_action_pressed()

func _on_action_button_up() -> void:
	controller.on_action_released()

func _on_state_changed(state: FishingController.State) -> void:
	_current_state = state
	match state:
		FishingController.State.IDLE:
			%StatusLabel.text = "Tap Cast to fish!"
			%ActionButton.text = "Cast"
			%ProgressFillBar.size.x = 0.0
		FishingController.State.CASTING:
			%StatusLabel.text = "Casting..."
		FishingController.State.WAITING_FOR_BITE:
			%StatusLabel.text = "Waiting for a bite..."
		FishingController.State.BITE_WINDOW:
			%StatusLabel.text = "BITE! Tap now!"
			%ActionButton.text = "Hook it!"
		FishingController.State.REELING:
			%StatusLabel.text = "Reel it in -- hold to keep the marker in the green!"
			%ActionButton.text = "Hold to Reel"
		FishingController.State.RESULT:
			%ActionButton.text = "..."

func _on_tension_updated(tension: float, progress: float) -> void:
	var track_width: float = %TensionTrack.size.x
	var marker_width: float = %TensionMarker.size.x
	%TensionMarker.position.x = clamp(tension * track_width - marker_width * 0.5, 0.0, track_width - marker_width)

	var progress_width: float = %ProgressTrack.size.x
	%ProgressFillBar.size.x = progress_width * progress

func _on_catch_result(fish: Fish, size_cm: float, coins: int) -> void:
	%StatusLabel.text = "Caught a %.0fcm %s! +%d coins" % [size_cm, fish.display_name, coins]

func _on_fish_escaped() -> void:
	%StatusLabel.text = "It got away!"

func _on_coins_changed(amount: int) -> void:
	%CoinsLabel.text = "Coins: %d" % amount
