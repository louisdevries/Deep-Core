extends Node2D

var radius: float = 48.0
const SEGMENTS: int = 64
const OVERLAY_COLOR: Color = Color(0.0, 0.0, 0.0, 0.60)

var _active: bool = false
var _progress: float = 0.0


func update_state(on_cooldown: bool, progress: float) -> void:
	var changed: bool = _active != on_cooldown or _progress != progress
	_active = on_cooldown
	_progress = clampf(progress, 0.0, 1.0)
	if changed:
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var remaining: float = 1.0 - _progress
	if remaining < 0.01:
		return
	var arc_angle: float = remaining * TAU
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(SEGMENTS + 1):
		var t: float = float(i) / float(SEGMENTS)
		var angle: float = -PI * 0.5 + t * arc_angle
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, OVERLAY_COLOR)
