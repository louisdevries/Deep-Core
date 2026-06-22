extends Building

@onready var sprite_off: Sprite2D = $SpriteOff
@onready var sprite_on: AnimatedSprite2D = $SpriteOn

const OFF_TEXTURES = [
	preload("res://assets/Equipment/furnace_level1_off.png"),
	preload("res://assets/Equipment/furnace_level2_off.png"),
	preload("res://assets/Equipment/furnace_level3_off.png"),
]

const ANIM_TEXTURES = [
	[preload("res://assets/Equipment/furnace_level1_frame1.png"), preload("res://assets/Equipment/furnace_level1_frame2.png")],
	[preload("res://assets/Equipment/furnace_level2_frame1.png"), preload("res://assets/Equipment/furnace_level2_frame2.png")],
	[preload("res://assets/Equipment/furnace_level3_frame1.png"), preload("res://assets/Equipment/furnace_level3_frame2.png")],
]

var _displayed_level: int = 0


func _ready() -> void:
	super._ready()


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


func _apply_level_sprites(level: int) -> void:
	var idx := clampi(level - 1, 0, 2)
	sprite_off.texture = OFF_TEXTURES[idx]

	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", 5.0)
	frames.set_animation_loop("default", true)
	frames.add_frame("default", ANIM_TEXTURES[idx][0])
	frames.add_frame("default", ANIM_TEXTURES[idx][1])
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
