extends CanvasLayer

const FurnaceData = preload("res://scripts/data/furnace_data.gd")
const ResourceData = preload("res://scripts/data/resource_data.gd")

# cost to upgrade: index 0 = level 1→2, index 1 = level 2→3
const UPGRADE_COSTS = [
	{ "money": 500,  "resources": { "iron": 8,  "coal": 5 } },
	{ "money": 2000, "resources": { "iron": 15, "copper": 10, "silver": 5 } },
]

@onready var upgrade_btn: Button = $Panel/VBox/HeaderHBox/UpgradeButton
@onready var recipe_list: VBoxContainer = $Panel/VBox/Content/RecipeCol/Scroll/RecipeList
@onready var slots_container: VBoxContainer = $Panel/VBox/Content/SlotsCol/SlotsContainer
@onready var close_button: Button = $Panel/VBox/CloseButton

var player: Node = null

# parallel arrays tracking live progress UI for each slot
var _slot_bars: Array[ProgressBar] = []
var _slot_labels: Array[Label] = []
# cache of done-state to detect slot completion
var _slot_done_cache: Array[bool] = []


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	upgrade_btn.pressed.connect(_on_upgrade)


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


func _process(_delta: float) -> void:
	if not visible or not player:
		return

	# detect any slot transitioning to done → rebuild for "Collect" button
	for i in FurnaceSystem.slots.size():
		var is_done := FurnaceSystem.is_slot_done(i)
		if i < _slot_done_cache.size() and is_done and not _slot_done_cache[i]:
			rebuild()
			return

	# update live progress bars
	for i in range(mini(_slot_bars.size(), FurnaceSystem.slots.size())):
		if FurnaceSystem.is_slot_empty(i) or FurnaceSystem.is_slot_done(i):
			continue
		var pb: ProgressBar = _slot_bars[i]
		var lbl: Label = _slot_labels[i]
		if not is_instance_valid(pb) or not is_instance_valid(lbl):
			continue
		var slot = FurnaceSystem.slots[i]
		if slot == null:
			continue
		var recipe: Dictionary = FurnaceData.RECIPES[slot["recipe_id"]]
		var remaining: float = FurnaceSystem.get_slot_remaining(i)
		var duration: float = recipe["duration_seconds"]
		pb.value = (1.0 - remaining / duration) * 100.0
		lbl.text = "%ds remaining" % int(ceil(remaining))


func rebuild() -> void:
	_slot_bars.clear()
	_slot_labels.clear()
	_slot_done_cache.clear()

	# snapshot done-states for transition detection
	for i in FurnaceSystem.slots.size():
		_slot_done_cache.append(FurnaceSystem.is_slot_done(i))

	# upgrade button
	var level: int = player.furnace_level
	if level < 3:
		var cost: Dictionary = UPGRADE_COSTS[level - 1]
		var txt := "Upgrade to Lv%d — $%d" % [level + 1, cost["money"]]
		for r in cost["resources"]:
			txt += "  %s:%d" % [r.capitalize(), cost["resources"][r]]
		upgrade_btn.text = txt
		upgrade_btn.disabled = not _can_afford_upgrade(level)
	else:
		upgrade_btn.text = "MAX LEVEL"
		upgrade_btn.disabled = true

	# recipe list
	for c in recipe_list.get_children():
		recipe_list.remove_child(c)
		c.queue_free()

	var display_order = [
		"copper_bar", "tin_bar", "iron_bar",
		"bronze_bar", "steel_bar", "brass_bar",
		"silver_ingot", "gold_ingot",
		"titanium_ingot", "tungsten_ingot",
		"gunpowder", "uranium_rod",
		"mythril_bar", "adamantine_plate",
	]
	for recipe_id in display_order:
		if FurnaceData.RECIPES.has(recipe_id):
			recipe_list.add_child(_build_recipe_row(recipe_id))

	# slot list
	for c in slots_container.get_children():
		slots_container.remove_child(c)
		c.queue_free()

	for i in FurnaceSystem.slots.size():
		slots_container.add_child(_build_slot_row(i))


func _build_recipe_row(recipe_id: String) -> Control:
	var recipe: Dictionary = FurnaceData.RECIPES[recipe_id]

	var card := PanelContainer.new()
	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = recipe["name"]
	vbox.add_child(name_lbl)

	# input costs with have/need
	var inputs_parts: Array = []
	for r in recipe["inputs"]:
		var have: int = player.resources.get(r, 0)
		var need: int = recipe["inputs"][r]
		inputs_parts.append("%s %d/%d" % [r.capitalize(), have, need])
	var cost_lbl := Label.new()
	cost_lbl.text = "  ".join(inputs_parts)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(cost_lbl)

	# output + duration
	var out_name: String = recipe["output_resource"].replace("_", " ").capitalize()
	var info_lbl := Label.new()
	info_lbl.text = "→ %s ×%d   (%ds)" % [out_name, recipe["output_amount"], recipe["duration_seconds"]]
	info_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(info_lbl)

	var btn := Button.new()
	btn.text = "Smelt"
	btn.disabled = not _can_smelt(recipe_id)
	btn.pressed.connect(_on_smelt.bind(recipe_id))
	vbox.add_child(btn)

	return card


func _build_slot_row(slot_idx: int) -> Control:
	var card := PanelContainer.new()
	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Slot %d" % (slot_idx + 1)
	vbox.add_child(header)

	if FurnaceSystem.is_slot_empty(slot_idx):
		var lbl := Label.new()
		lbl.text = "— empty —"
		vbox.add_child(lbl)
		_slot_bars.append(ProgressBar.new())
		_slot_labels.append(Label.new())

	elif FurnaceSystem.is_slot_done(slot_idx):
		var slot = FurnaceSystem.slots[slot_idx]
		var recipe: Dictionary = FurnaceData.RECIPES[slot["recipe_id"]]
		var out_name: String = recipe["output_resource"].replace("_", " ").capitalize()

		var lbl := Label.new()
		lbl.text = "READY: %s × %d" % [out_name, recipe["output_amount"]]
		vbox.add_child(lbl)

		var btn := Button.new()
		btn.text = "Collect"
		btn.pressed.connect(_on_collect.bind(slot_idx))
		vbox.add_child(btn)

		_slot_bars.append(ProgressBar.new())
		_slot_labels.append(Label.new())

	else:
		var slot = FurnaceSystem.slots[slot_idx]
		var recipe: Dictionary = FurnaceData.RECIPES[slot["recipe_id"]]
		var remaining: float = FurnaceSystem.get_slot_remaining(slot_idx)
		var duration: float = recipe["duration_seconds"]

		var name_lbl := Label.new()
		name_lbl.text = recipe["name"]
		vbox.add_child(name_lbl)

		var pb := ProgressBar.new()
		pb.max_value = 100.0
		pb.value = (1.0 - remaining / duration) * 100.0
		vbox.add_child(pb)

		var time_lbl := Label.new()
		time_lbl.text = "%ds remaining" % int(ceil(remaining))
		vbox.add_child(time_lbl)

		_slot_bars.append(pb)
		_slot_labels.append(time_lbl)

	return card


func _can_smelt(recipe_id: String) -> bool:
	var recipe: Dictionary = FurnaceData.RECIPES[recipe_id]
	for r in recipe["inputs"]:
		if player.resources.get(r, 0) < recipe["inputs"][r]:
			return false
	for i in FurnaceSystem.slots.size():
		if FurnaceSystem.is_slot_empty(i):
			return true
	return false


func _can_afford_upgrade(level: int) -> bool:
	if level >= 3:
		return false
	var cost: Dictionary = UPGRADE_COSTS[level - 1]
	if player.money < cost["money"]:
		return false
	for r in cost["resources"]:
		if player.resources.get(r, 0) < cost["resources"][r]:
			return false
	return true


func _on_smelt(recipe_id: String) -> void:
	for i in FurnaceSystem.slots.size():
		if FurnaceSystem.is_slot_empty(i):
			FurnaceSystem.start_recipe(i, recipe_id, 0, player)
			rebuild()
			return


func _on_collect(slot_idx: int) -> void:
	FurnaceSystem.collect_slot(slot_idx, player)
	rebuild()


func _on_upgrade() -> void:
	var level: int = player.furnace_level
	if not _can_afford_upgrade(level):
		return
	var cost: Dictionary = UPGRADE_COSTS[level - 1]
	player.money -= cost["money"]
	for r in cost["resources"]:
		player.resources[r] -= cost["resources"][r]
	player.furnace_level += 1
	FurnaceSystem.add_slot()
	rebuild()
