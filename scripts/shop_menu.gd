extends CanvasLayer

const ItemData     = preload("res://scripts/data/item_data.gd")
const ResourceData = preload("res://scripts/data/resource_data.gd")

@onready var tab_container: TabContainer = $Panel/VBox/TabContainer
@onready var money_label:   Label        = $Panel/VBox/HeaderHBox/MoneyLabel
@onready var close_button:  Button       = $Panel/VBox/CloseButton

# ── BLACK MARKET ──────────────────────────────────────────────────────────────
const BM_REFRESH_TIME: float = 300.0

const BM_ITEMS: Array = [
	{ "id": "copper",   "price": 60,   "max_stock": 5 },
	{ "id": "tin",      "price": 60,   "max_stock": 5 },
	{ "id": "coal",     "price": 50,   "max_stock": 8 },
	{ "id": "sulfur",   "price": 55,   "max_stock": 5 },
	{ "id": "iron",     "price": 120,  "max_stock": 4 },
	{ "id": "silver",   "price": 200,  "max_stock": 3 },
	{ "id": "titanium", "price": 800,  "max_stock": 2 },
	{ "id": "tungsten", "price": 600,  "max_stock": 2 },
	{ "id": "diamond",  "price": 3000, "max_stock": 1 },
	{ "id": "crystal",  "price": 400,  "max_stock": 3 },
	{ "id": "uranium",  "price": 2000, "max_stock": 1 },
	{ "id": "mythril",  "price": 5000, "max_stock": 1 },
]

var _bm_stock:       Array[int]   = []
var _bm_item_timers: Array[float] = []
var _bm_tick:        float        = 0.0

var player:   Node              = null
var _buy_sfx: AudioStreamPlayer = null
var _sell_sfx: AudioStreamPlayer = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)

	_buy_sfx = AudioStreamPlayer.new()
	_buy_sfx.stream = load("res://assets/Audio/SFX/Buy.wav")
	_buy_sfx.bus = "SFX"
	add_child(_buy_sfx)

	_sell_sfx = AudioStreamPlayer.new()
	_sell_sfx.stream = load("res://assets/Audio/SFX/Sell.wav")
	_sell_sfx.bus = "SFX"
	add_child(_sell_sfx)

	_bm_stock.resize(BM_ITEMS.size())
	_bm_item_timers.resize(BM_ITEMS.size())
	for i in BM_ITEMS.size():
		_bm_stock[i]       = BM_ITEMS[i]["max_stock"]
		_bm_item_timers[i] = 0.0

	_apply_theme()


func _apply_theme() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	add_child(backdrop)
	move_child(backdrop, 0)

	$Panel.add_theme_stylebox_override("panel", _panel_style())
	$Panel/VBox.add_theme_constant_override("separation", 8)

	var title := $Panel.get_node_or_null("VBox/HeaderHBox/TitleLabel") as Label
	if title:
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	money_label.add_theme_font_size_override("font_size", 18)
	money_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.42))

	# Tab bar colours
	tab_container.add_theme_color_override("font_selected_color",   Color(0.95, 0.78, 0.30))
	tab_container.add_theme_color_override("font_unselected_color", Color(0.60, 0.50, 0.32))
	var tab_panel_sty := StyleBoxFlat.new()
	tab_panel_sty.bg_color              = Color(0.10, 0.07, 0.04, 0.90)
	tab_panel_sty.border_color          = Color(0.45, 0.32, 0.12, 0.50)
	tab_panel_sty.border_width_left     = 1
	tab_panel_sty.border_width_right    = 1
	tab_panel_sty.border_width_top      = 1
	tab_panel_sty.border_width_bottom   = 1
	tab_container.add_theme_stylebox_override("panel", tab_panel_sty)

	_style_btn(close_button, false)


func _process(delta: float) -> void:
	if not visible:
		return

	var any_active    := false
	var any_restocked := false

	for i in BM_ITEMS.size():
		if _bm_item_timers[i] <= 0.0:
			continue
		any_active = true
		_bm_item_timers[i] -= delta
		if _bm_item_timers[i] <= 0.0:
			_bm_item_timers[i] = 0.0
			_bm_stock[i]       = BM_ITEMS[i]["max_stock"]
			any_restocked      = true

	if any_restocked:
		rebuild()
		_bm_tick = 0.0
	elif any_active:
		_bm_tick -= delta
		if _bm_tick <= 0.0:
			_bm_tick = 1.0
			_refresh_bm_timers()


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
	var sell_tab := tab_container.get_node("Sell")
	var buy_tab  := tab_container.get_node("Buy")
	var bm_tab   := tab_container.get_node("BlackMarket")

	for tab in [sell_tab, buy_tab, bm_tab]:
		for c in tab.get_children():
			tab.remove_child(c)
			c.queue_free()

	money_label.text = "$" + str(player.money)

	# ── SELL TAB ──────────────────────────────────────────────────────────────
	var sell_scroll := ScrollContainer.new()
	sell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_tab.add_child(sell_scroll)
	var sell_list := VBoxContainer.new()
	sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_list.add_theme_constant_override("separation", 4)
	sell_scroll.add_child(sell_list)

	for material_id in ResourceData.DISPLAY_ORDER:
		var count: int = player.ore if material_id == "basic_ore" else player.resources.get(material_id, 0)
		if count == 0:
			continue
		sell_list.add_child(_build_sell_row(material_id, count))

	# ── BUY TAB ───────────────────────────────────────────────────────────────
	var buy_scroll := ScrollContainer.new()
	buy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buy_tab.add_child(buy_scroll)
	var buy_list := VBoxContainer.new()
	buy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_list.add_theme_constant_override("separation", 4)
	buy_scroll.add_child(buy_list)

	for item_id in ItemData.SHOP_ORDER:
		buy_list.add_child(_build_buy_row(item_id))

	# ── BLACK MARKET TAB ──────────────────────────────────────────────────────
	var bm_scroll := ScrollContainer.new()
	bm_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm_tab.add_child(bm_scroll)
	var bm_list := VBoxContainer.new()
	bm_list.name = "BmList"
	bm_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bm_list.add_theme_constant_override("separation", 4)
	bm_scroll.add_child(bm_list)

	for i in BM_ITEMS.size():
		bm_list.add_child(_build_bm_row(i))


func _refresh_bm_timers() -> void:
	var bm_tab := tab_container.get_node_or_null("BlackMarket")
	if not bm_tab:
		return
	var scroll := bm_tab.get_child(0) if bm_tab.get_child_count() > 0 else null
	if not scroll:
		return
	var bm_list := scroll.get_node_or_null("BmList")
	if not bm_list:
		return

	for i in bm_list.get_child_count():
		if i >= BM_ITEMS.size():
			break
		if _bm_item_timers[i] <= 0.0:
			continue
		var row       := bm_list.get_child(i)
		var timer_lbl := row.find_child("TimerLabel", true, false) as Label
		if not timer_lbl:
			continue
		var secs: int = int(ceil(_bm_item_timers[i]))
		timer_lbl.text = "Restocks in %d:%02d" % [int(secs / 60.0), secs % 60]


# ── ROW BUILDERS ──────────────────────────────────────────────────────────────

func _build_sell_row(material_id: String, count: int) -> Control:
	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	var unit_value: int  = data.get("value", 0)

	var row  := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(20, 20)
	hbox.add_child(swatch)

	var lbl := Label.new()
	lbl.text = "%s × %d" % [data.get("display_name", material_id), count]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
	hbox.add_child(lbl)

	var btn := _make_btn("Sell ($%d)" % (unit_value * count), true)
	btn.pressed.connect(_on_sell_material.bind(material_id, count))
	hbox.add_child(btn)

	return row


func _build_buy_row(item_id: String) -> Control:
	var item: Dictionary = ItemData.ITEMS[item_id]

	var row  := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%s — $%d" % [item["name"], item["cost"]]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.80, 0.52))
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item["description"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.62, 0.52, 0.36))
	vbox.add_child(desc_lbl)

	var btn := _make_btn("Buy", true)
	btn.disabled = player.money < item["cost"]
	btn.pressed.connect(_on_buy_item.bind(item_id))
	vbox.add_child(btn)

	return row


func _build_bm_row(idx: int) -> Control:
	var item: Dictionary     = BM_ITEMS[idx]
	var mat_id: String       = item["id"]
	var price: int           = item["price"]
	var stock: int           = _bm_stock[idx]
	var timer_val: float     = _bm_item_timers[idx]
	var res_data: Dictionary = ResourceData.RESOURCES.get(mat_id, {})
	var display: String      = res_data.get("display_name", mat_id)

	var row  := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = res_data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(18, 18)
	hbox.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = display
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
	hbox.add_child(name_lbl)

	if timer_val > 0.0:
		var secs: int  = int(ceil(timer_val))
		var timer_lbl  := Label.new()
		timer_lbl.name = "TimerLabel"
		timer_lbl.text = "Restocks in %d:%02d" % [int(secs / 60.0), secs % 60]
		timer_lbl.add_theme_font_size_override("font_size", 13)
		timer_lbl.add_theme_color_override("font_color", Color(0.90, 0.62, 0.28))
		hbox.add_child(timer_lbl)
	else:
		var stock_lbl := Label.new()
		stock_lbl.text = "Stock: %d" % stock
		stock_lbl.add_theme_font_size_override("font_size", 13)
		stock_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.38))
		hbox.add_child(stock_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "$%d ea" % price
		price_lbl.add_theme_font_size_override("font_size", 13)
		price_lbl.add_theme_color_override("font_color", Color(0.78, 0.90, 0.42))
		hbox.add_child(price_lbl)

		var btn := _make_btn("Buy 1", true)
		btn.disabled = stock <= 0 or player.money < price
		btn.pressed.connect(_on_buy_bm_item.bind(idx))
		hbox.add_child(btn)

	return row


# ── SIGNAL HANDLERS ───────────────────────────────────────────────────────────

func _on_sell_material(material_id: String, count: int) -> void:
	player.sell_material(material_id, count)
	if _sell_sfx:
		_sell_sfx.play()
	rebuild()


func _on_buy_item(item_id: String) -> void:
	var item: Dictionary = ItemData.ITEMS[item_id]
	if player.money < item["cost"]:
		return
	player.money -= item["cost"]
	if not player.item_inventory.has(item_id):
		player.item_inventory[item_id] = 0
	player.item_inventory[item_id] += 1
	if _buy_sfx:
		_buy_sfx.play()
	rebuild()


func _on_buy_bm_item(idx: int) -> void:
	var item: Dictionary = BM_ITEMS[idx]
	var price: int       = item["price"]
	var mat_id: String   = item["id"]

	if _bm_stock[idx] <= 0 or player.money < price:
		return

	player.money   -= price
	_bm_stock[idx] -= 1

	if not player.resources.has(mat_id):
		player.resources[mat_id] = 0
	player.resources[mat_id] += 1
	player._recompute_cargo()

	if _bm_stock[idx] <= 0:
		_bm_item_timers[idx] = BM_REFRESH_TIME

	if _buy_sfx:
		_buy_sfx.play()
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
