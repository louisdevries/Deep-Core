extends Node

const FurnaceData = preload("res://scripts/data/furnace_data.gd")

var slots: Array = []
var slot_count: int = 1


func _ready() -> void:
	while slots.size() < slot_count:
		slots.append(null)


func load_from_save_data(save: Dictionary) -> void:
	if save.has("furnace"):
		var f: Dictionary = save["furnace"]
		slot_count = f.get("slot_count", 1)
		var raw_slots: Array = f.get("slots", [])
		slots.clear()
		for s in raw_slots:
			slots.append(s)
	else:
		slot_count = 1
		slots = []

	while slots.size() < slot_count:
		slots.append(null)


func save_data() -> Dictionary:
	return {
		"slot_count": slot_count,
		"slots": slots,
	}


func get_slot_remaining(slot_idx: int) -> float:
	if slot_idx < 0 or slot_idx >= slots.size():
		return 0.0
	var slot = slots[slot_idx]
	if slot == null:
		return 0.0
	var recipe: Dictionary = FurnaceData.RECIPES[slot["recipe_id"]]
	var elapsed: float = Time.get_unix_time_from_system() - slot["start_time"]
	return max(0.0, recipe["duration_seconds"] - elapsed)


func is_slot_done(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	if slots[slot_idx] == null:
		return false
	return get_slot_remaining(slot_idx) <= 0.0


func is_slot_empty(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return true
	return slots[slot_idx] == null


# Start a recipe in the first available slot.
# Returns true on success; deducts all inputs (including coal) from player.
func start_recipe(slot_idx: int, recipe_id: String, player: Node) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	if slots[slot_idx] != null:
		return false
	if not FurnaceData.RECIPES.has(recipe_id):
		return false

	var recipe: Dictionary = FurnaceData.RECIPES[recipe_id]

	# Verify player has all inputs (including coal)
	for input_id in recipe["inputs"]:
		var needed: int = recipe["inputs"][input_id]
		var have: int   = player.resources.get(input_id, 0)
		if have < needed:
			return false

	# Deduct all inputs
	for input_id in recipe["inputs"]:
		player.resources[input_id] -= recipe["inputs"][input_id]
	player._recompute_cargo()

	slots[slot_idx] = {
		"recipe_id":  recipe_id,
		"start_time": Time.get_unix_time_from_system(),
	}
	return true


# Collect finished output into player resources.
# Returns true on success.
func collect_slot(slot_idx: int, player: Node) -> bool:
	if not is_slot_done(slot_idx):
		return false

	var slot   = slots[slot_idx]
	var recipe: Dictionary = FurnaceData.RECIPES[slot["recipe_id"]]
	var out_id: String = recipe["output_resource"]

	if not player.resources.has(out_id):
		player.resources[out_id] = 0
	player.resources[out_id] += recipe["output_amount"]

	slots[slot_idx] = null
	return true


func add_slot() -> void:
	slot_count += 1
	slots.append(null)
