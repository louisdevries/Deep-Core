extends CanvasLayer

const ResourceData = preload("res://scripts/data/resource_data.gd")

@onready var items_grid: GridContainer = $Panel/VBox/ScrollContainer/ItemsGrid
@onready var capacity_label: Label     = $Panel/VBox/CapacityLabel
@onready var close_button: Button      = $Panel/VBox/CloseButton

var player: Node = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	items_grid.add_theme_constant_override("h_separation", 8)
	items_grid.add_theme_constant_override("v_separation", 8)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
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
	for child in items_grid.get_children():
		child.queue_free()

	capacity_label.text = "Cargo: %d / %d" % [player.cargo, player.max_cargo]

	for material_id in ResourceData.DISPLAY_ORDER:
		var count: int = player.ore if material_id == "basic_ore" else player.resources.get(material_id, 0)
		if count == 0:
			continue
		_add_cell(material_id, count)


func _add_cell(material_id: String, count: int) -> void:
	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	if data.is_empty():
		return

	# Outer card — fixed square minimum; expands to fill column equally
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(108, 118)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Inner margin so content doesn't touch the panel border
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top",    5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.add_theme_constant_override("margin_left",   5)
	margin.add_theme_constant_override("margin_right",  5)
	cell.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	# Colour block — expands to fill whatever height remains above the labels
	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(0, 60)
	swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swatch.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_child(swatch)

	# Material name — centred, wraps if needed
	var name_lbl := Label.new()
	name_lbl.text = data.get("display_name", material_id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(name_lbl)

	# Count — centred below the name
	var count_lbl := Label.new()
	count_lbl.text = "× %d" % count
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(count_lbl)

	items_grid.add_child(cell)
