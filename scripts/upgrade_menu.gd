# upgrade_menu.gd
extends CanvasLayer

const UpgradeData = preload("res://scripts/data/upgrade_data.gd")
const ResourceData = preload("res://scripts/data/resource_data.gd")

@onready var tab_container: TabContainer = $Panel/VBox/TabContainer
@onready var player_stats_label: Label = $Panel/VBox/PlayerStats
@onready var close_button: Button = $Panel/VBox/CloseButton

var player: Node = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)


func open(target_player: Node) -> void:

	player = target_player
	visible = true
	get_tree().paused = true
	rebuild_ui()


func close() -> void:

	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:

	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):

		# don't close if pause menu is shown on top
		var pause_menu := get_tree().current_scene.get_node_or_null("PauseMenu") as CanvasLayer
		if pause_menu and pause_menu.visible:
			return

		close()
		get_viewport().set_input_as_handled()


func rebuild_ui() -> void:

	# clear existing upgrade tabs
	for i in range(tab_container.get_child_count()):
		var tab := tab_container.get_child(i)
		for c in tab.get_children():
			c.queue_free()

	_update_player_stats()

	# UPGRADE TABS (existing logic)
	var by_category: Dictionary = {}
	for upgrade_id in UpgradeData.UPGRADES.keys():
		var upgrade: Dictionary = UpgradeData.UPGRADES[upgrade_id]
		var cat: String = upgrade["category"]
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(upgrade_id)

	for i in range(tab_container.get_child_count()):
		var tab_node := tab_container.get_child(i)
		var tab_name := tab_node.name

		# special tabs
		if tab_name == "Inventory":
			_populate_inventory_tab(tab_node)
			continue
		if tab_name == "Storage":
			_populate_storage_tab(tab_node)
			continue

		# upgrade tabs
		if not by_category.has(tab_name):
			continue

		for upgrade_id in by_category[tab_name]:
			var card := _build_card(upgrade_id)
			tab_node.add_child(card)


func _update_player_stats() -> void:

	if not player:
		return

	var line: String = "$" + str(player.money)
	line += "   Cu: " + str(player.resources.get("copper", 0))
	line += "   Fe: " + str(player.resources.get("iron", 0))
	line += "   Cr: " + str(player.resources.get("crystal", 0))

	player_stats_label.text = line


func _build_card(upgrade_id: String) -> Control:

	var upgrade: Dictionary = UpgradeData.UPGRADES[upgrade_id]
	var tiers: Array = upgrade["tiers"]
	var player_var: String = upgrade["player_var"]
	var current_value = player.get(player_var)
	var starting_value = UpgradeData.STARTING_VALUES.get(player_var, 1)
	var increment = UpgradeData.TIER_INCREMENTS.get(player_var, 1)

	# current tier = how many increments above starting value (1-indexed)
	var current_tier: int
	if typeof(current_value) == TYPE_BOOL:
		current_tier = 2 if current_value else 1
	else:
		current_tier = int(round((current_value - starting_value) / float(increment))) + 1
		
	var max_tier: int = tiers.size() + 1   # starting tier is tier 1, then +len tiers

	# build the visual card
	var card := PanelContainer.new()
	var box := VBoxContainer.new()
	card.add_child(box)

	var name_label := Label.new()
	name_label.text = "%s  (Tier %d/%d)" % [upgrade["name"], current_tier, max_tier]
	box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = upgrade["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc_label)

	# button
	var btn := Button.new()

	if current_tier > tiers.size():
		btn.text = "MAXED"
		btn.disabled = true
	else:

		# next tier data (current_tier is 1-indexed, tiers array is 0-indexed)
		var next_data: Dictionary = tiers[current_tier - 1]
		var cost_text: String = "$" + str(next_data["money"])

		for r in next_data["resources"]:
			cost_text += "   " + r.capitalize() + ": " + str(next_data["resources"][r])

		btn.text = "Buy — " + cost_text

		# affordability check
		var affordable: bool = _can_afford(next_data)
		btn.disabled = not affordable

		btn.pressed.connect(_on_buy.bind(upgrade_id))

	box.add_child(btn)

	return card


func _can_afford(tier_data: Dictionary) -> bool:

	if player.money < tier_data["money"]:
		return false

	for r in tier_data["resources"]:
		var needed: int = tier_data["resources"][r]
		var have: int = player.get_total_amount(r)
		if have < needed:
			return false

	return true


func _on_buy(upgrade_id: String) -> void:

	var upgrade: Dictionary = UpgradeData.UPGRADES[upgrade_id]
	var tiers: Array = upgrade["tiers"]
	var player_var: String = upgrade["player_var"]
	var current_value = player.get(player_var)
	var starting_value = UpgradeData.STARTING_VALUES.get(player_var, 1)
	var increment = UpgradeData.TIER_INCREMENTS.get(player_var, 1)

	var current_tier: int
	if typeof(current_value) == TYPE_BOOL:
		current_tier = 2 if current_value else 1
	else:
		current_tier = int(round((current_value - starting_value) / float(increment))) + 1

	if current_tier > tiers.size():
		return   # maxed

	var next_data: Dictionary = tiers[current_tier - 1]

	if not _can_afford(next_data):
		return

	# deduct cost
	player.money -= next_data["money"]
	for r in next_data["resources"]:
		player.consume_material(r, next_data["resources"][r])
		
	# apply upgrade
	var new_value
	if next_data.has("result_value"):
		new_value = next_data["result_value"]
	else:
		new_value = current_value + increment

	player.set(player_var, new_value)

	print("Bought upgrade: ", upgrade_id, " new value: ", new_value)

	

	rebuild_ui()
	
	
func _populate_inventory_tab(tab: Node) -> void:

	for material_id in ResourceData.DISPLAY_ORDER:

		var count: int = 0
		if material_id == "basic_ore":
			count = player.ore
		else:
			count = player.resources.get(material_id, 0)

		if count == 0:
			continue

		var row := _build_inventory_row(material_id, count)
		tab.add_child(row)


func _populate_storage_tab(tab: Node) -> void:

	# header showing storage usage
	var header := Label.new()
	header.text = "Storage: %d / %d" % [player.get_storage_used(), player.max_storage]
	tab.add_child(header)

	# items in storage
	for material_id in ResourceData.DISPLAY_ORDER:
		var count: int = player.storage.get(material_id, 0)
		if count == 0:
			continue

		var row := _build_storage_row(material_id, count)
		tab.add_child(row)


func _build_inventory_row(material_id: String, count: int) -> Control:

	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)

	# color swatch
	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(24, 24)
	hbox.add_child(swatch)

	# name + count
	var name_label := Label.new()
	name_label.text = "%s × %d" % [data.get("display_name", material_id), count]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	# unit value
	var unit_value: int = data.get("value", 0)

	# Sell All button
	var sell_btn := Button.new()
	sell_btn.text = "Sell ($%d)" % (unit_value * count)
	sell_btn.pressed.connect(_on_sell_material.bind(material_id, count))
	hbox.add_child(sell_btn)

	# Store All button
	var store_btn := Button.new()
	store_btn.text = "Store"
	# disable if storage is full
	if not player.can_store(1):
		store_btn.disabled = true
		store_btn.text = "Full"
	store_btn.pressed.connect(_on_store_material.bind(material_id, count))
	hbox.add_child(store_btn)

	return row


func _build_storage_row(material_id: String, count: int) -> Control:

	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(24, 24)
	hbox.add_child(swatch)

	var name_label := Label.new()
	name_label.text = "%s × %d" % [data.get("display_name", material_id), count]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	# Retrieve button (sends to cargo)
	var retrieve_btn := Button.new()
	retrieve_btn.text = "Retrieve"
	retrieve_btn.pressed.connect(_on_retrieve_material.bind(material_id, count))
	hbox.add_child(retrieve_btn)

	return row


func _on_sell_material(material_id: String, amount: int) -> void:
	var earned: int = player.sell_material(material_id, amount)
	print("Sold ", amount, " ", material_id, " for $", earned)
	rebuild_ui()


func _on_store_material(material_id: String, amount: int) -> void:
	var moved: int = player.transfer_to_storage(material_id, amount)
	print("Stored ", moved, " ", material_id)
	rebuild_ui()


func _on_retrieve_material(material_id: String, amount: int) -> void:
	var moved: int = player.transfer_to_cargo(material_id, amount)
	print("Retrieved ", moved, " ", material_id)
	rebuild_ui()
