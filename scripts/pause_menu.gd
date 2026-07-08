# pause_menu.gd
extends CanvasLayer

var _screenshot: Image = null

# Buttons (assigned in _build_ui)
var _save_btn:      Button
var _load_game_btn: Button

# Sub-overlays
var _settings_panel: CanvasLayer = null
var _load_game_menu: CanvasLayer = null

# Toast notification
var _toast_label:  Label = null
var _toast_timer:  float = 0.0

# Confirm dialog (for quit actions)
var _confirm_panel:  Control = null
var _confirm_label:  Label   = null
var _confirm_detail: Label   = null
var _pending_action: String  = ""

var _menu_music: AudioStreamPlayer = null


func _ready() -> void:
	visible = false
	_build_ui()

	_settings_panel = load("res://scripts/settings_panel.gd").new()
	add_child(_settings_panel)

	_load_game_menu = load("res://scripts/load_game_menu.gd").new()
	_load_game_menu.continue_pressed.connect(_on_load_continue)
	_load_game_menu.new_world_pressed.connect(_on_load_new_world)
	add_child(_load_game_menu)

	_menu_music = AudioStreamPlayer.new()
	_menu_music.stream   = load("res://assets/Audio/Ambience/Main_Menu.mp3")
	_menu_music.bus      = "Music"
	_menu_music.finished.connect(_menu_music.play)
	add_child(_menu_music)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_hide_toast()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		pass  # intentional — key debug removed

	if event.is_action_pressed("pause"):
		var upgrade_menu := get_tree().current_scene.get_node_or_null("UpgradeMenu") as CanvasLayer
		if upgrade_menu and upgrade_menu.visible and not visible:
			return

		if visible:
			if _confirm_panel and _confirm_panel.visible:
				_dismiss_confirm()
			elif _settings_panel.visible:
				_settings_panel.close()
			elif _load_game_menu.visible:
				_load_game_menu.close()
			else:
				close()
		else:
			open()

		get_viewport().set_input_as_handled()


# ══════════════════════════════════════════════════════════════════════════════
# BUILD
# ══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Full-screen dim backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.72)
	add_child(backdrop)

	# Centred panel via CenterContainer
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.55, 0.40, 0.16, 0.5))
	vbox.add_child(sep)

	# Main buttons
	var resume := _make_btn("▶  Resume", true)
	resume.pressed.connect(close)
	vbox.add_child(resume)

	_save_btn = _make_btn("💾  Save Game", false)
	_save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(_save_btn)

	_load_game_btn = _make_btn("↺  Load Game", false)
	_load_game_btn.pressed.connect(_on_load_game_pressed)
	vbox.add_child(_load_game_btn)

	var settings_btn := _make_btn("⚙  Settings", false)
	settings_btn.pressed.connect(func() -> void: _settings_panel.open())
	vbox.add_child(settings_btn)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.55, 0.40, 0.16, 0.3))
	vbox.add_child(sep2)

	var quit_main := _make_btn("⏏  Quit to Main Menu", false)
	quit_main.add_theme_color_override("font_color", Color(0.78, 0.62, 0.40))
	quit_main.pressed.connect(_on_quit_main_pressed)
	vbox.add_child(quit_main)

	var quit_btn := _make_btn("✕  Quit Game", false)
	quit_btn.add_theme_color_override("font_color", Color(0.72, 0.50, 0.38))
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	# Dev menu (small, at bottom of panel)
	var dev_btn := Button.new()
	dev_btn.text = "Dev Menu"
	dev_btn.add_theme_font_size_override("font_size", 12)
	dev_btn.add_theme_color_override("font_color", Color(0.40, 0.35, 0.28, 0.7))
	dev_btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	dev_btn.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
	dev_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	dev_btn.pressed.connect(_on_dev_menu_pressed)
	vbox.add_child(dev_btn)

	# Confirm sub-panel (hidden until needed)
	_confirm_panel = _build_confirm_sub_panel()
	_confirm_panel.visible = false
	vbox.add_child(_confirm_panel)

	# Toast notification — anchored to bottom of screen, outside the panel
	_toast_label = Label.new()
	_toast_label.text = "Game Saved!"
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color",        Color(0.90, 0.78, 0.45))
	_toast_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_toast_label.add_theme_constant_override("shadow_offset_x", 2)
	_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	_toast_label.anchor_left   = 0.0
	_toast_label.anchor_right  = 1.0
	_toast_label.anchor_top    = 1.0
	_toast_label.anchor_bottom = 1.0
	_toast_label.offset_top    = -52
	_toast_label.offset_bottom = -16
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)  # child of CanvasLayer, not of center/panel


func _build_confirm_sub_panel() -> Control:
	var panel := PanelContainer.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.06, 0.04, 0.02, 0.98)
	sty.border_color = Color(0.75, 0.35, 0.15, 0.80)
	sty.border_width_left   = 2
	sty.border_width_right  = 2
	sty.border_width_top    = 2
	sty.border_width_bottom = 2
	sty.corner_radius_top_left     = 4
	sty.corner_radius_top_right    = 4
	sty.corner_radius_bottom_left  = 4
	sty.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", sty)

	var m := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	m.add_child(vb)

	_confirm_label = Label.new()
	_confirm_label.add_theme_font_size_override("font_size", 17)
	_confirm_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.48))
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_confirm_label)

	_confirm_detail = Label.new()
	_confirm_detail.add_theme_font_size_override("font_size", 13)
	_confirm_detail.add_theme_color_override("font_color", Color(0.65, 0.55, 0.38))
	_confirm_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_confirm_detail)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)

	var yes := _make_btn("Yes", true)
	yes.pressed.connect(_on_confirm_yes)
	hb.add_child(yes)

	var no := _make_btn("Cancel", false)
	no.pressed.connect(_dismiss_confirm)
	hb.add_child(no)

	return panel


# ══════════════════════════════════════════════════════════════════════════════
# OPEN / CLOSE
# ══════════════════════════════════════════════════════════════════════════════

func open() -> void:
	# Capture game-world screenshot before menu appears
	_screenshot = get_viewport().get_texture().get_image()

	_confirm_panel.visible = false
	_pending_action = ""
	_load_game_btn.disabled = not SaveSystem.has_save()
	visible = true
	get_tree().paused = true
	if _menu_music and not _menu_music.is_playing():
		_menu_music.play()


func close() -> void:
	visible = false
	_confirm_panel.visible = false
	_pending_action = ""
	get_tree().paused = false
	if _menu_music:
		_menu_music.stop()


# ══════════════════════════════════════════════════════════════════════════════
# BUTTON HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_save_pressed() -> void:
	var player  := get_tree().get_first_node_in_group("player")
	var terrain := get_tree().get_first_node_in_group("terrain")
	if not player:
		return

	var payload: Dictionary = {}
	if player.has_method("build_player_save"):
		payload.merge(player.build_player_save())
	if terrain and terrain.has_method("build_world_save"):
		payload.merge(terrain.build_world_save())

	SaveSystem.save_game(payload)

	# Save screenshot captured in open()
	if _screenshot:
		SaveSystem.save_screenshot(_screenshot)

	_show_toast("Game Saved!")


func _on_load_game_pressed() -> void:
	_load_game_menu.open()


func _on_load_continue() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_load_new_world() -> void:
	SaveSystem.clear_world_only()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_main_pressed() -> void:
	_show_confirm(
		"quit_to_main",
		"Quit to Main Menu?",
		"Unsaved progress will be lost."
	)


func _on_quit_pressed() -> void:
	_show_confirm(
		"quit",
		"Quit Game?",
		"Unsaved progress since your last save will be lost."
	)


func _on_dev_menu_pressed() -> void:
	close()
	var dev_menu := get_tree().current_scene.get_node_or_null("DevMenu") as CanvasLayer
	if dev_menu and dev_menu.has_method("open"):
		dev_menu.open()


# ══════════════════════════════════════════════════════════════════════════════
# CONFIRM DIALOG
# ══════════════════════════════════════════════════════════════════════════════

func _show_confirm(action: String, title: String, detail: String) -> void:
	_pending_action   = action
	_confirm_label.text  = title
	_confirm_detail.text = detail
	_confirm_panel.visible = true


func _dismiss_confirm() -> void:
	_confirm_panel.visible = false
	_pending_action = ""


func _on_confirm_yes() -> void:
	match _pending_action:
		"quit_to_main":
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		"quit":
			get_tree().quit()
	_pending_action = ""


# ══════════════════════════════════════════════════════════════════════════════
# TOAST
# ══════════════════════════════════════════════════════════════════════════════

func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_timer = 2.5
	var tw := create_tween()
	tw.tween_property(_toast_label, "modulate:a", 1.0, 0.25)


func _hide_toast() -> void:
	var tw := create_tween()
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.4)


# ══════════════════════════════════════════════════════════════════════════════
# STYLE HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _make_btn(txt: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 20)
	var border := Color(0.55, 0.40, 0.15, 0.80) if primary else Color(0.42, 0.30, 0.10, 0.70)
	var bg     := Color(0.14, 0.09, 0.04, 0.90) if primary else Color(0.10, 0.07, 0.03, 0.85)
	btn.add_theme_stylebox_override("normal",  _flat_style(bg,                    border))
	btn.add_theme_stylebox_override("hover",   _flat_style(Color(0.26, 0.16, 0.06, 0.95), Color(0.90, 0.70, 0.25, 1.00)))
	btn.add_theme_stylebox_override("pressed", _flat_style(Color(0.35, 0.22, 0.08, 1.00), Color(1.00, 0.85, 0.40, 1.00)))
	btn.add_theme_color_override("font_color",         Color(0.92, 0.78, 0.50) if primary else Color(0.82, 0.70, 0.45))
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
