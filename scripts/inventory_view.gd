extends CanvasLayer

const ResourceData = preload("res://scripts/data/resource_data.gd")

@onready var items_list: VBoxContainer = $Panel/VBox/ScrollContainer/ItemsList
@onready var capacity_label: Label = $Panel/VBox/CapacityLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

var player: Node = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("inventory"):

		# don't open over other modals
		var pause_menu := get_tree().current_scene.get_node_or_null("PauseMenu") as CanvasLayer
		if pause_menu and pause_menu.visible:
			return
		var upgrade_menu := get_tree().current_scene.get_node_or_null("UpgradeMenu") as CanvasLayer
		if upgrade_menu and upgrade_menu.visible:
			return

		if visible:
			close()
		else:
			open()

		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if not player:
		return

	visible = true
	rebuild()


func close() -> void:
	visible = false


func rebuild() -> void:

	for child in items_list.get_children():
		child.queue_free()

	capacity_label.text = "Cargo: %d / %d" % [player.cargo, player.max_cargo]

	for material_id in ResourceData.DISPLAY_ORDER:

		var count: int = 0
		if material_id == "basic_ore":
			count = player.ore
		else:
			count = player.resources.get(material_id, 0)

		if count == 0:
			continue

		_add_row(material_id, count)


func _add_row(material_id: String, count: int) -> void:

	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	if data.is_empty():
		return

	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(24, 24)
	hbox.add_child(swatch)

	var name_label := Label.new()
	name_label.text = data.get("display_name", material_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "× " + str(count)
	hbox.add_child(count_label)

	items_list.add_child(row)
