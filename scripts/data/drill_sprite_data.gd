extends Node

# Indexed by drill_tier (0=bronze, 1=steel, 2=titanium, 3=diamond, 4=plasma)
# Each tier has 7 animation keys matching _get_drill_animation_name() returns:
#   "down", "left", "right", "left_right", "bottom_left", "bottom_right", "full"
# Each key holds an array of 3 frame textures.

const SPRITES: Array = [

	# ── 0: BRONZE ─────────────────────────────────────────────────────────────
	{
		"down": [
			preload("res://assets/Player/Bronze/drill_bottom_bronze_animated_frame1.png"),
			preload("res://assets/Player/Bronze/drill_bottom_bronze_animated_frame2.png"),
			preload("res://assets/Player/Bronze/drill_bottom_bronze_animated_frame3.png"),
		],
		"left": [
			preload("res://assets/Player/Bronze/drill_left_bronze_frame1.png"),
			preload("res://assets/Player/Bronze/drill_left_bronze_frame2.png"),
			preload("res://assets/Player/Bronze/drill_left_bronze_frame3.png"),
		],
		"right": [
			preload("res://assets/Player/Bronze/drill_right_bronze_frame1.png"),
			preload("res://assets/Player/Bronze/drill_right_bronze_frame2.png"),
			preload("res://assets/Player/Bronze/drill_right_bronze_frame3.png"),
		],
		"left_right": [
			preload("res://assets/Player/Bronze/drill_leftright_bronze_frame1.png"),
			preload("res://assets/Player/Bronze/drill_leftright_bronze_frame2.png"),
			preload("res://assets/Player/Bronze/drill_leftright_bronze_frame3.png"),
		],
		"bottom_left": [
			preload("res://assets/Player/Bronze/drill_bottomleft_bronze_frame1.png"),
			preload("res://assets/Player/Bronze/drill_bottomleft_bronze_frame2.png"),
			preload("res://assets/Player/Bronze/drill_bottomleft_bronze_frame3.png"),
		],
		"bottom_right": [
			preload("res://assets/Player/Bronze/drill_bottomright_bronze_frame1.png"),
			preload("res://assets/Player/Bronze/drill_bottomright_bronze_frame2.png"),
			preload("res://assets/Player/Bronze/drill_bottomright_bronze_frame3.png"),
		],
		"full": [
			preload("res://assets/Player/Bronze/drill_full_bronze_frame1.png"),
			preload("res://assets/Player/Bronze/drill_full_bronze_frame2.png"),
			preload("res://assets/Player/Bronze/drill_full_bronze_frame3.png"),
		],
	},

	# ── 1: STEEL ──────────────────────────────────────────────────────────────
	{
		"down": [
			preload("res://assets/Player/Steel/drill_bottom_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_bottom_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_bottom_steel_frame3.png"),
		],
		"left": [
			preload("res://assets/Player/Steel/drill_left_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_left_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_left_steel_frame3.png"),
		],
		"right": [
			preload("res://assets/Player/Steel/drill_right_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_right_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_right_steel_frame3.png"),
		],
		"left_right": [
			preload("res://assets/Player/Steel/drill_leftright_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_leftright_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_leftright_steel_frame3.png"),
		],
		"bottom_left": [
			preload("res://assets/Player/Steel/drill_bottomleft_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_bottomleft_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_bottomleft_steel_frame3.png"),
		],
		"bottom_right": [
			preload("res://assets/Player/Steel/drill_bottomright_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_bottomright_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_bottomright_steel_frame3.png"),
		],
		"full": [
			preload("res://assets/Player/Steel/drill_full_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_full_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_full_steel_frame3.png"),
		],
	},

	# ── 2: REINFORCED STEEL (uses Steel sprites until dedicated art is added) ───
	{
		"down": [
			preload("res://assets/Player/Steel/drill_bottom_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_bottom_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_bottom_steel_frame3.png"),
		],
		"left": [
			preload("res://assets/Player/Steel/drill_left_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_left_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_left_steel_frame3.png"),
		],
		"right": [
			preload("res://assets/Player/Steel/drill_right_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_right_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_right_steel_frame3.png"),
		],
		"left_right": [
			preload("res://assets/Player/Steel/drill_leftright_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_leftright_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_leftright_steel_frame3.png"),
		],
		"bottom_left": [
			preload("res://assets/Player/Steel/drill_bottomleft_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_bottomleft_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_bottomleft_steel_frame3.png"),
		],
		"bottom_right": [
			preload("res://assets/Player/Steel/drill_bottomright_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_bottomright_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_bottomright_steel_frame3.png"),
		],
		"full": [
			preload("res://assets/Player/Steel/drill_full_steel_frame1.png"),
			preload("res://assets/Player/Steel/drill_full_steel_frame2.png"),
			preload("res://assets/Player/Steel/drill_full_steel_frame3.png"),
		],
	},

	# ── 3: TITANIUM ───────────────────────────────────────────────────────────
	{
		"down": [
			preload("res://assets/Player/Titanium/drill_bottom_titanium_frame1.png"),
			preload("res://assets/Player/Titanium/drill_bottom_titanium_frame2.png"),
			preload("res://assets/Player/Titanium/drill_bottom_titanium_frame3.png"),
		],
		"left": [
			preload("res://assets/Player/Titanium/drill_left_titanium_frame1.png"),
			preload("res://assets/Player/Titanium/drill_left_titanium_frame2.png"),
			preload("res://assets/Player/Titanium/drill_left_titanium_frame3.png"),
		],
		"right": [
			preload("res://assets/Player/Titanium/drill_right_titanium_frame1.png"),
			preload("res://assets/Player/Titanium/drill_right_titanium_frame2.png"),
			preload("res://assets/Player/Titanium/drill_right_titanium_frame3.png"),
		],
		"left_right": [
			preload("res://assets/Player/Titanium/drill_leftright_titanium_frame1.png"),
			preload("res://assets/Player/Titanium/drill_leftright_titanium_frame2.png"),
			preload("res://assets/Player/Titanium/drill_leftright_titanium_frame3.png"),
		],
		"bottom_left": [
			preload("res://assets/Player/Titanium/drill_bottomleft_titanium_frame1.png"),
			preload("res://assets/Player/Titanium/drill_bottomleft_titanium_frame2.png"),
			preload("res://assets/Player/Titanium/drill_bottomleft_titanium_frame3.png"),
		],
		"bottom_right": [
			preload("res://assets/Player/Titanium/drill_bottomright_titanium_frame1.png"),
			preload("res://assets/Player/Titanium/drill_bottomright_titanium_frame2.png"),
			preload("res://assets/Player/Titanium/drill_bottomright_titanium_frame3.png"),
		],
		"full": [
			preload("res://assets/Player/Titanium/drill_full_titanium_frame1.png"),
			preload("res://assets/Player/Titanium/drill_full_titanium_frame2.png"),
			preload("res://assets/Player/Titanium/drill_full_titanium_frame3.png"),
		],
	},

	# ── 4: DIAMOND ────────────────────────────────────────────────────────────
	{
		"down": [
			preload("res://assets/Player/Diamond/drill_bottom_diamond_frame1.png"),
			preload("res://assets/Player/Diamond/drill_bottom_diamond_frame2.png"),
			preload("res://assets/Player/Diamond/drill_bottom_diamond_frame3.png"),
		],
		"left": [
			preload("res://assets/Player/Diamond/drill_left_diamond_frame1.png"),
			preload("res://assets/Player/Diamond/drill_left_diamond_frame2.png"),
			preload("res://assets/Player/Diamond/drill_left_diamond_frame3.png"),
		],
		"right": [
			preload("res://assets/Player/Diamond/drill_right_diamond_frame1.png"),
			preload("res://assets/Player/Diamond/drill_right_diamond_frame2.png"),
			preload("res://assets/Player/Diamond/drill_right_diamond_frame3.png"),
		],
		"left_right": [
			preload("res://assets/Player/Diamond/drill_leftright_diamond_frame1.png"),
			preload("res://assets/Player/Diamond/drill_leftright_diamond_frame2.png"),
			preload("res://assets/Player/Diamond/drill_leftright_diamond_frame3.png"),
		],
		"bottom_left": [
			preload("res://assets/Player/Diamond/drill_bottomleft_diamond_frame1.png"),
			preload("res://assets/Player/Diamond/drill_bottomleft_diamond_frame2.png"),
			preload("res://assets/Player/Diamond/drill_bottomleft_diamond_frame3.png"),
		],
		"bottom_right": [
			preload("res://assets/Player/Diamond/drill_bottomright_diamond_frame1.png"),
			preload("res://assets/Player/Diamond/drill_bottomright_diamond_frame2.png"),
			preload("res://assets/Player/Diamond/drill_bottomright_diamond_frame3.png"),
		],
		"full": [
			preload("res://assets/Player/Diamond/drill_full_diamond_frame1.png"),
			preload("res://assets/Player/Diamond/drill_full_diamond_frame2.png"),
			preload("res://assets/Player/Diamond/drill_full_diamond_frame3.png"),
		],
	},

	# ── 5: PLASMA ─────────────────────────────────────────────────────────────
	{
		"down": [
			preload("res://assets/Player/Plasma/drill_bottom_plasma_frame1.png"),
			preload("res://assets/Player/Plasma/drill_bottom_plasma_frame2.png"),
			preload("res://assets/Player/Plasma/drill_bottom_plasma_frame3.png"),
		],
		"left": [
			preload("res://assets/Player/Plasma/drill_left_plasma_frame1.png"),
			preload("res://assets/Player/Plasma/drill_left_plasma_frame2.png"),
			preload("res://assets/Player/Plasma/drill_left_plasma_frame3.png"),
		],
		"right": [
			preload("res://assets/Player/Plasma/drill_right_plasma_frame1.png"),
			preload("res://assets/Player/Plasma/drill_right_plasma_frame2.png"),
			preload("res://assets/Player/Plasma/drill_right_plasma_frame3.png"),
		],
		"left_right": [
			preload("res://assets/Player/Plasma/drill_leftright_plasma_frame1.png"),
			preload("res://assets/Player/Plasma/drill_leftright_plasma_frame2.png"),
			preload("res://assets/Player/Plasma/drill_leftright_plasma_frame3.png"),
		],
		"bottom_left": [
			preload("res://assets/Player/Plasma/drill_bottomleft_plasma_frame1.png"),
			preload("res://assets/Player/Plasma/drill_bottomleft_plasma_frame2.png"),
			preload("res://assets/Player/Plasma/drill_bottomleft_plasma_frame3.png"),
		],
		"bottom_right": [
			preload("res://assets/Player/Plasma/drill_bottomright_plasma_frame1.png"),
			preload("res://assets/Player/Plasma/drill_bottomright_plasma_frame2.png"),
			preload("res://assets/Player/Plasma/drill_bottomright_plasma_frame3.png"),
		],
		"full": [
			preload("res://assets/Player/Plasma/drill_full_plasma_frame1.png"),
			preload("res://assets/Player/Plasma/drill_full_plasma_frame2.png"),
			preload("res://assets/Player/Plasma/drill_full_plasma_frame3.png"),
		],
	},
]

const TIER_NAMES: Array[String] = ["Bronze", "Steel", "Reinforced Steel", "Titanium", "Diamond", "Plasma"]
