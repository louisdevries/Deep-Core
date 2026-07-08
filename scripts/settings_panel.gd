# settings_panel.gd
# Self-contained settings overlay. Add as a child of any CanvasLayer owner,
# then call open() / close().
extends CanvasLayer

signal closed

var _music_slider: HSlider
var _sfx_slider:   HSlider
var _panel_root:   Control


func _ready() -> void:
	layer   = 120
	visible = false
	_build()


func _build() -> void:
	# Full-screen dim
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)

	# CenterContainer fills the viewport and places the panel in the middle
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel_root = PanelContainer.new()
	_panel_root.custom_minimum_size = Vector2(420, 0)
	center.add_child(_panel_root)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.97)
	style.border_color = Color(0.60, 0.44, 0.18, 0.90)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	_panel_root.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	_panel_root.add_child(vbox)

	# Margin inside the panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 20)
	margin.add_child(inner)

	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.55, 0.40, 0.16, 0.5))
	inner.add_child(sep)

	# Music volume
	_music_slider = _add_slider(inner, "Music Volume", SettingsManager.music_volume)
	_music_slider.value_changed.connect(_on_music_changed)

	# SFX volume
	_sfx_slider = _add_slider(inner, "SFX Volume", SettingsManager.sfx_volume)
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	# Separator
	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.55, 0.40, 0.16, 0.5))
	inner.add_child(sep2)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(close)
	inner.add_child(close_btn)


func _add_slider(parent: VBoxContainer, label_text: String, initial: float) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var hbox := HBoxContainer.new()
	row.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var pct := Label.new()
	pct.text = "%d%%" % int(initial * 100)
	pct.add_theme_font_size_override("font_size", 18)
	pct.add_theme_color_override("font_color", Color(0.70, 0.60, 0.38))
	pct.custom_minimum_size.x = 48
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(pct)

	var slider := HSlider.new()
	slider.min_value      = 0.0
	slider.max_value      = 1.0
	slider.step           = 0.01
	slider.value          = initial
	slider.custom_minimum_size.x = 360
	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(v * 100)
	)
	row.add_child(slider)

	return slider


func open() -> void:
	_music_slider.value = SettingsManager.music_volume
	_sfx_slider.value   = SettingsManager.sfx_volume
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_music_changed(v: float) -> void:
	SettingsManager.set_music_volume(v)


func _on_sfx_changed(v: float) -> void:
	SettingsManager.set_sfx_volume(v)
