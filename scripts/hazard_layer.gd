extends TileMapLayer

func _ready():
	# wafting / pulsing effect
	var tween := create_tween().set_loops()
	tween.tween_property(self, "modulate:a", 0.45, 1.4)
	tween.tween_property(self, "modulate:a", 0.85, 1.4)
