extends Building

func _on_interact() -> void:
	var upgrade_menu := get_tree().current_scene.get_node_or_null("UpgradeMenu") as CanvasLayer
	if upgrade_menu:
		var player := get_tree().get_first_node_in_group("player")
		upgrade_menu.open(player)
