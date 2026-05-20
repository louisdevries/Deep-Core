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
@export var gravity: float = 800.0          # pixels/sec²
@export var max_fall_speed: float = 600.0
@export var thruster_force: float = 1100.0   # upward acceleration when thrusting
@export var thruster_fuel_drain: float = 8.0   # fuel/sec while thrusting
var is_thrusting: bool = false

# CABLE PHYSICS
var _cable_anchor: Vector2 = Vector2.ZERO
var _cable_length: float = 0.0

@export var max_cable_length: float = 1200.0  # 75 tiles * 16px
@export var pendulum_damping: float = 2.5     # angular vel damping per sec
@export var swing_input_force: float = 6.0    # how much L/R input affects swing
@export var cable_extend_speed: float = 150.0 # pixels/sec for extending cable
@export var cable_retract_speed: float = 200.0 # pixels/sec for retracting via thrusters

# CABLE
var cable_engaged: bool = false
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

# HEALTH
@export var max_health: float = 100.0
var health: float = 100.0
var health_regen_rate: float = 3.0           # HP per second when safe
var time_since_damage: float = 0.0
var regen_delay: float = 4.0                 # seconds before regen kicks in
var is_dead: bool = false
var damage_flash_timer: float = 0.0

# RESPAWN
var spawn_position: Vector2

# UI
var ui_health_bar

# NEW RESOURCE STORAGE
var resources = {
	"copper": 0,
	"iron": 0,
	"crystal": 0
}

const SONAR_TARGETS := {
	Vector2i(4, 0): Color(1.0, 0.7, 0.3, 1.0),    # Basic Ore - amber
	Vector2i(5, 0): Color(1.0, 0.5, 0.1, 1.0),    # Copper - orange
	Vector2i(6, 0): Color(0.8, 0.85, 0.9, 1.0),   # Iron - silver
	Vector2i(7, 0): Color(0.2, 1.0, 1.0, 1.0),    # Crystal - cyan
	Vector2i(8, 0): Color(1.0, 0.2, 0.0, 1.0),    # Lava - red (warning)
	Vector2i(9, 0): Color(0.3, 1.0, 0.2, 1.0),    # Gas - green (warning)
}

var ui_fuel_bar
var ui_gear_label
var ui_money_label
var ui_cargo_label
var ui_copper_label
var ui_iron_label
var ui_crystal_label
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
var drill_swivel_tier: int = 1            # 1=down only, 2=stop-to-swivel, 3=free swivel
var drill_direction: Vector2i = Vector2i.DOWN

var cargo = 0
var max_cargo = 20
var darkness_overlay
var revealed_tiles = {}

# SONAR
var sonar_range: int = 8
var sonar_terrain_duration: float = 3.0   # how long terrain stays revealed
var sonar_marker_duration: float = 6.0    # resource pulses last longer
var sonar_cooldown: float = 8.0
var sonar_cooldown_timer: float = 0.0
var sonar_markers_container: Node2D

# SONAR sweep state
var sonar_active: bool = false
var sonar_sweep_time: float = 0.0
var sonar_sweep_duration: float = 0.8    # how long the ring takes to expand fully
var sonar_last_radius: float = 0.0
var sonar_center_tile: Vector2i

@onready var player_light = $PointLight2D


func _ready():

	terrain = get_tree().get_first_node_in_group("terrain")
	print("=== TERRAIN DIAGNOSTIC ===")
	print("terrain node: ", terrain.name if terrain else "null")
	print("terrain has script: ", terrain.get_script() != null if terrain else "n/a")
	print("terrain tile under player:", terrain.get_cell_atlas_coords(world_to_tile(global_position)))
	print("TERRAIN NODES:")
	for n in get_tree().get_nodes_in_group("terrain"):
		print(n.name, " class:", n.get_class())
	var all_terrain = get_tree().get_nodes_in_group("terrain")
	print("nodes in 'terrain' group: ", all_terrain.size())
	for t in all_terrain:
		print("  - ", t.name, " | script: ", t.get_script() != null)

	var all_bg = get_tree().get_nodes_in_group("terrain_background")
	print("nodes in 'terrain_background' group: ", all_bg.size())
	for t in all_bg:
		print("  - ", t.name, " | script: ", t.get_script() != null)
	print("==========================")
		
	ui_fuel_bar = get_tree().get_first_node_in_group("ui_fuel")
	ui_gear_label = get_tree().get_first_node_in_group("ui_gear")
	ui_money_label = get_tree().get_first_node_in_group("ui_money")	
	ui_cargo_label = get_tree().get_first_node_in_group("ui_cargo")
	ui_copper_label = get_tree().get_first_node_in_group("ui_copper")
	ui_iron_label = get_tree().get_first_node_in_group("ui_iron")
	ui_crystal_label = get_tree().get_first_node_in_group("ui_crystal")	
	ui_sonar_label = get_tree().get_first_node_in_group("ui_sonar")
	ui_health_bar = get_tree().get_first_node_in_group("ui_health")
	hazard_layer = get_tree().get_first_node_in_group("hazards")
	ui_drill_dir_label = get_tree().get_first_node_in_group("ui_drill_dir")
	spawn_position = global_position
	health = max_health
# container for sonar markers (so we can clear them all at once)
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
	var save := SaveSystem.data
	if not save.is_empty():
		apply_player_save(save)
		
	drill_idle_sound.play()


func _physics_process(delta):

	print(
		"player global: ",
		global_position,
		" tile: ",
		world_to_tile(global_position)
	)
	handle_input()
	
	update_sonar_sweep(delta)
	if sonar_cooldown_timer > 0.0:
		sonar_cooldown_timer = max(0.0, sonar_cooldown_timer - delta)
	check_hazard_contact(delta)
	update_health(delta)
	
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

	if ui_money_label:
		ui_money_label.text = "$" + str(money)	

	if ui_cargo_label:
		ui_cargo_label.text = "Cargo: " + str(cargo) + " / " + str(max_cargo)
		
	if ui_copper_label:
		ui_copper_label.text = "Copper: " + str(resources["copper"])

	if ui_iron_label:
		ui_iron_label.text = "Iron: " + str(resources["iron"])

	if ui_crystal_label:
		ui_crystal_label.text = "Crystal: " + str(resources["crystal"])
		
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
			
	current_depth = int(global_position.y / 16)
	update_player_light()
	update_darkness()
	
	if terrain.has_method("set_depth_tint"):
		terrain.set_depth_tint(current_depth)		
	
	
	terrain.update_fog(global_position)
	update_camera_shake()
	_update_cable_visual()


func handle_input():

	var was_drilling = is_drilling

	is_drilling = Input.is_action_pressed("ui_accept")

	# Gear controls
	if Input.is_action_just_pressed("ui_page_up"):
		drill_gear = min(drill_gear + 1, 3)

	if Input.is_action_just_pressed("ui_page_down"):
		drill_gear = max(drill_gear - 1, 1)

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

	if Input.is_action_just_pressed("cable_toggle"):
		# only allow toggling while standing inside the refuel zone
		if can_upgrade:    # can_upgrade is true while inside refuel zone
			toggle_cable()


func handle_movement(delta):

	if cable_engaged:
		_handle_cable_movement(delta)
	else:
		_handle_free_movement(delta)

func world_to_tile(pos: Vector2) -> Vector2i:
	var local_pos = terrain.to_local(pos)
	return terrain.local_to_map(local_pos)

func drill(delta):

	drill_timer += delta

	if drill_timer < drill_interval:
		return

	drill_timer = 0.0

	# fuel usage scales with gear
	fuel -= fuel_drain_drill * drill_gear * delta

	# compute drill targets based on direction
	var perpendicular_offset: int = 6
	var depth_offset: int = 10

	var target_a: Vector2
	var target_b: Vector2

	match drill_direction:

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

	# try terrain first
	var tile_data: Vector2i = terrain.get_cell_atlas_coords(tile_pos)
	var source_layer: TileMapLayer = terrain

	# if terrain is empty here, check hazard layer
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


func spawn_drill_particles(tile_pos, tile_data):

	if not drill_particles:
		return

	var world_pos = terrain.map_to_local(tile_pos)

	drill_particles.global_position = terrain.to_global(world_pos)

	match tile_data:

		Vector2i(0, 0):
			drill_particles.modulate = Color.SADDLE_BROWN

		Vector2i(1, 0):
			drill_particles.modulate = Color.GRAY

		Vector2i(2, 0):
			drill_particles.modulate = Color.DIM_GRAY

		Vector2i(3, 0):
			drill_particles.modulate = Color.GOLDENROD

		Vector2i(4, 0):
			drill_particles.modulate = Color.ORANGE

		Vector2i(5, 0):
			drill_particles.modulate = Color.LIGHT_SLATE_GRAY

		Vector2i(6, 0):
			drill_particles.modulate = Color.CYAN

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

	match tile_data:

		Vector2i(0, 0):
			drill_sound.pitch_scale = 1.0

		Vector2i(1, 0):
			drill_sound.pitch_scale = 0.9

		Vector2i(2, 0):
			drill_sound.pitch_scale = 0.7

		Vector2i(3, 0):
			drill_sound.pitch_scale = 1.1

		Vector2i(4, 0):
			drill_sound.pitch_scale = 1.15

		Vector2i(5, 0):
			drill_sound.pitch_scale = 0.85

		Vector2i(6, 0):
			drill_sound.pitch_scale = 1.3

	drill_sound.play()


func play_impact_sound(tile_data):

	match tile_data:

		Vector2i(0, 0):
			drill_impact_sound.stream = dirt_break_sound

		Vector2i(1, 0):
			drill_impact_sound.stream = stone_break_sound

		Vector2i(2, 0):
			drill_impact_sound.stream = hard_stone_break_sound

		Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0):
			drill_impact_sound.stream = metal_break_sound

		Vector2i(6, 0):
			drill_impact_sound.stream = crystal_break_sound

		_:
			return

	drill_impact_sound.pitch_scale = randf_range(0.92, 1.08)

	drill_impact_sound.play()
	

func update_player_light():

	if not player_light:
		return

	# surface = weak light
	# deep underground = strong light

	var t = clamp((current_depth - 5) / 60.0, 0.0, 1.0)

	player_light.energy = lerp(0.15, 1.4, t)

func update_darkness():

	if not darkness_overlay:
		return

	# starts darkening after surface
	var t = clamp((current_depth - 5) / 120.0, 0.0, 1.0)

	# brightness range
	var brightness = lerp(1.0, 0.18, t)

	darkness_overlay.color = Color(
		brightness,
		brightness,
		brightness,
		1.0
	)


func use_sonar() -> void:

	if sonar_cooldown_timer > 0.0 or sonar_active:
		return

	sonar_cooldown_timer = sonar_cooldown

	# clear leftover markers from a previous ping
	for child in sonar_markers_container.get_children():
		child.queue_free()

	sonar_active = true
	sonar_sweep_time = 0.0
	sonar_last_radius = 0.0
	sonar_center_tile = world_to_tile(global_position)

	print("Sonar sweep started")

func spawn_sonar_marker(tile_pos: Vector2i, color: Color) -> void:

	var marker := Sprite2D.new()

	# build a small bright square texture procedurally
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(color)
	marker.texture = ImageTexture.create_from_image(img)

	# position at the tile's center, in world space
	var local_pos: Vector2 = terrain.map_to_local(tile_pos)
	marker.global_position = terrain.to_global(local_pos)

	# pulsing tween for visibility through fog
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

	# ease-out so the ring decelerates as it reaches max range (feels natural)
	var eased: float = 1.0 - pow(1.0 - t, 2.0)

	var current_radius: float = eased * float(sonar_range)

	# stamp the new ring band into the terrain's reveal dict
	if terrain.has_method("sonar_reveal_ring"):
		terrain.sonar_reveal_ring(
			sonar_center_tile,
			sonar_last_radius,
			current_radius,
			sonar_terrain_duration
		)

	# spawn resource markers for any new valuable tiles in the band
	spawn_markers_in_ring(sonar_last_radius, current_radius)

	sonar_last_radius = current_radius

	if t >= 1.0:
		sonar_active = false

		# auto-clear markers after the linger duration
		get_tree().create_timer(sonar_marker_duration).timeout.connect(clear_sonar_markers)
		
func spawn_markers_in_ring(inner: float, outer: float) -> void:

	var r_int: int = int(ceil(outer))

	for x in range(sonar_center_tile.x - r_int, sonar_center_tile.x + r_int + 1):
		for y in range(sonar_center_tile.y - r_int, sonar_center_tile.y + r_int + 1):

			var pos := Vector2i(x, y)
			var dist: float = sonar_center_tile.distance_to(pos)

			if dist < inner or dist > outer:
				continue

			# check terrain first
			var tile: Vector2i = terrain.get_cell_atlas_coords(pos)

			# fall back to hazard layer
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

	# camera shake on hit
	shake_strength = max(shake_strength, amount * 0.15)

	print("Took ", amount, " damage from ", source, " | HP: ", health)

	if health <= 0.0:
		die()
		
func die() -> void:

	is_dead = true
	health = 0.0

	print("=== PLAYER DIED ===")

	# wipe cargo and carried resources (money stays - it's in the bank)
	cargo = 0
	ore = 0
	resources["copper"] = 0
	resources["iron"] = 0
	resources["crystal"] = 0

	# brief pause then respawn
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
		Vector2(-6, -6),
		Vector2(6, -6),
		Vector2(-6, 6),
		Vector2(6, 6),
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

	# red flash sprite tint when hit
	if damage_flash_timer > 0.0:
		damage_flash_timer -= delta
		$Sprite2D.modulate = Color(1.5, 0.4, 0.4, 1.0)
	else:
		$Sprite2D.modulate = Color.WHITE


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
	max_cable_length = save.get("max_cable_length", 1200.0)
	max_fuel = save.get("max_fuel", 100.0)
	if save.has("drill_direction"):
		var d: Array = save["drill_direction"]
		drill_direction = Vector2i(int(d[0]), int(d[1]))
		
	if save.has("resources"):
		for key in save["resources"].keys():
			resources[key] = int(save["resources"][key])


func _handle_swivel_input() -> void:

	# tier 2: must be stationary AND not drilling
	if drill_swivel_tier == 2:
		if is_drilling:
			return
		if velocity.length() > 0.1:
			return

	# tier 3: no restrictions

	if Input.is_action_just_pressed("drill_left"):
		drill_direction = Vector2i.LEFT

	elif Input.is_action_just_pressed("drill_down"):
		drill_direction = Vector2i.DOWN

	elif Input.is_action_just_pressed("drill_right"):
		drill_direction = Vector2i.RIGHT

func toggle_cable() -> void:

	cable_engaged = not cable_engaged
	_cable_wrap_points.clear()

	if cable_engaged:
		_cable_anchor = _find_refuel_anchor()
		_cable_length = min(global_position.distance_to(_cable_anchor), max_cable_length)

func _find_refuel_anchor() -> Vector2:

	var refuel := get_tree().get_first_node_in_group("refuel_zone")
	if not refuel:
		return Vector2(0, 0)

	# prefer the visible sprite as the anchor, fall back to the area origin
	var sprite := refuel.get_node_or_null("Sprite2D") as Node2D
	if sprite:
		return sprite.global_position

	return refuel.global_position

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

	if direction_x != 0:
		last_direction = Vector2(direction_x, 0)


func _get_effective_anchor() -> Vector2:
	return _cable_wrap_points.back() if _cable_wrap_points.size() > 0 else _cable_anchor

func _find_wrap_corner(hit_pos: Vector2, hit_normal: Vector2, from_anchor: Vector2) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	var tile_pos: Vector2i = terrain.local_to_map(terrain.to_local(hit_pos - hit_normal * 1.0))
	var half := Vector2(terrain.tile_set.tile_size) * 0.5
	var tile_center: Vector2 = terrain.to_global(terrain.map_to_local(tile_pos))

	var corners := [
		tile_center + Vector2(-half.x, -half.y),
		tile_center + Vector2( half.x, -half.y),
		tile_center + Vector2(-half.x,  half.y),
		tile_center + Vector2( half.x,  half.y),
	]

	var best_corner := hit_pos
	var best_dist := INF
	for c: Vector2 in corners:
		var q := PhysicsRayQueryParameters2D.create(from_anchor, c)
		q.exclude = [self]
		if not space_state.intersect_ray(q).is_empty():
			continue
		var d := c.distance_to(hit_pos)
		if d < best_dist:
			best_dist = d
			best_corner = c
	return best_corner

func _update_cable_wrap_points() -> void:
	var space_state := get_world_2d().direct_space_state

	# Unwrap: remove the most recent wrap point if the previous anchor now has
	# line-of-sight to the player (i.e. the corner is no longer in the way).
	while _cable_wrap_points.size() > 0:
		var prev: Vector2 = _cable_wrap_points[-2] if _cable_wrap_points.size() > 1 else _cable_anchor
		var unwrap_q := PhysicsRayQueryParameters2D.create(prev, global_position)
		unwrap_q.exclude = [self]
		if space_state.intersect_ray(unwrap_q).is_empty():
			_cable_wrap_points.pop_back()
		else:
			break

	# Wrap: if the direct path from the current effective anchor to the player
	# is blocked, find the tile corner the cable bends around.
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

	_update_cable_wrap_points()

	var direction_x: float = Input.get_axis("ui_left", "ui_right")
	is_thrusting = Input.is_action_pressed("ui_up") and fuel > 0.0

	# Player moves freely under normal physics. The cable only acts when taut.
	velocity.x = direction_x * move_speed

	if is_thrusting:
		velocity.y -= thruster_force * delta
		fuel -= thruster_fuel_drain * delta
	else:
		velocity.y += gravity * delta

	velocity.y = clamp(velocity.y, -max_fall_speed, max_fall_speed)

	if abs(direction_x) > 0.0:
		fuel -= fuel_drain_move * delta

	move_and_slide()

	if direction_x != 0:
		last_direction = Vector2(direction_x, 0)

	# Rope constraint: if the total path length through all wrap corners exceeds
	# the cable length, pull the player back along the last segment and cancel
	# any velocity component that would stretch the rope further.
	var rope_len := _get_rope_path_length()
	if rope_len > _cable_length:
		var ea := _get_effective_anchor()
		var to_player := global_position - ea
		var seg := to_player.length()
		if seg > 0.001:
			var rope_dir := to_player / seg
			global_position -= rope_dir * (rope_len - _cable_length)
			var radial_vel := velocity.dot(rope_dir)
			if radial_vel > 0.0:
				velocity -= rope_dir * radial_vel

func _update_cable_visual() -> void:

	var cable_line: Line2D = get_node_or_null("CableLine")
	if not cable_line:
		return

	if cable_engaged:
		cable_line.visible = true
		cable_line.clear_points()
		cable_line.add_point(to_local(_cable_anchor))
		for wp: Vector2 in _cable_wrap_points:
			cable_line.add_point(to_local(wp))
		cable_line.add_point(Vector2.ZERO)
	else:
		cable_line.visible = false