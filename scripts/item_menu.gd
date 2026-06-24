extends CanvasLayer

const ItemData = preload("res://scripts/data/item_data.gd")

@onready var close_button: Button    = $Panel/VBox/CloseButton
@onready var list_container: VBoxContainer = $Panel/VBox/Scroll/List
@onready var beacon_banner: Label    = $Panel/VBox/BeaconBanner

var player: Node = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()


func open_for_current_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	open(players[0])


func open(p_player: Node) -> void:
	player = p_player
	visible = true
	get_tree().paused = true
	rebuild()


func close() -> void:
	visible = false
	get_tree().paused = false


func rebuild() -> void:
	for c in list_container.get_children():
		list_container.remove_child(c)
		c.queue_free()

	var has_beacon: bool = player.has_active_beacon if player else false
	beacon_banner.visible = has_beacon
	if has_beacon:
		beacon_banner.text = "Phase Beacon active — tap Return to teleport back!"

	var has_items := false

	for item_id in ItemData.SHOP_ORDER:
		var count: int = player.item_inventory.get(item_id, 0) if player else 0
		if count <= 0:
			continue
		has_items = true
		list_container.add_child(_build_item_row(item_id, count))

	if has_beacon:
		has_items = true
		list_container.add_child(_build_beacon_return_row())

	if not has_items:
		var lbl := Label.new()
		lbl.text = "No items in inventory.\nBuy consumables from the shop."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(lbl)


func _build_item_row(item_id: String, count: int) -> Control:
	var data: Dictionary = ItemData.ITEMS[item_id]

	var row := PanelContainer.new()
	var vbox := VBoxContainer.new()
	row.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = "%s  ×%d" % [data["name"], count]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var btn_text: String = "Use"
	match data["use_type"]:
		"place":        btn_text = "Place"
		"place_return": btn_text = "Place Beacon"

	var btn := Button.new()
	btn.text = btn_text
	btn.pressed.connect(_on_use_item.bind(item_id))
	header.add_child(btn)

	var desc := Label.new()
	desc.text = data["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	return row


func _build_beacon_return_row() -> Control:
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	row.add_child(hbox)

	var lbl := Label.new()
	lbl.text = "Phase Beacon — teleport back to beacon"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn := Button.new()
	btn.text = "Return"
	btn.pressed.connect(_on_beacon_return)
	hbox.add_child(btn)

	return row


func _on_use_item(item_id: String) -> void:
	if not player:
		return
	player.use_item(item_id)
	close()


func _on_beacon_return() -> void:
	if not player:
		return
	player.use_beacon_return()
	close()
