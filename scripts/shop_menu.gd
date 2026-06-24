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

# Per-item stock and restock timers (0 = stocked, >0 = counting down to restock)
var _bm_stock: Array[int]         = []
var _bm_item_timers: Array[float] = []

# Rebuild BM display at most once per second while counting down
var _bm_tick: float = 0.0

var player: Node = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)

	_bm_stock.resize(BM_ITEMS.size())
	_bm_item_timers.resize(BM_ITEMS.size())
	for i in BM_ITEMS.size():
		_bm_stock[i]        = BM_ITEMS[i]["max_stock"]
		_bm_item_timers[i]  = 0.0


func _process(delta: float) -> void:
	if not visible:
		return

	var any_active := false
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
	bm_scroll.add_child(bm_list)

	for i in BM_ITEMS.size():
		bm_list.add_child(_build_bm_row(i))


# Light per-second update of countdown labels — avoids full rebuild
func _refresh_bm_timers() -> void:
	var bm_tab  := tab_container.get_node_or_null("BlackMarket")
	if not bm_tab:
		return
	var scroll  := bm_tab.get_child(0) if bm_tab.get_child_count() > 0 else null
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
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(24, 24)
	hbox.add_child(swatch)

	var lbl := Label.new()
	lbl.text = "%s × %d" % [data.get("display_name", material_id), count]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn := Button.new()
	btn.text = "Sell ($%d)" % (unit_value * count)
	btn.pressed.connect(_on_sell_material.bind(material_id, count))
	hbox.add_child(btn)

	return row


func _build_buy_row(item_id: String) -> Control:
	var item: Dictionary = ItemData.ITEMS[item_id]

	var row  := PanelContainer.new()
	var vbox := VBoxContainer.new()
	row.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%s — $%d" % [item["name"], item["cost"]]
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item["description"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	var btn := Button.new()
	btn.text     = "Buy"
	btn.disabled = player.money < item["cost"]
	btn.pressed.connect(_on_buy_item.bind(item_id))
	vbox.add_child(btn)

	return row


func _build_bm_row(idx: int) -> Control:
	var item: Dictionary  = BM_ITEMS[idx]
	var mat_id: String    = item["id"]
	var price: int        = item["price"]
	var stock: int        = _bm_stock[idx]
	var timer_val: float  = _bm_item_timers[idx]

	var res_data: Dictionary = ResourceData.RESOURCES.get(mat_id, {})
	var display: String      = res_data.get("display_name", mat_id)

	var row  := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = res_data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(20, 20)
	hbox.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = display
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	if timer_val > 0.0:
		# Sold out — show per-item restock countdown
		var secs: int      = int(ceil(timer_val))
		var timer_lbl      := Label.new()
		timer_lbl.name     = "TimerLabel"
		timer_lbl.text     = "Restocks in %d:%02d" % [int(secs / 60.0), secs % 60]
		timer_lbl.modulate = Color(1.0, 0.6, 0.3, 1.0)
		hbox.add_child(timer_lbl)
	else:
		# In stock — show count, price, buy button
		var stock_lbl := Label.new()
		stock_lbl.text = "Stock: %d" % stock
		hbox.add_child(stock_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "$%d ea" % price
		hbox.add_child(price_lbl)

		var btn := Button.new()
		btn.text     = "Buy 1"
		btn.disabled = stock <= 0 or player.money < price
		btn.pressed.connect(_on_buy_bm_item.bind(idx))
		hbox.add_child(btn)

	return row


# ── SIGNAL HANDLERS ───────────────────────────────────────────────────────────

func _on_sell_material(material_id: String, count: int) -> void:
	player.sell_material(material_id, count)
	rebuild()


func _on_buy_item(item_id: String) -> void:
	var item: Dictionary = ItemData.ITEMS[item_id]
	if player.money < item["cost"]:
		return

	player.money -= item["cost"]

	if not player.item_inventory.has(item_id):
		player.item_inventory[item_id] = 0
	player.item_inventory[item_id] += 1

	rebuild()


func _on_buy_bm_item(idx: int) -> void:
	var item: Dictionary = BM_ITEMS[idx]
	var price: int       = item["price"]
	var mat_id: String   = item["id"]

	if _bm_stock[idx] <= 0 or player.money < price:
		return

	player.money          -= price
	_bm_stock[idx]        -= 1

	if not player.resources.has(mat_id):
		player.resources[mat_id] = 0
	player.resources[mat_id] += 1
	player._recompute_cargo()

	# Only start the per-item restock timer when this item's stock hits zero
	if _bm_stock[idx] <= 0:
		_bm_item_timers[idx] = BM_REFRESH_TIME

	rebuild()
