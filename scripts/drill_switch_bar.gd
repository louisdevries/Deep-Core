extends Node2D

var _active: bool = false
var _progress: float = 0.0

func show_bar(p: float) -> void:
	_active = true
	_progress = clampf(p, 0.0, 1.0)
	queue_redraw()

func hide_bar() -> void:
	_active = false
	_progress = 0.0
	queue_redraw()

func _draw() -> void:
	if not _active:
		return
	const W: float = 48.0
	const H: float = 4.0
	const Y: float = -22.0
	var x: float = -W * 0.5
	draw_rect(Rect2(x, Y, W, H), Color(0.08, 0.08, 0.08, 0.9))
	draw_rect(Rect2(x, Y, W * _progress, H), Color(0.25, 0.85, 0.45, 1.0))
