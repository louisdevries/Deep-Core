# player.gd
extends CharacterBody2D

const TerrainData = preload("res://scripts/data/terrain_data.gd")
const UpgradeData = preload("res://scripts/data/upgrade_data.gd")
const ResourceData = preload("res://scripts/data/resource_data.gd")

@export var move_speed = 200.0
@export var drill_interval = 0.15

@export var max_fuel = 100.0
@export var fuel_drain_move = 2.0
@export var fuel_drain_drill = 6.0

@export var ore_sell_value = 10

@export var dirt_break_sound: AudioStream
@export var stone_break_sound: AudioStream
@export var hard_stone_break_sound: AudioStream
@export var metal_break_sound: AudioStream
@export var crystal_break_sound: AudioStream

# GRAVITY
@export var gravity: float = 800.0
@export var max_fall_speed: float = 600.0
@export var thruster_force: float = 1100.0
@export var thruster_fuel_drain: float = 8.0
var is_thrusting: bool = false

# CABLE
var _cable_anchor: Vector2 = Vector2.ZERO
var _cable_paid_out: float = 200.0
@export var initial_cable_slack: float = 200.0
@export var max_cable_length: float = 800.0
@export var cable_extend_speed: float = 150.0
@export var cable_retract_speed: float = 150.0
var _cable_wrap_points: Array[Vector2] = []

var hazard_layer: TileMapLayer

const TILE_SOURCE_ID = 1

var fuel = 100.0

var terrain
var is_drilling = false
var drill_timer = 0.0

var last_direction = Vector2.DOWN

var drill_gear = 1
var drill_power = 1

var ore = 0
var money = 0
var upgrade_cost = 50
var can_upgrade = false
var current_depth = 0

# STORAGE
var storage: Dictionary = {}
var max_storage: int = 100   # starting capacity

# HEALTH
@export var max_health: float = 100.0
var health: float = 100.0
var health_regen_rate: float = 3.0
var time_since_damage: float = 0.0
var regen_delay: float = 4.0
var is_dead: bool = false
var damage_flash_timer: float = 0.0

# Multi-drill: 1 = single, 2 = dual, 3 = triple
var drill_count: int = 1
var permanent_drills: Array[Vector2i] = []   # which sides are permanently mounted
# THRUSTERS (upgrade-gated)
var has_thrusters: bool = false

# RESPAWN
var spawn_position: Vector2

# UI
var ui_health_bar

var furnace_slot_count: int = 1
var furnace_level: int = 1

# RESOURCE STORAGE - all material types
var resources = {
	"copper": 0,
	"tin": 0,
	"coal": 0,
	"sulfur": 0,
	"iron": 0,
	"silver": 0,
	"aluminum": 0,
	"lead": 0,
	"zinc": 0,
	"gold": 0,
	"platinum": 0,
	"titanium": 0,
	"tungsten": 0,
	"crystal": 0,
	"ruby": 0,
	"sapphire": 0,
	"emerald": 0,
	"diamond": 0,
	"obsidian": 0,
	"uranium": 0,
	"mythril": 0,
	"adamantium": 0,
}

# ============================
# SONAR TARGETS - all valuable tiles + hazards
# (updated for row-based atlas layout)
# ============================
const SONAR_TARGETS := {
	# Row 1 - ores
	Vector2i(0, 1): Color(1.0, 0.7, 0.3, 1.0),     # Basic Ore - amber
	Vector2i(1, 1): Color(1.0, 0.5, 0.1, 1.0),     # Copper - bright orange
	Vector2i(2, 1): Color(0.9, 0.9, 0.85, 1.0),    # Tin - pale silver
	Vector2i(3, 1): Color(0.3, 0.3, 0.3, 1.0),     # Coal - dark grey
	Vector2i(4, 1): Color(0.95, 0.9, 0.3, 1.0),    # Sulfur - mustard yellow

	# Row 2 - metals
	Vector2i(0, 2): Color(0.8, 0.85, 0.9, 1.0),    # Iron - slate
	Vector2i(1, 2): Color(0.95, 0.95, 0.95, 1.0),  # Silver - bright cool white
	Vector2i(2, 2): Color(0.75, 0.8, 0.85, 1.0),   # Aluminum - matte light
	Vector2i(3, 2): Color(0.45, 0.5, 0.55, 1.0),   # Lead - dark blue-grey
	Vector2i(4, 2): Color(0.6, 0.65, 0.7, 1.0),    # Zinc - medium grey

	# Row 3 - precious
	Vector2i(0, 3): Color(1.0, 0.85, 0.3, 1.0),    # Gold - warm yellow
	Vector2i(1, 3): Color(0.95, 0.9, 0.85, 1.0),   # Platinum - cream
	Vector2i(2, 3): Color(0.6, 0.7, 0.8, 1.0),     # Titanium - steel-blue
	Vector2i(3, 3): Color(0.35, 0.4, 0.45, 1.0),   # Tungsten - very dark cool

	# Row 4 - gems
	Vector2i(0, 4): Color(0.2, 1.0, 1.0, 1.0),     # Crystal - cyan
	Vector2i(1, 4): Color(0.95, 0.2, 0.2, 1.0),    # Ruby - saturated red
	Vector2i(2, 4): Color(0.2, 0.4, 0.95, 1.0),    # Sapphire - deep blue
	Vector2i(3, 4): Color(0.15, 0.75, 0.45, 1.0),  # Emerald - rich green
	Vector2i(4, 4): Color(0.8, 0.95, 1.0, 1.0),    # Diamond - pale luminous

	# Row 5 - hazards (warning colors)
	Vector2i(0, 5): Color(1.0, 0.2, 0.0, 1.0),     # Lava - red
	Vector2i(1, 5): Color(0.3, 1.0, 0.2, 1.0),     # Gas - green warning
	Vector2i(2, 5): Color(0.7, 0.9, 1.0, 1.0),     # Ice - pale icy blue
	Vector2i(3, 5): Color(0.7, 0.95, 0.2, 1.0),    # Acid - lime warning

	# Row 6 - specials
	Vector2i(0, 6): Color(0.4, 0.3, 0.5, 1.0),     # Obsidian - violet-black
	Vector2i(1, 6): Color(0.3, 0.9, 0.3, 1.0),     # Uranium - radioactive green
	Vector2i(2, 6): Color(0.7, 0.9, 1.0, 1.0),     # Mythril - luminous pale blue
	Vector2i(3, 6): Color(0.4, 0.5, 0.6, 1.0),     # Adamantium - dark steel
}


# ============================
# TILE → CATEGORY (data-driven sounds and particles)
# Each tile maps to a "material category" used for picking sounds and effects.
# ============================
const TILE_CATEGORY := {
	# Row 0 - terrain
	Vector2i(0, 0): "soft",      # grass
	Vector2i(1, 0): "soft",      # dirt
	Vector2i(2, 0): "stone",     # stone
	Vector2i(3, 0): "stone",     # hard stone
	Vector2i(4, 0): "stone",     # deep stone

	# Row 1 - common ores
	Vector2i(0, 1): "ore",       # basic ore
	Vector2i(1, 1): "metal",     # copper
	Vector2i(2, 1): "metal",     # tin
	Vector2i(3, 1): "ore",       # coal
	Vector2i(4, 1): "ore",       # sulfur

	# Row 2 - metals
	Vector2i(0, 2): "metal",     # iron
	Vector2i(1, 2): "metal",     # silver
	Vector2i(2, 2): "metal",     # aluminum
	Vector2i(3, 2): "metal",     # lead
	Vector2i(4, 2): "metal",     # zinc

	# Row 3 - precious
	Vector2i(0, 3): "metal",     # gold
	Vector2i(1, 3): "metal",     # platinum
	Vector2i(2, 3): "metal",     # titanium
	Vector2i(3, 3): "metal",     # tungsten

	# Row 4 - gems
	Vector2i(0, 4): "crystal",   # crystal
	Vector2i(1, 4): "crystal",   # ruby
	Vector2i(2, 4): "crystal",   # sapphire
	Vector2i(3, 4): "crystal",   # emerald
	Vector2i(4, 4): "crystal",   # diamond

	# Row 5 - hazards (no break sound usually but defined for safety)
	Vector2i(0, 5): "hazard",    # lava
	Vector2i(1, 5): "hazard",    # gas
	Vector2i(2, 5): "stone",     # ice (sounds like stone)
	Vector2i(3, 5): "hazard",    # acid

	# Row 6 - specials
	Vector2i(0, 6): "crystal",   # obsidian (glassy)
	Vector2i(1, 6): "metal",     # uranium
	Vector2i(2, 6): "metal",     # mythril
	Vector2i(3, 6): "metal",     # adamantium
	Vector2i(4, 6): "stone",    # concrete sounds like stone if anyone tries
}

# Particle colors per category
const CATEGORY_PARTICLE_COLOR := {
	"soft":    Color.SADDLE_BROWN,
	"stone":   Color.DIM_GRAY,
	"ore":     Color.ORANGE,
	"metal":   Color.LIGHT_SLATE_GRAY,
	"crystal": Color.CYAN,
	"hazard":  Color.RED,
}

# Drill pitch per category
const CATEGORY_DRILL_PITCH := {
	"soft":    1.0,
	"stone":   0.85,
	"ore":     1.0,
	"metal":   0.95,
	"crystal": 1.3,
	"hazard":  0.7,
}


var ui_fuel_bar
var ui_gear_label
var ui_money_label
var ui_cargo_label
var ui_sonar_label
var ui_drill_dir_label

var drill_particles

var camera
var shake_strength = 0.0

var drill_sound
var drill_idle_sound
var drill_loop_sound
var drill_impact_sound

# DRILL SWIVEL
var drill_swivel_tier: int = 1
var drill_direction: Vector2i = Vector2i.DOWN
var has_left_drill: bool = false
var has_right_drill: bool = false

var cargo = 0
var max_cargo = 20
var darkness_overlay
var revealed_tiles = {}

# SONAR
var sonar_range: int = 8
var sonar_terrain_duration: float = 3.0
var sonar_marker_duration: float = 6.0
var sonar_cooldown: float = 8.0
var sonar_cooldown_timer: float = 0.0
var sonar_markers_container: Node2D

# SONAR sweep state
var sonar_active: bool = false
var sonar_sweep_time: float = 0.0
var sonar_sweep_duration: float = 0.8
var sonar_last_radius: float = 0.0
var sonar_center_tile: Vector2i

var ui_cable_bar
var ui_cable_label

@onready var player_light = $PointLight2D


func _ready():

	terrain = get_tree().get_first_node_in_group("terrain")
	print("=== TERRAIN DIAGNOSTIC ===")
	print("terrain node: ", terrain.name if terrain else "null")
	print("terrain has script: ", terrain.get_script() != null if terrain else "n/a")
	print("terrain tile under player:", terrain.get_cell_atlas_coords(world_to_tile(global_position)))
	print("==========================")

	ui_fuel_bar = get_tree().get_first_node_in_group("ui_fuel")
	ui_gear_label = get_tree().get_first_node_in_group("ui_gear")
	ui_money_label = get_tree().get_first_node_in_group("ui_money")
	ui_cargo_label = get_tree().get_first_node_in_group("ui_cargo")
	
	ui_sonar_label = get_tree().get_first_node_in_group("ui_sonar")
	ui_health_bar = get_tree().get_first_node_in_group("ui_health")
	hazard_layer = get_tree().get_first_node_in_group("hazards")
	ui_drill_dir_label = get_tree().get_first_node_in_group("ui_drill_dir")
	ui_cable_bar = get_tree().get_first_node_in_group("ui_cable_bar")
	ui_cable_label = get_tree().get_first_node_in_group("ui_cable_label")

	if ui_cable_bar:
		ui_cable_bar.max_value = max_cable_length
		
	spawn_position = global_position
	_cable_anchor = _find_refuel_anchor()
	health = max_health

	sonar_markers_container = Node2D.new()
	sonar_markers_container.name = "SonarMarkers"
	sonar_markers_container.z_index = 10
	get_tree().current_scene.add_child.call_deferred(sonar_markers_container)
	darkness_overlay = get_tree().get_first_node_in_group("darkness_overlay")

	drill_particles = $DrillParticles
	camera = $Camera2D
	drill_sound = $DrillSound
	drill_idle_sound = $DrillIdleSound
	drill_impact_sound = $DrillImpactSound

	# restore player state from save (if any)
	var save: Dictionary = SaveSystem.data
	if not save.is_empty():
		apply_player_save(save)

	drill_idle_sound.play()


func _physics_process(delta):

	handle_input()

	update_sonar_sweep(delta)
	if sonar_cooldown_timer > 0.0:
		sonar_cooldown_timer = max(0.0, sonar_cooldown_timer - delta)
	check_hazard_contact(delta)
	update_health(delta)

	if ui_money_label:
		ui_money_label.text = "$" + str(money)

	if fuel <= 0 or is_dead:
		velocity = Vector2.ZERO
		return

	handle_movement(delta)

	if is_drilling:
		drill_idle_sound.pitch_scale = 1.0 + (drill_gear * 0.03)
		drill(delta)

	fuel = clamp(fuel, 0.0, max_fuel)

	# UI Updates
	if ui_fuel_bar:
		ui_fuel_bar.value = fuel

	if ui_gear_label:
		ui_gear_label.text = "Gear: " + str(drill_gear)

	if ui_cargo_label:
		ui_cargo_label.text = "Cargo: " + str(cargo) + " / " + str(max_cargo)
		
	if ui_sonar_label:
		if sonar_cooldown_timer > 0.0:
			ui_sonar_label.text = "Sonar: %.1fs" % sonar_cooldown_timer
		else:
			ui_sonar_label.text = "Sonar: READY"

	if ui_health_bar:
		ui_health_bar.value = health

	if ui_drill_dir_label:
		match drill_direction:
			Vector2i.LEFT:  ui_drill_dir_label.text = "Drill: ←"
			Vector2i.DOWN:  ui_drill_dir_label.text = "Drill: ↓"
			Vector2i.RIGHT: ui_drill_dir_label.text = "Drill: →"
			
	if ui_cable_bar:
		ui_cable_bar.max_value = max_cable_length    # in case it got upgraded
		ui_cable_bar.value = _cable_paid_out

	if ui_cable_label:
		ui_cable_label.text = "Cable: %d / %d" % [int(_cable_paid_out), int(max_cable_length)]
	
	_update_machine_sprite()
	current_depth = int(global_position.y / 16)
	update_player_light()
	update_darkness()

	if terrain.has_method("set_depth_tint"):
		terrain.set_depth_tint(current_depth)

	terrain.update_fog(global_position)
	update_camera_shake()
	_update_cable_wrap_points()
	_update_cable_visual()


func handle_input():

	var was_drilling = is_drilling

	is_drilling = Input.is_action_pressed("ui_accept")

	# Gear controls
	if Input.is_action_just_pressed("set_gear_1"):
		drill_gear = 1
	if Input.is_action_just_pressed("set_gear_2"):
		drill_gear = 2
	if Input.is_action_just_pressed("set_gear_3"):
		drill_gear = 3

	if Input.is_action_just_pressed("sonar"):
		use_sonar()

	# Audio transitions
	if is_drilling and not was_drilling:
		drill_idle_sound.volume_db = -6
		drill_idle_sound.pitch_scale = 1.08
	elif not is_drilling and was_drilling:
		drill_idle_sound.volume_db = -12
		drill_idle_sound.pitch_scale = 1.0

	# DRILL DIRECTION (swivel system)
	if drill_swivel_tier >= 2:
		_handle_swivel_input()	


func handle_movement(delta: float) -> void:

	var direction_x: float = Input.get_axis("ui_left", "ui_right")
	var winch_in: bool = Input.is_action_pressed("ui_up")
	var winch_out: bool = Input.is_action_pressed("ui_down")

	# thrusters (only if unlocked, and only on a dedicated key)
	is_thrusting = has_thrusters and Input.is_action_pressed("thrust") and fuel > 0.0

	# --- winch cable in/out ---
	if winch_in:
		_cable_paid_out = max(0.0, _cable_paid_out - cable_retract_speed * delta)
	elif winch_out:
		_cable_paid_out = min(max_cable_length, _cable_paid_out + cable_extend_speed * delta)

	# --- horizontal: snappy ground-style movement (creates swing if at full extension) ---
	velocity.x = direction_x * move_speed

	if abs(direction_x) > 0.0:
		fuel -= fuel_drain_move * delta

	# --- vertical: gravity always applies; cable catches it ---
	if is_thrusting:
		# thrusters override the cable's hold
		velocity.y -= thruster_force * delta
		fuel -= thruster_fuel_drain * delta
	else:
		velocity.y += gravity * delta

	# cap vertical speed
	velocity.y = min(velocity.y, max_fall_speed)
	velocity.y = max(velocity.y, -max_fall_speed)

	move_and_slide()
	_clamp_to_camera_bounds()

	# total length of cable path through any wrap points
	var path_length: float = _get_rope_path_length()

	if path_length > _cable_paid_out:
		# the "free" portion of cable goes from the effective anchor (last wrap point)
		# to the player. We need to clamp the free portion's length.
		var effective_anchor: Vector2 = _get_effective_anchor()
		var to_player: Vector2 = global_position - effective_anchor

		# length used by the wrapped portion (anchor → wrap points)
		var wrapped_length: float = path_length - to_player.length()

		# how much cable is left for the final segment
		var free_length: float = max(0.0, _cable_paid_out - wrapped_length)

		var clamped: Vector2 = effective_anchor + to_player.normalized() * free_length
		global_position = clamped

		var away_dir: Vector2 = to_player.normalized()
		var away_velocity: float = velocity.dot(away_dir)
		if away_velocity > 0:
			velocity -= away_dir * away_velocity

	if direction_x != 0:
		last_direction = Vector2(direction_x, 0)


func world_to_tile(pos: Vector2) -> Vector2i:
	var local_pos = terrain.to_local(pos)
	return terrain.local_to_map(local_pos)


func drill(delta: float) -> void:

	drill_timer += delta

	if drill_timer < drill_interval:
		return

	drill_timer = 0.0

	fuel -= fuel_drain_drill * drill_gear * delta

	var perpendicular_offset: int = 8
	var depth_offset: int = 20

	# Build list of drill directions based on multi-drill upgrade and current swivel
	var drill_dirs: Array = _get_active_drill_directions()

	# For each active direction, drill 2 perpendicular tiles
	for dir: Vector2i in drill_dirs:

		var target_a: Vector2
		var target_b: Vector2

		match dir:

			Vector2i.DOWN:
				target_a = global_position + Vector2(-perpendicular_offset, depth_offset)
				target_b = global_position + Vector2(perpendicular_offset, depth_offset)

			Vector2i.LEFT:
				target_a = global_position + Vector2(-depth_offset, -perpendicular_offset)
				target_b = global_position + Vector2(-depth_offset, perpendicular_offset)

			Vector2i.RIGHT:
				target_a = global_position + Vector2(depth_offset, -perpendicular_offset)
				target_b = global_position + Vector2(depth_offset, perpendicular_offset)

		try_break_tile(world_to_tile(target_a))
		try_break_tile(world_to_tile(target_b))

func try_break_tile(tile_pos: Vector2i):

	var tile_data: Vector2i = terrain.get_cell_atlas_coords(tile_pos)
	var source_layer: TileMapLayer = terrain

	if tile_data == Vector2i(-1, -1) and hazard_layer:
		tile_data = hazard_layer.get_cell_atlas_coords(tile_pos)
		source_layer = hazard_layer

	if tile_data == Vector2i(-1, -1):
		return

	if not TerrainData.TERRAIN_TYPES.has(tile_data):
		return

	var terrain_info = TerrainData.TERRAIN_TYPES[tile_data]

	var required_power = terrain_info["required_power"]
	var effective_power = drill_power + drill_gear

	if effective_power < required_power:
		return

	var cargo_value = terrain_info["cargo"]

	if cargo_value > 0 and cargo + cargo_value > max_cargo:
		return

	spawn_drill_particles(tile_pos, tile_data)
	shake_strength = required_power * 0.6
	play_drill_sound(tile_data)
	play_impact_sound(tile_data)

	var resource_type = terrain_info["resource"]

	if resource_type != null:
		# create the bucket on demand for any new resource type
		if not resources.has(resource_type):
			resources[resource_type] = 0
		resources[resource_type] += 1
	elif terrain_info.get("is_ore", false):
		ore += 1

	cargo += cargo_value

	source_layer.set_cell(tile_pos, -1)

	# track for save system (only terrain-layer breaks, not hazards)
	if source_layer == terrain and terrain.has_method("mark_cleared"):
		terrain.mark_cleared(tile_pos)

	# wake hazards that might want to flow into the new empty cell
	if terrain.has_method("_wake_neighbors"):
		terrain._wake_neighbors(tile_pos)


# ============================
# DATA-DRIVEN PARTICLE / SOUND HELPERS
# ============================
func _get_category(tile_data: Vector2i) -> String:
	return TILE_CATEGORY.get(tile_data, "stone")


func spawn_drill_particles(tile_pos, tile_data):

	if not drill_particles:
		return

	var world_pos = terrain.map_to_local(tile_pos)
	drill_particles.global_position = terrain.to_global(world_pos)

	var category: String = _get_category(tile_data)
	drill_particles.modulate = CATEGORY_PARTICLE_COLOR.get(category, Color.DIM_GRAY)

	drill_particles.restart()
	drill_particles.emitting = true


func update_camera_shake():

	if shake_strength > 0:
		camera.offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		shake_strength = lerp(shake_strength, 0.0, 0.2)
	else:
		camera.offset = Vector2.ZERO


func play_drill_sound(tile_data):

	if not drill_sound:
		return

	var category: String = _get_category(tile_data)
	drill_sound.pitch_scale = CATEGORY_DRILL_PITCH.get(category, 1.0)

	drill_sound.play()


func play_impact_sound(tile_data):

	var category: String = _get_category(tile_data)
	var stream: AudioStream = null

	match category:
		"soft":
			stream = dirt_break_sound
		"stone":
			stream = stone_break_sound
		"ore":
			stream = hard_stone_break_sound
		"metal":
			stream = metal_break_sound
		"crystal":
			stream = crystal_break_sound
		_:
			return

	if not stream:
		return

	drill_impact_sound.stream = stream
	drill_impact_sound.pitch_scale = randf_range(0.92, 1.08)
	drill_impact_sound.play()


func update_player_light():

	if not player_light:
		return

	var t = clamp((current_depth - 5) / 60.0, 0.0, 1.0)
	player_light.energy = lerp(0.15, 1.4, t)


func update_darkness():

	if not darkness_overlay:
		return

	var t = clamp((current_depth - 5) / 120.0, 0.0, 1.0)
	var brightness = lerp(1.0, 0.18, t)

	darkness_overlay.color = Color(brightness, brightness, brightness, 1.0)


func use_sonar() -> void:

	if sonar_cooldown_timer > 0.0 or sonar_active:
		return

	sonar_cooldown_timer = sonar_cooldown

	for child in sonar_markers_container.get_children():
		child.queue_free()

	sonar_active = true
	sonar_sweep_time = 0.0
	sonar_last_radius = 0.0
	sonar_center_tile = world_to_tile(global_position)

	print("Sonar sweep started")


func spawn_sonar_marker(tile_pos: Vector2i, color: Color) -> void:

	var marker := Sprite2D.new()

	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(color)
	marker.texture = ImageTexture.create_from_image(img)

	var local_pos: Vector2 = terrain.map_to_local(tile_pos)
	marker.global_position = terrain.to_global(local_pos)

	sonar_markers_container.add_child(marker)

	var tween := marker.create_tween().set_loops()
	tween.tween_property(marker, "modulate:a", 0.4, 0.5)
	tween.tween_property(marker, "modulate:a", 1.0, 0.5)


func clear_sonar_markers() -> void:

	if not is_instance_valid(sonar_markers_container):
		return

	for child in sonar_markers_container.get_children():
		child.queue_free()


func update_sonar_sweep(delta: float) -> void:

	if not sonar_active:
		return

	sonar_sweep_time += delta

	var t: float = clamp(sonar_sweep_time / sonar_sweep_duration, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var current_radius: float = eased * float(sonar_range)

	if terrain.has_method("sonar_reveal_ring"):
		terrain.sonar_reveal_ring(
			sonar_center_tile,
			sonar_last_radius,
			current_radius,
			sonar_terrain_duration
		)

	spawn_markers_in_ring(sonar_last_radius, current_radius)

	sonar_last_radius = current_radius

	if t >= 1.0:
		sonar_active = false
		get_tree().create_timer(sonar_marker_duration).timeout.connect(clear_sonar_markers)


func spawn_markers_in_ring(inner: float, outer: float) -> void:

	var r_int: int = int(ceil(outer))

	for x in range(sonar_center_tile.x - r_int, sonar_center_tile.x + r_int + 1):
		for y in range(sonar_center_tile.y - r_int, sonar_center_tile.y + r_int + 1):

			var pos := Vector2i(x, y)
			var dist: float = sonar_center_tile.distance_to(pos)

			if dist < inner or dist > outer:
				continue

			var tile: Vector2i = terrain.get_cell_atlas_coords(pos)

			if tile == Vector2i(-1, -1) and hazard_layer:
				tile = hazard_layer.get_cell_atlas_coords(pos)

			if not SONAR_TARGETS.has(tile):
				continue

			spawn_sonar_marker(pos, SONAR_TARGETS[tile])


func take_damage(amount: float, source: String = "") -> void:

	if is_dead:
		return

	health -= amount
	time_since_damage = 0.0
	damage_flash_timer = 0.15

	shake_strength = max(shake_strength, amount * 0.15)

	print("Took ", amount, " damage from ", source, " | HP: ", health)

	if health <= 0.0:
		die()


func die() -> void:

	is_dead = true
	health = 0.0

	print("=== PLAYER DIED ===")

	# Wipe cargo (the risky stuff)
	cargo = 0
	ore = 0
	for key in resources.keys():
		resources[key] = 0

	# Storage SURVIVES death — it's the safe space

	get_tree().create_timer(1.5).timeout.connect(respawn)

func respawn() -> void:

	global_position = spawn_position
	velocity = Vector2.ZERO
	health = max_health
	fuel = max_fuel
	is_dead = false

	print("Respawned at base")


func check_hazard_contact(delta: float) -> void:

	if is_dead:
		return

	if not hazard_layer:
		return

	var check_offsets: Array = [
		Vector2(0, 0),
		Vector2(-12, -12),
		Vector2(12, -12),
		Vector2(-12, 12),
		Vector2(12, 12),
	]

	var health_dmg: float = 0.0
	var fuel_dmg: float = 0.0

	for offset in check_offsets:

		var world_pos: Vector2 = global_position + offset
		var check_tile: Vector2i = hazard_layer.local_to_map(hazard_layer.to_local(world_pos))
		var tile_data: Vector2i = hazard_layer.get_cell_atlas_coords(check_tile)

		if tile_data == Vector2i(-1, -1):
			continue

		if not TerrainData.TERRAIN_TYPES.has(tile_data):
			continue

		var info: Dictionary = TerrainData.TERRAIN_TYPES[tile_data]

		if not info.has("hazard"):
			continue

		var ch: float = info.get("contact_damage", 0.0)
		var fh: float = info.get("fuel_damage", 0.0)

		if ch > health_dmg:
			health_dmg = ch
		if fh > fuel_dmg:
			fuel_dmg = fh

	if health_dmg > 0.0:
		take_damage(health_dmg * delta, "hazard")

	if fuel_dmg > 0.0:
		fuel = max(0.0, fuel - fuel_dmg * delta)


func update_health(delta: float) -> void:

	if is_dead:
		return

	time_since_damage += delta

	if time_since_damage >= regen_delay and health < max_health:
		health = min(max_health, health + health_regen_rate * delta)

	if damage_flash_timer > 0.0:
		damage_flash_timer -= delta
		$MachineSprite.modulate = Color(1.5, 0.4, 0.4, 1.0)
	else:
		$MachineSprite.modulate = Color.WHITE


func build_player_save() -> Dictionary:

	return {
		"position_x": global_position.x,
		"position_y": global_position.y,
		"money": money,
		"drill_power": drill_power,
		"sonar_range": sonar_range,
		"fuel": fuel,
		"health": health,
		"cargo": cargo,
		"ore": ore,
		"drill_swivel_tier": drill_swivel_tier,
		"drill_direction": [drill_direction.x, drill_direction.y],
		"resources": resources,
		"max_cargo": max_cargo,
		"max_fuel": max_fuel,
		"max_cable_length": max_cable_length,
		"has_thrusters": has_thrusters,
		"furnace_slot_count": furnace_slot_count,
		"furnace_level": furnace_level,
		"drill_count": drill_count,
		"has_left_drill": has_left_drill,
		"has_right_drill": has_right_drill,
		"storage": storage,
		"max_storage": max_storage,
	}


func apply_player_save(save: Dictionary) -> void:

	if save.has("position_x") and save.has("position_y"):
		global_position = Vector2(save["position_x"], save["position_y"])

	money = save.get("money", 0)
	drill_power = save.get("drill_power", 1)
	sonar_range = save.get("sonar_range", 8)
	fuel = save.get("fuel", max_fuel)
	health = save.get("health", max_health)
	cargo = save.get("cargo", 0)
	ore = save.get("ore", 0)
	drill_swivel_tier = save.get("drill_swivel_tier", 1)
	max_cargo = save.get("max_cargo", 20)
	max_cable_length = save.get("max_cable_length", 800.0)
	max_fuel = save.get("max_fuel", 100.0)
	has_thrusters = save.get("has_thrusters", false)
	drill_count = save.get("drill_count", 1)
	has_left_drill = save.get("has_left_drill", false)
	has_right_drill = save.get("has_right_drill", false)
	max_storage = save.get("max_storage", 100)

	if save.has("storage"):
		storage = save["storage"].duplicate()
		# ensure all keys are ints (JSON might load them as floats)
		for key in storage.keys():
			storage[key] = int(storage[key])
	furnace_slot_count = save.get("furnace_slot_count", 1)
	furnace_level = save.get("furnace_level", 1)
	FurnaceSystem.slot_count = furnace_slot_count
	if save.has("drill_direction"):
		var d: Array = save["drill_direction"]
		drill_direction = Vector2i(int(d[0]), int(d[1]))

	if save.has("resources"):
		for key in save["resources"].keys():
			if not resources.has(key):
				resources[key] = 0
			resources[key] = int(save["resources"][key])


func _handle_swivel_input() -> void:

	# tier 2: must be stationary AND not drilling
	if drill_swivel_tier == 2:
		if is_drilling:
			return
		if velocity.length() > 0.1:
			return

	# tier 3: no restrictions

	# Can't swivel toward a permanently-mounted drill (it's already there)
	if Input.is_action_just_pressed("drill_left"):
		if not (Vector2i.LEFT in permanent_drills):
			drill_direction = Vector2i.LEFT

	elif Input.is_action_just_pressed("drill_down"):
		drill_direction = Vector2i.DOWN

	elif Input.is_action_just_pressed("drill_right"):
		if not (Vector2i.RIGHT in permanent_drills):
			drill_direction = Vector2i.RIGHT




func _find_refuel_anchor() -> Vector2:
	var tether := get_tree().get_first_node_in_group("tether")
	if not tether:
		push_error("No node in 'tether' group — cable anchor will be wrong!")
		return Vector2(0, 0)
	return tether.global_position


func _handle_free_movement(delta):

	var direction_x: float = Input.get_axis("ui_left", "ui_right")

	is_thrusting = Input.is_action_pressed("ui_up") and fuel > 0.0

	velocity.x = direction_x * move_speed

	if abs(direction_x) > 0.0:
		fuel -= fuel_drain_move * delta

	if is_thrusting:
		velocity.y -= thruster_force * delta
		fuel -= thruster_fuel_drain * delta
	else:
		velocity.y += gravity * delta

	velocity.y = min(velocity.y, max_fall_speed)
	velocity.y = max(velocity.y, -max_fall_speed)

	move_and_slide()
	_clamp_to_camera_bounds()

	if direction_x != 0:
		last_direction = Vector2(direction_x, 0)


func _clamp_to_camera_bounds() -> void:
	const HALF_W: float = 12.0
	global_position.x = clamp(global_position.x, camera.limit_left + HALF_W, camera.limit_right - HALF_W)


func _get_effective_anchor() -> Vector2:
	return _cable_wrap_points.back() if _cable_wrap_points.size() > 0 else _cable_anchor


func _find_wrap_corner(hit_pos: Vector2, hit_normal: Vector2, from_anchor: Vector2) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	
	# Find the solid tile we hit
	var solid_tile_pos: Vector2i = terrain.local_to_map(terrain.to_local(hit_pos - hit_normal * 1.0))
	var half := Vector2(terrain.tile_set.tile_size) * 0.5
	var solid_center: Vector2 = terrain.to_global(terrain.map_to_local(solid_tile_pos))
	
	# 4 corners of the solid tile
	var raw_corners := [
		solid_center + Vector2(-half.x, -half.y),
		solid_center + Vector2( half.x, -half.y),
		solid_center + Vector2(-half.x,  half.y),
		solid_center + Vector2( half.x,  half.y),
	]
	
	# Push each corner OUTWARD from the solid tile by a few pixels
	# so the wrap point sits in empty space
	var corners := []
	for c: Vector2 in raw_corners:
		var outward: Vector2 = (c - solid_center).normalized()
		corners.append(c + outward * 3.0)    # 3 pixels outward
	
	# Among corners that have line-of-sight to BOTH the anchor and the player,
	# pick the one closest to the anchor-player line.
	var best_corner: Vector2 = hit_pos
	var best_dist: float = INF
	
	for c: Vector2 in corners:
		# must have LOS to anchor
		var q1 := PhysicsRayQueryParameters2D.create(from_anchor, c)
		q1.exclude = [self]
		if not space_state.intersect_ray(q1).is_empty():
			continue
		
		# must also have LOS to player (otherwise it's not a useful wrap)
		var q2 := PhysicsRayQueryParameters2D.create(c, global_position)
		q2.exclude = [self]
		if not space_state.intersect_ray(q2).is_empty():
			continue
		
		# pick the corner closest to the anchor-player line
		var d := _distance_point_to_segment(c, from_anchor, global_position)
		if d < best_dist:
			best_dist = d
			best_corner = c
	
	return best_corner


func _update_cable_wrap_points() -> void:
	var space_state := get_world_2d().direct_space_state

	while _cable_wrap_points.size() > 0:
		var prev: Vector2 = _cable_wrap_points[-2] if _cable_wrap_points.size() > 1 else _cable_anchor
		
		# check with a small margin — only unwrap if there's clear LOS with some space
		var to_player_dir: Vector2 = (global_position - prev).normalized()
		var check_target: Vector2 = global_position - to_player_dir * 4.0    # 4px back from player
		
		var unwrap_q := PhysicsRayQueryParameters2D.create(prev, check_target)
		unwrap_q.exclude = [self]
		if space_state.intersect_ray(unwrap_q).is_empty():
			_cable_wrap_points.pop_back()
		else:
			break

	if _cable_wrap_points.size() >= 8:
		return
	var ea := _get_effective_anchor()
	var q := PhysicsRayQueryParameters2D.create(ea, global_position)
	q.exclude = [self]
	var hit := space_state.intersect_ray(q)
	if not hit.is_empty():
		var corner := _find_wrap_corner(hit["position"], hit["normal"], ea)
		if corner.distance_to(ea) > 2.0 and corner.distance_to(global_position) > 2.0:
			_cable_wrap_points.append(corner)


func _get_rope_path_length() -> float:
	var total := 0.0
	var prev := _cable_anchor
	for wp: Vector2 in _cable_wrap_points:
		total += prev.distance_to(wp)
		prev = wp
	total += prev.distance_to(global_position)
	return total


func _handle_cable_movement(delta):

	if Input.is_action_pressed("cable_winch_out"):
		_cable_paid_out = min(max_cable_length, _cable_paid_out + cable_extend_speed * delta)
	if Input.is_action_pressed("cable_winch_in"):
		_cable_paid_out = max(0.0, _cable_paid_out - cable_retract_speed * delta)

	var direction_x: float = Input.get_axis("ui_left", "ui_right")
	is_thrusting = Input.is_action_pressed("ui_up") and fuel > 0.0

	velocity.x = direction_x * move_speed

	if abs(direction_x) > 0.0:
		fuel -= fuel_drain_move * delta

	if is_thrusting:
		velocity.y -= thruster_force * delta
		fuel -= thruster_fuel_drain * delta
	else:
		velocity.y += gravity * delta

	velocity.y = min(velocity.y, max_fall_speed)
	velocity.y = max(velocity.y, -max_fall_speed)

	move_and_slide()
	_clamp_to_camera_bounds()

	# cable constraint: clamp distance to anchor
	var to_anchor: Vector2 = global_position - _cable_anchor
	var dist: float = to_anchor.length()

	if dist > _cable_paid_out:
		var clamped: Vector2 = _cable_anchor + to_anchor.normalized() * _cable_paid_out
		global_position = clamped

		var away_dir: Vector2 = to_anchor.normalized()
		var away_velocity: float = velocity.dot(away_dir)
		if away_velocity > 0:
			velocity -= away_dir * away_velocity

	if direction_x != 0:
		last_direction = Vector2(direction_x, 0)


func _update_cable_visual() -> void:

	var cable_line: Line2D = get_node_or_null("CableLine")
	if not cable_line:
		return	
	
	cable_line.visible = true
	cable_line.clear_points()
	cable_line.add_point(to_local(_cable_anchor))
	for wp: Vector2 in _cable_wrap_points:
		cable_line.add_point(to_local(wp))
	cable_line.add_point(Vector2.ZERO)

func _distance_point_to_segment(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var seg := seg_end - seg_start
	var len_sq := seg.length_squared()
	if len_sq == 0.0:
		return point.distance_to(seg_start)
	
	# project point onto segment, clamped to [0, 1]
	var t: float = clamp((point - seg_start).dot(seg) / len_sq, 0.0, 1.0)
	var projection: Vector2 = seg_start + seg * t
	return point.distance_to(projection)

func _get_drill_animation_name() -> String:

	# Stage 4: both sides mounted
	if has_left_drill and has_right_drill:
		return "full"

	# Stage 3a: left drill mounted
	if has_left_drill:
		match drill_direction:
			Vector2i.RIGHT: return "left_right"
			_:              return "bottom_left"

	# Stage 3b: right drill mounted
	if has_right_drill:
		match drill_direction:
			Vector2i.LEFT:  return "left_right"
			_:              return "bottom_right"

	# Stage 1 or 2: starter drill only
	match drill_direction:
		Vector2i.LEFT:  return "left"
		Vector2i.RIGHT: return "right"
		_:              return "down"


func _get_active_drill_directions() -> Array:

	var dirs: Array = [drill_direction]   # swivel-controlled drill

	if has_left_drill and not (Vector2i.LEFT in dirs):
		dirs.append(Vector2i.LEFT)

	if has_right_drill and not (Vector2i.RIGHT in dirs):
		dirs.append(Vector2i.RIGHT)

	return dirs
	
func _update_machine_sprite() -> void:

	var machine_sprite: AnimatedSprite2D = $MachineSprite
	if not machine_sprite:
		return

	var target_anim: String = _get_drill_animation_name()

	# only change animation if needed (avoid restarting every frame)
	if machine_sprite.animation != target_anim:
		machine_sprite.animation = target_anim
		machine_sprite.frame = 0

	# play animation while drilling, freeze on frame 0 when idle
	if is_drilling and not machine_sprite.is_playing():
		machine_sprite.play()
	elif not is_drilling and machine_sprite.is_playing():
		machine_sprite.stop()
		machine_sprite.frame = 0


func _on_inventory_button_pressed() -> void:
	var inv := get_node_or_null("InventoryMenu") as CanvasLayer
	if inv and inv.has_method("open"):
		if inv.visible:
			inv.close()
		else:
			inv.open()

# Total amount of a material across cargo + storage (for upgrade checks)
func get_total_amount(material: String) -> int:
	var cargo_amt: int = resources.get(material, 0)
	var storage_amt: int = storage.get(material, 0)
	return cargo_amt + storage_amt


# Consume material for an upgrade — deducts from cargo first, then storage
func consume_material(material: String, amount: int) -> bool:

	if get_total_amount(material) < amount:
		return false

	var cargo_amt: int = resources.get(material, 0)
	var from_cargo: int = min(cargo_amt, amount)

	resources[material] = cargo_amt - from_cargo
	amount -= from_cargo

	if amount > 0:
		var storage_amt: int = storage.get(material, 0)
		storage[material] = storage_amt - amount

	# update cargo capacity used
	_recompute_cargo()

	return true


# Recompute cargo used based on current resources
func _recompute_cargo() -> void:

	var total: int = ore   # basic ore = 1 cargo each

	for tile in TerrainData.TERRAIN_TYPES:
		var info: Dictionary = TerrainData.TERRAIN_TYPES[tile]
		var rt = info.get("resource")
		if rt == null:
			continue
		var cargo_value: int = info.get("cargo", 1)
		var count: int = resources.get(rt, 0)
		total += count * cargo_value

	cargo = total


# Total amount in storage (for capacity checks)
func get_storage_used() -> int:
	var total: int = 0
	for v in storage.values():
		total += v
	return total


# Check if there's room to store amount more of material
func can_store(amount: int) -> bool:
	return get_storage_used() + amount <= max_storage


# Move material from cargo to storage; returns how much was actually moved
func transfer_to_storage(material: String, amount: int) -> int:

	var available: int = resources.get(material, 0)
	if material == "basic_ore":
		available = ore

	var to_move: int = min(amount, available)

	# capacity limit
	var room: int = max_storage - get_storage_used()
	to_move = min(to_move, room)

	if to_move <= 0:
		return 0

	# remove from cargo
	if material == "basic_ore":
		ore -= to_move
	else:
		resources[material] = available - to_move

	# add to storage
	if not storage.has(material):
		storage[material] = 0
	storage[material] += to_move

	_recompute_cargo()

	return to_move


# Move material from storage to cargo; returns how much was actually moved
func transfer_to_cargo(material: String, amount: int) -> int:

	var in_storage: int = storage.get(material, 0)
	var to_move: int = min(amount, in_storage)

	# cargo capacity check
	var cargo_value: int = _get_cargo_value_for_material(material)
	var room_in_cargo: int = max_cargo - cargo
	var max_by_cargo: int = int(floor(float(room_in_cargo) / float(max(cargo_value, 1))))

	to_move = min(to_move, max_by_cargo)

	if to_move <= 0:
		return 0

	# remove from storage
	storage[material] = in_storage - to_move

	# add to cargo
	if material == "basic_ore":
		ore += to_move
	else:
		if not resources.has(material):
			resources[material] = 0
		resources[material] += to_move

	_recompute_cargo()

	return to_move


# Look up cargo cost per unit for a given material
func _get_cargo_value_for_material(material: String) -> int:

	if material == "basic_ore":
		return 1

	for tile in TerrainData.TERRAIN_TYPES:
		var info: Dictionary = TerrainData.TERRAIN_TYPES[tile]
		if info.get("resource") == material:
			return info.get("cargo", 1)

	return 1


# Sell material from cargo only (or both? — design choice)
# For now: sell from cargo only. Storage is the "I want to keep this" space.
func sell_material(material: String, amount: int) -> int:

	const ResourceDataLocal = preload("res://scripts/data/resource_data.gd")
	var data: Dictionary = ResourceDataLocal.RESOURCES.get(material, {})
	var unit_value: int = data.get("value", 0)

	var available: int
	if material == "basic_ore":
		available = ore
	else:
		available = resources.get(material, 0)

	var to_sell: int = min(amount, available)
	if to_sell <= 0:
		return 0

	if material == "basic_ore":
		ore -= to_sell
	else:
		resources[material] = available - to_sell

	var total: int = to_sell * unit_value
	money += total

	_recompute_cargo()

	return total
