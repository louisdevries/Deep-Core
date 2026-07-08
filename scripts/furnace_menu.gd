extends CanvasLayer

const FurnaceData  = preload("res://scripts/data/furnace_data.gd")
const ResourceData = preload("res://scripts/data/resource_data.gd")

@onready var recipe_list:      VBoxContainer = $Panel/VBox/Content/RecipeCol/Scroll/RecipeList
@onready var slots_container:  VBoxContainer = $Panel/VBox/Content/SlotsCol/SlotsContainer
@onready var close_button:     Button        = $Panel/VBox/CloseButton

var player: Node = null

var _slot_bars:       Array[ProgressBar] = []
var _slot_labels:     Array[Label]       = []
var _slot_done_cache: Array[bool]        = []


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	_apply_theme()


func _apply_theme() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	add_child(backdrop)
	move_child(backdrop, 0)

	$Panel.add_theme_stylebox_override("panel", _panel_style())
	$Panel/VBox.add_theme_constant_override("separation", 10)

	for path in ["VBox/HeaderHBox/TitleLabel", "VBox/Content/RecipeCol/RecipeLabel",
				 "VBox/Content/SlotsCol/SlotsLabel"]:
		var node := $Panel.get_node_or_null(path) as Label
		if not node:
			continue
		if "Title" in path:
			node.add_theme_font_size_override("font_size", 24)
			node.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
		else:
			node.add_theme_font_size_override("font_size", 14)
			node.add_theme_color_override("font_color", Color(0.80, 0.68, 0.44))

	var content := $Panel.get_node_or_null("VBox/Content") as HBoxContainer
	if content:
		content.add_theme_constant_override("separation", 14)

	_style_btn(close_button, false)


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


func _process(_delta: float) -> void:
	if not visible or not player:
		return

	for i in FurnaceSystem.slots.size():
		var is_done := FurnaceSystem.is_slot_done(i)
		if i < _slot_done_cache.size() and is_done and not _slot_done_cache[i]:
			rebuild()
			return

	for i in range(mini(_slot_bars.size(), FurnaceSystem.slots.size())):
		if FurnaceSystem.is_slot_empty(i) or FurnaceSystem.is_slot_done(i):
			continue
		var pb: ProgressBar = _slot_bars[i]
		var lbl: Label      = _slot_labels[i]
		if not is_instance_valid(pb) or not is_instance_valid(lbl):
			continue
		var slot = FurnaceSystem.slots[i]
		if slot == null:
			continue
		var recipe: Dictionary = FurnaceData.RECIPES[slot["recipe_id"]]
		var remaining: float   = FurnaceSystem.get_slot_remaining(i)
		var duration: float    = recipe["duration_seconds"]
		pb.value  = (1.0 - remaining / duration) * 100.0
		lbl.text  = "%ds remaining" % int(ceil(remaining))


func rebuild() -> void:
	_slot_bars.clear()
	_slot_labels.clear()
	_slot_done_cache.clear()

	for i in FurnaceSystem.slots.size():
		_slot_done_cache.append(FurnaceSystem.is_slot_done(i))

	for c in recipe_list.get_children():
		recipe_list.remove_child(c)
		c.queue_free()

	var display_order := [
		"copper_bar", "tin_bar", "iron_bar",
		"bronze_bar", "steel_bar", "brass_bar",
		"silver_ingot", "gold_ingot",
		"titanium_ingot", "tungsten_ingot",
		"gunpowder", "uranium_rod",
		"mythril_bar", "adamantine_plate",
	]
	for recipe_id in display_order:
		if FurnaceData.RECIPES.has(recipe_id):
			recipe_list.add_child(_build_recipe_row(recipe_id))

	for c in slots_container.get_children():
		slots_container.remove_child(c)
		c.queue_free()

	for i in FurnaceSystem.slots.size():
		slots_container.add_child(_build_slot_row(i))


func _build_recipe_row(recipe_id: String) -> Control:
	var recipe: Dictionary = FurnaceData.RECIPES[recipe_id]

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = recipe["name"]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.80, 0.52))
	vbox.add_child(name_lbl)

	var inputs_parts: Array = []
	for r in recipe["inputs"]:
		var have: int = player.resources.get(r, 0)
		var need: int = recipe["inputs"][r]
		inputs_parts.append("%s %d/%d" % [r.capitalize(), have, need])
	var cost_lbl := Label.new()
	cost_lbl.text = "  ".join(inputs_parts)
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.38))
	vbox.add_child(cost_lbl)

	var out_name: String = recipe["output_resource"].replace("_", " ").capitalize()
	var info_lbl := Label.new()
	info_lbl.text = "→ %s ×%d   (%ds)" % [out_name, recipe["output_amount"], recipe["duration_seconds"]]
	info_lbl.add_theme_font_size_override("font_size", 11)
	info_lbl.add_theme_color_override("font_color", Color(0.70, 0.80, 0.52))
	vbox.add_child(info_lbl)

	var btn := _make_btn("Smelt", true)
	btn.disabled = not _can_smelt(recipe_id)
	btn.pressed.connect(_on_smelt.bind(recipe_id))
	vbox.add_child(btn)

	return card


func _build_slot_row(slot_idx: int) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "Slot %d" % (slot_idx + 1)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.70, 0.60, 0.38))
	vbox.add_child(header)

	if FurnaceSystem.is_slot_empty(slot_idx):
		var lbl := Label.new()
		lbl.text = "— empty —"
		lbl.add_theme_color_override("font_color", Color(0.45, 0.38, 0.26))
		vbox.add_child(lbl)
		_slot_bars.append(ProgressBar.new())
		_slot_labels.append(Label.new())

	elif FurnaceSystem.is_slot_done(slot_idx):
		var slot   = FurnaceSystem.slots[slot_idx]
		var recipe: Dictionary = FurnaceData.RECIPES[slot["recipe_id"]]
		var out_name: String   = recipe["output_resource"].replace("_", " ").capitalize()

		var lbl := Label.new()
		lbl.text = "READY: %s × %d" % [out_name, recipe["output_amount"]]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.70, 0.90, 0.45))
		vbox.add_child(lbl)

		var btn := _make_btn("Collect", true)
		btn.pressed.connect(_on_collect.bind(slot_idx))
		vbox.add_child(btn)

		_slot_bars.append(ProgressBar.new())
		_slot_labels.append(Label.new())

	else:
		var slot   = FurnaceSystem.slots[slot_idx]
		var recipe: Dictionary = FurnaceData.RECIPES[slot["recipe_id"]]
		var remaining: float   = FurnaceSystem.get_slot_remaining(slot_idx)
		var duration: float    = recipe["duration_seconds"]

		var name_lbl := Label.new()
		name_lbl.text = recipe["name"]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
		vbox.add_child(name_lbl)

		var pb := ProgressBar.new()
		pb.max_value = 100.0
		pb.value     = (1.0 - remaining / duration) * 100.0
		var fill_sty := StyleBoxFlat.new()
		fill_sty.bg_color = Color(0.75, 0.52, 0.10)
		fill_sty.corner_radius_top_left     = 2
		fill_sty.corner_radius_top_right    = 2
		fill_sty.corner_radius_bottom_left  = 2
		fill_sty.corner_radius_bottom_right = 2
		var bg_sty := StyleBoxFlat.new()
		bg_sty.bg_color              = Color(0.08, 0.06, 0.03)
		bg_sty.border_color          = Color(0.40, 0.28, 0.10, 0.60)
		bg_sty.border_width_left     = 1
		bg_sty.border_width_right    = 1
		bg_sty.border_width_top      = 1
		bg_sty.border_width_bottom   = 1
		pb.add_theme_stylebox_override("fill",       fill_sty)
		pb.add_theme_stylebox_override("background", bg_sty)
		vbox.add_child(pb)

		var time_lbl := Label.new()
		time_lbl.text = "%ds remaining" % int(ceil(remaining))
		time_lbl.add_theme_font_size_override("font_size", 12)
		time_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.38))
		vbox.add_child(time_lbl)

		_slot_bars.append(pb)
		_slot_labels.append(time_lbl)

	return card


func _can_smelt(recipe_id: String) -> bool:
	var recipe: Dictionary = FurnaceData.RECIPES[recipe_id]
	for r in recipe["inputs"]:
		if player.resources.get(r, 0) < recipe["inputs"][r]:
			return false
	for i in FurnaceSystem.slots.size():
		if FurnaceSystem.is_slot_empty(i):
			return true
	return false


func _on_smelt(recipe_id: String) -> void:
	for i in FurnaceSystem.slots.size():
		if FurnaceSystem.is_slot_empty(i):
			if FurnaceSystem.start_recipe(i, recipe_id, player):
				rebuild()
			return


func _on_collect(slot_idx: int) -> void:
	FurnaceSystem.collect_slot(slot_idx, player)
	player._recompute_cargo()
	rebuild()


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
