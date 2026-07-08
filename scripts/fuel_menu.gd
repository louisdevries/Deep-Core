extends CanvasLayer

@onready var money_label:       Label          = $Panel/VBox/HeaderHBox/MoneyLabel
@onready var fuel_bar:          ProgressBar    = $Panel/VBox/FuelBar
@onready var buttons_container: VBoxContainer  = $Panel/VBox/ButtonsContainer
@onready var close_button:      Button         = $Panel/VBox/CloseButton

const FUEL_PRICE_PER_UNIT: float = 2.0

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

	var title := $Panel.get_node_or_null("VBox/HeaderHBox/TitleLabel") as Label
	if title:
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))

	money_label.add_theme_font_size_override("font_size", 18)
	money_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.42))

	# Style the fuel progress bar (amber fill)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.80, 0.55, 0.12)
	bar_fill.corner_radius_top_left     = 3
	bar_fill.corner_radius_top_right    = 3
	bar_fill.corner_radius_bottom_left  = 3
	bar_fill.corner_radius_bottom_right = 3
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color              = Color(0.10, 0.07, 0.04)
	bar_bg.border_color          = Color(0.45, 0.32, 0.12, 0.70)
	bar_bg.border_width_left     = 1
	bar_bg.border_width_right    = 1
	bar_bg.border_width_top      = 1
	bar_bg.border_width_bottom   = 1
	bar_bg.corner_radius_top_left     = 3
	bar_bg.corner_radius_top_right    = 3
	bar_bg.corner_radius_bottom_left  = 3
	bar_bg.corner_radius_bottom_right = 3
	fuel_bar.add_theme_stylebox_override("fill",       bar_fill)
	fuel_bar.add_theme_stylebox_override("background", bar_bg)

	_style_btn(close_button, false)


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
	money_label.text  = "$" + str(player.money)
	fuel_bar.max_value = player.max_fuel
	fuel_bar.value     = player.fuel

	for c in buttons_container.get_children():
		buttons_container.remove_child(c)
		c.queue_free()

	var fractions   := [0.25, 0.5, 0.75, 1.0]
	var labels_text := ["1/4 Tank", "1/2 Tank", "3/4 Tank", "Full Tank"]

	for i in fractions.size():
		var target_fuel: float = fractions[i] * player.max_fuel
		var amount: float      = maxf(0.0, target_fuel - player.fuel)
		var cost: int          = int(ceil(amount * FUEL_PRICE_PER_UNIT))

		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_style())
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		card.add_child(hbox)

		var info := Label.new()
		info.text = "%s  (+%.0f fuel)  $%d" % [labels_text[i], amount, cost]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 16)
		info.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
		hbox.add_child(info)

		var btn := _make_btn("Buy", true)
		btn.disabled = player.money < cost or amount <= 0.0
		btn.pressed.connect(_on_buy_fuel.bind(target_fuel, cost))
		hbox.add_child(btn)

		buttons_container.add_child(card)


func _on_buy_fuel(target_fuel: float, cost: int) -> void:
	if player.money < cost:
		return
	player.money -= cost
	player.fuel   = minf(player.max_fuel, target_fuel)
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
