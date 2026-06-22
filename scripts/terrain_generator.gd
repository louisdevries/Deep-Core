extends TileMapLayer

@export var world_width = 50
@export var world_depth = 200
@export var light_radius := 6

const TILE_SOURCE_ID = 1
const FOG_SOURCE_ID = 1
const FOG_TILE = Vector2i(0, 0)

# ============================
# DEPTH BANDS (define which tiles spawn at what depths)
# ============================

# Each band: { y_min, y_max, base_tile, deposits }
# deposits = array of { tile, chance } - each rolled independently
const DEPTH_BANDS = [
	# Grass — single row of surface only
	{
		"y_min": 0,
		"y_max": 1,
		"base": Vector2i(0, 0),       # grass
		"deposits": []
	},
	# Shallow dirt (now extends from y=1 to y=25)
	{
		"y_min": 1,
		"y_max": 25,
		"base": Vector2i(1, 0),       # dirt
		"deposits": [
			{ "tile": Vector2i(0, 1), "chance": 0.03 },    # basic ore
			{ "tile": Vector2i(3, 1), "chance": 0.02 },    # coal
		]
	},
	# Stone layer
	{
		"y_min": 25,
		"y_max": 60,
		"base": Vector2i(2, 0),       # stone
		"deposits": [
			{ "tile": Vector2i(0, 1), "chance": 0.015 },   # basic ore
			{ "tile": Vector2i(1, 1), "chance": 0.025 },   # copper
			{ "tile": Vector2i(2, 1), "chance": 0.015 },   # tin
			{ "tile": Vector2i(3, 1), "chance": 0.02 },    # coal
			{ "tile": Vector2i(4, 1), "chance": 0.01 },    # sulfur
		]
	},
	# Hard stone layer (metals appear)
	{
		"y_min": 60,
		"y_max": 110,
		"base": Vector2i(3, 0),       # hard stone
		"deposits": [
			{ "tile": Vector2i(1, 1), "chance": 0.015 },   # copper (rarer here)
			{ "tile": Vector2i(0, 2), "chance": 0.025 },   # iron
			{ "tile": Vector2i(1, 2), "chance": 0.01 },    # silver
			{ "tile": Vector2i(2, 2), "chance": 0.015 },   # aluminum
			{ "tile": Vector2i(3, 2), "chance": 0.01 },    # lead
			{ "tile": Vector2i(4, 2), "chance": 0.012 },   # zinc
		]
	},
	# Deep stone (precious and first gems)
	{
		"y_min": 110,
		"y_max": 160,
		"base": Vector2i(4, 0),       # deep stone
		"deposits": [
			{ "tile": Vector2i(0, 2), "chance": 0.015 },   # iron (rarer)
			{ "tile": Vector2i(0, 3), "chance": 0.012 },   # gold
			{ "tile": Vector2i(1, 3), "chance": 0.006 },   # platinum
			{ "tile": Vector2i(2, 3), "chance": 0.008 },   # titanium
			{ "tile": Vector2i(0, 4), "chance": 0.01 },    # crystal
			{ "tile": Vector2i(1, 4), "chance": 0.006 },   # ruby
			{ "tile": Vector2i(2, 4), "chance": 0.005 },   # sapphire
			{ "tile": Vector2i(3, 4), "chance": 0.005 },   # emerald
		]
	},
	# Endgame depth (specials + rarest gems)
	{
		"y_min": 160,
		"y_max": 200,
		"base": Vector2i(4, 0),       # deep stone
		"deposits": [
			{ "tile": Vector2i(2, 3), "chance": 0.01 },    # titanium
			{ "tile": Vector2i(3, 3), "chance": 0.008 },   # tungsten
			{ "tile": Vector2i(0, 4), "chance": 0.005 },   # crystal
			{ "tile": Vector2i(4, 4), "chance": 0.003 },   # diamond
			{ "tile": Vector2i(0, 6), "chance": 0.005 },   # obsidian
			{ "tile": Vector2i(1, 6), "chance": 0.004 },   # uranium
			{ "tile": Vector2i(2, 6), "chance": 0.002 },   # mythril
			{ "tile": Vector2i(3, 6), "chance": 0.001 },   # adamantium
		]
	}
]

# Hazard tile coordinates (centralised - update here when atlas changes)
const HAZARD_LAVA  := Vector2i(0, 5)
const HAZARD_GAS   := Vector2i(1, 5)
const HAZARD_ICE   := Vector2i(2, 5)
const HAZARD_ACID  := Vector2i(3, 5)

var noise = FastNoiseLite.new()

var terrain: TileMapLayer
var background_layer: TileMapLayer
var fog_layer: TileMapLayer
var hazard_layer: TileMapLayer
var sonar_revealed: Dictionary = {}

# HAZARD FLOW SIM
var active_hazards: Dictionary = {}
var flow_tick_rate: float = 0.25
var flow_tick_timer: float = 0.0
var gas_dissipate_chance: float = 0.002

var cave_zones = []
var sonar_duration := 1.5
var world_seed: int = 0
var cleared_cells: Dictionary = {}


func _process(delta: float) -> void:

	flow_tick_timer += delta

	if flow_tick_timer >= flow_tick_rate:
		flow_tick_timer = 0.0
		tick_hazards()


func _mark_hazard_active(pos: Vector2i) -> void:
	active_hazards[pos] = true


func _wake_neighbors(pos: Vector2i) -> void:

	var checks: Array = [
		Vector2i(pos.x, pos.y - 1),
		Vector2i(pos.x, pos.y + 1),
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

	# explicit type annotation to fix the inference error
	var save: Dictionary = {}
	if SaveSystem.has_save():
		save = SaveSystem.load_game()

	if save.has("world_seed"):
		world_seed = int(save["world_seed"])
	else:
		world_seed = randi()

	seed(world_seed)
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
	

	if not save.is_empty():
		_apply_world_save(save)
		
	if save.has("cleared_cells") or save.has("hazards"):
		_apply_world_save(save)
		
	_place_base_foundation()


# -------------------------
# WORLD GENERATION (data-driven)
# -------------------------
func generate_world():

	clear()
	if background_layer:
		background_layer.clear()

	for x in range(-world_width, world_width):
		for y in range(0, world_depth):

			var pos := Vector2i(x, y)
			var band: Dictionary = _get_band_for_depth(y)
			var tile: Vector2i = band["base"]

			# roll each deposit independently
			for deposit in band["deposits"]:
				if randf() < deposit["chance"]:
					tile = deposit["tile"]
					break    # one deposit per tile, first one wins

			set_cell(pos, TILE_SOURCE_ID, tile)

			if background_layer:
				background_layer.set_cell(pos, TILE_SOURCE_ID, band["base"])


func _get_band_for_depth(y: int) -> Dictionary:

	for band in DEPTH_BANDS:
		if y >= band["y_min"] and y < band["y_max"]:
			return band

	# fallback: last band
	return DEPTH_BANDS[-1]


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
# FOG UPDATE
# -------------------------
const SKY_SHAFT_DEPTH := 6
const SKY_BLEED := 3


func update_fog(player_global_pos: Vector2):

	if not fog_layer:
		return

	var player_tile := world_to_tile(player_global_pos)
	var now := Time.get_ticks_msec()

	fill_fog()

	# Sky lighting
	for x in range(-world_width, world_width):
		var y := 0
		var open_tiles := 0
		while y < world_depth:
			if get_cell_atlas_coords(Vector2i(x, y)) == Vector2i(-1, -1):
				if open_tiles < SKY_SHAFT_DEPTH:
					fog_layer.set_cell(Vector2i(x, y), -1)
				open_tiles += 1
				y += 1
			else:
				if open_tiles < SKY_SHAFT_DEPTH:
					for b in range(SKY_BLEED):
						if y + b < world_depth:
							fog_layer.set_cell(Vector2i(x, y + b), -1)
				break

	# Player light radius
	for x in range(player_tile.x - light_radius, player_tile.x + light_radius + 1):
		for y in range(player_tile.y - light_radius, player_tile.y + light_radius + 1):

			var target := Vector2i(x, y)

			if player_tile.distance_to(target) > light_radius:
				continue

			if not has_line_of_sight(player_tile, target):
				continue

			fog_layer.set_cell(target, -1)

	# Sonar reveals
	var expired: Array = []

	for tile_pos in sonar_revealed.keys():
		if now >= sonar_revealed[tile_pos]:
			expired.append(tile_pos)
		else:
			fog_layer.set_cell(tile_pos, -1)

	for tile_pos in expired:
		sonar_revealed.erase(tile_pos)


# -------------------------
# TILE CONVERSION
# -------------------------
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return terrain.local_to_map(terrain.to_local(world_pos))


# -------------------------
# CAVES
# -------------------------
func carve_caves():

	if not hazard_layer:
		return

	for zone in cave_zones:

		var center: Vector2 = zone["pos"]
		var radius: int = zone["radius"]
		var hazard: String = zone["hazard"]

		var cave_cells: Array = []

		for x in range(center.x - radius, center.x + radius + 1):
			for y in range(center.y - radius, center.y + radius + 1):

				var pos := Vector2i(x, y)

				if center.distance_to(Vector2(x, y)) > radius:
					continue

				set_cell(pos, -1)
				cave_cells.append(pos)

		# fill with hazard
		match hazard:

			"lava":
				_fill_cave_bottom(cave_cells, radius, HAZARD_LAVA)

			"acid":
				_fill_cave_bottom(cave_cells, radius, HAZARD_ACID)

			"gas":
				for c in cave_cells:
					hazard_layer.set_cell(c, TILE_SOURCE_ID, HAZARD_GAS)
					_mark_hazard_active(c)

			"ice":
				# ice fills the whole cave (frozen pocket)
				for c in cave_cells:
					hazard_layer.set_cell(c, TILE_SOURCE_ID, HAZARD_ICE)
					# don't mark active - ice doesn't flow


func _fill_cave_bottom(cave_cells: Array, radius: int, hazard_tile: Vector2i) -> void:

	var max_y: int = -10000
	for c in cave_cells:
		if c.y > max_y:
			max_y = c.y

	var threshold: int = max_y - int(radius * 0.4)

	for c in cave_cells:
		if c.y >= threshold:
			hazard_layer.set_cell(c, TILE_SOURCE_ID, hazard_tile)
			_mark_hazard_active(c)


# -------------------------
# CAVE ZONES (depth-aware hazard selection)
# -------------------------
func generate_cave_zones():

	cave_zones.clear()

	var zone_count = 30

	for i in range(zone_count):

		var x: int = randi_range(-world_width, world_width)
		var y: int = randi_range(35, world_depth)

		var hazard: String = _pick_cave_hazard(y)

		cave_zones.append({
			"pos": Vector2(x, y),
			"radius": randi_range(5, 11),
			"hazard": hazard
		})


func _pick_cave_hazard(depth: int) -> String:

	var depth_factor: float = clamp((depth - 35) / 165.0, 0.0, 1.0)
	var roll: float = randf()

	if depth_factor < 0.3:
		# shallow - mostly empty, gas, occasional ice
		if roll < 0.30:
			return "gas"
		elif roll < 0.40:
			return "ice"

	elif depth_factor < 0.7:
		# mid - gas, lava starts appearing, occasional ice and acid
		if roll < 0.30:
			return "gas"
		elif roll < 0.45:
			return "lava"
		elif roll < 0.55:
			return "ice"
		elif roll < 0.60:
			return "acid"

	else:
		# deep - lava heavy, acid more common
		if roll < 0.20:
			return "gas"
		elif roll < 0.55:
			return "lava"
		elif roll < 0.75:
			return "acid"

	return "none"


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

			if dist < inner_radius or dist > outer_radius:
				continue

			sonar_revealed[pos] = expiry


# -------------------------
# HAZARD FLOW
# -------------------------
func tick_hazards() -> void:

	const MAX_PER_TICK := 400

	if not hazard_layer:
		return

	if active_hazards.is_empty():
		return

	var to_process: Array = active_hazards.keys()
	var still_active: Dictionary = {}

	if to_process.size() > MAX_PER_TICK:
		to_process.shuffle()
		to_process = to_process.slice(0, MAX_PER_TICK)

	for pos in to_process:

		var tile: Vector2i = hazard_layer.get_cell_atlas_coords(pos)

		if tile == Vector2i(-1, -1):
			continue

		var moved: bool = false

		match tile:

			HAZARD_LAVA:
				moved = _flow_liquid(pos, HAZARD_LAVA)

			HAZARD_ACID:
				moved = _flow_liquid(pos, HAZARD_ACID)

			HAZARD_GAS:
				if randf() < gas_dissipate_chance:
					hazard_layer.set_cell(pos, -1)
					_wake_neighbors(pos)
					continue
				moved = _flow_gas(pos)

			# ice doesn't flow - never gets added to active_hazards anyway

		if moved:
			still_active[pos] = true

	active_hazards = still_active


# Generic liquid flow (for lava and acid - both behave the same way)
func _flow_liquid(pos: Vector2i, liquid_tile: Vector2i) -> bool:

	var below: Vector2i = Vector2i(pos.x, pos.y + 1)

	if _is_empty(below):
		_move_hazard(pos, below, liquid_tile)
		return true

	var left: Vector2i = Vector2i(pos.x - 1, pos.y)
	var right: Vector2i = Vector2i(pos.x + 1, pos.y)

	var candidates: Array = []
	if _is_empty(left) and _is_empty(Vector2i(left.x, left.y + 1)):
		candidates.append(left)
	if _is_empty(right) and _is_empty(Vector2i(right.x, right.y + 1)):
		candidates.append(right)

	if candidates.is_empty():
		if _is_empty(left):
			candidates.append(left)
		if _is_empty(right):
			candidates.append(right)

	if candidates.is_empty():
		return false

	var target: Vector2i = candidates[randi() % candidates.size()]
	_move_hazard(pos, target, liquid_tile)
	return true


func _flow_gas(pos: Vector2i) -> bool:

	var neighbors: Array = [
		Vector2i(pos.x, pos.y - 1),
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
	]

	var spread: bool = false

	for n in neighbors:
		if _is_empty(n):
			hazard_layer.set_cell(n, TILE_SOURCE_ID, HAZARD_GAS)
			active_hazards[n] = true
			spread = true

	return spread


func _is_empty(pos: Vector2i) -> bool:

	if get_cell_atlas_coords(pos) != Vector2i(-1, -1):
		return false

	if hazard_layer and hazard_layer.get_cell_atlas_coords(pos) != Vector2i(-1, -1):
		return false

	return true


func _move_hazard(from: Vector2i, to: Vector2i, tile: Vector2i) -> void:

	hazard_layer.set_cell(from, -1)
	hazard_layer.set_cell(to, TILE_SOURCE_ID, tile)

	active_hazards[to] = true

	_wake_neighbors(from)


# -------------------------
# SAVE / LOAD
# -------------------------
func _apply_world_save(save: Dictionary) -> void:

	if save.has("cleared_cells"):
		for cell_str in save["cleared_cells"]:
			var parts: PackedStringArray = cell_str.split(",")
			if parts.size() != 2:
				continue
			var pos := Vector2i(int(parts[0]), int(parts[1]))
			set_cell(pos, -1)
			cleared_cells[pos] = true

	if save.has("hazards") and hazard_layer:
		hazard_layer.clear()
		active_hazards.clear()

		for h in save["hazards"]:
			var pos := Vector2i(int(h["x"]), int(h["y"]))
			var tile := Vector2i(int(h["tx"]), int(h["ty"]))
			hazard_layer.set_cell(pos, TILE_SOURCE_ID, tile)

			# only flowing hazards become active again on reload
			if tile == HAZARD_LAVA or tile == HAZARD_GAS or tile == HAZARD_ACID:
				active_hazards[pos] = true


func mark_cleared(pos: Vector2i) -> void:
	# Don't track concrete — it's structural, not drilled terrain
	var existing: Vector2i = get_cell_atlas_coords(pos)
	if existing == Vector2i(4, 6):   # concrete
		return
	cleared_cells[pos] = true


func build_world_save() -> Dictionary:
	var cleared: Array = []
	for pos in cleared_cells.keys():
		cleared.append(str(pos.x) + "," + str(pos.y))

	var hazards: Array = []
	if hazard_layer:
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

func _place_base_foundation() -> void:

	const CONCRETE: Vector2i = Vector2i(4, 6)	
	
	var source: TileSetSource = tile_set.get_source(TILE_SOURCE_ID)
	if source is TileSetAtlasSource:
		var atlas: TileSetAtlasSource = source as TileSetAtlasSource
		print("Concrete tile exists? ", atlas.has_tile(CONCRETE))
		print("Available tiles in atlas:")
		for i in atlas.get_tiles_count():
			print("  ", atlas.get_tile_id(i))

	var foundation_x_start: int = -world_width        # absolute left edge (-50)
	var foundation_x_end: int = -world_width + 16     # 16 tiles wide — fits 5 buildings
	var foundation_y_top: int = 0                     # inline with the grass surface
	var foundation_y_bottom: int = 2                  # 2 tiles deep

	for x in range(foundation_x_start, foundation_x_end):
		for y in range(foundation_y_top, foundation_y_bottom):
			set_cell(Vector2i(x, y), TILE_SOURCE_ID, CONCRETE)

	# Wall on the right edge so the player can't bypass the base from underground
	var wall_x: int = foundation_x_end
	for y in range(foundation_y_top, foundation_y_bottom + 20):
		set_cell(Vector2i(wall_x, y), TILE_SOURCE_ID, CONCRETE)
