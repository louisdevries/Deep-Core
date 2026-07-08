extends Control

signal direction_changed(direction: Vector2i)

@export var snap_speed: float = 18.0

@onready var knob: Control = $Background/Knob
@onready var dir_display: Label = $Background/DirDisplay

var is_dragging: bool = false
var current_idx: int = 0
var knob_target_x: float = 0.0
var drag_offset: float = 0.0

var _snap_positions: Array[float] = []
var _directions: Array[Vector2i] = []
var _dir_labels: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	if _directions.is_empty():
		_build_directions(false, false)
	_recompute_and_apply()


func _build_directions(has_left_permanent: bool, has_right_permanent: bool) -> void:
	_directions.clear()
	_dir_labels.clear()
	if not has_left_permanent:
		_directions.append(Vector2i.LEFT)
		_dir_labels.append("←")
	_directions.append(Vector2i.DOWN)
	_dir_labels.append("↓")
	if not has_right_permanent:
		_directions.append(Vector2i.RIGHT)
		_dir_labels.append("→")


func _recompute_and_apply() -> void:
	_snap_positions.clear()
	var n: int = _directions.size()
	var usable: float = size.x - knob.size.x
	for i in range(n):
		var x: float = 0.0 if n <= 1 else (float(i) / float(n - 1)) * usable
		_snap_positions.append(x)

	var new_idx: int = _directions.find(Vector2i.DOWN)
	if new_idx < 0:
		new_idx = 0
	current_idx = new_idx
	knob.position.x = _snap_positions[current_idx]
	knob_target_x = _snap_positions[current_idx]
	_apply_visuals(current_idx)


func configure(has_left_permanent: bool, has_right_permanent: bool) -> void:
	_build_directions(has_left_permanent, has_right_permanent)
	if size.x > 0:
		_recompute_and_apply()


func _process(delta: float) -> void:
	if not is_dragging:
		knob.position.x = lerp(knob.position.x, knob_target_x, snap_speed * delta)
	if dir_display and dir_display.size.x > 0:
		dir_display.position.x = knob.position.x + (knob.size.x - dir_display.size.x) * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			drag_offset = event.position.x - knob.position.x
			get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				is_dragging = false
				_snap_to_nearest()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag and is_dragging:
		_drag_knob(event.position.x)
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.pressed:
			var knob_rect := Rect2(knob.position, knob.size)
			if knob_rect.has_point(event.position):
				is_dragging = true
				drag_offset = event.position.x - knob.position.x
				get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				is_dragging = false
				_snap_to_nearest()
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_dragging:
		_drag_knob(event.position.x)
		get_viewport().set_input_as_handled()


func _drag_knob(touch_x: float) -> void:
	var new_x: float = clamp(touch_x - drag_offset, 0.0, size.x - knob.size.x)
	knob.position.x = new_x
	knob.modulate = Color(1.2, 1.2, 1.2)


func _snap_to_nearest() -> void:
	var cx: float = knob.position.x
	var best_idx: int = 0
	var best_dist: float = INF
	for i in range(_snap_positions.size()):
		var d: float = abs(_snap_positions[i] - cx)
		if d < best_dist:
			best_dist = d
			best_idx = i
	current_idx = best_idx
	knob_target_x = _snap_positions[current_idx]
	direction_changed.emit(_directions[current_idx])
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(30)
	_apply_visuals(current_idx)


func _apply_visuals(idx: int) -> void:
	if dir_display and idx < _dir_labels.size():
		dir_display.text = _dir_labels[idx]
	knob.modulate = Color.WHITE


func set_direction(dir: Vector2i) -> void:
	var idx: int = _directions.find(dir)
	if idx < 0:
		idx = _directions.find(Vector2i.DOWN)
	if idx < 0:
		idx = 0
	current_idx = idx
	if _snap_positions.size() > idx:
		knob.position.x = _snap_positions[idx]
		knob_target_x = _snap_positions[idx]
	_apply_visuals(idx)
