extends TileMapLayer

@export var world_width = 50
@export var world_depth = 200
@export var light_radius := 6

const TILE_SOURCE_ID = 1
const FOG_SOURCE_ID = 0
const FOG_TILE = Vector2i(0, 0)

var noise = FastNoiseLite.new()

var terrain: TileMapLayer
var background_layer: TileMapLayer
var fog_layer: TileMapLayer

var cave_zones = []


# -------------------------
# INIT
# -------------------------
func _ready():
	randomize()

	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.08
	noise.fractal_octaves = 3

	terrain = self
	background_layer = get_tree().get_first_node_in_group("terrain_background")
	fog_layer = get_tree().get_first_node_in_group("terrain_fog")

	if not fog_layer:
		push_error("Fog layer missing")
	if not background_layer:
		push_warning("Background layer missing")

	generate_cave_zones()
	generate_world()
	fill_fog()
	carve_caves()


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

	# full fog reset (important for correctness)
	fill_fog()

	for x in range(player_tile.x - light_radius, player_tile.x + light_radius + 1):
		for y in range(player_tile.y - light_radius, player_tile.y + light_radius + 1):

			var target := Vector2i(x, y)

			# STEP 1: skip out of range (still needed, but ONLY for performance)
			if player_tile.distance_to(target) > light_radius:
				continue

			# STEP 2: REAL LIGHT CHECK (this is what you were missing)
			if not has_line_of_sight(player_tile, target):
				continue

			fog_layer.set_cell(target, -1)

# -------------------------
# TILE CONVERSION (CRITICAL FIX)
# -------------------------
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return terrain.local_to_map(terrain.to_local(world_pos))


# -------------------------
# CAVES (UNCHANGED LOGIC, FIXED SAFETY)
# -------------------------
func carve_caves():

	for zone in cave_zones:

		var center: Vector2 = zone["pos"]
		var radius: int = zone["radius"]
		var ore_tile = zone["ore"]
		var richness: float = zone["richness"]

		for x in range(center.x - radius, center.x + radius):
			for y in range(center.y - radius, center.y + radius):

				var pos := Vector2i(x, y)

				if center.distance_to(Vector2(x, y)) > radius:
					continue

				var current := get_cell_atlas_coords(pos)

				if current == Vector2i(-1, -1):
					continue

				set_cell(pos, -1)

				if ore_tile != null and randf() < richness:
					set_cell(pos, TILE_SOURCE_ID, ore_tile)


# -------------------------
# CAVE ZONES
# -------------------------
func generate_cave_zones():

	var zone_count = 25

	for i in range(zone_count):

		var x = randi_range(-world_width, world_width)
		var y = randi_range(20, world_depth)

		cave_zones.append({
			"pos": Vector2(x, y),
			"radius": randi_range(4, 10),
			"ore": null,
			"richness": 0.05
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
