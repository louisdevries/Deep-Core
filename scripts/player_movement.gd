extends CharacterBody2D

@export var move_speed = 200.0
@export var drill_interval = 0.15

@export var max_fuel = 100.0
@export var fuel_drain_move = 2.0
@export var fuel_drain_drill = 6.0

var fuel = 100.0

var terrain
var is_drilling = false
var drill_timer = 0.0

var last_direction = Vector2.DOWN

var drill_gear = 1
var drill_power = 1

var ui_fuel_bar
var ui_gear_label


# Atlas-based terrain definitions
var terrain_types = {
	Vector2i(1, 0): { "name": "Dirt", "required_power": 1 },
	Vector2i(0, 0): { "name": "Stone", "required_power": 3 },
	Vector2i(2, 0): { "name": "Ore", "required_power": 4 }
}


func _ready():
	terrain = get_tree().get_first_node_in_group("terrain")
	ui_fuel_bar = get_tree().get_first_node_in_group("ui_fuel")
	ui_gear_label = get_tree().get_first_node_in_group("ui_gear")


func _physics_process(delta):
	handle_input()

	if fuel <= 0:
		velocity = Vector2.ZERO
		return

	handle_movement(delta)

	if is_drilling:
		drill(delta)

	fuel = clamp(fuel, 0.0, max_fuel)
	
	if ui_fuel_bar:
		ui_fuel_bar.value = fuel

	if ui_gear_label:
		ui_gear_label.text = "Gear: " + str(drill_gear)


func handle_input():
	is_drilling = Input.is_action_pressed("ui_accept")

	if Input.is_action_just_pressed("ui_page_up"):
		drill_gear = min(drill_gear + 1, 3)

	if Input.is_action_just_pressed("ui_page_down"):
		drill_gear = max(drill_gear - 1, 1)


func handle_movement(delta):
	var direction = Vector2.ZERO

	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	if direction.length() > 0:
		last_direction = direction.normalized()
		fuel -= fuel_drain_move * delta

	velocity = direction.normalized() * move_speed
	move_and_slide()


# --- FIXED WORLD → TILE CONVERSION ---
func world_to_tile(pos: Vector2) -> Vector2i:
	var local_pos = terrain.to_local(pos)
	return terrain.local_to_map(local_pos)


func drill(delta):
	drill_timer += delta

	if drill_timer < drill_interval:
		return

	drill_timer = 0.0

	# fuel cost scales with gear
	fuel -= fuel_drain_drill * drill_gear * delta

	# correct alignment positions
	var left_tile = world_to_tile(global_position + Vector2(-6, 10))
	var right_tile = world_to_tile(global_position + Vector2(6, 10))

	try_break_tile(left_tile)
	try_break_tile(right_tile)


func try_break_tile(tile_pos: Vector2i):
	var tile_data = terrain.get_cell_atlas_coords(tile_pos)

	if tile_data == Vector2i(-1, -1):
		return

	if not terrain_types.has(tile_data):
		return

	var required_power = terrain_types[tile_data]["required_power"]
	var effective_power = drill_power + drill_gear

	if effective_power >= required_power:
		terrain.erase_cell(tile_pos)
