extends Control

const ItemData = preload("res://scripts/data/item_data.gd")

const ITEM_COLORS: Dictionary = {
	"fuel_can":         Color(0.9,  0.50, 0.10),
	"large_fuel_can":   Color(1.0,  0.65, 0.00),
	"repair_kit":       Color(0.2,  0.80, 0.30),
	"sonar_battery":    Color(0.2,  0.60, 1.00),
	"teleport_charge":  Color(0.7,  0.20, 1.00),
	"dynamite":         Color(0.9,  0.20, 0.20),
	"shaped_charge":    Color(1.0,  0.30, 0.10),
	"mineral_detector": Color(0.9,  0.85, 0.10),
	"phase_beacon":     Color(0.3,  0.80, 0.90),
}

@export var slot_index: int = 0

var _current_item: String = ""
var _count: int = 0
var _pressing: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(76, 76)
	mouse_filter = MOUSE_FILTER_STOP


func refresh(player: Node) -> void:
	if not player:
		return
	if player.quick_slots.size() <= slot_index:
		_current_item = ""
		_count = 0
		queue_redraw()
		return

	var item_id: String = player.quick_slots[slot_index]
	var count: int = player.item_inventory.get(item_id, 0) if not item_id.is_empty() else 0

	if not item_id.is_empty() and count <= 0:
		player.quick_slots[slot_index] = ""
		item_id = ""
		count = 0

	if item_id == _current_item and count == _count:
		return

	_current_item = item_id
	_count = count
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var r: float = min(size.x, size.y) * 0.5 - 1.0

	# Background circle
	draw_circle(center, r, Color(0.22, 0.22, 0.28, 0.95) if _pressing else Color(0.10, 0.10, 0.13, 0.92))

	# Item swatch (inner colored circle)
	if not _current_item.is_empty() and _count > 0:
		draw_circle(center, r * 0.58, ITEM_COLORS.get(_current_item, Color(0.45, 0.45, 0.50)))

	var font: Font = ThemeDB.fallback_font
	const FS_LABEL: int = 10
	const FS_NAME: int  = 8
	var asc_label: float = font.get_ascent(FS_LABEL)
	var asc_name: float  = font.get_ascent(FS_NAME)
	var baseline_top: float = 3.0 + asc_label

	# Slot number — top-left
	draw_string(font, Vector2(5.0, baseline_top),
		"S%d" % (slot_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, FS_LABEL, Color(1, 1, 1, 0.70))

	# Count — top-right
	if not _current_item.is_empty() and _count > 0:
		var ct := "×%d" % _count
		var ct_w: float = font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_LABEL).x
		draw_string(font, Vector2(size.x - ct_w - 4.0, baseline_top),
			ct, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_LABEL, Color.WHITE)

	# Item name — centered in lower half
	var display_name: String = _get_display_name()
	draw_string(font, Vector2(0.0, center.y + asc_name + 4.0),
		display_name, HORIZONTAL_ALIGNMENT_CENTER, int(size.x), FS_NAME, Color(1, 1, 1, 0.90))


func _get_display_name() -> String:
	if _current_item.is_empty():
		return "—"
	var data: Dictionary = ItemData.ITEMS.get(_current_item, {})
	var n: String = str(data.get("name", _current_item))
	return n if n.length() <= 8 else n.left(7) + "…"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_pressing = event.pressed
		queue_redraw()
		if event.pressed:
			_tap_use()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressing = event.pressed
		queue_redraw()
		if event.pressed:
			_tap_use()
		get_viewport().set_input_as_handled()


func _tap_use() -> void:
	if _current_item.is_empty() or _count <= 0:
		return
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	player.use_item(_current_item)
