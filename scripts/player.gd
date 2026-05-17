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
var ui_upgrade_label
var ui_cargo_label
var ui_copper_label
var ui_iron_label
var ui_crystal_label
var ui_upgrade_title
var ui_upgrade_cost
var ui_upgrade_resources
var ui_sonar_label

var drill_particles

var camera
var shake_strength = 0.0

var drill_sound
var drill_idle_sound
var drill_loop_sound
var drill_impact_sound

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
	ui_upgrade_label = get_tree().get_first_node_in_group("ui_upgrade")
	ui_cargo_label = get_tree().get_first_node_in_group("ui_cargo")
	ui_copper_label = get_tree().get_first_node_in_group("ui_copper")
	ui_iron_label = get_tree().get_first_node_in_group("ui_iron")
	ui_crystal_label = get_tree().get_first_node_in_group("ui_crystal")
	ui_upgrade_title = get_tree().get_first_node_in_group("ui_upgrade_title")
	ui_upgrade_cost = get_tree().get_first_node_in_group("ui_upgrade_cost")
	ui_upgrade_resources = get_tree().get_first_node_in_group("ui_upgrade_resources")
	ui_sonar_label = get_tree().get_first_node_in_group("ui_sonar")
	ui_health_bar = get_tree().get_first_node_in_group("ui_health")
	hazard_layer = get_tree().get_first_node_in_group("hazards")
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

	if ui_upgrade_label:
		ui_upgrade_label.text = "Power: " + str(drill_power) + " ($" + str(upgrade_cost) + ")"

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

	current_depth = int(global_position.y / 16)
	update_player_light()
	update_darkness()
	
	if terrain.has_method("set_depth_tint"):
		terrain.set_depth_tint(current_depth)		
	
	
	terrain.update_fog(global_position)
	update_upgrade_ui()
	update_camera_shake()


func handle_input():

	var was_drilling = is_drilling

	is_drilling = Input.is_action_pressed("ui_accept")

	# Gear controls
	if Input.is_action_just_pressed("ui_page_up"):
		drill_gear = min(drill_gear + 1, 3)

	if Input.is_action_just_pressed("ui_page_down"):
		drill_gear = max(drill_gear - 1, 1)
		
	if Input.is_action_just_pressed("sonar"):
		use_sonar()

	# Audio transitions
	if is_drilling and not was_drilling:

		drill_idle_sound.volume_db = -6
		drill_idle_sound.pitch_scale = 1.08

	elif not is_drilling and was_drilling:

		drill_idle_sound.volume_db = -12
		drill_idle_sound.pitch_scale = 1.0


func handle_movement(delta):

	var direction = Vector2.ZERO

	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	if direction.length() > 0:
		last_direction = direction.normalized()
		fuel -= fuel_drain_move * delta

	velocity = direction.normalized() * move_speed

	move_and_slide()
	print("pos: ", global_position, " vel: ", velocity, " on_floor: ", is_on_floor(), " on_wall: ", is_on_wall())


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

	# drill below player
	var left_tile = world_to_tile(global_position + Vector2(-6, 10))
	var right_tile = world_to_tile(global_position + Vector2(6, 10))

	try_break_tile(left_tile)
	try_break_tile(right_tile)
	
	print("player global: ", global_position)
	print("drill check left: ", global_position + Vector2(-6, 10), " -> tile ", world_to_tile(global_position + Vector2(-6, 10)))


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
	elif terrain_info.get("hazard") == null:
		# only count "ore" for non-hazard non-resource tiles
		ore += 1

	cargo += cargo_value

	source_layer.set_cell(tile_pos, -1)
	
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
	
func update_upgrade_ui():

	if not can_upgrade:

		ui_upgrade_title.text = ""
		ui_upgrade_cost.text = ""
		ui_upgrade_resources.text = ""

		return

	var next_level = drill_power + 1

	if not UpgradeData.DRILL_UPGRADES.has(next_level):

		ui_upgrade_title.text = "MAX POWER"
		ui_upgrade_cost.text = ""
		ui_upgrade_resources.text = ""

		return

	var data = UpgradeData.DRILL_UPGRADES[next_level]

	ui_upgrade_title.text = "DRILL POWER " + str(next_level)

	ui_upgrade_cost.text = "$" + str(money) + " / $" + str(data["money"])

	var resource_text = ""

	for resource_name in data["resources"]:

		var required = data["resources"][resource_name]
		var owned = resources.get(resource_name, 0)

		resource_text += (
			resource_name.capitalize()
			+ ": "
			+ str(owned)
			+ " / "
			+ str(required)
			+ "\n"
		)

	ui_upgrade_resources.text = resource_text
	
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
