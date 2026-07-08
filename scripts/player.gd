# player.gd
extends CharacterBody2D

const TerrainData = preload("res://scripts/data/terrain_data.gd")
const UpgradeData = preload("res://scripts/data/upgrade_data.gd")
const ResourceData = preload("res://scripts/data/resource_data.gd")
const ItemData    = preload("res://scripts/data/item_data.gd")

const CRACK_TEXTURES: Array = [
	preload("res://assets/Art/Environment/crack_light.png"),
	preload("res://assets/Art/Environment/crack_medium.png"),
	preload("res://assets/Art/Environment/crack_heavy.png"),
]
const CRACK_THRESHOLDS: Array[float] = [0.15, 0.45, 0.75]

@export var move_speed = 200.0

@export var max_fuel = 100.0
@export var fuel_drain_move = 0.0
@export var fuel_drain_drill = 4.0

@export var ore_sell_value = 10

@export var dirt_break_sound: AudioStream
@export var stone_break_sound: AudioStream
@export var hard_stone_break_sound: AudioStream
@export var metal_break_sound: AudioStream
@export var crystal_break_sound: AudioStream

# GRAVITY
@export var gravity: float = 800.0
@export var max_fall_speed: float = 600.0
@export var thruster_force: float = 200.0
@export var thruster_fuel_drain: float = 8.0
var is_thrusting: bool = false

var hazard_layer: TileMapLayer

const TILE_SOURCE_ID = 1

# Break time by material_tier (index 0 unused; tier 1-6)
const MATERIAL_BREAK_TIMES: Array[float] = [0.0, 1.0, 2.0, 3.5, 5.0, 7.5, 10.0]

# Time multiplier by drill_tier (0=Bronze … 5=Plasma). Lower = faster.
const DRILL_TIME_MULT: Array[float] = [1.0, 0.85, 0.7, 0.55, 0.4, 0.25]

# Break-time factor by gear (index 0 unused; gear 1-3).
# Gear 2/3 burn more fuel but also drill more slowly (factor > 1).
const GEAR_TIME_FACTOR: Array[float] = [0.0, 1.0, 1.515, 1.205]

var fuel = 100.0

var terrain
var is_drilling = false

# Per-tile break-time progress (tile_pos → accumulated seconds)
var _tile_progress: Dictionary = {}
# Crack overlay sprites (tile_pos → Sprite2D)
var _tile_crack_sprites: Dictionary = {}

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

# FALL DAMAGE
var _fall_damage_threshold: float = 350.0
var _fall_damage_multiplier: float = 0.25

# Multi-drill: 1 = single, 2 = dual, 3 = triple
var drill_count: int = 1
var permanent_drills: Array[Vector2i] = []   # which sides are permanently mounted

var hull_tier: int = 0
var heat_shield_tier: int = 0
var cabin_tier: int = 0

# RESPAWN
var spawn_position: Vector2

# ITEM INVENTORY — one-time use tools
var item_inventory: Dictionary = {}
var quick_slots: Array = ["", ""]

# PHASE BEACON
var has_active_beacon: bool = false
var _beacon_node: Node2D = null

# UI
var ui_health_bar

var furnace_slot_count: int = 1
var furnace_level: int = 1
var drill_tier: int = 0   # 0=bronze 1=steel 2=titanium 3=diamond 4=plasma

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

# HAZARD AMBIENT SFX (looping, volume-faded)
var _hazard_sound_lava: AudioStreamPlayer = null
var _hazard_sound_gas: AudioStreamPlayer = null
var _hazard_sound_acid: AudioStreamPlayer = null
var _hazard_sound_freezing: AudioStreamPlayer = null
var _is_in_lava: bool = false

# DAMAGE SFX
var _damage_sfx: AudioStreamPlayer = null
var _lava_damage_sfx: AudioStreamPlayer = null

# AMBIENCE LAYERS (depth-based crossfade)
var _ambience_layers: Array = []

# SONAR SFX
var _sonar_sfx: AudioStreamPlayer = null

# DRILL SWIVEL
var drill_swivel_tier: int = 1
var drill_direction: Vector2i = Vector2i.DOWN
var has_left_drill: bool = false
var has_right_drill: bool = false

const DRILL_SWITCH_DELAY: float = 3.0
var _pending_drill_dir: Vector2i = Vector2i.DOWN
var _switching_drill: bool = false
var _drill_switch_progress: float = 0.0
var _switch_bar: Node2D = null

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

var godmode: bool = false
var noclip: bool = false

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

	spawn_position = global_position
	health         = max_health

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

	drill_idle_sound.bus = "SFX"
	drill_idle_sound.finished.connect(_on_drill_idle_finished)
	drill_idle_sound.volume_db = -20.0
	drill_idle_sound.pitch_scale = 0.85
	drill_idle_sound.play()

	drill_impact_sound.bus = "SFX"

	# Hazard ambient SFX
	_hazard_sound_lava     = _make_sfx_loop("res://assets/Audio/SFX/lava.wav")
	_hazard_sound_gas      = _make_sfx_loop("res://assets/Audio/SFX/Gas.wav")
	_hazard_sound_acid     = _make_sfx_loop("res://assets/Audio/SFX/Acid.wav")
	_hazard_sound_freezing = _make_sfx_loop("res://assets/Audio/SFX/Freezing.wav")

	# Damage SFX
	_damage_sfx = AudioStreamPlayer.new()
	_damage_sfx.stream = load("res://assets/Audio/SFX/Damage.wav")
	_damage_sfx.bus = "SFX"
	add_child(_damage_sfx)

	_lava_damage_sfx = AudioStreamPlayer.new()
	_lava_damage_sfx.stream = load("res://assets/Audio/SFX/lava_damage.wav")
	_lava_damage_sfx.bus = "SFX"
	add_child(_lava_damage_sfx)

	# Sonar SFX
	_sonar_sfx = AudioStreamPlayer.new()
	_sonar_sfx.stream = load("res://assets/Audio/SFX/echo.wav")
	_sonar_sfx.bus = "SFX"
	add_child(_sonar_sfx)

	# Ambience layers (depth-based crossfade)
	for i in range(1, 4):
		var ap := AudioStreamPlayer.new()
		ap.stream = load("res://assets/Audio/Ambience/Layer_%d.mp3" % i)
		ap.bus = "Music"
		ap.volume_db = -80.0
		ap.finished.connect(ap.play)
		add_child(ap)
		ap.play()
		_ambience_layers.append(ap)

	_switch_bar = Node2D.new()
	_switch_bar.set_script(load("res://scripts/drill_switch_bar.gd"))
	_switch_bar.z_index = 8
	add_child(_switch_bar)

	_setup_player_sprites()


func _physics_process(delta):

	handle_input()
	_update_drill_switch(delta)

	update_sonar_sweep(delta)
	if sonar_cooldown_timer > 0.0:
		sonar_cooldown_timer = max(0.0, sonar_cooldown_timer - delta)
	check_hazard_contact(delta)
	update_health(delta)

	if ui_money_label:
		ui_money_label.text = "$" + str(money)

	if is_dead:
		velocity = Vector2.ZERO
		return

	handle_movement(delta)
	if noclip:
	# bypass physics, just move freely
		var direction: Vector2 = Vector2.ZERO
		direction.x = Input.get_axis("ui_left", "ui_right")
		direction.y = Input.get_axis("ui_up", "ui_down")
		global_position += direction * 400.0 * delta
		return

# ... normal movement

	_update_drill_audio()
	_update_ambience_audio(delta)

	if is_drilling and fuel > 0:
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
			
	_update_all_sprites()
	current_depth = int(global_position.y / 16)
	update_player_light()
	update_darkness()

	if terrain.has_method("set_depth_tint"):
		terrain.set_depth_tint(current_depth)

	terrain.update_fog(global_position)
	update_camera_shake()


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

	if not is_drilling and was_drilling:
		_clear_all_cracks()

	# DRILL DIRECTION (swivel system)
	if drill_swivel_tier >= 2:
		_handle_swivel_input()	


func handle_movement(delta: float) -> void:

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

	velocity.y = clamp(velocity.y, -max_fall_speed, max_fall_speed)

	var pre_land_vel_y := velocity.y
	var was_on_floor := is_on_floor()

	move_and_slide()
	_clamp_to_camera_bounds()

	if is_on_floor() and not was_on_floor and pre_land_vel_y > _fall_damage_threshold:
		var excess := pre_land_vel_y - _fall_damage_threshold
		take_damage(clampf(excess * _fall_damage_multiplier, 0.0, max_health), "fall")

	if direction_x != 0:
		last_direction = Vector2(direction_x, 0)


func world_to_tile(pos: Vector2) -> Vector2i:
	var local_pos = terrain.to_local(pos)
	return terrain.local_to_map(local_pos)


func drill(delta: float) -> void:

	# Fuel drains continuously while drilling
	var fuel_mult: float = 1.0
	match drill_gear:
		2: fuel_mult = 3.0
		3: fuel_mult = 5.0
	fuel -= fuel_drain_drill * fuel_mult * delta

	# Accumulate progress on every targeted tile this frame
	var active_targets: Array = _compute_drill_targets()  # Array of {pos, flip_h, rot}
	var active_positions: Array[Vector2i] = []
	for t in active_targets:
		active_positions.append(t["pos"])
		_advance_drill_tile(t["pos"], t["flip_h"], t["rot"], delta)

	# Drop stale tiles (no longer being targeted)
	var stale: Array = []
	for tile_pos in _tile_progress.keys():
		if not (tile_pos in active_positions):
			stale.append(tile_pos)
	for tile_pos in stale:
		_tile_progress.erase(tile_pos)
		_free_crack_sprite(tile_pos)


func _compute_drill_targets() -> Array:
	var targets: Array = []
	const P_OFF: int = 8
	const D_OFF: int = 20
	for dir: Vector2i in _get_active_drill_directions():
		match dir:
			Vector2i.DOWN:
				# Left tile: crack "/" as-is; Right tile: flip_h → "\"
				targets.append({"pos": world_to_tile(global_position + Vector2(-P_OFF,  D_OFF)), "flip_h": false, "rot": 0.0})
				targets.append({"pos": world_to_tile(global_position + Vector2( P_OFF,  D_OFF)), "flip_h": true,  "rot": 0.0})
			Vector2i.LEFT:
				# Top tile: rotate 90°; Bottom tile: rotate -90°
				targets.append({"pos": world_to_tile(global_position + Vector2(-D_OFF, -P_OFF)), "flip_h": false, "rot":  90.0})
				targets.append({"pos": world_to_tile(global_position + Vector2(-D_OFF,  P_OFF)), "flip_h": false, "rot": -90.0})
			Vector2i.RIGHT:
				targets.append({"pos": world_to_tile(global_position + Vector2( D_OFF, -P_OFF)), "flip_h": false, "rot": -90.0})
				targets.append({"pos": world_to_tile(global_position + Vector2( D_OFF,  P_OFF)), "flip_h": false, "rot":  90.0})
	return targets


func _advance_drill_tile(tile_pos: Vector2i, flip_h: bool, rot: float, delta: float) -> void:

	var tile_data: Vector2i = terrain.get_cell_atlas_coords(tile_pos)
	var source_layer: TileMapLayer = terrain

	if tile_data == Vector2i(-1, -1) and hazard_layer:
		tile_data    = hazard_layer.get_cell_atlas_coords(tile_pos)
		source_layer = hazard_layer

	if tile_data == Vector2i(-1, -1):
		return
	if not TerrainData.TERRAIN_TYPES.has(tile_data):
		return

	var terrain_info: Dictionary = TerrainData.TERRAIN_TYPES[tile_data]
	var material_tier: int = terrain_info.get("material_tier", 1)

	var max_breakable_tier: int = drill_tier + 1
	if drill_gear >= 2:
		max_breakable_tier += 1
	if max_breakable_tier < material_tier:
		return

	var base_time: float   = MATERIAL_BREAK_TIMES[clampi(material_tier, 0, MATERIAL_BREAK_TIMES.size() - 1)]
	var drill_mult: float  = DRILL_TIME_MULT[clampi(drill_tier, 0, DRILL_TIME_MULT.size() - 1)]
	var gear_factor: float = GEAR_TIME_FACTOR[clampi(drill_gear, 1, GEAR_TIME_FACTOR.size() - 1)]
	var break_time: float  = base_time * drill_mult * gear_factor

	var is_new: bool = not _tile_progress.has(tile_pos)
	if is_new:
		_tile_progress[tile_pos] = 0.0
		spawn_drill_particles(tile_pos, tile_data)
		# per-tile drill sound removed — continuous ambient loop handles this
		_create_crack_sprite(tile_pos, flip_h, rot)
	else:
		if drill_particles:
			drill_particles.global_position = terrain.to_global(terrain.map_to_local(tile_pos))

	shake_strength = max(shake_strength, material_tier * 0.5)
	_tile_progress[tile_pos] += delta

	# Update crack overlay texture based on progress ratio
	var ratio: float = _tile_progress[tile_pos] / break_time
	_update_crack_sprite(tile_pos, ratio)

	if _tile_progress[tile_pos] >= break_time:
		_free_crack_sprite(tile_pos)
		_tile_progress.erase(tile_pos)
		_execute_break(tile_pos, tile_data, source_layer, terrain_info)


func _create_crack_sprite(tile_pos: Vector2i, flip_h: bool, rot: float) -> void:
	var sprite := Sprite2D.new()
	sprite.flip_h            = flip_h
	sprite.rotation_degrees  = rot
	sprite.z_index           = 5
	sprite.centered          = true
	# Auto-scale to fit a 16×16 tile using the light texture as reference
	var ref_tex: Texture2D = CRACK_TEXTURES[0]
	if ref_tex and ref_tex.get_width() > 0:
		sprite.scale = Vector2(16.0 / ref_tex.get_width(), 16.0 / ref_tex.get_height())
	sprite.global_position   = terrain.to_global(terrain.map_to_local(tile_pos))
	get_tree().current_scene.add_child(sprite)
	_tile_crack_sprites[tile_pos] = sprite


func _update_crack_sprite(tile_pos: Vector2i, ratio: float) -> void:
	if not _tile_crack_sprites.has(tile_pos):
		return
	var sprite: Sprite2D = _tile_crack_sprites[tile_pos]
	sprite.global_position = terrain.to_global(terrain.map_to_local(tile_pos))
	if ratio >= CRACK_THRESHOLDS[2]:
		sprite.texture = CRACK_TEXTURES[2]
	elif ratio >= CRACK_THRESHOLDS[1]:
		sprite.texture = CRACK_TEXTURES[1]
	elif ratio >= CRACK_THRESHOLDS[0]:
		sprite.texture = CRACK_TEXTURES[0]
	else:
		sprite.texture = null


func _free_crack_sprite(tile_pos: Vector2i) -> void:
	if _tile_crack_sprites.has(tile_pos):
		if is_instance_valid(_tile_crack_sprites[tile_pos]):
			_tile_crack_sprites[tile_pos].queue_free()
		_tile_crack_sprites.erase(tile_pos)


func _clear_all_cracks() -> void:
	for tile_pos in _tile_crack_sprites.keys():
		if is_instance_valid(_tile_crack_sprites[tile_pos]):
			_tile_crack_sprites[tile_pos].queue_free()
	_tile_crack_sprites.clear()
	_tile_progress.clear()


func _execute_break(tile_pos: Vector2i, tile_data: Vector2i, source_layer: TileMapLayer, terrain_info: Dictionary) -> void:

	play_impact_sound(tile_data)

	var resource_type = terrain_info["resource"]
	var cargo_value: int = terrain_info.get("cargo", 0)
	var cargo_full: bool = cargo_value > 0 and cargo + cargo_value > max_cargo

	if cargo_full:
		var world_pos: Vector2 = terrain.to_global(terrain.map_to_local(tile_pos))
		_spawn_floating_text("CARGO FULL", world_pos)
	else:
		if resource_type != null:
			if not resources.has(resource_type):
				resources[resource_type] = 0
			resources[resource_type] += 1
			var world_pos: Vector2 = terrain.to_global(terrain.map_to_local(tile_pos))
			var display: String = ResourceData.RESOURCES.get(resource_type, {}).get("display_name", resource_type)
			_spawn_floating_text("+1 " + display, world_pos)
		elif terrain_info.get("is_ore", false):
			ore += 1
			var world_pos: Vector2 = terrain.to_global(terrain.map_to_local(tile_pos))
			_spawn_floating_text("+1 Basic Ore", world_pos)

		cargo += cargo_value
	source_layer.set_cell(tile_pos, -1)

	if source_layer == terrain and terrain.has_method("mark_cleared"):
		terrain.mark_cleared(tile_pos)
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


func _on_drill_idle_finished() -> void:
	if drill_idle_sound:
		drill_idle_sound.play()


func _update_drill_audio() -> void:
	if not drill_idle_sound:
		return
	# Keep the stream alive — it should always be playing
	if not drill_idle_sound.is_playing():
		drill_idle_sound.play()
	if is_drilling:
		match drill_gear:
			1:
				drill_idle_sound.volume_db  = -8.0
				drill_idle_sound.pitch_scale = 1.0
			2:
				drill_idle_sound.volume_db  = -4.0
				drill_idle_sound.pitch_scale = 1.3
			3:
				drill_idle_sound.volume_db  = 0.0
				drill_idle_sound.pitch_scale = 1.7
	else:
		drill_idle_sound.volume_db  = -20.0
		drill_idle_sound.pitch_scale = 0.85


func _make_sfx_loop(path: String) -> AudioStreamPlayer:
	var ap := AudioStreamPlayer.new()
	ap.stream = load(path)
	ap.bus = "SFX"
	ap.volume_db = -80.0
	ap.finished.connect(ap.play)
	add_child(ap)
	ap.play()
	return ap


func _update_hazard_audio(in_lava: bool, in_gas: bool, in_acid: bool, in_ice: bool, delta: float) -> void:
	var speed := 20.0 * delta
	if _hazard_sound_lava:
		_hazard_sound_lava.volume_db = move_toward(_hazard_sound_lava.volume_db, -8.0 if in_lava else -80.0, speed)
	if _hazard_sound_gas:
		_hazard_sound_gas.volume_db = move_toward(_hazard_sound_gas.volume_db, -8.0 if in_gas else -80.0, speed)
	if _hazard_sound_acid:
		_hazard_sound_acid.volume_db = move_toward(_hazard_sound_acid.volume_db, -8.0 if in_acid else -80.0, speed)
	if _hazard_sound_freezing:
		_hazard_sound_freezing.volume_db = move_toward(_hazard_sound_freezing.volume_db, -8.0 if in_ice else -80.0, speed)


func _update_ambience_audio(delta: float) -> void:
	if _ambience_layers.size() < 3:
		return
	var depth := float(current_depth)
	# Layer 1: surface (full at 0-5, silent at depth 55+)
	var t1 := 1.0 - clampf((depth - 5.0) / 50.0, 0.0, 1.0)
	# Layer 2: mid-depth (peaks around depth 50, fades out by 120)
	var t2 := clampf(depth / 40.0, 0.0, 1.0) * (1.0 - clampf((depth - 80.0) / 40.0, 0.0, 1.0))
	# Layer 3: deep (fades in from depth 70-120)
	var t3 := clampf((depth - 70.0) / 50.0, 0.0, 1.0)
	var fade := 5.0 * delta
	_ambience_layers[0].volume_db = move_toward(_ambience_layers[0].volume_db, lerp(-40.0, -10.0, t1), fade)
	_ambience_layers[1].volume_db = move_toward(_ambience_layers[1].volume_db, lerp(-40.0, -10.0, t2), fade)
	_ambience_layers[2].volume_db = move_toward(_ambience_layers[2].volume_db, lerp(-40.0, -10.0, t3), fade)


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

	if _sonar_sfx:
		_sonar_sfx.play()

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
	if is_dead or godmode:
		return

	if source == "fall" and _damage_sfx and not _damage_sfx.is_playing():
		_damage_sfx.play()
	elif source == "hazard" and _is_in_lava and _lava_damage_sfx and not _lava_damage_sfx.is_playing():
		_lava_damage_sfx.play()

	# apply hull armor reduction to physical damage
	if source != "radiation" and source != "heat":
		var hull_reduction: float = _get_hull_reduction()
		amount *= (1.0 - hull_reduction)

	health -= amount
	time_since_damage = 0.0
	damage_flash_timer = 0.15

	shake_strength = max(shake_strength, amount * 0.15)

	if health <= 0.0:
		die()


func _get_hull_reduction() -> float:
	match hull_tier:
		0: return 0.0
		1: return 0.1     # 10% reduction
		2: return 0.25    # 25%
		3: return 0.4     # 40%
		_: return 0.6     # 60% (max tier)


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

	# Clear any active beacon
	if has_active_beacon and is_instance_valid(_beacon_node):
		_beacon_node.queue_free()
	_beacon_node      = null
	has_active_beacon = false
	_clear_all_cracks()

	get_tree().create_timer(1.5).timeout.connect(respawn)

func respawn() -> void:

	global_position = spawn_position
	velocity = Vector2.ZERO
	health = max_health
	fuel = max_fuel
	is_dead = false

	print("Respawned at base")


func check_hazard_contact(delta: float) -> void:

	if is_dead or godmode:
		_is_in_lava = false
		_update_hazard_audio(false, false, false, false, delta)
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
	var in_lava := false
	var in_gas := false
	var in_acid := false
	var in_ice := false

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

		match info["hazard"]:
			"lava":  in_lava = true
			"gas":   in_gas  = true
			"acid":  in_acid = true
			"ice":   in_ice  = true

	_is_in_lava = in_lava
	_update_hazard_audio(in_lava, in_gas, in_acid, in_ice, delta)

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
		_set_sprite_modulate(Color(1.5, 0.4, 0.4, 1.0))
	else:
		_set_sprite_modulate(Color.WHITE)


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
		"thruster_force": thruster_force,
		"furnace_slot_count": furnace_slot_count,
		"furnace_level": furnace_level,
		"drill_tier": drill_tier,
		"drill_count": drill_count,
		"has_left_drill": has_left_drill,
		"has_right_drill": has_right_drill,
		"storage": storage,
		"max_storage": max_storage,
		"item_inventory": item_inventory,
		"quick_slots": quick_slots,
		"drill_gear": drill_gear,
		"furnace": FurnaceSystem.save_data(),
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
	max_fuel = save.get("max_fuel", 100.0)
	thruster_force = save.get("thruster_force", 200.0)
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
	drill_tier = save.get("drill_tier", 0)
	drill_gear = save.get("drill_gear", 1)
	FurnaceSystem.slot_count = furnace_slot_count
	if save.has("drill_direction"):
		var d: Array = save["drill_direction"]
		drill_direction = Vector2i(int(d[0]), int(d[1]))

	if save.has("resources"):
		for key in save["resources"].keys():
			if not resources.has(key):
				resources[key] = 0
			resources[key] = int(save["resources"][key])

	if save.has("item_inventory"):
		item_inventory = {}
		for key in save["item_inventory"].keys():
			item_inventory[key] = int(save["item_inventory"][key])

	if save.has("quick_slots"):
		quick_slots = Array(save["quick_slots"])
		while quick_slots.size() < 2:
			quick_slots.append("")

	FurnaceSystem.load_from_save_data(save)

	var mc := get_tree().get_root().find_child("MobileControls", true, false)
	if mc and mc.has_method("_sync_gear_knob_to_player"):
		mc._sync_gear_knob_to_player()


func _handle_swivel_input() -> void:

	# tier 2: must be stationary AND not drilling
	if drill_swivel_tier == 2:
		if is_drilling:
			return
		if velocity.length() > 0.1:
			return

	# tier 3: no restrictions

	if Input.is_action_just_pressed("drill_left"):
		if not (Vector2i.LEFT in permanent_drills):
			request_drill_direction(Vector2i.LEFT)

	elif Input.is_action_just_pressed("drill_down"):
		request_drill_direction(Vector2i.DOWN)

	elif Input.is_action_just_pressed("drill_right"):
		if not (Vector2i.RIGHT in permanent_drills):
			request_drill_direction(Vector2i.RIGHT)


func request_drill_direction(new_dir: Vector2i) -> void:
	if new_dir == drill_direction and not _switching_drill:
		return
	if new_dir == drill_direction:
		_switching_drill = false
		_drill_switch_progress = 0.0
		if _switch_bar:
			_switch_bar.call("hide_bar")
		return
	if _switching_drill and new_dir == _pending_drill_dir:
		return
	_pending_drill_dir = new_dir
	_drill_switch_progress = 0.0
	_switching_drill = true
	if _switch_bar:
		_switch_bar.call("show_bar", 0.0)


func _update_drill_switch(delta: float) -> void:
	if not _switching_drill:
		return
	_drill_switch_progress = minf(_drill_switch_progress + delta / DRILL_SWITCH_DELAY, 1.0)
	if _switch_bar:
		_switch_bar.call("show_bar", _drill_switch_progress)
	if _drill_switch_progress >= 1.0:
		drill_direction = _pending_drill_dir
		_switching_drill = false
		_drill_switch_progress = 0.0
		if _switch_bar:
			_switch_bar.call("hide_bar")




func _clamp_to_camera_bounds() -> void:
	const HALF_W: float = 12.0
	global_position.x = clamp(global_position.x, camera.limit_left + HALF_W, camera.limit_right - HALF_W)


func _get_active_drill_directions() -> Array:

	var dirs: Array = [drill_direction]   # swivel-controlled drill

	if has_left_drill and not (Vector2i.LEFT in dirs):
		dirs.append(Vector2i.LEFT)

	if has_right_drill and not (Vector2i.RIGHT in dirs):
		dirs.append(Vector2i.RIGHT)

	return dirs
	
# ============================
# LAYERED SPRITE SYSTEM
# All part sprites share the same 36×32 canvas origin — no positional offset needed.
# ============================

var _displayed_drill_tier: int = -1
var _hull_sprite: Sprite2D = null
var _heat_shield_sprite: Sprite2D = null
var _cabin_sprite: Sprite2D = null
var _thruster_sprite: Sprite2D = null
var _drill_sprite: AnimatedSprite2D = null
var _left_drill_sprite: AnimatedSprite2D = null
var _right_drill_sprite: AnimatedSprite2D = null
var _drill_in_startup: bool = false
var _displayed_hull_tier: int = -1
var _displayed_heat_shield_tier: int = -1
var _displayed_cabin_tier: int = -1
var _displayed_thruster_tier: int = -1
var _displayed_thruster_on: bool = false


func _build_drill_frames(tier: int) -> SpriteFrames:
	const TIER_FOLDER: Array[String] = ["Bronze", "Steel", "Steel", "Titanium", "Diamond", "Plasma"]
	var folder: String = TIER_FOLDER[clampi(tier, 0, 5)]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	if tier == 5:
		frames.add_animation("startup")
		frames.set_animation_speed("startup", 10.0)
		frames.set_animation_loop("startup", false)
		for i in range(1, 5):
			frames.add_frame("startup", load("res://assets/Art/Player/Drill/Plasma/Plasma_Startup_%d.png" % i))
	frames.add_animation("loop")
	frames.set_animation_speed("loop", 10.0)
	frames.set_animation_loop("loop", true)
	for i in range(1, 4):
		frames.add_frame("loop", load("res://assets/Art/Player/Drill/%s/%s_Frame %d.png" % [folder, folder, i]))
	return frames


func _setup_player_sprites() -> void:
	var old_machine := $MachineSprite as AnimatedSprite2D
	if old_machine:
		old_machine.visible = false

	_hull_sprite = Sprite2D.new()
	_hull_sprite.z_index = 0
	add_child(_hull_sprite)

	_heat_shield_sprite = Sprite2D.new()
	_heat_shield_sprite.z_index = 1
	add_child(_heat_shield_sprite)

	_thruster_sprite = Sprite2D.new()
	_thruster_sprite.z_index = 2
	add_child(_thruster_sprite)

	_cabin_sprite = Sprite2D.new()
	_cabin_sprite.z_index = 3
	add_child(_cabin_sprite)

	_left_drill_sprite = AnimatedSprite2D.new()
	_left_drill_sprite.z_index = 4
	_left_drill_sprite.visible = false
	add_child(_left_drill_sprite)

	_right_drill_sprite = AnimatedSprite2D.new()
	_right_drill_sprite.z_index = 4
	_right_drill_sprite.visible = false
	add_child(_right_drill_sprite)

	_drill_sprite = AnimatedSprite2D.new()
	_drill_sprite.z_index = 4
	add_child(_drill_sprite)
	_drill_sprite.animation_finished.connect(_on_drill_animation_finished)

	_update_all_sprites()


func _on_drill_animation_finished() -> void:
	if _drill_in_startup and is_drilling:
		_drill_in_startup = false
		_drill_sprite.play("loop")
		if has_left_drill and _left_drill_sprite.visible:
			_left_drill_sprite.play("loop")
		if has_right_drill and _right_drill_sprite.visible:
			_right_drill_sprite.play("loop")


func _update_hull_sprite() -> void:
	if not _hull_sprite:
		return
	var t: int = clampi(hull_tier, 0, 4)
	if t == _displayed_hull_tier:
		return
	_hull_sprite.texture = load("res://assets/Art/Player/Hull/Hull_Tier_%d.png" % t)
	_displayed_hull_tier = t


func _update_heat_shield_sprite() -> void:
	if not _heat_shield_sprite:
		return
	var t: int = clampi(heat_shield_tier, 0, 3)
	if t == _displayed_heat_shield_tier:
		return
	_heat_shield_sprite.texture = load("res://assets/Art/Player/Heat Shield/Heat_Shield_Tier_%d.png" % t)
	_displayed_heat_shield_tier = t


func _update_cabin_sprite() -> void:
	if not _cabin_sprite:
		return
	var t: int = clampi(cabin_tier, 0, 3)
	if t == _displayed_cabin_tier:
		return
	_cabin_sprite.texture = load("res://assets/Art/Player/Cabin/Cabin_Tier %d.png" % t)
	_displayed_cabin_tier = t


func _update_thruster_sprite() -> void:
	if not _thruster_sprite:
		return
	var t: int = clampi(int(round((thruster_force - 200.0) / 200.0)), 0, 4)
	var on: bool = is_thrusting
	if t == _displayed_thruster_tier and on == _displayed_thruster_on:
		return
	var tier_suffix: String = "_Tier_%d" % t if t > 0 else ""
	var state: String = "On" if on else "Off"
	_thruster_sprite.texture = load("res://assets/Art/Player/Thrusters/Thrusters_%s%s.png" % [state, tier_suffix])
	_displayed_thruster_tier = t
	_displayed_thruster_on = on


func _apply_drill_transform(sprite: AnimatedSprite2D, dir: Vector2i) -> void:
	sprite.position = Vector2.ZERO
	match dir:
		Vector2i.LEFT:  sprite.rotation_degrees = -90.0
		Vector2i.RIGHT: sprite.rotation_degrees =  90.0
		_:              sprite.rotation_degrees =   0.0


func _set_drill_idle(sprite: AnimatedSprite2D, anim: String) -> void:
	if sprite.animation != anim:
		sprite.animation = anim
	sprite.frame = 0


func _update_drill_all() -> void:
	if not _drill_sprite:
		return

	if drill_tier != _displayed_drill_tier:
		var frames := _build_drill_frames(drill_tier)
		_drill_sprite.sprite_frames = frames
		_left_drill_sprite.sprite_frames = frames
		_right_drill_sprite.sprite_frames = frames
		_displayed_drill_tier = drill_tier
		_drill_in_startup = false

	_apply_drill_transform(_drill_sprite, drill_direction)
	if has_left_drill:
		_apply_drill_transform(_left_drill_sprite, Vector2i.LEFT)
	if has_right_drill:
		_apply_drill_transform(_right_drill_sprite, Vector2i.RIGHT)

	_left_drill_sprite.visible = has_left_drill
	_right_drill_sprite.visible = has_right_drill

	var speed: float = ([1.0, 1.6, 2.5] as Array)[clampi(drill_gear - 1, 0, 2)]
	_drill_sprite.speed_scale = speed
	_left_drill_sprite.speed_scale = speed
	_right_drill_sprite.speed_scale = speed

	var has_startup: bool = (drill_tier == 5
		and _drill_sprite.sprite_frames != null
		and _drill_sprite.sprite_frames.has_animation("startup"))

	if is_drilling:
		if not _drill_sprite.is_playing():
			if has_startup and not _drill_in_startup:
				_drill_in_startup = true
				_drill_sprite.play("startup")
				if has_left_drill:  _left_drill_sprite.play("startup")
				if has_right_drill: _right_drill_sprite.play("startup")
			elif not _drill_in_startup:
				_drill_sprite.play("loop")
				if has_left_drill:  _left_drill_sprite.play("loop")
				if has_right_drill: _right_drill_sprite.play("loop")
	else:
		if _drill_sprite.is_playing():
			_drill_sprite.stop()
			_left_drill_sprite.stop()
			_right_drill_sprite.stop()
		_drill_in_startup = false
		var idle_anim: String = "startup" if has_startup else "loop"
		_set_drill_idle(_drill_sprite, idle_anim)
		if has_left_drill:  _set_drill_idle(_left_drill_sprite, idle_anim)
		if has_right_drill: _set_drill_idle(_right_drill_sprite, idle_anim)


func _set_sprite_modulate(color: Color) -> void:
	if _hull_sprite:          _hull_sprite.modulate = color
	if _heat_shield_sprite:   _heat_shield_sprite.modulate = color
	if _cabin_sprite:         _cabin_sprite.modulate = color
	if _thruster_sprite:      _thruster_sprite.modulate = color
	if _drill_sprite:         _drill_sprite.modulate = color
	if _left_drill_sprite:    _left_drill_sprite.modulate = color
	if _right_drill_sprite:   _right_drill_sprite.modulate = color


func _update_all_sprites() -> void:
	_update_hull_sprite()
	_update_heat_shield_sprite()
	_update_cabin_sprite()
	_update_thruster_sprite()
	_update_drill_all()


func _on_inventory_button_pressed() -> void:
	var inv := get_node_or_null("InventoryMenu") as CanvasLayer
	if inv and inv.has_method("open"):
		if inv.visible:
			inv.close()
		else:
			inv.open()


# ============================
# FLOATING RESOURCE TEXT
# ============================
func _spawn_floating_text(text: String, world_pos: Vector2) -> void:
	var label := Label.new()
	label.text  = text
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 5)
	label.modulate = Color(1.0, 1.0, 0.4, 1.0)
	get_tree().current_scene.add_child(label)
	label.global_position = world_pos - Vector2(0.0, 10.0)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", world_pos.y - 26.0, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.finished.connect(label.queue_free)


# ============================
# ONE-TIME USE ITEMS
# ============================
func use_item(item_id: String) -> void:
	var count: int = item_inventory.get(item_id, 0)
	if count <= 0:
		return

	var data: Dictionary = ItemData.ITEMS.get(item_id, {})
	if data.is_empty():
		return

	match data["use_type"]:
		"instant":
			_apply_instant_item(item_id)
			item_inventory[item_id] = count - 1
			if item_inventory[item_id] <= 0:
				item_inventory.erase(item_id)

		"place":
			_place_explosive(item_id)
			item_inventory[item_id] = count - 1
			if item_inventory[item_id] <= 0:
				item_inventory.erase(item_id)

		"place_return":
			if has_active_beacon:
				return
			_place_beacon()
			item_inventory[item_id] = count - 1
			if item_inventory[item_id] <= 0:
				item_inventory.erase(item_id)


func _apply_instant_item(item_id: String) -> void:
	match item_id:
		"fuel_can":
			fuel = min(max_fuel, fuel + 50.0)
		"large_fuel_can":
			fuel = max_fuel
		"repair_kit":
			health = min(max_health, health + 30.0)
		"sonar_battery":
			sonar_cooldown_timer = 0.0
		"teleport_charge":
			global_position = spawn_position
			velocity = Vector2.ZERO
		"mineral_detector":
			_use_mineral_detector()


func _place_explosive(item_id: String) -> void:
	var item_node := Node2D.new()
	item_node.set_script(load("res://scripts/placeable_item.gd"))
	get_tree().current_scene.add_child(item_node)
	item_node.global_position = global_position
	item_node.call("setup", item_id, self, terrain, hazard_layer)


func _place_beacon() -> void:
	var beacon := Node2D.new()
	beacon.set_script(load("res://scripts/placeable_item.gd"))
	get_tree().current_scene.add_child(beacon)
	beacon.global_position = global_position
	beacon.call("setup", "phase_beacon", self, terrain, hazard_layer)
	_beacon_node    = beacon
	has_active_beacon = true


func use_beacon_return() -> void:
	if not has_active_beacon:
		return
	if is_instance_valid(_beacon_node):
		global_position = _beacon_node.global_position
		velocity        = Vector2.ZERO
		_beacon_node.queue_free()
	_beacon_node      = null
	has_active_beacon = false


func _use_mineral_detector() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var zoom_x: float = camera.zoom.x if camera else 1.0
	var zoom_y: float = camera.zoom.y if camera else 1.0
	var half_w: float = viewport_size.x / zoom_x / 2.0
	var half_h: float = viewport_size.y / zoom_y / 2.0

	const TILE_SIZE := 16.0
	var cam_pos: Vector2 = camera.global_position if camera else global_position
	var center_tile := world_to_tile(cam_pos)
	var range_x: int = int(ceil(half_w / TILE_SIZE)) + 2
	var range_y: int = int(ceil(half_h / TILE_SIZE)) + 2

	for x in range(center_tile.x - range_x, center_tile.x + range_x + 1):
		for y in range(center_tile.y - range_y, center_tile.y + range_y + 1):
			var pos := Vector2i(x, y)
			var tile: Vector2i = terrain.get_cell_atlas_coords(pos)
			if tile == Vector2i(-1, -1) and hazard_layer:
				tile = hazard_layer.get_cell_atlas_coords(pos)
			if SONAR_TARGETS.has(tile):
				spawn_sonar_marker(pos, SONAR_TARGETS[tile])

	get_tree().create_timer(30.0).timeout.connect(clear_sonar_markers)

# Total amount of a material across cargo + storage (for upgrade checks)
func get_total_amount(mat_id: String) -> int:
	var cargo_amt: int = resources.get(mat_id, 0)
	var storage_amt: int = storage.get(mat_id, 0)
	return cargo_amt + storage_amt


# Consume material for an upgrade — deducts from cargo first, then storage
func consume_material(mat_id: String, amount: int) -> bool:

	if get_total_amount(mat_id) < amount:
		return false

	var cargo_amt: int = resources.get(mat_id, 0)
	var from_cargo: int = min(cargo_amt, amount)

	resources[mat_id] = cargo_amt - from_cargo
	amount -= from_cargo

	if amount > 0:
		var storage_amt: int = storage.get(mat_id, 0)
		storage[mat_id] = storage_amt - amount

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
func transfer_to_storage(mat_id: String, amount: int) -> int:

	var available: int = resources.get(mat_id, 0)
	if mat_id == "basic_ore":
		available = ore

	var to_move: int = min(amount, available)

	# capacity limit
	var room: int = max_storage - get_storage_used()
	to_move = min(to_move, room)

	if to_move <= 0:
		return 0

	# remove from cargo
	if mat_id == "basic_ore":
		ore -= to_move
	else:
		resources[mat_id] = available - to_move

	# add to storage
	if not storage.has(mat_id):
		storage[mat_id] = 0
	storage[mat_id] += to_move

	_recompute_cargo()

	return to_move


# Move material from storage to cargo; returns how much was actually moved
func transfer_to_cargo(mat_id: String, amount: int) -> int:

	var in_storage: int = storage.get(mat_id, 0)
	var to_move: int = min(amount, in_storage)

	# cargo capacity check
	var cargo_value: int = _get_cargo_value_for_material(mat_id)
	var room_in_cargo: int = max_cargo - cargo
	var max_by_cargo: int = int(floor(float(room_in_cargo) / float(max(cargo_value, 1))))

	to_move = min(to_move, max_by_cargo)

	if to_move <= 0:
		return 0

	# remove from storage
	storage[mat_id] = in_storage - to_move

	# add to cargo
	if mat_id == "basic_ore":
		ore += to_move
	else:
		if not resources.has(mat_id):
			resources[mat_id] = 0
		resources[mat_id] += to_move

	_recompute_cargo()

	return to_move


# Look up cargo cost per unit for a given material
func _get_cargo_value_for_material(mat_id: String) -> int:

	if mat_id == "basic_ore":
		return 1

	for tile in TerrainData.TERRAIN_TYPES:
		var info: Dictionary = TerrainData.TERRAIN_TYPES[tile]
		if info.get("resource") == mat_id:
			return info.get("cargo", 1)

	return 1


func sell_material(mat_id: String, amount: int) -> int:

	const ResourceDataLocal = preload("res://scripts/data/resource_data.gd")
	var data: Dictionary = ResourceDataLocal.RESOURCES.get(mat_id, {})
	var unit_value: int = data.get("value", 0)

	var available: int
	if mat_id == "basic_ore":
		available = ore
	else:
		available = resources.get(mat_id, 0)

	var to_sell: int = min(amount, available)
	if to_sell <= 0:
		return 0

	if mat_id == "basic_ore":
		ore -= to_sell
	else:
		resources[mat_id] = available - to_sell

	var total: int = to_sell * unit_value
	money += total

	_recompute_cargo()

	return total
