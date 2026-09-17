extends Node

## Plain-JSON save to user://save.json. Kept deliberately dumb (no schema
## versioning yet) since the save shape will still be changing weekly at
## this stage -- add migration handling once the economy/data model has
## actually stabilized, not preemptively.

const SAVE_PATH := "user://save.json"

func save_game(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save file for writing: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save file for reading: %s" % FileAccess.get_open_error())
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: save file was corrupt or not a dictionary, ignoring it")
		return {}
	return parsed
