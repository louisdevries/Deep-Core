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
		close()
		get_viewport().set_input_as_handled()


func rebuild_ui() -> void:

	# clear all tab contents
	for i in range(tab_container.get_child_count()):
		var tab := tab_container.get_child(i)
		for c in tab.get_children():
			c.queue_free()

	# refresh player resource header
	_update_player_stats()

	# group upgrades by category, then create cards
	var by_category: Dictionary = {}

	for upgrade_id in UpgradeData.UPGRADES.keys():

		var upgrade: Dictionary = UpgradeData.UPGRADES[upgrade_id]
		var cat: String = upgrade["category"]

		if not by_category.has(cat):
			by_category[cat] = []

		by_category[cat].append(upgrade_id)

	# populate each tab
	for i in range(tab_container.get_child_count()):

		var tab_node := tab_container.get_child(i)
		var tab_name := tab_node.name

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
	var current_tier: int = int(round((current_value - starting_value) / float(increment))) + 1
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
		if player.resources.get(r, 0) < tier_data["resources"][r]:
			return false

	return true


func _on_buy(upgrade_id: String) -> void:

	var upgrade: Dictionary = UpgradeData.UPGRADES[upgrade_id]
	var tiers: Array = upgrade["tiers"]
	var player_var: String = upgrade["player_var"]
	var current_value = player.get(player_var)
	var starting_value = UpgradeData.STARTING_VALUES.get(player_var, 1)
	var increment = UpgradeData.TIER_INCREMENTS.get(player_var, 1)

	var current_tier: int = int(round((current_value - starting_value) / float(increment))) + 1

	if current_tier > tiers.size():
		return   # maxed

	var next_data: Dictionary = tiers[current_tier - 1]

	if not _can_afford(next_data):
		return

	# deduct cost
	player.money -= next_data["money"]
	for r in next_data["resources"]:
		player.resources[r] -= next_data["resources"][r]

	# apply upgrade
	var new_value = current_value + increment
	player.set(player_var, new_value)

	print("Bought upgrade: ", upgrade_id, " new value: ", new_value)

	rebuild_ui()
