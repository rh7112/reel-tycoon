extends Node

## Pure presentation layer -- everything it knows comes from
## FishingController's signals or Economy's, so the core loop stays
## testable/tunable without any UI node references baked into it.

const BOBBER_REST_Y: float = 420.0 # at the "shore" -- resting position when idle
const BOBBER_CAST_Y: float = 180.0 # out in the "water" -- resting position while a line is out
const BOBBER_BITE_DIP: float = 40.0 # extra downward jerk when a fish bites

@onready var controller: FishingController = get_parent()
var _current_state: FishingController.State = FishingController.State.IDLE
var _bob_tween: Tween

func _ready() -> void:
	controller.state_changed.connect(_on_state_changed)
	controller.tension_updated.connect(_on_tension_updated)
	controller.catch_result.connect(_on_catch_result)
	controller.fish_escaped.connect(_on_fish_escaped)
	Economy.coins_changed.connect(_on_coins_changed)

	%ActionButton.button_down.connect(_on_action_button_down)
	%ActionButton.button_up.connect(_on_action_button_up)
	%ShopButton.pressed.connect(%ShopPanel.open)

	_on_coins_changed(Economy.coins)
	_on_state_changed(controller.get_state())
	%ProgressFillBar.size.x = 0.0
	%Bobber.position.y = BOBBER_REST_Y

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
			_kill_bob_tween()
			_tween_bobber_to(BOBBER_REST_Y, 0.4)
		FishingController.State.CASTING:
			%StatusLabel.text = "Casting..."
			_tween_bobber_to(BOBBER_CAST_Y, 0.6)
		FishingController.State.WAITING_FOR_BITE:
			%StatusLabel.text = "Waiting for a bite..."
			_start_idle_bob()
		FishingController.State.BITE_WINDOW:
			%StatusLabel.text = "BITE! Tap now!"
			%ActionButton.text = "Hook it!"
			_kill_bob_tween()
			_tween_bobber_to(BOBBER_CAST_Y + BOBBER_BITE_DIP, 0.15)
		FishingController.State.REELING:
			%StatusLabel.text = "Reel it in -- hold to keep the marker in the green!"
			%ActionButton.text = "Hold to Reel"
			_position_safe_band()
		FishingController.State.RESULT:
			%ActionButton.text = "..."

func _on_tension_updated(tension: float, progress: float) -> void:
	var track_width: float = %TensionTrack.size.x
	var marker_width: float = %TensionMarker.size.x
	%TensionMarker.position.x = clamp(tension * track_width - marker_width * 0.5, 0.0, track_width - marker_width)

	var progress_width: float = %ProgressTrack.size.x
	%ProgressFillBar.size.x = progress_width * progress

	# Visually reel the bobber back in as catch progress fills, so the
	# animation reads as "pulling the fish toward shore" rather than a
	# progress bar that happens to sit near an unrelated bobbing dot.
	%Bobber.position.y = lerp(BOBBER_CAST_Y + BOBBER_BITE_DIP, BOBBER_REST_Y, progress)

func _on_catch_result(fish: Fish, size_cm: float, coins: int) -> void:
	%StatusLabel.text = "Caught a %.0fcm %s! +%d coins" % [size_cm, fish.display_name, coins]
	_spawn_coin_popup(coins)

func _on_fish_escaped() -> void:
	%StatusLabel.text = "It got away!"

func _on_coins_changed(amount: int) -> void:
	%CoinsLabel.text = "Coins: %d" % amount

## Repositions the green safe-band highlight to match the current rod
## tier's actual safe band -- it widens on upgrade, so this can't stay
## the static rect the scene was authored with.
func _position_safe_band() -> void:
	var band: Vector2 = controller.get_safe_band()
	var track_width: float = %TensionTrack.size.x
	%SafeBand.position.x = band.x * track_width
	%SafeBand.size.x = (band.y - band.x) * track_width

func _tween_bobber_to(target_y: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(%Bobber, "position:y", target_y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _start_idle_bob() -> void:
	_kill_bob_tween()
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(%Bobber, "position:y", BOBBER_CAST_Y - 10.0, 0.6).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(%Bobber, "position:y", BOBBER_CAST_Y + 10.0, 0.6).set_trans(Tween.TRANS_SINE)

func _kill_bob_tween() -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null

## Simple "+N" popup that floats up and fades -- the kind of cheap juice
## that makes a currency gain actually feel like a reward instead of a
## number quietly changing in the corner.
func _spawn_coin_popup(coins: int) -> void:
	var popup := Label.new()
	popup.text = "+%d" % coins
	popup.add_theme_font_size_override("font_size", 40)
	popup.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	popup.position = Vector2(300.0, 100.0)
	controller.add_child(popup)

	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 60.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(popup.queue_free)
