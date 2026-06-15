extends Node

const FurnaceData = preload("res://scripts/data/furnace_data.gd")

# slot data lives in save; this caches it
var slots: Array = []
var slot_count: int = 1


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

	# ensure slots array is sized correctly
	while slots.size() < slot_count:
		slots.append(null)


func save_data() -> Dictionary:
	return {
		"slot_count": slot_count,
		"slots": slots
	}


# Returns the time remaining (in seconds) for a slot, or 0 if done/empty
func get_slot_remaining(slot_idx: int) -> float:

	if slot_idx < 0 or slot_idx >= slots.size():
		return 0.0

	var slot = slots[slot_idx]
	if slot == null:
		return 0.0

	var recipe_id: String = slot["recipe_id"]
	var recipe: Dictionary = FurnaceData.RECIPES[recipe_id]

	var elapsed: float = (Time.get_unix_time_from_system() - slot["start_time"])

	# coal speedup
	var coal: int = slot.get("coal_used", 0)
	var speed_mult: float = _get_speed_multiplier(coal)

	var effective_elapsed: float = elapsed * speed_mult
	var duration: float = recipe["duration_seconds"]

	return max(0.0, duration - effective_elapsed)


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


func _get_speed_multiplier(coal_used: int) -> float:
	match coal_used:
		0: return 1.0
		1: return 1.5
		2: return 2.0
		_: return 3.0


# Attempt to start a recipe in a slot
# Returns true on success
func start_recipe(slot_idx: int, recipe_id: String, coal_to_use: int, player: Node) -> bool:

	if slot_idx < 0 or slot_idx >= slots.size():
		return false

	if slots[slot_idx] != null:
		# slot occupied — must collect first
		return false

	if not FurnaceData.RECIPES.has(recipe_id):
		return false

	var recipe: Dictionary = FurnaceData.RECIPES[recipe_id]

	# check player has the materials
	for input_resource in recipe["inputs"]:
		var needed: int = recipe["inputs"][input_resource]
		var have: int = player.resources.get(input_resource, 0)
		if have < needed:
			return false

	# check coal
	if coal_to_use > 0:
		if player.resources.get("coal", 0) < coal_to_use:
			return false

	# deduct materials
	for input_resource in recipe["inputs"]:
		player.resources[input_resource] -= recipe["inputs"][input_resource]

	if coal_to_use > 0:
		player.resources["coal"] -= coal_to_use

	# start the slot
	slots[slot_idx] = {
		"recipe_id": recipe_id,
		"start_time": Time.get_unix_time_from_system(),
		"coal_used": clamp(coal_to_use, 0, 3)
	}

	return true


# Collect the output of a completed slot
# Returns true on success
func collect_slot(slot_idx: int, player: Node) -> bool:

	if not is_slot_done(slot_idx):
		return false

	var slot = slots[slot_idx]
	var recipe: Dictionary = FurnaceData.RECIPES[slot["recipe_id"]]

	var output_resource: String = recipe["output_resource"]
	var output_amount: int = recipe["output_amount"]

	# add to player resources (create bucket if it doesn't exist)
	if not player.resources.has(output_resource):
		player.resources[output_resource] = 0

	player.resources[output_resource] += output_amount

	# clear slot
	slots[slot_idx] = null

	return true


# Buy an additional slot
func add_slot() -> void:
	slot_count += 1
	slots.append(null)
