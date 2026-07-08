extends CanvasLayer

const ResourceData = preload("res://scripts/data/resource_data.gd")
const UpgradeData = preload("res://scripts/data/upgrade_data.gd")

@onready var give_money_btn: Button = $Panel/VBox/HBoxOne/GiveMoneyButton
@onready var give_lots_money_btn: Button = $Panel/VBox/HBoxOne/GiveLotsMoneyButton
@onready var refuel_btn: Button = $Panel/VBox/HBoxTwo/RefuelButton
@onready var restore_health_btn: Button = $Panel/VBox/HBoxTwo/RestoreHealthButton
@onready var give_all_ores_btn: Button = $Panel/VBox/HBoxThree/GiveAllOresButton
@onready var give_gems_btn: Button = $Panel/VBox/HBoxThree/GiveGemsButton
@onready var drill_tier_btn: Button = $Panel/VBox/HBoxFour/DrillTierUpButton
@onready var max_all_btn: Button = $Panel/VBox/HBoxFour/MaxAllUpgradesButton
@onready var godmode_btn: Button = $Panel/VBox/HBoxFive/ToggleGodModeButton
@onready var noclip_btn: Button = $Panel/VBox/HBoxFive/ToggleNoclipButton
@onready var teleport_core_btn: Button = $Panel/VBox/HBoxSix/TeleportToCoreButton
@onready var reset_pos_btn: Button = $Panel/VBox/HBoxSix/ResetPositionButton
@onready var close_btn: Button = $Panel/VBox/CloseButton

var player: Node = null
var _god_mode: bool = false
var _noclip:   bool = false


func _ready() -> void:

	visible = false

	give_money_btn.pressed.connect(_on_give_money.bind(1000))
	give_lots_money_btn.pressed.connect(_on_give_money.bind(10000))
	refuel_btn.pressed.connect(_on_refuel)
	restore_health_btn.pressed.connect(_on_restore_health)
	give_all_ores_btn.pressed.connect(_on_give_all_ores)
	give_gems_btn.pressed.connect(_on_give_gems)
	drill_tier_btn.pressed.connect(_on_drill_tier_up)
	max_all_btn.pressed.connect(_on_max_all_upgrades)
	godmode_btn.pressed.connect(_on_toggle_godmode)
	noclip_btn.pressed.connect(_on_toggle_noclip)
	teleport_core_btn.pressed.connect(_on_teleport_core)
	reset_pos_btn.pressed.connect(_on_reset_position)
	close_btn.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:

	# Toggle with the dev key (define below in input map)
	if event.is_action_pressed("dev_menu"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if not player:
		push_warning("DevMenu: no player found")
		return

	visible = true


func close() -> void:
	visible = false


func _physics_process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	if _god_mode:
		player.health  = player.max_health
		player.is_dead = false
	if _noclip:
		player.velocity.y = 0.0


# === BUTTON HANDLERS ===

func _on_give_money(amount: int) -> void:
	if not player:
		return
	player.money += amount
	print("[DEV] +$", amount)


func _on_refuel() -> void:
	if not player:
		return
	player.fuel = player.max_fuel
	print("[DEV] Refueled")


func _on_restore_health() -> void:
	if not player:
		return
	player.health = player.max_health
	print("[DEV] Health restored")


func _on_give_all_ores() -> void:
	if not player:
		return
	var ores: Array = [
		"copper", "tin", "coal", "sulfur",
		"iron", "silver", "aluminum", "lead", "zinc",
		"gold", "platinum", "titanium", "tungsten"
	]
	for o in ores:
		if not player.resources.has(o):
			player.resources[o] = 0
		player.resources[o] += 50
	player._recompute_cargo()
	print("[DEV] Gave 50 of each ore")


func _on_give_gems() -> void:
	if not player:
		return
	var gems: Array = [
		"crystal", "ruby", "sapphire", "emerald", "diamond",
		"obsidian", "uranium", "mythril", "adamantium"
	]
	for g in gems:
		if not player.resources.has(g):
			player.resources[g] = 0
		player.resources[g] += 20
	player._recompute_cargo()
	print("[DEV] Gave 20 of each gem/special")


func _on_drill_tier_up() -> void:
	if not player:
		return
	player.drill_tier = min(player.drill_tier + 1, 5)
	print("[DEV] Drill tier: ", player.drill_tier)


func _on_max_all_upgrades() -> void:
	if not player:
		return
	player.drill_tier        = 5
	player.drill_swivel_tier = 3
	player.max_cargo         = 65
	player.max_fuel          = 250.0
	player.fuel              = player.max_fuel
	player.thruster_force    = 1000.0
	player.sonar_range       = 17
	player.furnace_slot_count = 5
	player.drill_count       = 3
	player.has_left_drill    = true
	player.has_right_drill   = true
	player.max_storage       = 500
	FurnaceSystem.slot_count = 5
	print("[DEV] Maxed all upgrades")


func _on_toggle_godmode() -> void:
	_god_mode = not _god_mode
	godmode_btn.text = "Godmode: ON" if _god_mode else "Toggle Godmode"
	print("[DEV] Godmode: ", _god_mode)


func _on_toggle_noclip() -> void:
	_noclip = not _noclip
	noclip_btn.text = "Noclip: ON" if _noclip else "Toggle Noclip"
	if player:
		player.set_collision_mask_value(1, not _noclip)
		player.set_collision_layer_value(1, not _noclip)
	print("[DEV] Noclip: ", _noclip)


func _on_teleport_core() -> void:
	if not player:
		return
	player.global_position = Vector2(0, 180 * 16)    # tile y=180 in world coords
	print("[DEV] Teleported to deep area")


func _on_reset_position() -> void:
	if not player:
		return
	player.global_position = player.spawn_position
	print("[DEV] Reset to spawn")
