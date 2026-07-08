extends Control

var _overlay: Node2D = null


func _ready() -> void:
	if DisplayServer.is_touchscreen_available():
		queue_free()
		return

	var tex := TextureRect.new()
	tex.layout_mode = 1
	tex.anchor_right = 1.0
	tex.anchor_bottom = 1.0
	tex.grow_horizontal = 2
	tex.grow_vertical = 2
	tex.texture = load("res://assets/Art/UI/ui_sonar.png")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(tex)

	_overlay = Node2D.new()
	_overlay.set_script(load("res://scripts/sonar_cooldown_overlay.gd"))
	_overlay.set("radius", 32.0)
	_overlay.position = Vector2(32.0, 32.0)
	add_child(_overlay)


func _process(_delta: float) -> void:
	if not _overlay:
		return
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var on_cd: bool = player.sonar_cooldown_timer > 0.0
	var p: float = 1.0 - (player.sonar_cooldown_timer / player.sonar_cooldown) if on_cd else 1.0
	_overlay.update_state(on_cd, p)
