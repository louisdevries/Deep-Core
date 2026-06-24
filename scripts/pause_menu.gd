# pause_menu.gd
extends CanvasLayer

@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var save_button: Button = $Panel/VBox/SaveButton
@onready var load_button: Button = $Panel/VBox/LoadButton
@onready var saved_label: Label = $Panel/VBox/SavedLabel
@onready var new_world_button: Button = $Panel/VBox/NewWorldButton
@onready var full_reset_button: Button = $Panel/VBox/FullResetButton
@onready var quit_button: Button = $Panel/VBox/QuitButton

@onready var confirm_panel: PanelContainer = $Panel/VBox/ConfirmPanel
@onready var confirm_label: Label = $Panel/VBox/ConfirmPanel/ConfirmVBox/ConfirmLabel
@onready var confirm_detail: Label = $Panel/VBox/ConfirmPanel/ConfirmVBox/ConfirmDetail
@onready var yes_button: Button = $Panel/VBox/ConfirmPanel/ConfirmVBox/HBox/YesButton
@onready var no_button: Button = $Panel/VBox/ConfirmPanel/ConfirmVBox/HBox/NoButton

var pending_action: String = ""
var _save_feedback_timer: float = 0.0


func _ready() -> void:

	visible = false
	confirm_panel.visible = false
	saved_label.visible = false

	resume_button.pressed.connect(close)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	new_world_button.pressed.connect(_on_new_world_pressed)
	full_reset_button.pressed.connect(_on_full_reset_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	yes_button.pressed.connect(_on_confirm_yes)
	no_button.pressed.connect(_on_confirm_no)


func _process(delta: float) -> void:
	if _save_feedback_timer > 0.0:
		_save_feedback_timer -= delta
		if _save_feedback_timer <= 0.0:
			saved_label.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		print("Key pressed: ", event.keycode, " | Action 'pause': ", event.is_action_pressed("pause"))

func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("pause"):

		# don't open if another modal is already active
		var upgrade_menu := get_tree().current_scene.get_node_or_null("UpgradeMenu") as CanvasLayer
		if upgrade_menu and upgrade_menu.visible and not visible:
			return

		if visible:
			if confirm_panel.visible:
				_on_confirm_no()
			else:
				close()
		else:
			open()

		get_viewport().set_input_as_handled()


func open() -> void:

	visible = true
	confirm_panel.visible = false
	pending_action = ""
	saved_label.visible = false
	_save_feedback_timer = 0.0
	load_button.disabled = not SaveSystem.has_save()
	get_tree().paused = true


func close() -> void:

	visible = false
	confirm_panel.visible = false
	pending_action = ""
	get_tree().paused = false


func _show_confirm(action: String, title: String, detail: String) -> void:

	pending_action = action
	confirm_label.text = title
	confirm_detail.text = detail
	confirm_panel.visible = true


func _on_save_pressed() -> void:

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var terrain := get_tree().get_first_node_in_group("terrain")
	var payload: Dictionary = {}
	if player.has_method("build_player_save"):
		payload.merge(player.build_player_save())
	if terrain and terrain.has_method("build_world_save"):
		payload.merge(terrain.build_world_save())
	SaveSystem.save_game(payload)
	saved_label.visible = true
	_save_feedback_timer = 2.0


func _on_load_pressed() -> void:

	_show_confirm(
		"load",
		"Load Last Save?",
		"Unsaved progress will be lost. The game will reload from your last save."
	)


func _on_new_world_pressed() -> void:

	_show_confirm(
		"new_world",
		"Generate New World?",
		"Your money, upgrades, and inventory will be kept. The world layout, dug tunnels, and hazards will reset."
	)


func _on_full_reset_pressed() -> void:

	_show_confirm(
		"full_reset",
		"Reset Everything?",
		"This wipes all progress: money, upgrades, inventory, and the world. You will start from the beginning."
	)


func _on_quit_pressed() -> void:

	_show_confirm(
		"quit",
		"Quit Game?",
		"Your progress is saved at the refuel zone. Anything since your last save will be lost."
	)


func _on_confirm_yes() -> void:

	match pending_action:

		"load":
			get_tree().paused = false
			get_tree().reload_current_scene()

		"new_world":
			SaveSystem.clear_world_only()
			get_tree().paused = false
			get_tree().reload_current_scene()

		"full_reset":
			SaveSystem.clear_save()
			get_tree().paused = false
			get_tree().reload_current_scene()

		"quit":
			get_tree().quit()

	pending_action = ""


func _on_confirm_no() -> void:

	confirm_panel.visible = false
	pending_action = ""
