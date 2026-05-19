# refuel.gd
extends Area2D

const UpgradeMenuScene := preload("res://scenes/upgrade_menu.tscn")

@export var button_offset_y: float = -80.0    # how far above the zone, in world pixels
@export var visual_anchor_path: NodePath       # optional override; defaults to Sprite2D child

var armed: bool = false
var upgrade_menu: CanvasLayer = null
var upgrade_button: Button = null
var current_player: Node = null


func _ready():

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	armed = not SaveSystem.has_save()

	upgrade_menu = get_tree().current_scene.get_node_or_null("UpgradeMenu") as CanvasLayer
	if not upgrade_menu:
		upgrade_menu = UpgradeMenuScene.instantiate()
		get_tree().current_scene.add_child.call_deferred(upgrade_menu)

	upgrade_button = get_tree().current_scene.get_node_or_null("UI/UpgradeButton") as Button
	if upgrade_button:
		upgrade_button.visible = false
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	else:
		print("Warning: UpgradeButton node not found in UI")


func _process(_delta: float) -> void:

	if upgrade_button and upgrade_button.visible:
		_update_button_position()


func _get_anchor_global_position() -> Vector2:

	# prefer an explicit anchor node, else look for a Sprite2D child
	if visual_anchor_path and has_node(visual_anchor_path):
		var anchor := get_node(visual_anchor_path)
		if anchor is Node2D:
			return (anchor as Node2D).global_position

	var sprite := get_node_or_null("Sprite2D") as Node2D
	if sprite:
		return sprite.global_position

	return global_position


func _update_button_position() -> void:

	if not upgrade_button:
		return

	var anchor_world: Vector2 = _get_anchor_global_position()
	var anchor_above: Vector2 = anchor_world + Vector2(0, button_offset_y)

	# convert world position to screen-space using the canvas transform
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var screen_pos: Vector2 = canvas_transform * anchor_above

	var button_size: Vector2 = upgrade_button.size

	# center horizontally over the anchor point
	upgrade_button.position = screen_pos - Vector2(button_size.x * 0.5, 0)


func _show_upgrade_button() -> void:

	if not upgrade_button:
		return

	upgrade_button.visible = true
	_update_button_position()


func _on_body_entered(body):

	if not body.is_in_group("player"):
		return

	current_player = body
	body.can_upgrade = true

	if upgrade_button:
		_show_upgrade_button()

	if not armed:
		return

	# refuel
	if body.fuel < body.max_fuel:
		body.fuel = body.max_fuel

	# sell ore
	var earned = body.ore * body.ore_sell_value
	if earned > 0:
		body.money += earned

	body.ore = 0
	body.cargo = 0

	# save
	var world_save: Dictionary = body.terrain.build_world_save() if body.terrain else {}
	var player_save: Dictionary = body.build_player_save()
	var payload := player_save.duplicate()
	for key in world_save.keys():
		payload[key] = world_save[key]

	SaveSystem.save_game(payload)
	print("Game saved at refuel zone")


func _on_body_exited(body):

	if body.is_in_group("player"):
		body.can_upgrade = false
		armed = true
		current_player = null
		if upgrade_button:
			upgrade_button.visible = false


func _on_upgrade_button_pressed():

	if not current_player:
		return

	if upgrade_menu and upgrade_menu.has_method("open"):
		upgrade_menu.open(current_player)