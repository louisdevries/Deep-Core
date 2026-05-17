extends TileMapLayer

@export var world_width = 50
@export var world_depth = 200
@export var light_radius := 6

const TILE_SOURCE_ID = 0
const FOG_SOURCE_ID = 1
const FOG_TILE = Vector2i(0, 0)

var noise = FastNoiseLite.new()

var terrain: TileMapLayer
var background_layer: TileMapLayer
var fog_layer: TileMapLayer
var hazard_layer: TileMapLayer
var sonar_revealed: Dictionary = {}

# HAZARD FLOW SIM
var active_hazards: Dictionary = {}    # Vector2i -> true (active set)
var flow_tick_rate: float = 0.25       # seconds per tick (4 Hz)
var flow_tick_timer: float = 0.0
var gas_dissipate_chance: float = 0.002   # per tick per cell - very slow

var cave_zones = []

var sonar_duration := 1.5
var world_seed: int = 0
var cleared_cells: Dictionary = {}   # Vector2i -> true (tiles the player has cleared)


func _process(delta: float) -> void:

	flow_tick_timer += delta

	if flow_tick_timer >= flow_tick_rate:
		flow_tick_timer = 0.0
		tick_hazards()


func _mark_hazard_active(pos: Vector2i) -> void:
	active_hazards[pos] = true


func _wake_neighbors(pos: Vector2i) -> void:

	# wake hazards that might want to flow into this newly-empty cell
	var checks: Array = [
		Vector2i(pos.x, pos.y - 1),    # cell above (lava could fall in? no, but gas wants to rise into it)
		Vector2i(pos.x, pos.y + 1),    # cell below (gas could sink? no, but consistent)
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x + 1, pos.y),
	]

	for c in checks:
		if hazard_layer.get_cell_atlas_coords(c) != Vector2i(-1, -1):
			active_hazards[c] = true
# -------------------------
# INIT
# -------------------------
func _ready():
	randomize()

	# check for saved data first
	var save := SaveSystem.load_game() if SaveSystem.has_save() else {}

	if save.has("world_seed"):
		world_seed = int(save["world_seed"])
	else:
		world_seed = randi()

	seed(world_seed)            # makes randf/randi deterministic
	noise.seed = world_seed

	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.08
	noise.fractal_octaves = 3

	terrain = self
	background_layer = get_tree().get_first_node_in_group("terrain_background")
	fog_layer = get_tree().get_first_node_in_group("terrain_fog")
	hazard_layer = get_tree().get_first_node_in_group("hazards")

	if not hazard_layer:
		push_warning("Hazard layer missing")
	if not fog_layer:
		push_error("Fog layer missing")
	if not background_layer:
		push_warning("Background layer missing")

	generate_cave_zones()
	generate_world()
	fill_fog()
	carve_caves()

	# now apply saved overrides (player-cleared cells, current hazard positions)
	if not save.is_empty():
		_apply_world_save(save)


# -------------------------
# WORLD GENERATION
# -------------------------
func generate_world():

	clear()
	if background_layer:
		background_layer.clear()

	for x in range(-world_width, world_width):
		for y in range(0, world_depth):

			var pos := Vector2i(x, y)

			var tile := Vector2i(1, 0)
			var bg := Vector2i(1, 0)

			# surface
			if y < 8:
				tile = Vector2i(0, 0)
				bg = Vector2i(0, 0)

			# dirt
			elif y < 25:
				tile = Vector2i(1, 0)
				bg = Vector2i(1, 0)

				if randf() < 0.03:
					tile = Vector2i(4, 0)

			# stone
			elif y < 60:
				tile = Vector2i(2, 0)
				bg = Vector2i(2, 0)

			# deep stone
			else:
				tile = Vector2i(3, 0)
				bg = Vector2i(3, 0)
			
			set_cell(pos, TILE_SOURCE_ID, tile)
			
			if background_layer:
				background_layer.set_cell(pos, TILE_SOURCE_ID, bg)


# -------------------------
# FOG INIT (FULL COVER)
# -------------------------
func fill_fog():

	if not fog_layer:
		return

	for x in range(-world_width, world_width):
		for y in range(0, world_depth):
			fog_layer.set_cell(Vector2i(x, y), FOG_SOURCE_ID, FOG_TILE)


# -------------------------
# FOG UPDATE (CALL FROM PLAYER)
# -------------------------
func update_fog(player_global_pos: Vector2):

	if not fog_layer:
		return

	var player_tile := world_to_tile(player_global_pos)
	var now := Time.get_ticks_msec()

	# full fog reset
	fill_fog()

	# clear fog around the player (light radius)
	for x in range(player_tile.x - light_radius, player_tile.x + light_radius + 1):
		for y in range(player_tile.y - light_radius, player_tile.y + light_radius + 1):

			var target := Vector2i(x, y)

			if player_tile.distance_to(target) > light_radius:
				continue

			if not has_line_of_sight(player_tile, target):
				continue

			fog_layer.set_cell(target, -1)

	# also clear fog on any tiles the sonar is currently revealing
	var expired: Array = []

	for tile_pos in sonar_revealed.keys():
		if now >= sonar_revealed[tile_pos]:
			expired.append(tile_pos)
		else:
			fog_layer.set_cell(tile_pos, -1)

	for tile_pos in expired:
		sonar_revealed.erase(tile_pos)
# -------------------------
# TILE CONVERSION (CRITICAL FIX)
# -------------------------
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return terrain.local_to_map(terrain.to_local(world_pos))


# -------------------------
# CAVES (UNCHANGED LOGIC, FIXED SAFETY)
# -------------------------
func carve_caves():

	if not hazard_layer:
		return

	for zone in cave_zones:

		var center: Vector2 = zone["pos"]
		var radius: int = zone["radius"]
		var hazard: String = zone["hazard"]

		# collect cells inside the cave (rough disc)
		var cave_cells: Array = []

		for x in range(center.x - radius, center.x + radius + 1):
			for y in range(center.y - radius, center.y + radius + 1):

				var pos := Vector2i(x, y)

				if center.distance_to(Vector2(x, y)) > radius:
					continue

				# clear terrain (carve the cave)
				set_cell(pos, -1)
				cave_cells.append(pos)

		# now fill with hazard
		if hazard == "lava":
			# lava settles at the BOTTOM of the cave (bottom 40%)
			var max_y: int = -10000
			for c in cave_cells:
				if c.y > max_y:
					max_y = c.y

			var lava_threshold: int = max_y - int(radius * 0.4)

			for c in cave_cells:
				if c.y >= lava_threshold:
					hazard_layer.set_cell(c, TILE_SOURCE_ID, Vector2i(8, 0))
					_mark_hazard_active(c)

		elif hazard == "gas":
			# gas fills the WHOLE cave volume
			for c in cave_cells:
				hazard_layer.set_cell(c, TILE_SOURCE_ID, Vector2i(9, 0))
				_mark_hazard_active(c)

# -------------------------
# CAVE ZONES
# -------------------------
func generate_cave_zones():

	cave_zones.clear()

	var zone_count = 30

	for i in range(zone_count):

		var x: int = randi_range(-world_width, world_width)
		var y: int = randi_range(35, world_depth)

		# pick hazard based on depth
		# shallow caves: empty or gas
		# deep caves: gas or lava
		var hazard: String = "none"
		var depth_factor: float = clamp((y - 35) / 165.0, 0.0, 1.0)

		var roll: float = randf()

		if depth_factor < 0.3:
			# shallow - mostly empty, occasional gas
			if roll < 0.35:
				hazard = "gas"
		elif depth_factor < 0.7:
			# mid - mix of gas and the first lava
			if roll < 0.4:
				hazard = "gas"
			elif roll < 0.55:
				hazard = "lava"
		else:
			# deep - lava heavy
			if roll < 0.3:
				hazard = "gas"
			elif roll < 0.75:
				hazard = "lava"

		cave_zones.append({
			"pos": Vector2(x, y),
			"radius": randi_range(5, 11),
			"hazard": hazard
		})


func has_line_of_sight(from_tile: Vector2i, to_tile: Vector2i) -> bool:

	var steps: int = max(
		abs(to_tile.x - from_tile.x),
		abs(to_tile.y - from_tile.y)
	)

	if steps == 0:
		return true

	for i in range(steps):

		var t: float = float(i) / float(steps)

		var check: Vector2i = Vector2i(
			int(round(lerp(from_tile.x, to_tile.x, t))),
			int(round(lerp(from_tile.y, to_tile.y, t)))
		)

		# if there's a solid tile → light is blocked
		if get_cell_atlas_coords(check) != Vector2i(-1, -1):
			return false

	return true
	
func sonar_reveal_ring(center_tile: Vector2i, inner_radius: float, outer_radius: float, duration_sec: float) -> void:

	var expiry := Time.get_ticks_msec() + int(duration_sec * 1000.0)
	var r_int: int = int(ceil(outer_radius))

	for x in range(center_tile.x - r_int, center_tile.x + r_int + 1):
		for y in range(center_tile.y - r_int, center_tile.y + r_int + 1):

			var pos := Vector2i(x, y)
			var dist := center_tile.distance_to(pos)

			# only stamp tiles in the ring band
			if dist < inner_radius or dist > outer_radius:
				continue

			sonar_revealed[pos] = expiry

func tick_hazards() -> void:
	const MAX_PER_TICK := 400

	if not hazard_layer:
		return

	if active_hazards.is_empty():
		return

	# snapshot so we can modify the dict while iterating
	var to_process: Array = active_hazards.keys()
	var still_active: Dictionary = {}
	
	if to_process.size() > MAX_PER_TICK:
		to_process.shuffle()
		to_process = to_process.slice(0, MAX_PER_TICK)
		
	for pos in to_process:

		var tile: Vector2i = hazard_layer.get_cell_atlas_coords(pos)

		if tile == Vector2i(-1, -1):
			continue   # cell was already cleared

		var moved: bool = false

		if tile == Vector2i(8, 0):
			moved = _flow_lava(pos)

		elif tile == Vector2i(9, 0):
			# small chance to dissipate
			if randf() < gas_dissipate_chance:
				hazard_layer.set_cell(pos, -1)
				_wake_neighbors(pos)
				continue
			moved = _flow_gas(pos)

		# if it moved, both the source and destination need another tick
		# if it didn't move, it goes dormant
		if moved:
			still_active[pos] = true   # something happened, re-check next tick

	active_hazards = still_active


# -------- LAVA: tries to fall, then spread sideways --------
func _flow_lava(pos: Vector2i) -> bool:

	var below: Vector2i = Vector2i(pos.x, pos.y + 1)

	if _is_empty(below):
		_move_hazard(pos, below, Vector2i(8, 0))
		return true

	# can't fall - try to spread sideways (only if blocked below)
	var left: Vector2i = Vector2i(pos.x - 1, pos.y)
	var right: Vector2i = Vector2i(pos.x + 1, pos.y)

	# prefer the side that has emptiness underneath (real flow)
	var candidates: Array = []
	if _is_empty(left) and _is_empty(Vector2i(left.x, left.y + 1)):
		candidates.append(left)
	if _is_empty(right) and _is_empty(Vector2i(right.x, right.y + 1)):
		candidates.append(right)

	# fallback: any empty side
	if candidates.is_empty():
		if _is_empty(left):
			candidates.append(left)
		if _is_empty(right):
			candidates.append(right)

	if candidates.is_empty():
		return false

	var target: Vector2i = candidates[randi() % candidates.size()]
	_move_hazard(pos, target, Vector2i(8, 0))
	return true


# -------- GAS: drifts up and sideways, fills volume --------
func _flow_gas(pos: Vector2i) -> bool:

	# gas spreads to all empty neighbors (volume-fill) rather than moves
	# this models "gas wants to occupy any empty space it touches"
	var neighbors: Array = [
		Vector2i(pos.x, pos.y - 1),    # up (preferred)
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
	]

	var spread: bool = false

	for n in neighbors:
		if _is_empty(n):
			hazard_layer.set_cell(n, TILE_SOURCE_ID, Vector2i(9, 0))
			active_hazards[n] = true
			spread = true

	return spread


# -------- HELPERS --------
func _is_empty(pos: Vector2i) -> bool:

	# empty means: no solid terrain AND no hazard
	if get_cell_atlas_coords(pos) != Vector2i(-1, -1):
		return false

	if hazard_layer and hazard_layer.get_cell_atlas_coords(pos) != Vector2i(-1, -1):
		return false

	return true


func _move_hazard(from: Vector2i, to: Vector2i, tile: Vector2i) -> void:

	hazard_layer.set_cell(from, -1)
	hazard_layer.set_cell(to, TILE_SOURCE_ID, tile)

	active_hazards[to] = true

	# the now-empty source cell might let other hazards flow into it
	_wake_neighbors(from)


func _apply_world_save(save: Dictionary) -> void:

	# restore player-cleared terrain cells
	if save.has("cleared_cells"):
		for cell_str in save["cleared_cells"]:
			var parts: PackedStringArray = cell_str.split(",")
			if parts.size() != 2:
				continue
			var pos := Vector2i(int(parts[0]), int(parts[1]))
			set_cell(pos, -1)
			cleared_cells[pos] = true

	# restore hazards (overwrite generated ones with saved state)
	if save.has("hazards") and hazard_layer:
		hazard_layer.clear()
		active_hazards.clear()

		for h in save["hazards"]:
			var pos := Vector2i(int(h["x"]), int(h["y"]))
			var tile := Vector2i(int(h["tx"]), int(h["ty"]))
			hazard_layer.set_cell(pos, TILE_SOURCE_ID, tile)
			active_hazards[pos] = true
		
			
func mark_cleared(pos: Vector2i) -> void:
	cleared_cells[pos] = true
	
	
func build_world_save() -> Dictionary:

	var cleared: Array = []
	for pos in cleared_cells.keys():
		cleared.append(str(pos.x) + "," + str(pos.y))

	var hazards: Array = []
	if hazard_layer:
		# enumerate every used hazard cell
		for cell in hazard_layer.get_used_cells():
			var tile: Vector2i = hazard_layer.get_cell_atlas_coords(cell)
			hazards.append({
				"x": cell.x,
				"y": cell.y,
				"tx": tile.x,
				"ty": tile.y
			})

	return {
		"world_seed": world_seed,
		"cleared_cells": cleared,
		"hazards": hazards
	}
