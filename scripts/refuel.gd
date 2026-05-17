# refuel.gd
extends Area2D

const UpgradeMenuScene := preload("res://scenes/upgrade_menu.tscn")

var armed: bool = false
var upgrade_menu: CanvasLayer = null


func _ready():

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	armed = not SaveSystem.has_save()

	# instantiate the menu once and reuse it
	upgrade_menu = UpgradeMenuScene.instantiate()
	get_tree().current_scene.add_child.call_deferred(upgrade_menu)


func _on_body_entered(body):

	if not body.is_in_group("player"):
		return

	if not armed:
		body.can_upgrade = true
		return

	body.can_upgrade = true

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

	# open upgrade menu
	if upgrade_menu and upgrade_menu.has_method("open"):
		upgrade_menu.open(body)


func _on_body_exited(body):

	if body.is_in_group("player"):
		body.can_upgrade = false
		armed = true
