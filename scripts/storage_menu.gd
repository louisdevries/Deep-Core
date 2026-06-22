extends CanvasLayer

const ResourceData = preload("res://scripts/data/resource_data.gd")

@onready var inv_label: Label = $Panel/VBox/Content/InventoryCol/InvHeader
@onready var inv_list: VBoxContainer = $Panel/VBox/Content/InventoryCol/InvScroll/InvList
@onready var stor_label: Label = $Panel/VBox/Content/StorageCol/StorHeader
@onready var stor_list: VBoxContainer = $Panel/VBox/Content/StorageCol/StorScroll/StorList
@onready var close_button: Button = $Panel/VBox/CloseButton

var player: Node = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()


func open(target_player: Node) -> void:
	player = target_player
	visible = true
	get_tree().paused = true
	rebuild()


func close() -> void:
	visible = false
	get_tree().paused = false


func rebuild() -> void:
	inv_label.text = "Inventory  %d / %d" % [player.cargo, player.max_cargo]
	stor_label.text = "Storage  %d / %d" % [player.get_storage_used(), player.max_storage]

	for c in inv_list.get_children():
		inv_list.remove_child(c)
		c.queue_free()
	for c in stor_list.get_children():
		stor_list.remove_child(c)
		c.queue_free()

	for material_id in ResourceData.DISPLAY_ORDER:
		var inv_count: int
		if material_id == "basic_ore":
			inv_count = player.ore
		else:
			inv_count = player.resources.get(material_id, 0)

		var stor_count: int = player.storage.get(material_id, 0)

		if inv_count > 0:
			inv_list.add_child(_build_inv_row(material_id, inv_count))

		if stor_count > 0:
			stor_list.add_child(_build_stor_row(material_id, stor_count))


func _build_inv_row(material_id: String, count: int) -> Control:
	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})

	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(20, 20)
	hbox.add_child(swatch)

	var lbl := Label.new()
	lbl.text = "%s × %d" % [data.get("display_name", material_id), count]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn := Button.new()
	btn.text = "Store"
	btn.disabled = not player.can_store(1)
	btn.pressed.connect(_on_store.bind(material_id, count))
	hbox.add_child(btn)

	return row


func _build_stor_row(material_id: String, count: int) -> Control:
	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})

	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(20, 20)
	hbox.add_child(swatch)

	var lbl := Label.new()
	lbl.text = "%s × %d" % [data.get("display_name", material_id), count]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn := Button.new()
	btn.text = "Retrieve"
	btn.pressed.connect(_on_retrieve.bind(material_id, count))
	hbox.add_child(btn)

	return row


func _on_store(material_id: String, count: int) -> void:
	player.transfer_to_storage(material_id, count)
	rebuild()


func _on_retrieve(material_id: String, count: int) -> void:
	player.transfer_to_cargo(material_id, count)
	rebuild()
