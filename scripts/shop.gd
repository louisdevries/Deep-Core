extends Building

func _on_interact() -> void:
	var shop_menu := get_tree().current_scene.get_node_or_null("ShopMenu") as CanvasLayer
	if shop_menu:
		var player := get_tree().get_first_node_in_group("player")
		shop_menu.open(player)
