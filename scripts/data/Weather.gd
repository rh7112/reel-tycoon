class_name Weather
extends RefCounted

## The set of weather conditions a region can be in. Fish.preferred_weather
## references these ids -- see Fish.gd for how a match/mismatch swings
## bite likelihood.

const CONDITIONS: Array[Dictionary] = [
	{"id": &"sunny", "display_name": "Sunny"},
	{"id": &"cloudy", "display_name": "Cloudy"},
	{"id": &"rainy", "display_name": "Rainy"},
	{"id": &"windy", "display_name": "Windy"},
]

static func display_name(id: StringName) -> String:
	for c in CONDITIONS:
		if c.id == id:
			return c.display_name
	return "Unknown"

static func random_id() -> StringName:
	return CONDITIONS[randi() % CONDITIONS.size()].id

## Maps Open-Meteo's real weather response to one of our four conditions.
## weathercode is the WMO code; windspeed_kmh overrides straight to
## "windy" above the threshold regardless of sky conditions, matching how
## an angler actually thinks about wind as its own factor.
static func from_open_meteo(weathercode: int, windspeed_kmh: float) -> StringName:
	const WINDY_THRESHOLD_KMH := 25.0
	if windspeed_kmh >= WINDY_THRESHOLD_KMH:
		return &"windy"
	if weathercode <= 1:
		return &"sunny" # 0 = clear sky, 1 = mainly clear
	if weathercode in [2, 3, 45, 48]:
		return &"cloudy" # partly cloudy, overcast, fog
	return &"rainy" # everything else -- drizzle/rain/showers/snow/thunderstorms
