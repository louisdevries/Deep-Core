# save_system.gd
extends Node

const SAVE_PATH := "user://savegame.json"

# in-memory copy of the latest save (or empty dict if no save)
var data: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(payload: Dictionary) -> bool:

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if not file:
		push_error("Could not open save file for writing")
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	data = payload
	print("Game saved to ", SAVE_PATH)
	return true


func load_game() -> Dictionary:

	if not has_save():
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if not file:
		push_error("Could not open save file for reading")
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Save file is corrupt")
		return {}

	data = parsed
	print("Game loaded from ", SAVE_PATH)
	return data


func clear_save() -> void:

	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		data = {}
