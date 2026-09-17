extends Node

## Pure presentation layer -- everything it knows comes from
## FishingController's signals, Economy's, or a direct read of current
## conditions, so the core loop stays testable/tunable without any of
## this UI logic baked into it.

const BOBBER_REST_Y: float = 420.0 # at the "shore" -- resting position when idle
const BOBBER_CAST_Y: float = 180.0 # out in the "water" -- resting position while a line is out
const BOBBER_SUBMERGE_DEPTH: float = 70.0 # extra downward pull when a fish bites -- it goes under
const BOBBER_WIGGLE_RADIUS: float = 9.0 # how far the submerged bobber jitters per hop
const BOBBER_WIGGLE_HOP_DURATION: float = 0.06 # seconds per jitter hop -- fast enough to read as "fighting"
const ROD_TIP: Vector2 = Vector2(410.0, 150.0) # where the fishing line visually starts
const REEL_SPIN_SPEED: float = 6.0 # radians/sec while REELING

## Non-uniform scale per sighting bucket (flattened, wider than tall --
## reads as a shadow, not a ball) -- see FishingController.fish_sighted.
const SHADOW_SCALE_BY_BUCKET: Dictionary = {
	"small": Vector2(0.55, 0.3),
	"medium": Vector2(0.9, 0.45),
	"large": Vector2(1.3, 0.6),
	"trophy": Vector2(1.9, 0.8),
}
const SHADOW_APPROACH_DISTANCE: float = 110.0 # how far out the shadow starts before swimming in

@onready var controller: FishingController = get_parent()
var _current_state: FishingController.State = FishingController.State.IDLE
var _bob_tween: Tween

func _ready() -> void:
	controller.theme = GameTheme.build()

	controller.state_changed.connect(_on_state_changed)
	controller.tension_updated.connect(_on_tension_updated)
	controller.fish_escaped.connect(_on_fish_escaped)
	controller.fish_sighted.connect(_on_fish_sighted)
	Economy.coins_changed.connect(_on_coins_changed)

	%ActionButton.button_down.connect(_on_action_button_down)
	%ActionButton.button_up.connect(_on_action_button_up)
	%MenuButton.pressed.connect(%MenuPanel.open)
	%CloseMenuButton.pressed.connect(_refresh_region_visuals)
	%DepthMinusButton.pressed.connect(_on_depth_step.bind(-1.0))
	%DepthPlusButton.pressed.connect(_on_depth_step.bind(1.0))

	_on_coins_changed(Economy.coins)
	_on_state_changed(controller.get_state())
	%ProgressFillBar.size.x = 0.0
	%Bobber.position.y = BOBBER_REST_Y
	_update_depth_label()
	_refresh_region_visuals()

func _process(delta: float) -> void:
	# The line always tracks the bobber's live position, however it's
	# currently being moved (tween or direct set) -- one place, no
	# coupling to which mechanism is animating the bobber right now.
	%FishingLine.points = PackedVector2Array([ROD_TIP, %Bobber.position])

	if _current_state == FishingController.State.REELING:
		%ReelWheel.rotation += REEL_SPIN_SPEED * delta

func _on_action_button_down() -> void:
	match _current_state:
		FishingController.State.IDLE:
			controller.cast()
		FishingController.State.WAITING_FOR_BITE, FishingController.State.BITE_WINDOW, FishingController.State.REELING:
			controller.on_action_pressed()

func _on_action_button_up() -> void:
	controller.on_action_released()

func _on_state_changed(state: FishingController.State) -> void:
	_current_state = state
	%DepthMinusButton.disabled = state != FishingController.State.IDLE
	%DepthPlusButton.disabled = state != FishingController.State.IDLE

	# Nothing to show a tension/progress bar for until a fish is actually
	# on the hook -- keeps the screen uncluttered for most of the loop,
	# and the bars showing up is itself a signal that something's on.
	var reel_ui_visible: bool = state == FishingController.State.REELING or state == FishingController.State.RESULT
	%TensionTrack.visible = reel_ui_visible
	%TensionHint.visible = reel_ui_visible
	%ProgressTrack.visible = reel_ui_visible
	%ProgressHint.visible = reel_ui_visible

	# The sighting preview only means anything during the wait -- once
	# the bite actually happens (or the cast ends some other way), the
	# shadow either resolved into a real strike or the moment's passed.
	if state != FishingController.State.WAITING_FOR_BITE:
		%FishShadow.visible = false

	match state:
		FishingController.State.IDLE:
			%StatusLabel.text = "Tap Cast to fish!"
			%ActionButton.text = "Cast"
			%ProgressFillBar.size.x = 0.0
			_kill_bob_tween()
			%Bobber.scale = Vector2.ONE
			_tween_bobber_to(BOBBER_REST_Y, 0.4)
		FishingController.State.CASTING:
			%StatusLabel.text = "Casting..."
			_tween_bobber_to(BOBBER_CAST_Y, 0.6)
		FishingController.State.WAITING_FOR_BITE:
			if controller.get_current_style() == &"bobber":
				%StatusLabel.text = "Waiting for a bite... (tap to reel in early)"
				%ActionButton.text = "Reel In"
				_start_idle_bob()
			else:
				%StatusLabel.text = "Hold to retrieve..."
				%ActionButton.text = "Hold to Reel"
				_kill_bob_tween()
			_update_conditions_label()
		FishingController.State.BITE_WINDOW:
			%StatusLabel.text = "BITE! Tap now!"
			%ActionButton.text = "Hook it!"
			_start_bite_submerge()
		FishingController.State.REELING:
			%StatusLabel.text = "Reel it in -- hold to keep the marker in the green!"
			%ActionButton.text = "Hold to Reel"
			_kill_bob_tween()
			%Bobber.scale = Vector2.ONE
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
	%Bobber.position.y = lerp(BOBBER_CAST_Y + BOBBER_SUBMERGE_DEPTH, BOBBER_REST_Y, progress)

## Only fires for a player who owns polarized glasses -- see
## FishingController.fish_sighted. Shows a shadow swimming in toward
## the bobber from a random direction, sized by the bucket, so a
## picky/small fish can be judged not worth going for before it bites.
func _on_fish_sighted(size_bucket: String) -> void:
	%FishShadow.scale = SHADOW_SCALE_BY_BUCKET.get(size_bucket, Vector2(0.9, 0.45))
	var angle := randf_range(0.0, TAU)
	var start_offset := Vector2(cos(angle), sin(angle)) * SHADOW_APPROACH_DISTANCE
	%FishShadow.position = %Bobber.position + start_offset
	%FishShadow.visible = true

	var tween := create_tween()
	tween.tween_property(%FishShadow, "position", %Bobber.position + Vector2(18.0, 10.0), FishingController.SIGHT_PREVIEW_SECONDS * 0.85).set_trans(Tween.TRANS_SINE)

func _on_fish_escaped() -> void:
	%StatusLabel.text = "It got away!"

func _on_coins_changed(amount: int) -> void:
	%CoinsLabel.text = "Coins: %d" % amount

## Shows current weather + this cast's rolled depth -- without this, the
## whole weather/lure/depth bite-affinity system is invisible and
## unlearnable to the player.
func _update_conditions_label() -> void:
	if controller.location == null:
		return
	var weather_id := WeatherService.get_weather(controller.location.id)
	var depth_ft := controller.get_current_depth_ft()
	%ConditionsLabel.text = "%s -- %dft deep" % [Weather.display_name(weather_id), int(depth_ft)]

func _on_depth_step(delta_ft: float) -> void:
	controller.set_depth(controller.get_current_depth_ft() + delta_ft)
	_update_depth_label()
	_refresh_region_visuals()

func _update_depth_label() -> void:
	%DepthLabel.text = "Depth: %dft" % int(controller.get_current_depth_ft())

## Re-syncs the water tint and depth/conditions labels to whatever
## region (and depth) we're actually in -- called after the menu
## closes, since traveling is the only way the region can have changed
## mid-session, and after every depth step. Deeper water reads darker/
## murkier, so picking a depth actually looks like picking a depth.
func _refresh_region_visuals() -> void:
	if controller.location == null:
		return
	var loc: FishingLocation = controller.location
	var depth_fraction: float = 0.0
	if loc.max_depth_ft > loc.min_depth_ft:
		depth_fraction = clamp((controller.get_current_depth_ft() - loc.min_depth_ft) / (loc.max_depth_ft - loc.min_depth_ft), 0.0, 1.0)
	%Background.color = loc.theme_color.darkened(depth_fraction * 0.4)
	%Dock.tier = GameManager.boat_tier
	%ReelWheel.reel_type = GameManager.equipped_reel_type

## Repositions the green safe-band highlight to match the current
## region's mastery-derived safe band -- it widens on upgrade, so this
## can't stay the static rect the scene was authored with.
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
	%Bobber.scale = Vector2.ONE
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(%Bobber, "position:y", BOBBER_CAST_Y - 10.0, 0.6).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(%Bobber, "position:y", BOBBER_CAST_Y + 10.0, 0.6).set_trans(Tween.TRANS_SINE)

## A bite pulls the bobber under (deeper + slightly smaller, selling
## "gone below the surface") and then, once submerged, shakes it hard
## and fast -- a fixed set of quick random hops looped, which reads as
## a violent fight even though the pattern itself repeats every ~0.3s.
func _start_bite_submerge() -> void:
	_kill_bob_tween()
	_bob_tween = create_tween()
	_bob_tween.set_parallel(true)
	_bob_tween.tween_property(%Bobber, "position:y", BOBBER_CAST_Y + BOBBER_SUBMERGE_DEPTH, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_bob_tween.tween_property(%Bobber, "scale", Vector2(0.7, 0.7), 0.12)
	_bob_tween.chain().tween_callback(_start_bite_wiggle)

func _start_bite_wiggle() -> void:
	if _current_state != FishingController.State.BITE_WINDOW:
		return # the bite already resolved while the submerge tween was still playing
	_kill_bob_tween()
	var base_pos: Vector2 = %Bobber.position
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	for i in range(5):
		var offset := Vector2(randf_range(-BOBBER_WIGGLE_RADIUS, BOBBER_WIGGLE_RADIUS), randf_range(-BOBBER_WIGGLE_RADIUS * 0.6, BOBBER_WIGGLE_RADIUS * 0.6))
		_bob_tween.tween_property(%Bobber, "position", base_pos + offset, BOBBER_WIGGLE_HOP_DURATION)

func _kill_bob_tween() -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null
