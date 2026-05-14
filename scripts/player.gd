# player.gd
extends CharacterBody2D

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

var ui_fuel_bar
var ui_gear_label
var ui_money_label
var ui_upgrade_label
var drill_particles

var camera
var shake_strength = 0.0
var drill_sound

var cargo = 0
var max_cargo = 20
var ui_cargo_label

var drill_idle_sound
var drill_loop_sound
var drill_impact_sound

const TILE_SOURCE_ID = 2

# Atlas terrain definitions
var terrain_types = {

	Vector2i(0, 0): {
		"name": "Dirt",
		"required_power": 1,
		"cargo": 0
	},

	Vector2i(1, 0): {
		"name": "Stone",
		"required_power": 2,
		"cargo": 0
	},

	Vector2i(2, 0): {
		"name": "Hard Stone",
		"required_power": 4,
		"cargo": 0
	},

	Vector2i(3, 0): {
		"name": "Basic Ore",
		"required_power": 2,
		"cargo": 1
	},

	Vector2i(4, 0): {
		"name": "Copper",
		"required_power": 3,
		"cargo": 2
	},

	Vector2i(5, 0): {
		"name": "Iron",
		"required_power": 5,
		"cargo": 3
	},

	Vector2i(6, 0): {
		"name": "Crystal",
		"required_power": 6,
		"cargo": 5
	}
}


func _ready():
	terrain = get_tree().get_first_node_in_group("terrain")

	ui_fuel_bar = get_tree().get_first_node_in_group("ui_fuel")
	ui_gear_label = get_tree().get_first_node_in_group("ui_gear")
	ui_money_label = get_tree().get_first_node_in_group("ui_money")
	ui_upgrade_label = get_tree().get_first_node_in_group("ui_upgrade")
	ui_cargo_label = get_tree().get_first_node_in_group("ui_cargo")
	drill_particles = $DrillParticles
	camera = $Camera2D
	drill_sound = $DrillSound
	drill_idle_sound = $DrillIdleSound
	drill_impact_sound = $DrillImpactSound
	
	drill_idle_sound.play()


func _physics_process(delta):

	handle_input()

	if fuel <= 0:
		velocity = Vector2.ZERO
		return

	handle_movement(delta)

	if is_drilling:
		drill_idle_sound.pitch_scale = 1.0 + (drill_gear * 0.03)
		drill(delta)

	fuel = clamp(fuel, 0.0, max_fuel)

	# UI updates
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
		
	current_depth = int(global_position.y / 16)

	if terrain.has_method("set_depth_tint"):
		terrain.set_depth_tint(current_depth)
		
	update_camera_shake()	

func handle_input():

	var was_drilling = is_drilling

	is_drilling = Input.is_action_pressed("ui_accept")

	# Gear controls
	if Input.is_action_just_pressed("ui_page_up"):
		drill_gear = min(drill_gear + 1, 3)

	if Input.is_action_just_pressed("ui_page_down"):
		drill_gear = max(drill_gear - 1, 1)

	# Audio transitions
	if is_drilling and not was_drilling:

		# drilling started
		drill_idle_sound.volume_db = -6
		drill_idle_sound.pitch_scale = 1.08

	elif not is_drilling and was_drilling:

		# drilling stopped
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


func try_break_tile(tile_pos: Vector2i):
	var tile_data = terrain.get_cell_atlas_coords(tile_pos)
	print("--- try_break_tile ---")
	print("tile_pos: ", tile_pos)
	print("tile_data: ", tile_data)
	
	if tile_data == Vector2i(-1, -1):
		print("BAIL: empty cell")
		return

	if not terrain_types.has(tile_data):
		print("BAIL: tile not in terrain_types")
		return

	var required_power = terrain_types[tile_data]["required_power"]
	var effective_power = drill_power + drill_gear
	print("required_power: ", required_power, " effective_power: ", effective_power)

	if effective_power < required_power:
		print("BAIL: not enough power")
		return

	var cargo_value = terrain_types[tile_data]["cargo"]
	print("cargo: ", cargo, "/", max_cargo, " cargo_value: ", cargo_value)

	if cargo_value > 0 and cargo + cargo_value > max_cargo:
		print("BAIL: cargo full")
		return

	print("BREAKING TILE")
	spawn_drill_particles(tile_pos, tile_data)
	shake_strength = required_power * 0.6
	play_drill_sound(tile_data)
	play_impact_sound(tile_data)

	if cargo_value > 0:
		ore += 1
	cargo += cargo_value

	terrain.set_cell(tile_pos, -1)

func spawn_drill_particles(tile_pos, tile_data):
	if not drill_particles:
		return

	var world_pos = terrain.map_to_local(tile_pos)

	drill_particles.global_position = terrain.to_global(world_pos)

	# Different colors per material
	match tile_data:

		Vector2i(0, 0): # dirt
			drill_particles.modulate = Color.SADDLE_BROWN

		Vector2i(1, 0): # stone
			drill_particles.modulate = Color.GRAY

		Vector2i(2, 0): # hard stone
			drill_particles.modulate = Color.DIM_GRAY

		Vector2i(3, 0): # basic ore
			drill_particles.modulate = Color.GOLDENROD

		Vector2i(4, 0): # copper
			drill_particles.modulate = Color.ORANGE

		Vector2i(5, 0): # iron
			drill_particles.modulate = Color.LIGHT_SLATE_GRAY

		Vector2i(6, 0): # crystal
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

		Vector2i(0, 0): # dirt
			drill_sound.pitch_scale = 1.0

		Vector2i(1, 0): # stone
			drill_sound.pitch_scale = 0.9

		Vector2i(2, 0): # hard stone
			drill_sound.pitch_scale = 0.7

		Vector2i(3, 0): # ore
			drill_sound.pitch_scale = 1.1

		Vector2i(4, 0): # copper
			drill_sound.pitch_scale = 1.15

		Vector2i(5, 0): # iron
			drill_sound.pitch_scale = 0.85

		Vector2i(6, 0): # crystal
			drill_sound.pitch_scale = 1.3

	drill_sound.play()
	
func play_impact_sound(tile_data):

	match tile_data:

		Vector2i(0, 0): # dirt
			drill_impact_sound.stream = dirt_break_sound

		Vector2i(1, 0): # stone
			drill_impact_sound.stream = stone_break_sound

		Vector2i(2, 0): # hard stone
			drill_impact_sound.stream = hard_stone_break_sound

		Vector2i(3, 0), Vector2i(4, 0): # copper / iron
			drill_impact_sound.stream = metal_break_sound

		Vector2i(6, 0): # crystal
			drill_impact_sound.stream = crystal_break_sound

		_:
			return

	drill_impact_sound.pitch_scale = randf_range(0.92, 1.08)
	drill_impact_sound.play()
