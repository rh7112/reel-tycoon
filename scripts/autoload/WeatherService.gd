extends Node

## Current weather, keyed by region id.
##
## A region tied to a real lake (FishingLocation.latitude/longitude set)
## gets REAL current weather for those exact coordinates from Open-Meteo
## (https://open-meteo.com -- free, no API key, no account setup). Since
## it's the same real-world weather no matter which player asks, this is
## honestly global/shared -- no backend of our own needed for this piece,
## unlike LeaderboardService.gd's situation (see its header), which still
## needs one for real cross-player comparison.
##
## A region with no coordinates (Home Pond -- not a real place) falls
## back to a local per-device random roll, same as the original approach.
## Gameplay-facing code (FishingController) only ever calls get_weather(),
## never touches HTTP or the RNG directly.

signal weather_changed(region_id: StringName, weather_id: StringName)

const REFRESH_INTERVAL_SECONDS: float = 15.0 * 60.0 # real weather doesn't need checking more often than this

var _current: Dictionary = {} # region_id -> StringName weather_id
var _timer: Timer
var _http: HTTPRequest
var _pending_region_id: StringName = &""

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = REFRESH_INTERVAL_SECONDS
	_timer.autostart = true
	_timer.timeout.connect(_refresh_all)
	add_child(_timer)

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

## Returns the last known weather for this region, kicking off the first
## fetch/roll if this is the first time it's been asked about. The very
## first call for a real-coordinate region can return a placeholder for a
## moment while the network request is in flight -- see _fetch_real.
func get_weather(region_id: StringName) -> StringName:
	if not _current.has(region_id):
		_refresh_one(region_id)
	return _current.get(region_id, &"sunny")

## Called early (FishingController._ready) to give a real-weather fetch a
## head start before it's actually needed for a bite roll -- a cast takes
## a few seconds anyway, which is normally enough time for the request to
## land first.
func prime(region_id: StringName) -> void:
	if not _current.has(region_id):
		_refresh_one(region_id)

func _refresh_all() -> void:
	for region_id in _current.keys():
		_refresh_one(region_id)

func _refresh_one(region_id: StringName) -> void:
	var region := Regions.get_by_id(region_id)
	if region != null and region.has_real_coordinates():
		_fetch_real(region)
	else:
		_roll_local(region_id)

func _roll_local(region_id: StringName) -> void:
	var weather_id := Weather.random_id()
	_current[region_id] = weather_id
	weather_changed.emit(region_id, weather_id)

func _fetch_real(region: FishingLocation) -> void:
	if not _current.has(region.id):
		_current[region.id] = &"sunny" # placeholder until the first fetch lands
	# One HTTPRequest node can only handle one in-flight request -- if a
	# refresh tick wants two real-weather regions at once, the second is
	# simply skipped this tick and picked up on the next one. Fine for the
	# handful of real-weather regions this game has; worth a small request
	# queue if that number grows a lot.
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_pending_region_id = region.id
	var url := "https://api.open-meteo.com/v1/forecast?latitude=%f&longitude=%f&current_weather=true" % [region.latitude, region.longitude]
	var err := _http.request(url)
	if err != OK:
		push_warning("WeatherService: failed to start weather request for %s: error %d" % [region.id, err])
		_pending_region_id = &""

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var region_id := _pending_region_id
	_pending_region_id = &""
	if region_id == &"":
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("WeatherService: real weather fetch failed for %s (result=%d, code=%d) -- keeping last known weather" % [region_id, result, response_code])
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("current_weather"):
		push_warning("WeatherService: unexpected weather response shape for %s" % region_id)
		return

	var current: Dictionary = parsed.current_weather
	var weather_id := Weather.from_open_meteo(int(current.get("weathercode", 0)), float(current.get("windspeed", 0.0)))
	_current[region_id] = weather_id
	weather_changed.emit(region_id, weather_id)
