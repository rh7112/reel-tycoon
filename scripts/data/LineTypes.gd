class_name LineTypes
extends RefCounted

## Line types -- owned/equipped like lures. Monofilament stretches
## (absorbs sudden tension spikes, most forgiving); fluorocarbon is
## low-visibility (softens a weather/lure mismatch's penalty);
## braided has zero stretch (amplifies tension spikes -- higher risk --
## but gives the best hook-sets, a small progress_fill bonus).

const ALL: Array[Dictionary] = [
	{
		"id": &"monofilament",
		"name": "Monofilament",
		"cost": 0,
		"noise_dampen_mult": 0.7,
		"affinity_leniency": 0.0,
		"progress_fill_mult": 1.0,
	},
	{
		"id": &"fluorocarbon",
		"name": "Fluorocarbon",
		"cost": 70,
		"noise_dampen_mult": 0.9,
		"affinity_leniency": 0.35,
		"progress_fill_mult": 1.0,
	},
	{
		"id": &"braided",
		"name": "Braided",
		"cost": 90,
		"noise_dampen_mult": 1.25,
		"affinity_leniency": -0.15,
		"progress_fill_mult": 1.1,
	},
]

static func get_by_id(id: StringName) -> Dictionary:
	for line in ALL:
		if line.id == id:
			return line
	return ALL[0] # monofilament -- the safe default every save already starts owning
