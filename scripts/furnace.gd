extends Building

@onready var sprite_off: Sprite2D = $SpriteOff
@onready var sprite_on: AnimatedSprite2D = $SpriteOn

const OFF_TEXTURE  = preload("res://assets/Art/Buildings/Furnace_Off.png")
const ANIM_FRAME_1 = preload("res://assets/Art/Buildings/Furnace.png")
const ANIM_FRAME_2 = preload("res://assets/Art/Buildings/Furnace_2.png")

var _displayed_level: int = 0
var _furnace_sfx: AudioStreamPlayer2D = null


func _ready() -> void:
	super._ready()

	_furnace_sfx = AudioStreamPlayer2D.new()
	_furnace_sfx.stream = load("res://assets/Audio/SFX/Furnace.wav")
	_furnace_sfx.bus = "SFX"
	_furnace_sfx.max_distance = 200.0
	_furnace_sfx.volume_db = -80.0
	_furnace_sfx.finished.connect(_furnace_sfx.play)
	add_child(_furnace_sfx)
	_furnace_sfx.play()


func _process(delta: float) -> void:
	super._process(delta)

	var player := get_tree().get_first_node_in_group("player")
	var level: int = player.furnace_level if player else 1

	if level != _displayed_level:
		_apply_level_sprites(level)

	var is_active: bool = _has_active_slot()
	sprite_off.visible = not is_active
	sprite_on.visible = is_active

	if is_active and not sprite_on.is_playing():
		sprite_on.play("default")
	elif not is_active:
		sprite_on.stop()

	if _furnace_sfx:
		var target_vol := -10.0 if is_active else -80.0
		_furnace_sfx.volume_db = move_toward(_furnace_sfx.volume_db, target_vol, 20.0 * delta)


func _apply_level_sprites(level: int) -> void:
	sprite_off.texture = OFF_TEXTURE

	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 5.0)
	frames.set_animation_loop("default", true)
	frames.add_frame("default", ANIM_FRAME_1)
	frames.add_frame("default", ANIM_FRAME_2)
	sprite_on.sprite_frames = frames

	_displayed_level = level


func _has_active_slot() -> bool:
	if not FurnaceSystem:
		return false
	for i in FurnaceSystem.slots.size():
		if not FurnaceSystem.is_slot_empty(i) and not FurnaceSystem.is_slot_done(i):
			return true
	return false


func _on_interact() -> void:
	var furnace_menu := get_tree().current_scene.get_node_or_null("FurnaceMenu") as CanvasLayer
	if furnace_menu:
		var player := get_tree().get_first_node_in_group("player")
		furnace_menu.open(player)
