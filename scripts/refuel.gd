extends Area2D

const UpgradeData = preload("res://scripts/data/upgrade_data.gd")


func _ready():

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta):

	if Input.is_action_just_pressed("interact"):

		var bodies = get_overlapping_bodies()

		for body in bodies:

			if body.is_in_group("player"):

				attempt_upgrade(body)


func attempt_upgrade(player):

	var next_level = player.drill_power + 1

	if not UpgradeData.DRILL_UPGRADES.has(next_level):

		print("Max upgrade level reached")
		return

	var upgrade_data = UpgradeData.DRILL_UPGRADES[next_level]

	var required_money = upgrade_data["money"]
	var required_resources = upgrade_data["resources"]

	# CHECK MONEY
	if player.money < required_money:

		print("Not enough money")
		return

	# CHECK RESOURCES
	for resource_name in required_resources:

		var amount_needed = required_resources[resource_name]

		if player.resources.get(resource_name, 0) < amount_needed:

			print("Missing resource:", resource_name)
			return

	# REMOVE MONEY
	player.money -= required_money

	# REMOVE RESOURCES
	for resource_name in required_resources:

		player.resources[resource_name] -= required_resources[resource_name]

	# APPLY UPGRADE
	player.drill_power += 1

	print("Drill upgraded!")
	print("New Power:", player.drill_power)


func _on_body_entered(body):
	
	body.spawn_position = body.global_position

	if body.is_in_group("player"):

		body.can_upgrade = true

		# REFUEL
		body.fuel = body.max_fuel

		# SELL BASIC ORE ONLY
		var earned = body.ore * body.ore_sell_value

		body.money += earned

		print("Sold ore for:", earned)

		# CLEAR SELLABLE ORE
		body.ore = 0

		# CLEAR CARGO
		body.cargo = 0


func _on_body_exited(body):

	if body.is_in_group("player"):

		body.can_upgrade = false
