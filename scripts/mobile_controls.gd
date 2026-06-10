extends CanvasLayer

func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		for child in get_children():
			if child is Panel:
				child.visible = false
