# settings_manager.gd  (Autoload: SettingsManager)
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS     := "Music"
const SFX_BUS       := "SFX"

var music_volume: float = 1.0
var sfx_volume:   float = 1.0


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	load_settings()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus(MUSIC_BUS, music_volume)
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus(SFX_BUS, sfx_volume)
	save_settings()


func _apply_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume",   sfx_volume)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_apply_bus(MUSIC_BUS, music_volume)
		_apply_bus(SFX_BUS,   sfx_volume)
		return
	music_volume = cfg.get_value("audio", "music_volume", 1.0)
	sfx_volume   = cfg.get_value("audio", "sfx_volume",   1.0)
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS,   sfx_volume)
