extends Node2D
class_name Building

@export var building_id: String = "generic"

var _highlight_node: Node = null


func _ready() -> void:
	_highlight_node = get_node_or_null("Sprite2D")
	if not _highlight_node:
		_highlight_node = get_node_or_null("SpriteOff")
	var area: Area2D = $Area2D
	if area:
		area.input_event.connect(_on_area_input)


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_interact()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_interact()


func _on_interact() -> void:
	pass


func _process(_delta: float) -> void:
	if not _highlight_node:
		return
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var is_near: bool = global_position.distance_to(player.global_position) < 100.0
	_highlight_node.modulate = Color(1.2, 1.2, 1.2, 1.0) if is_near else Color(1.0, 1.0, 1.0, 1.0)
