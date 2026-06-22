extends Building

func _on_interact() -> void:
	var fuel_menu := get_tree().current_scene.get_node_or_null("FuelMenu") as CanvasLayer
	if fuel_menu:
		var player := get_tree().get_first_node_in_group("player")
		fuel_menu.open(player)
