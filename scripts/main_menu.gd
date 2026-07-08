# main_menu.gd
extends Node2D

const W := 1280.0
const H := 720.0

const TEX_TERRAIN = preload("res://assets/Art/Environment/terrain.png")
const TILE_SRC  := 16    # source tile px in terrain.png
const TILE_DSP  := 48    # display px per tile (3× scale)

# Terrain grid — large enough for ~90 s of diagonal scrolling
const GRID_COLS := 55
const GRID_ROWS := 32

# Diagonal camera speed (world px / second)
const CAM_VEL := Vector2(18.0, 12.0)

# ── Live nodes ────────────────────────────────────────────────────────────────
var _terrain_root: Node2D
var _music: AudioStreamPlayer
var _title: Label
var _settings: CanvasLayer
var _ui_nodes_intro: Array  # [[node, delay], ...]

# ── Ore particle pool ─────────────────────────────────────────────────────────
const PARTICLE_COUNT := 45
var _ptcl_pos:   PackedVector2Array
var _ptcl_vel:   PackedVector2Array
var _ptcl_life:  PackedFloat32Array
var _ptcl_nodes: Array[ColorRect]

# ── Animation ─────────────────────────────────────────────────────────────────
var _time: float = 0.0


func _ready() -> void:
	_build_terrain()
	_build_particles()
	_build_ui()
	_build_settings()
	_build_music()
	_play_intro()


func _process(delta: float) -> void:
	_time += delta
	_terrain_root.position -= CAM_VEL * delta
	_animate_particles(delta)


# ══════════════════════════════════════════════════════════════════════════════
# TERRAIN GRID
# ══════════════════════════════════════════════════════════════════════════════

func _build_terrain() -> void:
	_terrain_root = Node2D.new()
	_terrain_root.position = Vector2.ZERO
	add_child(_terrain_root)

	# Zone definitions: [row_start, row_end, base_col, base_row, ores, ore_chance, tint]
	# terrain.png atlas: col 0-4, row 0=terrain 1=common 2=metals 3=precious 4=crystals 5=hazards 6=special
	var zones: Array = [
		[0,  3,  1, 0, [[0,1],[1,1],[3,1],[4,1]],           0.10, Color(1.00, 1.00, 1.00)],  # Dirt + basic ores
		[4,  7,  2, 0, [[0,2],[1,2],[2,1],[0,1],[2,2]],     0.09, Color(0.88, 0.88, 0.90)],  # Stone + iron/silver
		[8,  12, 3, 0, [[0,3],[1,3],[2,3],[3,3],[0,2]],     0.09, Color(0.75, 0.75, 0.82)],  # Hard Stone + gold/platinum
		[13, 21, 4, 0, [[0,4],[1,4],[2,4],[4,4],[0,6],[2,6],[1,6]], 0.08, Color(0.58, 0.52, 0.72)],  # Deep + crystals/mythril
		[22, 31, 4, 0, [[0,4],[4,4],[1,6],[3,6],[0,6]],     0.07, Color(0.42, 0.36, 0.58)],  # Abyss
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 9001

	for z in zones:
		var row_start: int = z[0]
		var row_end:   int = z[1]
		var base_col:  int = z[2]
		var base_row:  int = z[3]
		var ores:      Array = z[4]
		var ore_ch:    float = z[5]
		var tint:      Color = z[6]

		for row in range(row_start, row_end + 1):
			for col in range(GRID_COLS):
				var tc := base_col
				var trow := base_row
				if ores.size() > 0 and rng.randf() < ore_ch:
					var ore: Array = ores[rng.randi() % ores.size()]
					tc   = ore[0]
					trow = ore[1]

				var spr := Sprite2D.new()
				spr.texture = TEX_TERRAIN
				spr.region_enabled = true
				spr.region_rect = Rect2(tc * TILE_SRC, trow * TILE_SRC, TILE_SRC, TILE_SRC)
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				spr.scale = Vector2(3.0, 3.0)
				spr.position = Vector2(
					col * TILE_DSP + TILE_DSP * 0.5,
					row * TILE_DSP + TILE_DSP * 0.5
				)
				spr.self_modulate = tint
				_terrain_root.add_child(spr)


# ══════════════════════════════════════════════════════════════════════════════
# ORE PARTICLES  (screen-space, CanvasLayer)
# ══════════════════════════════════════════════════════════════════════════════

func _build_particles() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	var ore_colors: Array[Color] = [
		Color(0.9, 0.65, 0.25),  # copper/gold
		Color(0.35, 0.85, 0.95), # crystal
		Color(0.85, 0.85, 0.85), # iron
		Color(0.65, 0.35, 0.90), # mythril/deep
		Color(0.30, 0.90, 0.40), # uranium glow
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 888

	_ptcl_pos  = PackedVector2Array()
	_ptcl_vel  = PackedVector2Array()
	_ptcl_life = PackedFloat32Array()
	_ptcl_nodes = []

	for i in range(PARTICLE_COUNT):
		var px: float = rng.randf_range(0, W)
		var py: float = rng.randf_range(50, H)
		_ptcl_pos.append(Vector2(px, py))
		_ptcl_vel.append(Vector2(rng.randf_range(-6, 6), rng.randf_range(-28, -10)))
		_ptcl_life.append(rng.randf_range(0.0, 4.5))

		var cr := ColorRect.new()
		cr.color = ore_colors[i % ore_colors.size()]
		cr.size = Vector2(2, 2)
		cr.position = Vector2(px, py)
		cr.modulate.a = 0.0
		layer.add_child(cr)
		_ptcl_nodes.append(cr)


func _animate_particles(delta: float) -> void:
	for i in range(PARTICLE_COUNT):
		_ptcl_life[i] -= delta
		if _ptcl_life[i] <= 0.0:
			_respawn_particle(i)
			continue
		var pos: Vector2 = _ptcl_pos[i] + _ptcl_vel[i] * delta
		_ptcl_pos[i] = pos
		var t: float = 1.0 - (_ptcl_life[i] / 4.5)
		_ptcl_nodes[i].position  = pos
		_ptcl_nodes[i].modulate.a = sin(clampf(t, 0.0, 1.0) * PI) * 0.70


func _respawn_particle(i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec() + i * 31
	_ptcl_pos[i]  = Vector2(rng.randf_range(0, W), rng.randf_range(H * 0.3, H))
	_ptcl_vel[i]  = Vector2(rng.randf_range(-6, 6), rng.randf_range(-30, -10))
	_ptcl_life[i] = rng.randf_range(3.0, 5.5)
	_ptcl_nodes[i].modulate.a = 0.0


# ══════════════════════════════════════════════════════════════════════════════
# UI
# ══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	_ui_nodes_intro = []

	# Dark panel behind the text
	var panel := ColorRect.new()
	panel.size       = Vector2(660, H)
	panel.position   = Vector2.ZERO
	panel.color      = Color(0.0, 0.0, 0.0, 0.52)
	panel.modulate.a = 0.0
	ui.add_child(panel)
	_ui_nodes_intro.append([panel, 0.0])

	# Title
	_title = Label.new()
	_title.text = "DEEP CORE"
	_title.position = Vector2(55, 88)
	_title.add_theme_font_size_override("font_size", 102)
	_title.add_theme_color_override("font_color",        Color(0.97, 0.80, 0.30))
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_title.add_theme_constant_override("shadow_offset_x", 5)
	_title.add_theme_constant_override("shadow_offset_y", 5)
	_title.modulate.a = 0.0
	ui.add_child(_title)
	_ui_nodes_intro.append([_title, 0.1])

	# Subtitle
	var sub := Label.new()
	sub.text = "Mine Deeper.  Go Further."
	sub.position = Vector2(62, 200)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.72, 0.60, 0.38))
	sub.modulate.a = 0.0
	ui.add_child(sub)
	_ui_nodes_intro.append([sub, 0.35])

	var sep := ColorRect.new()
	sep.size     = Vector2(480, 2)
	sep.position = Vector2(58, 232)
	sep.color    = Color(0.65, 0.48, 0.20, 0.6)
	sep.modulate.a = 0.0
	ui.add_child(sep)
	_ui_nodes_intro.append([sep, 0.40])

	# Buttons
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(62, 258)
	vbox.add_theme_constant_override("separation", 12)
	ui.add_child(vbox)

	var delay := 0.55
	var has_save := SaveSystem.has_save()

	if has_save:
		var btn_cont := _make_btn("▶  Continue")
		btn_cont.pressed.connect(_on_continue)
		vbox.add_child(btn_cont)
		_ui_nodes_intro.append([btn_cont, delay])
		delay += 0.10

	var btn_new := _make_btn("⊕  New Game")
	btn_new.pressed.connect(_on_new_game)
	if has_save:
		btn_new.add_theme_color_override("font_color", Color(0.78, 0.68, 0.48))
	vbox.add_child(btn_new)
	_ui_nodes_intro.append([btn_new, delay])
	delay += 0.10

	if has_save:
		var btn_load := _make_btn("↺  Load Game")
		btn_load.pressed.connect(_on_load_game)
		btn_load.add_theme_color_override("font_color", Color(0.78, 0.68, 0.48))
		vbox.add_child(btn_load)
		_ui_nodes_intro.append([btn_load, delay])
		delay += 0.10

	var btn_settings := _make_btn("⚙  Settings")
	btn_settings.pressed.connect(_on_settings)
	btn_settings.add_theme_color_override("font_color", Color(0.78, 0.68, 0.48))
	vbox.add_child(btn_settings)
	_ui_nodes_intro.append([btn_settings, delay])
	delay += 0.10

	var btn_quit := _make_btn("✕  Quit")
	btn_quit.pressed.connect(get_tree().quit)
	btn_quit.add_theme_color_override("font_color", Color(0.68, 0.52, 0.40))
	vbox.add_child(btn_quit)
	_ui_nodes_intro.append([btn_quit, delay])

	# Version tag
	var ver := Label.new()
	ver.text = "v0.1 alpha"
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.42, 0.37, 0.28, 0.7))
	ver.position = Vector2(W - 110, H - 24)
	ui.add_child(ver)


func _build_settings() -> void:
	_settings = load("res://scripts/settings_panel.gd").new()
	add_child(_settings)


func _make_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(290, 50)
	btn.add_theme_font_size_override("font_size", 24)
	btn.modulate.a = 0.0

	var n := _flat_style(Color(0.10, 0.07, 0.03, 0.88), Color(0.55, 0.40, 0.15, 0.80))
	var h := _flat_style(Color(0.22, 0.14, 0.05, 0.95), Color(0.90, 0.70, 0.25, 1.00))
	var p := _flat_style(Color(0.32, 0.20, 0.07, 1.00), Color(1.00, 0.85, 0.40, 1.00))

	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color",         Color(0.90, 0.78, 0.50))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.92, 0.65))
	btn.add_theme_color_override("font_pressed_color", Color(1.00, 1.00, 0.80))
	return btn


func _flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	return s


# ══════════════════════════════════════════════════════════════════════════════
# MUSIC
# ══════════════════════════════════════════════════════════════════════════════

func _build_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream   = load("res://assets/Audio/Ambience/Main_Menu.mp3")
	_music.bus      = "Music"
	_music.volume_db = -5.0
	_music.finished.connect(_music.play)
	add_child(_music)
	_music.play()


# ══════════════════════════════════════════════════════════════════════════════
# INTRO TWEEN
# ══════════════════════════════════════════════════════════════════════════════

func _play_intro() -> void:
	for entry in _ui_nodes_intro:
		var node: CanvasItem = entry[0]
		var delay: float     = entry[1]
		var tw := create_tween()
		tw.tween_property(node, "modulate:a", 1.0, 0.4).set_delay(delay)

	# Title breathe (runs forever)
	var tw_breathe := create_tween().set_loops()
	tw_breathe.tween_property(_title, "scale", Vector2(1.008, 1.008), 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_breathe.tween_property(_title, "scale", Vector2(1.0, 1.0), 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ══════════════════════════════════════════════════════════════════════════════
# BUTTON HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_play() -> void:
	_fade_out_then(func() -> void: get_tree().change_scene_to_file("res://scenes/Main.tscn"))


func _on_continue() -> void:
	_fade_out_then(func() -> void: get_tree().change_scene_to_file("res://scenes/Main.tscn"))


func _on_load_game() -> void:
	_fade_out_then(func() -> void: get_tree().change_scene_to_file("res://scenes/Main.tscn"))


func _on_new_game() -> void:
	SaveSystem.clear_save()
	_fade_out_then(func() -> void: get_tree().change_scene_to_file("res://scenes/Main.tscn"))


func _on_settings() -> void:
	_settings.open()


func _fade_out_then(callback: Callable) -> void:
	if _music:
		var tw_m := create_tween()
		tw_m.tween_property(_music, "volume_db", -60.0, 0.5)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(callback)
