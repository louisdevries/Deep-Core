# upgrade_menu.gd
extends CanvasLayer

const UpgradeData  = preload("res://scripts/data/upgrade_data.gd")
const ResourceData = preload("res://scripts/data/resource_data.gd")

@onready var tab_container:      TabContainer = $Panel/VBox/TabContainer
@onready var player_stats_label: Label        = $Panel/VBox/PlayerStats
@onready var close_button:       Button       = $Panel/VBox/CloseButton

var player:      Node              = null
var _hammer_sfx: AudioStreamPlayer = null
var _sell_sfx:   AudioStreamPlayer = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)

	_hammer_sfx = AudioStreamPlayer.new()
	_hammer_sfx.stream = load("res://assets/Audio/SFX/Hammer.wav")
	_hammer_sfx.bus = "SFX"
	add_child(_hammer_sfx)

	_sell_sfx = AudioStreamPlayer.new()
	_sell_sfx.stream = load("res://assets/Audio/SFX/Sell.wav")
	_sell_sfx.bus = "SFX"
	add_child(_sell_sfx)

	_apply_theme()


func _apply_theme() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	add_child(backdrop)
	move_child(backdrop, 0)

	$Panel.add_theme_stylebox_override("panel", _panel_style())
	$Panel/VBox.add_theme_constant_override("separation", 8)

	var title := $Panel.get_node_or_null("VBox/Title") as Label
	if title:
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	player_stats_label.add_theme_font_size_override("font_size", 14)
	player_stats_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.42))

	tab_container.add_theme_color_override("font_selected_color",   Color(0.95, 0.78, 0.30))
	tab_container.add_theme_color_override("font_unselected_color", Color(0.60, 0.50, 0.32))
	var tab_panel_sty := StyleBoxFlat.new()
	tab_panel_sty.bg_color              = Color(0.10, 0.07, 0.04, 0.90)
	tab_panel_sty.border_color          = Color(0.45, 0.32, 0.12, 0.50)
	tab_panel_sty.border_width_left     = 1
	tab_panel_sty.border_width_right    = 1
	tab_panel_sty.border_width_top      = 1
	tab_panel_sty.border_width_bottom   = 1
	tab_container.add_theme_stylebox_override("panel", tab_panel_sty)

	_style_btn(close_button, false)
	close_button.text = "Exit (Esc)"


func open(target_player: Node) -> void:
	player = target_player
	visible = true
	get_tree().paused = true
	rebuild_ui()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		var pause_menu := get_tree().current_scene.get_node_or_null("PauseMenu") as CanvasLayer
		if pause_menu and pause_menu.visible:
			return
		close()
		get_viewport().set_input_as_handled()


func rebuild_ui() -> void:
	for i in range(tab_container.get_child_count()):
		var tab := tab_container.get_child(i)
		for c in tab.get_children():
			c.queue_free()

	_update_player_stats()

	var by_category: Dictionary = {}
	for upgrade_id in UpgradeData.UPGRADES.keys():
		var upgrade: Dictionary = UpgradeData.UPGRADES[upgrade_id]
		var cat: String = upgrade["category"]
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(upgrade_id)

	for i in range(tab_container.get_child_count()):
		var tab_node := tab_container.get_child(i)
		var tab_name := tab_node.name

		if tab_name == "Inventory":
			_populate_inventory_tab(tab_node)
			continue
		if tab_name == "Storage":
			_populate_storage_tab(tab_node)
			continue

		if not by_category.has(tab_name):
			continue
		for upgrade_id in by_category[tab_name]:
			var scroll := ScrollContainer.new() if tab_node.get_child_count() == 0 else null
			var list: VBoxContainer
			if scroll:
				scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
				tab_node.add_child(scroll)
				list = VBoxContainer.new()
				list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				list.add_theme_constant_override("separation", 6)
				scroll.add_child(list)
			else:
				list = tab_node.get_child(0).get_child(0) as VBoxContainer
			list.add_child(_build_card(upgrade_id))


func _update_player_stats() -> void:
	if not player:
		return
	var line: String = "$" + str(player.money)
	line += "   Cu: " + str(player.resources.get("copper", 0))
	line += "   Fe: " + str(player.resources.get("iron", 0))
	line += "   Cr: " + str(player.resources.get("crystal", 0))
	player_stats_label.text = line


func _build_card(upgrade_id: String) -> Control:
	var upgrade: Dictionary  = UpgradeData.UPGRADES[upgrade_id]
	var tiers: Array         = upgrade["tiers"]
	var player_var: String   = upgrade["player_var"]
	var current_value        = player.get(player_var)
	var starting_value       = UpgradeData.STARTING_VALUES.get(player_var, 1)
	var increment            = UpgradeData.TIER_INCREMENTS.get(player_var, 1)

	var current_tier: int
	if typeof(current_value) == TYPE_BOOL:
		current_tier = 2 if current_value else 1
	else:
		current_tier = int(round((current_value - starting_value) / float(increment))) + 1

	var max_tier: int = tiers.size() + 1

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var name_label := Label.new()
	name_label.text = "%s  (Tier %d/%d)" % [upgrade["name"], current_tier, max_tier]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.80, 0.52))
	box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = upgrade["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.62, 0.52, 0.36))
	box.add_child(desc_label)

	var btn := _make_btn("", false)
	if current_tier > tiers.size():
		btn.text     = "MAXED"
		btn.disabled = true
	else:
		var next_data: Dictionary = tiers[current_tier - 1]
		var cost_text: String     = "$" + str(next_data["money"])
		for r in next_data["resources"]:
			cost_text += "   " + r.capitalize() + ": " + str(next_data["resources"][r])
		btn.text     = "Buy — " + cost_text
		btn.disabled = not _can_afford(next_data)
		btn.pressed.connect(_on_buy.bind(upgrade_id))
	box.add_child(btn)

	return card


func _can_afford(tier_data: Dictionary) -> bool:
	if player.money < tier_data["money"]:
		return false
	for r in tier_data["resources"]:
		if player.get_total_amount(r) < tier_data["resources"][r]:
			return false
	return true


func _on_buy(upgrade_id: String) -> void:
	var upgrade: Dictionary = UpgradeData.UPGRADES[upgrade_id]
	var tiers: Array        = upgrade["tiers"]
	var player_var: String  = upgrade["player_var"]
	var current_value       = player.get(player_var)
	var starting_value      = UpgradeData.STARTING_VALUES.get(player_var, 1)
	var increment           = UpgradeData.TIER_INCREMENTS.get(player_var, 1)

	var current_tier: int
	if typeof(current_value) == TYPE_BOOL:
		current_tier = 2 if current_value else 1
	else:
		current_tier = int(round((current_value - starting_value) / float(increment))) + 1

	if current_tier > tiers.size():
		return

	var next_data: Dictionary = tiers[current_tier - 1]
	if not _can_afford(next_data):
		return

	player.money -= next_data["money"]
	for r in next_data["resources"]:
		player.consume_material(r, next_data["resources"][r])

	var new_value
	if next_data.has("result_value"):
		new_value = next_data["result_value"]
	else:
		new_value = current_value + increment
	player.set(player_var, new_value)

	if _hammer_sfx:
		_hammer_sfx.stop()
		_hammer_sfx.play()
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if is_instance_valid(_hammer_sfx) and _hammer_sfx.is_playing():
				_hammer_sfx.stop()
		)

	rebuild_ui()


func _populate_inventory_tab(tab: Node) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	for material_id in ResourceData.DISPLAY_ORDER:
		var count: int = player.ore if material_id == "basic_ore" else player.resources.get(material_id, 0)
		if count == 0:
			continue
		list.add_child(_build_inventory_row(material_id, count))


func _populate_storage_tab(tab: Node) -> void:
	var header := Label.new()
	header.text = "Storage: %d / %d" % [player.get_storage_used(), player.max_storage]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.80, 0.68, 0.44))
	tab.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	for material_id in ResourceData.DISPLAY_ORDER:
		var count: int = player.storage.get(material_id, 0)
		if count == 0:
			continue
		list.add_child(_build_storage_row(material_id, count))


func _build_inventory_row(material_id: String, count: int) -> Control:
	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	var row  := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(20, 20)
	hbox.add_child(swatch)

	var name_label := Label.new()
	name_label.text = "%s × %d" % [data.get("display_name", material_id), count]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
	hbox.add_child(name_label)

	var unit_value: int = data.get("value", 0)
	var sell_btn := _make_btn("Sell ($%d)" % (unit_value * count), true)
	sell_btn.pressed.connect(_on_sell_material.bind(material_id, count))
	hbox.add_child(sell_btn)

	var store_btn := _make_btn("Store", false)
	if not player.can_store(1):
		store_btn.disabled = true
		store_btn.text = "Full"
	store_btn.pressed.connect(_on_store_material.bind(material_id, count))
	hbox.add_child(store_btn)

	return row


func _build_storage_row(material_id: String, count: int) -> Control:
	var data: Dictionary = ResourceData.RESOURCES.get(material_id, {})
	var row  := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.color = data.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(20, 20)
	hbox.add_child(swatch)

	var name_label := Label.new()
	name_label.text = "%s × %d" % [data.get("display_name", material_id), count]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
	hbox.add_child(name_label)

	var retrieve_btn := _make_btn("Retrieve", false)
	retrieve_btn.pressed.connect(_on_retrieve_material.bind(material_id, count))
	hbox.add_child(retrieve_btn)

	return row


func _on_sell_material(material_id: String, amount: int) -> void:
	player.sell_material(material_id, amount)
	if _sell_sfx:
		_sell_sfx.play()
	rebuild_ui()


func _on_store_material(material_id: String, amount: int) -> void:
	player.transfer_to_storage(material_id, amount)
	rebuild_ui()


func _on_retrieve_material(material_id: String, amount: int) -> void:
	player.transfer_to_cargo(material_id, amount)
	rebuild_ui()


# ── Style helpers ────────────────────────────────────────────────────────────

func _style_btn(btn: Button, primary: bool) -> void:
	btn.add_theme_font_size_override("font_size", 16)
	var border := Color(0.55, 0.40, 0.15, 0.80) if primary else Color(0.42, 0.30, 0.10, 0.70)
	var bg     := Color(0.14, 0.09, 0.04, 0.90) if primary else Color(0.10, 0.07, 0.03, 0.85)
	btn.add_theme_stylebox_override("normal",  _flat_style(bg, border))
	btn.add_theme_stylebox_override("hover",   _flat_style(Color(0.26, 0.16, 0.06, 0.95), Color(0.90, 0.70, 0.25, 1.00)))
	btn.add_theme_stylebox_override("pressed", _flat_style(Color(0.35, 0.22, 0.08, 1.00), Color(1.00, 0.85, 0.40, 1.00)))
	btn.add_theme_color_override("font_color",         Color(0.92, 0.78, 0.50) if primary else Color(0.82, 0.70, 0.45))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.92, 0.65))
	btn.add_theme_color_override("font_pressed_color", Color(1.00, 1.00, 0.80))


func _make_btn(txt: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = txt
	_style_btn(btn, primary)
	return btn


func _flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color              = bg
	s.border_color          = border
	s.border_width_left     = 2
	s.border_width_right    = 2
	s.border_width_top      = 2
	s.border_width_bottom   = 2
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	return s


func _card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color              = Color(0.12, 0.09, 0.05, 0.85)
	s.border_color          = Color(0.45, 0.32, 0.12, 0.60)
	s.border_width_left     = 1
	s.border_width_right    = 1
	s.border_width_top      = 1
	s.border_width_bottom   = 1
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left   = 8
	s.content_margin_right  = 8
	s.content_margin_top    = 6
	s.content_margin_bottom = 6
	return s


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color              = Color(0.08, 0.06, 0.04, 0.97)
	s.border_color          = Color(0.60, 0.44, 0.18, 0.90)
	s.border_width_left     = 2
	s.border_width_right    = 2
	s.border_width_top      = 2
	s.border_width_bottom   = 2
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	s.content_margin_left   = 18
	s.content_margin_right  = 18
	s.content_margin_top    = 14
	s.content_margin_bottom = 14
	return s
