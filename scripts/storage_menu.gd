extends CanvasLayer

const ResourceData = preload("res://scripts/data/resource_data.gd")

@onready var inv_label:    Label          = $Panel/VBox/Content/InventoryCol/InvHeader
@onready var inv_list:     VBoxContainer  = $Panel/VBox/Content/InventoryCol/InvScroll/InvList
@onready var stor_label:   Label          = $Panel/VBox/Content/StorageCol/StorHeader
@onready var stor_list:    VBoxContainer  = $Panel/VBox/Content/StorageCol/StorScroll/StorList
@onready var close_button: Button         = $Panel/VBox/CloseButton

var player: Node = null


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
	$Panel/VBox.add_theme_constant_override("separation", 10)

	var title := $Panel.get_node_or_null("VBox/TitleLabel") as Label
	if title:
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for lbl in [inv_label, stor_label]:
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))

	_style_btn(close_button, false)

	# Column section separators
	var content := $Panel.get_node_or_null("VBox/Content") as HBoxContainer
	if content:
		content.add_theme_constant_override("separation", 16)

	# Vertical separators between columns
	var inv_col := $Panel.get_node_or_null("VBox/Content/InventoryCol")
	var stor_col := $Panel.get_node_or_null("VBox/Content/StorageCol")
	for col in [inv_col, stor_col]:
		if col:
			col.add_theme_constant_override("separation", 6)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()


func open(target_player: Node) -> void:
	player = target_player
	visible = true
	get_tree().paused = true
	rebuild()


func close() -> void:
	visible = false
	get_tree().paused = false


func rebuild() -> void:
	inv_label.text  = "Inventory  %d / %d"  % [player.cargo, player.max_cargo]
	stor_label.text = "Storage  %d / %d"    % [player.get_storage_used(), player.max_storage]

	for c in inv_list.get_children():
		inv_list.remove_child(c)
		c.queue_free()
	for c in stor_list.get_children():
		stor_list.remove_child(c)
		c.queue_free()

	for material_id in ResourceData.DISPLAY_ORDER:
		var inv_count: int
		if material_id == "basic_ore":
			inv_count = player.ore
		else:
			inv_count = player.resources.get(material_id, 0)
		var stor_count: int = player.storage.get(material_id, 0)

		if inv_count > 0:
			inv_list.add_child(_build_inv_row(material_id, inv_count))
		if stor_count > 0:
			stor_list.add_child(_build_stor_row(material_id, stor_count))


func _build_inv_row(material_id: String, count: int) -> Control:
	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	var row  := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(18, 18)
	hbox.add_child(swatch)

	var lbl := Label.new()
	lbl.text = "%s × %d" % [data.get("display_name", material_id), count]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
	hbox.add_child(lbl)

	var btn := _make_btn("Store", false)
	btn.disabled = not player.can_store(1)
	if btn.disabled:
		btn.text = "Full"
	btn.pressed.connect(_on_store.bind(material_id, count))
	hbox.add_child(btn)

	return row


func _build_stor_row(material_id: String, count: int) -> Control:
	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	var row  := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(18, 18)
	hbox.add_child(swatch)

	var lbl := Label.new()
	lbl.text = "%s × %d" % [data.get("display_name", material_id), count]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
	hbox.add_child(lbl)

	var btn := _make_btn("Retrieve", false)
	btn.pressed.connect(_on_retrieve.bind(material_id, count))
	hbox.add_child(btn)

	return row


func _on_store(material_id: String, count: int) -> void:
	player.transfer_to_storage(material_id, count)
	rebuild()


func _on_retrieve(material_id: String, count: int) -> void:
	player.transfer_to_cargo(material_id, count)
	rebuild()


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
