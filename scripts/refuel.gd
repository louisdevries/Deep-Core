extends Area2D


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta):

	if Input.is_action_just_pressed("interact"):

		var bodies = get_overlapping_bodies()

		for body in bodies:

			if body.is_in_group("player"):

				if body.money >= body.upgrade_cost:

					body.money -= body.upgrade_cost

					body.drill_power += 1

					body.upgrade_cost *= 2
					
					body.cargo = 0

					print("Drill upgraded!")
					print("Power:", body.drill_power)


func _on_body_entered(body):
	if body.is_in_group("player"):
		body.can_upgrade = true
		body.fuel = body.max_fuel
		var earned = body.ore * body.ore_sell_value
		body.money += earned
		body.ore = 0
		body.cargo = 0  # <-- add this
		print("Sold ore for:", earned)
		print("Money:", body.money)


func _on_body_exited(body):

	if body.is_in_group("player"):
		body.can_upgrade = false
