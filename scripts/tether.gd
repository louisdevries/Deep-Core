extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

const VELOCITY_THRESHOLD := 10.0

var _last_dir := 0  # -1 ascending, 0 stopped, 1 descending

func _process(_delta: float) -> void:
	var dir := 0
	if Input.is_action_pressed("ui_down"):
		dir = 1
	elif Input.is_action_pressed("ui_up"):
		dir = -1

	if dir == _last_dir:
		return
	_last_dir = dir

	match dir:
		1:
			anim.play("descend")
		-1:
			anim.play("ascend")
		0:
			anim.stop()
