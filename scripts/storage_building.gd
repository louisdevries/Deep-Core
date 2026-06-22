extends Building

func _on_interact() -> void:
	var storage_menu := get_tree().current_scene.get_node_or_null("StorageMenu") as CanvasLayer
	if storage_menu:
		var player := get_tree().get_first_node_in_group("player")
		storage_menu.open(player)
