extends Control

signal gear_changed(new_gear: int)

@export var num_gears: int = 3
@export var snap_speed: float = 18.0

@onready var knob: Control = $Background/Knob
@onready var gear_display: Label = $Background/GearDisplay

var is_dragging: bool = false
var current_gear: int = 1
var knob_target_y: float = 0.0
var drag_offset: float = 0.0

var gear_positions: Array[float] = []


func _ready() -> void:
	await get_tree().process_frame
	_compute_gear_positions()
	_position_detents()
	knob.position.y = gear_positions[0]
	knob_target_y = gear_positions[0]
	_apply_gear_visuals(1)
	var click_sound_node: AudioStreamPlayer = get_node_or_null("ClickSound")
	if click_sound_node:
		click_sound_node.bus = "SFX"


func _position_detents() -> void:
	for i in range(num_gears):
		var marker := get_node_or_null("Background/Detents/Detent%dMarker" % (i + 1)) as Label
		if marker:
			var knob_center_y := gear_positions[i] + knob.size.y * 0.5
			marker.position.y = knob_center_y - marker.size.y * 0.5


func _compute_gear_positions() -> void:
	gear_positions.clear()
	var usable_height: float = size.y - knob.size.y
	var spacing: float = usable_height / float(num_gears - 1)
	for i in range(num_gears):
		var pos_y: float = usable_height - (i * spacing)
		gear_positions.append(pos_y)


func _process(delta: float) -> void:
	if not is_dragging:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.is_drilling:
			var wobble: float = sin(Time.get_ticks_msec() * 0.01) * 1.5
			knob.position.y = lerp(knob.position.y, knob_target_y + wobble, snap_speed * delta)
		else:
			knob.position.y = lerp(knob.position.y, knob_target_y, snap_speed * delta)

	if gear_display and gear_display.size.y > 0:
		gear_display.position.y = knob.position.y + (knob.size.y - gear_display.size.y) * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		# event.position is screen coords; skip hit test — _gui_input only fires within this control's rect
		if event.pressed:
			is_dragging = true
			drag_offset = event.position.y - knob.position.y
			get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				is_dragging = false
				_snap_to_nearest_gear()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag and is_dragging:
		_drag_knob(event.position.y)
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.pressed:
			var knob_rect: Rect2 = Rect2(knob.position, knob.size)
			if knob_rect.has_point(event.position):
				is_dragging = true
				drag_offset = event.position.y - knob.position.y
				get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				is_dragging = false
				_snap_to_nearest_gear()
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_dragging:
		_drag_knob(event.position.y)
		get_viewport().set_input_as_handled()


func _drag_knob(touch_y: float) -> void:
	var new_y: float = touch_y - drag_offset
	new_y = clamp(new_y, 0.0, size.y - knob.size.y)
	knob.position.y = new_y
	knob.modulate = Color(1.2, 1.2, 1.2)


func _snap_to_nearest_gear() -> void:
	var current_y: float = knob.position.y
	var closest_idx: int = 0
	var closest_dist: float = INF

	for i in range(gear_positions.size()):
		var dist: float = abs(gear_positions[i] - current_y)
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i

	knob_target_y = gear_positions[closest_idx]
	var new_gear: int = closest_idx + 1

	if new_gear != current_gear:
		current_gear = new_gear
		gear_changed.emit(current_gear)
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(30)
		var click_sound: AudioStreamPlayer = get_node_or_null("ClickSound")
		if click_sound:
			click_sound.play()

	_apply_gear_visuals(current_gear)


func _apply_gear_visuals(gear: int) -> void:
	match gear:
		1:
			knob.modulate = Color.WHITE
			if gear_display:
				gear_display.text = "ECO"
		2:
			knob.modulate = Color(1.0, 0.5, 0.2)
			if gear_display:
				gear_display.text = "BURNOUT"
		3:
			knob.modulate = Color(1.0, 0.9, 0.3)
			if gear_display:
				gear_display.text = "OVERDRIVE"



func set_gear(gear: int) -> void:
	gear = clamp(gear, 1, num_gears)
	current_gear = gear
	if gear_positions.size() > 0:
		knob.position.y = gear_positions[gear - 1]
		knob_target_y = gear_positions[gear - 1]
	_apply_gear_visuals(gear)
