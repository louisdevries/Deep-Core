extends CanvasLayer

const ShopData = preload("res://scripts/data/shop_data.gd")
const ResourceData = preload("res://scripts/data/resource_data.gd")

@onready var tab_container: TabContainer = $Panel/VBox/TabContainer
@onready var money_label: Label = $Panel/VBox/HeaderHBox/MoneyLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

var player: Node = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)


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

	# remove_child first so nodes leave the tree immediately, then free memory
	var sell_tab := tab_container.get_node("Sell")
	var buy_tab  := tab_container.get_node("Buy")

	for c in sell_tab.get_children():
		sell_tab.remove_child(c)
		c.queue_free()
	for c in buy_tab.get_children():
		buy_tab.remove_child(c)
		c.queue_free()

	money_label.text = "$" + str(player.money)

	# SELL TAB
	for material_id in ResourceData.DISPLAY_ORDER:
		var count: int = 0
		if material_id == "basic_ore":
			count = player.ore
		else:
			count = player.resources.get(material_id, 0)
		if count == 0:
			continue
		sell_tab.add_child(_build_sell_row(material_id, count))

	# BUY TAB
	for item_id in ShopData.DISPLAY_ORDER:
		buy_tab.add_child(_build_buy_row(item_id))


func _build_sell_row(material_id: String, count: int) -> Control:

	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	var unit_value: int = data.get("value", 0)

	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(24, 24)
	hbox.add_child(swatch)

	var label := Label.new()
	label.text = "%s × %d" % [data.get("display_name", material_id), count]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var btn := Button.new()
	btn.text = "Sell ($%d)" % (unit_value * count)
	btn.pressed.connect(_on_sell_material.bind(material_id, count))
	hbox.add_child(btn)

	return row


func _build_buy_row(item_id: String) -> Control:

	var item: Dictionary = ShopData.CONSUMABLES[item_id]

	var row := PanelContainer.new()
	var vbox := VBoxContainer.new()
	row.add_child(vbox)

	var name_label := Label.new()
	name_label.text = "%s — $%d" % [item["name"], item["cost"]]
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = item["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	var btn := Button.new()
	btn.text = "Buy"
	btn.disabled = player.money < item["cost"]
	btn.pressed.connect(_on_buy_item.bind(item_id))
	vbox.add_child(btn)

	return row


func _on_sell_material(material_id: String, count: int) -> void:
	var earned: int = player.sell_material(material_id, count)
	print("Sold ", count, " ", material_id, " for $", earned)
	rebuild()


func _on_buy_item(item_id: String) -> void:

	var item: Dictionary = ShopData.CONSUMABLES[item_id]
	if player.money < item["cost"]:
		return

	player.money -= item["cost"]

	match item["effect_type"]:
		"health":
			player.health = min(player.max_health, player.health + item["effect_amount"])
		"sonar_reset":
			player.sonar_cooldown_timer = 0.0

	print("Bought ", item_id)
	rebuild()
