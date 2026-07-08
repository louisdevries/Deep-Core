extends CanvasLayer

@onready var gear_knob: Control = $GearKnob
@onready var swivel_knob: Control = $SwivelKnob
@onready var sonar_overlay: Node2D = $SonarOverlay
@onready var quick_slot_1: Control = $QuickSlot1
@onready var quick_slot_2: Control = $QuickSlot2

var _last_swivel_tier: int = -1
var _last_has_left: bool = false
var _last_has_right: bool = false


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		gear_knob.visible = false
		quick_slot_1.visible = false
		quick_slot_2.visible = false
		for child in get_children():
			if child is Panel:
				child.visible = false

	gear_knob.gear_changed.connect(_on_gear_changed)
	swivel_knob.direction_changed.connect(_on_swivel_direction_changed)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	if sonar_overlay and DisplayServer.is_touchscreen_available():
		var on_cd: bool = player.sonar_cooldown_timer > 0.0
		var p: float = 1.0 - (player.sonar_cooldown_timer / player.sonar_cooldown) if on_cd else 1.0
		sonar_overlay.update_state(on_cd, p)

	if DisplayServer.is_touchscreen_available():
		quick_slot_1.refresh(player)
		quick_slot_2.refresh(player)

	var tier: int = player.drill_swivel_tier
	var has_left: bool = Vector2i.LEFT in player.permanent_drills
	var has_right: bool = Vector2i.RIGHT in player.permanent_drills

	if tier != _last_swivel_tier or has_left != _last_has_left or has_right != _last_has_right:
		_last_swivel_tier = tier
		_last_has_left = has_left
		_last_has_right = has_right

		swivel_knob.visible = DisplayServer.is_touchscreen_available() and tier >= 2
		if swivel_knob.visible:
			swivel_knob.configure(has_left, has_right)


func _on_gear_changed(new_gear: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.drill_gear = new_gear


func _on_swivel_direction_changed(dir: Vector2i) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("request_drill_direction"):
		player.request_drill_direction(dir)


func _sync_gear_knob_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	if gear_knob and gear_knob.has_method("set_gear"):
		gear_knob.set_gear(player.drill_gear)
	if swivel_knob and swivel_knob.has_method("set_direction"):
		swivel_knob.set_direction(player.drill_direction)
