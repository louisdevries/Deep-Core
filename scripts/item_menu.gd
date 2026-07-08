extends CanvasLayer

const ItemData = preload("res://scripts/data/item_data.gd")

@onready var close_button:   Button         = $Panel/VBox/CloseButton
@onready var list_container: VBoxContainer  = $Panel/VBox/Scroll/List
@onready var beacon_banner:  Label          = $Panel/VBox/BeaconBanner
@onready var slot1_zone:     PanelContainer = $Panel/VBox/SlotZoneRow/Slot1Zone
@onready var slot2_zone:     PanelContainer = $Panel/VBox/SlotZoneRow/Slot2Zone
@onready var slot1_label:    Label          = $Panel/VBox/SlotZoneRow/Slot1Zone/Slot1Label
@onready var slot2_label:    Label          = $Panel/VBox/SlotZoneRow/Slot2Zone/Slot2Label

var player: Node = null

var _pending_hold_item: String  = ""
var _hold_press_pos:    Vector2
var _drag_active:       bool    = false
var _drag_item_id:      String  = ""
var _drag_ghost:        Control = null
var _drag_last_pos:     Vector2
var _assign_popup:      Control = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	_apply_theme()


func _apply_theme() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	add_child(backdrop)
	move_child(backdrop, 0)

	$Panel.add_theme_stylebox_override("panel", _panel_style())
	$Panel/VBox.add_theme_constant_override("separation", 8)

	var title := $Panel.get_node_or_null("VBox/TitleLabel") as Label
	if title:
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	beacon_banner.add_theme_font_size_override("font_size", 13)
	beacon_banner.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))

	var slot_sty := _card_style()
	for zone in [slot1_zone, slot2_zone]:
		zone.add_theme_stylebox_override("panel", slot_sty)
	for lbl in [slot1_label, slot2_label]:
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.70, 0.60, 0.40))

	_style_btn(close_button, false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	var screen_pos: Vector2
	var is_move    := false
	var is_release := false

	if event is InputEventScreenDrag:
		screen_pos = event.position
		is_move = true
	elif event is InputEventScreenTouch and not event.pressed:
		screen_pos = event.position
		is_release = true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		screen_pos = get_viewport().get_mouse_position()
		is_move = true
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		screen_pos = get_viewport().get_mouse_position()
		is_release = true
	else:
		return

	if is_move:
		_drag_last_pos = screen_pos
		if _drag_active:
			if _drag_ghost:
				_drag_ghost.position = screen_pos + Vector2(-44, -20)
			_update_slot_highlights(screen_pos)
			get_viewport().set_input_as_handled()
		elif not _pending_hold_item.is_empty():
			if screen_pos.distance_to(_hold_press_pos) > 12.0:
				var item := _pending_hold_item
				_pending_hold_item = ""
				_enter_drag(item, screen_pos)
				get_viewport().set_input_as_handled()

	if is_release:
		_pending_hold_item = ""
		if _drag_active:
			_finish_drag(screen_pos)
			get_viewport().set_input_as_handled()


func open_for_current_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	open(players[0])


func open(p_player: Node) -> void:
	player = p_player
	visible = true
	get_tree().paused = true
	rebuild()


func close() -> void:
	_hide_assign_popup()
	_cancel_drag()
	visible = false
	get_tree().paused = false


func rebuild() -> void:
	for c in list_container.get_children():
		list_container.remove_child(c)
		c.queue_free()

	var has_beacon: bool = player.has_active_beacon if player else false
	beacon_banner.visible = has_beacon
	if has_beacon:
		beacon_banner.text = "Phase Beacon active — tap Return to teleport back!"

	var has_items := false

	for item_id in ItemData.SHOP_ORDER:
		var count: int = player.item_inventory.get(item_id, 0) if player else 0
		if count <= 0:
			continue
		has_items = true
		list_container.add_child(_build_item_row(item_id, count))

	if has_beacon:
		has_items = true
		list_container.add_child(_build_beacon_return_row())

	if not has_items:
		var lbl := Label.new()
		lbl.text = "No items in inventory.\nBuy consumables from the shop."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.60, 0.50, 0.34))
		list_container.add_child(lbl)

	_update_slot_zones()


func _build_item_row(item_id: String, count: int) -> Control:
	var data: Dictionary = ItemData.ITEMS[item_id]

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = "%s  ×%d" % [data["name"], count]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.80, 0.52))
	header.add_child(name_lbl)

	var hint := Label.new()
	hint.text = "hold to assign"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.50, 0.42, 0.28))
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(hint)

	var btn_text: String = "Use"
	match data["use_type"]:
		"place":        btn_text = "Place"
		"place_return": btn_text = "Place Beacon"

	var btn := _make_btn(btn_text, true)
	btn.pressed.connect(_on_use_item.bind(item_id))
	header.add_child(btn)

	var desc := Label.new()
	desc.text = data["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.62, 0.52, 0.36))
	vbox.add_child(desc)

	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_gui_input.bind(item_id))

	return row


func _build_beacon_return_row() -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style())
	var hbox := HBoxContainer.new()
	row.add_child(hbox)

	var lbl := Label.new()
	lbl.text = "Phase Beacon — teleport back to beacon"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	hbox.add_child(lbl)

	var btn := _make_btn("Return", true)
	btn.pressed.connect(_on_beacon_return)
	hbox.add_child(btn)

	return row


# ── Row interaction ────────────────────────────────────────────────────────────

func _on_row_gui_input(event: InputEvent, item_id: String) -> void:
	if _assign_popup != null:
		return
	if event is InputEventScreenTouch and event.pressed:
		_hold_press_pos = event.position
		_start_hold(item_id)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hold_press_pos = get_viewport().get_mouse_position()
		_start_hold(item_id)
		get_viewport().set_input_as_handled()


func _start_hold(item_id: String) -> void:
	_pending_hold_item = item_id
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(func() -> void:
		if _pending_hold_item == item_id and not _drag_active:
			_pending_hold_item = ""
			_show_assign_popup(item_id)
	)


# ── Drag ──────────────────────────────────────────────────────────────────────

func _enter_drag(item_id: String, screen_pos: Vector2) -> void:
	_drag_active  = true
	_drag_item_id = item_id
	_drag_last_pos = screen_pos

	_drag_ghost = PanelContainer.new()
	_drag_ghost.add_theme_stylebox_override("panel", _card_style())
	var lbl := Label.new()
	lbl.text = "  %s  " % ItemData.ITEMS.get(item_id, {}).get("name", item_id)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.50))
	_drag_ghost.add_child(lbl)
	_drag_ghost.modulate = Color(1, 1, 1, 0.88)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_ghost)
	_drag_ghost.position = screen_pos + Vector2(-44, -20)

	_update_slot_highlights(screen_pos)


func _update_slot_highlights(screen_pos: Vector2) -> void:
	if slot1_zone:
		slot1_zone.modulate = Color(0.5, 1.0, 0.55) if slot1_zone.get_global_rect().has_point(screen_pos) else Color.WHITE
	if slot2_zone:
		slot2_zone.modulate = Color(0.5, 1.0, 0.55) if slot2_zone.get_global_rect().has_point(screen_pos) else Color.WHITE


func _finish_drag(screen_pos: Vector2) -> void:
	var item_id := _drag_item_id
	_cancel_drag()
	if slot1_zone and slot1_zone.get_global_rect().has_point(screen_pos):
		_assign_to_slot(item_id, 0)
	elif slot2_zone and slot2_zone.get_global_rect().has_point(screen_pos):
		_assign_to_slot(item_id, 1)
	_update_slot_zones()


func _cancel_drag() -> void:
	_drag_active  = false
	_drag_item_id = ""
	if _drag_ghost and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null
	if slot1_zone:
		slot1_zone.modulate = Color.WHITE
	if slot2_zone:
		slot2_zone.modulate = Color.WHITE


# ── Slot assignment ───────────────────────────────────────────────────────────

func _assign_to_slot(item_id: String, slot_idx: int) -> void:
	if not player:
		return
	while player.quick_slots.size() <= slot_idx:
		player.quick_slots.append("")
	player.quick_slots[slot_idx] = item_id


func _update_slot_zones() -> void:
	var zones  := [slot1_zone,  slot2_zone]
	var labels := [slot1_label, slot2_label]
	for i in range(2):
		var lbl: Label = labels[i]
		if not lbl:
			continue
		var item_id: String = player.quick_slots[i] if player and player.quick_slots.size() > i else ""
		if item_id.is_empty():
			lbl.text = "Quick %d: —  (drag here or hold item)" % (i + 1)
		else:
			var item_name: String = ItemData.ITEMS.get(item_id, {}).get("name", item_id)
			var count: int = player.item_inventory.get(item_id, 0) if player else 0
			lbl.text = "Quick %d: %s  ×%d" % [i + 1, item_name, count]


# ── Assign popup ──────────────────────────────────────────────────────────────

func _show_assign_popup(item_id: String) -> void:
	_hide_assign_popup()
	var item_name: String = ItemData.ITEMS.get(item_id, {}).get("name", item_id)

	var popup := PanelContainer.new()
	popup.name = "AssignPopup"
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_theme_stylebox_override("panel", _panel_style())

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = 'Assign "%s" to quick slot:' % item_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.48))
	vbox.add_child(title)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	for i in range(2):
		var existing: String = player.quick_slots[i] if player and player.quick_slots.size() > i else ""
		var btn := _make_btn("", false)
		if existing.is_empty():
			btn.text = "Add to Slot %d" % (i + 1)
		else:
			var ex_name: String = ItemData.ITEMS.get(existing, {}).get("name", existing)
			btn.text = "Slot %d\n(replaces %s)" % [i + 1, ex_name]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		btn.pressed.connect(func() -> void:
			_assign_to_slot(item_id, idx)
			_hide_assign_popup()
			_update_slot_zones()
		)
		btn_row.add_child(btn)

	var cancel := _make_btn("Cancel", false)
	cancel.pressed.connect(_hide_assign_popup)
	vbox.add_child(cancel)

	add_child(popup)
	_assign_popup = popup

	await get_tree().process_frame
	if is_instance_valid(popup):
		popup.position = (get_viewport().get_visible_rect().size - popup.size) * 0.5


func _hide_assign_popup() -> void:
	if _assign_popup and is_instance_valid(_assign_popup):
		_assign_popup.queue_free()
	_assign_popup = null


# ── Use / beacon ──────────────────────────────────────────────────────────────

func _on_use_item(item_id: String) -> void:
	if not player:
		return
	player.use_item(item_id)
	close()


func _on_beacon_return() -> void:
	if not player:
		return
	player.use_beacon_return()
	close()


# ── Style helpers ────────────────────────────────────────────────────────────

func _style_btn(btn: Button, primary: bool) -> void:
	btn.add_theme_font_size_override("font_size", 16)
	var border := Color(0.55, 0.40, 0.15, 0.80) if primary else Color(0.42, 0.30, 0.10, 0.70)
	var bg     := Color(0.14, 0.09, 0.04, 0.90) if primary else Color(0.10, 0.07, 0.03, 0.85)
	btn.add_theme_stylebox_override("normal",  _flat_style(bg, border))
	btn.add_theme_stylebox_override("hover",   _flat_style(Color(0.26, 0.16, 0.06, 0.95), Color(0.90, 0.70, 0.25, 1.00)))
	btn.add_theme_stylebox_override("pressed", _flat_style(Color(0.35, 0.22, 0.08, 1.00), Color(1.00, 0.85, 0.40, 1.00)))
	btn.add_theme_color_override("font_color",         Color(0.92, 0.78, 0.50) if primary else Color(0.82, 0.70, 0.45))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.92, 0.65))
	btn.add_theme_color_override("font_pressed_color", Color(1.00, 1.00, 0.80))


func _make_btn(txt: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = txt
	_style_btn(btn, primary)
	return btn


func _flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color              = bg
	s.border_color          = border
	s.border_width_left     = 2
	s.border_width_right    = 2
	s.border_width_top      = 2
	s.border_width_bottom   = 2
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	return s


func _card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color              = Color(0.12, 0.09, 0.05, 0.85)
	s.border_color          = Color(0.45, 0.32, 0.12, 0.60)
	s.border_width_left     = 1
	s.border_width_right    = 1
	s.border_width_top      = 1
	s.border_width_bottom   = 1
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left   = 8
	s.content_margin_right  = 8
	s.content_margin_top    = 6
	s.content_margin_bottom = 6
	return s


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color              = Color(0.08, 0.06, 0.04, 0.97)
	s.border_color          = Color(0.60, 0.44, 0.18, 0.90)
	s.border_width_left     = 2
	s.border_width_right    = 2
	s.border_width_top      = 2
	s.border_width_bottom   = 2
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	s.content_margin_left   = 18
	s.content_margin_right  = 18
	s.content_margin_top    = 14
	s.content_margin_bottom = 14
	return s
