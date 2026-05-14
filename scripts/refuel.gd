# refuel.gd
extends Area2D


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):

	if body.is_in_group("player"):

		# refuel
		body.fuel = body.max_fuel

		# sell ore
		var earned = body.ore * body.ore_sell_value

		body.money += earned

		# clear ore inventory
		body.ore = 0

		print("Sold ore for: ", earned)
		print("Money: ", body.money)
