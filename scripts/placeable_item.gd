extends Node2D

const TerrainData = preload("res://scripts/data/terrain_data.gd")
const ResourceData = preload("res://scripts/data/resource_data.gd")

var item_id: String = ""
var fuse_time: float = 1.5
var tier_bonus: int = 1
var player: Node = null
var terrain: TileMapLayer = null
var hazard_layer: TileMapLayer = null

var _timer: float = 0.0
var _active: bool = false   # true once fuse is lit (dynamite/shaped_charge)


func setup(
	p_item_id: String,
	p_player: Node,
	p_terrain: TileMapLayer,
	p_hazard: TileMapLayer
) -> void:
	item_id     = p_item_id
	player      = p_player
	terrain     = p_terrain
	hazard_layer = p_hazard

	var icon_path: String = ""
	match item_id:
		"dynamite":
			icon_path  = "res://assets/Art/Tools/dynamite.png"
			tier_bonus = 1
			_active    = true
		"shaped_charge":
			icon_path  = "res://assets/Art/Tools/vertical_charge.png"
			tier_bonus = 2
			_active    = true
		"phase_beacon":
			icon_path = "res://assets/Art/Tools/phase_beacon.png"
			# Beacon doesn't auto-detonate; persists until player returns

	if icon_path != "":
		var sprite := Sprite2D.new()
		var tex := load(icon_path) as Texture2D
		if tex:
			sprite.texture = tex
		add_child(sprite)


func _process(delta: float) -> void:
	if not _active:
		return

	_timer += delta

	# Flash red as fuse burns
	modulate = Color.WHITE if int(_timer * 6) % 2 == 0 else Color(1.0, 0.3, 0.3, 1.0)

	if _timer >= fuse_time:
		modulate = Color.WHITE
		_explode()
		queue_free()


func _explode() -> void:
	if not terrain or not player:
		return

	var sfx := AudioStreamPlayer.new()
	sfx.stream = load("res://assets/Audio/SFX/Dynamite.wav")
	sfx.bus = "SFX"
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	var center_tile := terrain.local_to_map(terrain.to_local(global_position))
	var max_breakable_tier: int = player.drill_tier + 1 + tier_bonus

	match item_id:
		"dynamite":
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					_break_tile(
						Vector2i(center_tile.x + dx, center_tile.y + dy),
						max_breakable_tier,
						true
					)
			if player.global_position.distance_to(global_position) < 64.0:
				player.take_damage(40.0, "explosion")

		"shaped_charge":
			for dy in range(0, 10):
				_break_tile(
					Vector2i(center_tile.x, center_tile.y + dy),
					max_breakable_tier,
					false
				)


func _break_tile(tile_pos: Vector2i, max_tier: int, collect: bool) -> void:
	if not terrain:
		return

	var tile_atlas := terrain.get_cell_atlas_coords(tile_pos)
	var source_layer: TileMapLayer = terrain

	if tile_atlas == Vector2i(-1, -1) and hazard_layer:
		tile_atlas    = hazard_layer.get_cell_atlas_coords(tile_pos)
		source_layer  = hazard_layer

	if tile_atlas == Vector2i(-1, -1):
		return
	if not TerrainData.TERRAIN_TYPES.has(tile_atlas):
		return

	var info: Dictionary    = TerrainData.TERRAIN_TYPES[tile_atlas]
	var mat_tier: int       = info.get("material_tier", 1)

	if mat_tier >= 99 or mat_tier > max_tier:
		return

	if collect and player:
		var skip_resource := item_id == "dynamite" and randf() < 0.30
		if not skip_resource:
			var resource: Variant = info.get("resource", null)
			var cargo_value: int  = info.get("cargo", 0)

			if resource != null and player.cargo + cargo_value <= player.max_cargo:
				if not player.resources.has(resource):
					player.resources[resource] = 0
				player.resources[resource] += 1
				player._recompute_cargo()

				var world_pos := terrain.to_global(terrain.map_to_local(tile_pos))
				var display: String = ResourceData.RESOURCES.get(resource, {}).get("display_name", resource)
				player._spawn_floating_text("+1 " + display, world_pos)

			elif info.get("is_ore", false) and player.cargo + 1 <= player.max_cargo:
				player.ore += 1
				player._recompute_cargo()
				var world_pos := terrain.to_global(terrain.map_to_local(tile_pos))
				player._spawn_floating_text("+1 Basic Ore", world_pos)

	source_layer.set_cell(tile_pos, -1)

	if source_layer == terrain and terrain.has_method("mark_cleared"):
		terrain.mark_cleared(tile_pos)

	if terrain.has_method("_wake_neighbors"):
		terrain._wake_neighbors(tile_pos)
