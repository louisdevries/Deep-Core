# load_game_menu.gd
# Overlay shown when "Load Game" is pressed from the pause menu.
extends CanvasLayer

signal continue_pressed
signal new_world_pressed

var _confirm_action: String = ""
var _confirm_panel:  Control = null


func _ready() -> void:
	layer   = 115
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(720, 0)
	outer.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(outer)

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	outer.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "LOAD GAME"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var back_btn := _make_btn("← Back", false)
	back_btn.pressed.connect(close)
	header.add_child(back_btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.55, 0.40, 0.16, 0.5))
	vbox.add_child(sep)

	# ── Save card (one slot for now) ─────────────────────────────────────────
	if SaveSystem.has_save():
		vbox.add_child(_build_save_card())
	else:
		var empty := Label.new()
		empty.text = "No saves found."
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.60, 0.52, 0.38))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty)

	# ── Confirm sub-panel (hidden, replaces card on delete/new world confirm) ─
	_confirm_panel = _build_confirm_panel()
	_confirm_panel.visible = false
	vbox.add_child(_confirm_panel)


func _build_save_card() -> Control:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color     = Color(0.12, 0.09, 0.05, 0.90)
	card_style.border_color = Color(0.50, 0.36, 0.13, 0.70)
	card_style.border_width_left   = 1
	card_style.border_width_right  = 1
	card_style.border_width_top    = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left     = 4
	card_style.corner_radius_top_right    = 4
	card_style.corner_radius_bottom_left  = 4
	card_style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", card_style)

	var card_margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		card_margin.add_theme_constant_override("margin_" + side, 14)
	card.add_child(card_margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card_margin.add_child(row)

	# Screenshot (left)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(256, 144)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if FileAccess.file_exists(SaveSystem.SCREENSHOT_PATH):
		var img := Image.load_from_file(SaveSystem.SCREENSHOT_PATH)
		if img:
			thumb.texture = ImageTexture.create_from_image(img)
	if not thumb.texture:
		var placeholder := Image.create(256, 144, false, Image.FORMAT_RGB8)
		placeholder.fill(Color(0.10, 0.08, 0.06))
		thumb.texture = ImageTexture.create_from_image(placeholder)
	row.add_child(thumb)

	# Info (right)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)

	# Name + delete row
	var top_row := HBoxContainer.new()
	info.add_child(top_row)

	var save_data := SaveSystem.data
	if save_data.is_empty():
		save_data = SaveSystem.load_game()

	var name_lbl := Label.new()
	name_lbl.text = save_data.get("save_name", "Save 1")
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.48))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var del_btn := Button.new()
	del_btn.text = "🗑"
	del_btn.add_theme_font_size_override("font_size", 18)
	del_btn.add_theme_stylebox_override("normal",  _flat_style(Color(0.20, 0.06, 0.06, 0.85), Color(0.65, 0.20, 0.20, 0.70)))
	del_btn.add_theme_stylebox_override("hover",   _flat_style(Color(0.40, 0.10, 0.10, 0.95), Color(0.85, 0.30, 0.30, 1.00)))
	del_btn.add_theme_stylebox_override("pressed", _flat_style(Color(0.55, 0.12, 0.12, 1.00), Color(1.00, 0.40, 0.40, 1.00)))
	del_btn.add_theme_color_override("font_color",       Color(0.90, 0.45, 0.45))
	del_btn.add_theme_color_override("font_hover_color", Color(1.00, 0.60, 0.60))
	del_btn.pressed.connect(_on_delete_pressed)
	top_row.add_child(del_btn)

	# Date
	var date_str: String = save_data.get("saved_at", "")
	var date_lbl := Label.new()
	date_lbl.text = "Saved: " + (date_str if date_str != "" else "Unknown")
	date_lbl.add_theme_font_size_override("font_size", 14)
	date_lbl.add_theme_color_override("font_color", Color(0.60, 0.52, 0.38))
	info.add_child(date_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	info.add_child(btn_row)

	var cont_btn := _make_btn("▶  Continue", true)
	cont_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont_btn.pressed.connect(_on_continue_pressed)
	btn_row.add_child(cont_btn)

	var nw_btn := _make_btn("⊕  New World", false)
	nw_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nw_btn.add_theme_color_override("font_color", Color(0.78, 0.68, 0.48))
	nw_btn.pressed.connect(_on_new_world_pressed)
	btn_row.add_child(nw_btn)

	return card


func _build_confirm_panel() -> Control:
	var panel := PanelContainer.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.06, 0.04, 0.02, 0.98)
	sty.border_color            = Color(0.75, 0.35, 0.15, 0.80)
	sty.border_width_left       = 2
	sty.border_width_right      = 2
	sty.border_width_top        = 2
	sty.border_width_bottom     = 2
	sty.corner_radius_top_left     = 4
	sty.corner_radius_top_right    = 4
	sty.corner_radius_bottom_left  = 4
	sty.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", sty)

	var m := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	m.add_child(vb)

	var lbl := Label.new()
	lbl.name = "ConfirmLabel"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.48))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl)

	var detail := Label.new()
	detail.name = "ConfirmDetail"
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", Color(0.65, 0.55, 0.38))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(detail)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)

	var yes := _make_btn("Yes, do it", true)
	yes.pressed.connect(_on_confirm_yes)
	hb.add_child(yes)

	var no := _make_btn("Cancel", false)
	no.pressed.connect(_on_confirm_no)
	hb.add_child(no)

	return panel


func _show_confirm(action: String, title: String, detail: String) -> void:
	_confirm_action = action
	(_confirm_panel.get_child(0).get_child(0).get_child(0) as Label).text = title
	(_confirm_panel.get_child(0).get_child(0).get_child(1) as Label).text = detail
	_confirm_panel.visible = true


func _on_continue_pressed() -> void:
	close()
	continue_pressed.emit()


func _on_new_world_pressed() -> void:
	_show_confirm(
		"new_world",
		"Generate New World?",
		"Money, upgrades, and inventory are kept.\nThe world and dug tunnels reset."
	)


func _on_delete_pressed() -> void:
	_show_confirm(
		"delete",
		"Delete Save?",
		"This permanently deletes all progress."
	)


func _on_confirm_yes() -> void:
	match _confirm_action:
		"new_world":
			close()
			new_world_pressed.emit()
		"delete":
			SaveSystem.clear_save()
			if FileAccess.file_exists(SaveSystem.SCREENSHOT_PATH):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SCREENSHOT_PATH))
			close()
	_confirm_action = ""


func _on_confirm_no() -> void:
	_confirm_panel.visible = false
	_confirm_action = ""


func open() -> void:
	_confirm_panel.visible = false
	_confirm_action = ""
	visible = true


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _confirm_panel.visible:
			_on_confirm_no()
		else:
			close()
		get_viewport().set_input_as_handled()


# ── Style helpers (mirrors main_menu / settings_panel) ───────────────────────

func _make_btn(txt: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 18)
	var border := Color(0.55, 0.40, 0.15, 0.80) if primary else Color(0.42, 0.30, 0.10, 0.70)
	var bg     := Color(0.14, 0.09, 0.04, 0.90) if primary else Color(0.10, 0.07, 0.03, 0.85)
	var bg_h   := Color(0.26, 0.16, 0.06, 0.95)
	var bg_p   := Color(0.35, 0.22, 0.08, 1.00)
	btn.add_theme_stylebox_override("normal",  _flat_style(bg,   border))
	btn.add_theme_stylebox_override("hover",   _flat_style(bg_h, Color(0.90, 0.70, 0.25, 1.00)))
	btn.add_theme_stylebox_override("pressed", _flat_style(bg_p, Color(1.00, 0.85, 0.40, 1.00)))
	btn.add_theme_color_override("font_color",         Color(0.92, 0.78, 0.50) if primary else Color(0.78, 0.66, 0.44))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.92, 0.65))
	btn.add_theme_color_override("font_pressed_color", Color(1.00, 1.00, 0.80))
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
	return s
