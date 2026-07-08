# terrain_data.gd
extends Node

# material_tier controls which drill tier can break this tile:
#   Drill tier 0 (Bronze)          → breaks tier 1
#   Drill tier 1 (Steel)           → breaks tier 2
#   Drill tier 2 (Reinforced Steel)→ breaks tier 3
#   Drill tier 3 (Titanium)        → breaks tier 4
#   Drill tier 4 (Diamond)         → breaks tier 5
#   Drill tier 5 (Plasma)          → breaks tier 6
#   Gear 2/3 adds +1 to max breakable tier (overdrive / burnout)
#   material_tier 99 = indestructible

const TERRAIN_TYPES = {

	# ============================
	# ROW 0 — TERRAIN
	# ============================

	Vector2i(0, 0): {
		"name": "Grass",
		"material_tier": 1,
		"cargo": 0,
		"resource": null
	},

	Vector2i(1, 0): {
		"name": "Dirt",
		"material_tier": 1,
		"cargo": 0,
		"resource": null
	},

	Vector2i(2, 0): {
		"name": "Stone",
		"material_tier": 2,
		"cargo": 0,
		"resource": null
	},

	Vector2i(3, 0): {
		"name": "Hard Stone",
		"material_tier": 3,
		"cargo": 0,
		"resource": null
	},

	Vector2i(4, 0): {
		"name": "Deep Stone",
		"material_tier": 4,
		"cargo": 0,
		"resource": null
	},

	# ============================
	# ROW 1 — COMMON ORES
	# ============================

	Vector2i(0, 1): {
		"name": "Basic Ore",
		"material_tier": 1,
		"cargo": 1,
		"resource": null,
		"is_ore": true
	},

	Vector2i(1, 1): {
		"name": "Copper",
		"material_tier": 2,
		"cargo": 2,
		"resource": "copper"
	},

	Vector2i(2, 1): {
		"name": "Tin",
		"material_tier": 2,
		"cargo": 2,
		"resource": "tin"
	},

	Vector2i(3, 1): {
		"name": "Coal",
		"material_tier": 2,
		"cargo": 2,
		"resource": "coal"
	},

	Vector2i(4, 1): {
		"name": "Sulfur",
		"material_tier": 2,
		"cargo": 1,
		"resource": "sulfur"
	},

	# ============================
	# ROW 2 — METALS
	# ============================

	Vector2i(0, 2): {
		"name": "Iron",
		"material_tier": 3,
		"cargo": 3,
		"resource": "iron"
	},

	Vector2i(1, 2): {
		"name": "Silver",
		"material_tier": 3,
		"cargo": 3,
		"resource": "silver"
	},

	Vector2i(2, 2): {
		"name": "Aluminum",
		"material_tier": 3,
		"cargo": 2,
		"resource": "aluminum"
	},

	Vector2i(3, 2): {
		"name": "Lead",
		"material_tier": 3,
		"cargo": 5,
		"resource": "lead"
	},

	Vector2i(4, 2): {
		"name": "Zinc",
		"material_tier": 3,
		"cargo": 3,
		"resource": "zinc"
	},

	# ============================
	# ROW 3 — PRECIOUS
	# ============================

	Vector2i(0, 3): {
		"name": "Gold",
		"material_tier": 4,
		"cargo": 4,
		"resource": "gold"
	},

	Vector2i(1, 3): {
		"name": "Platinum",
		"material_tier": 4,
		"cargo": 4,
		"resource": "platinum"
	},

	Vector2i(2, 3): {
		"name": "Titanium",
		"material_tier": 4,
		"cargo": 5,
		"resource": "titanium"
	},

	Vector2i(3, 3): {
		"name": "Tungsten",
		"material_tier": 4,
		"cargo": 6,
		"resource": "tungsten"
	},

	# ============================
	# ROW 4 — CRYSTALS / GEMS
	# ============================

	Vector2i(0, 4): {
		"name": "Crystal",
		"material_tier": 5,
		"cargo": 5,
		"resource": "crystal"
	},

	Vector2i(1, 4): {
		"name": "Ruby",
		"material_tier": 5,
		"cargo": 5,
		"resource": "ruby"
	},

	Vector2i(2, 4): {
		"name": "Sapphire",
		"material_tier": 5,
		"cargo": 5,
		"resource": "sapphire"
	},

	Vector2i(3, 4): {
		"name": "Emerald",
		"material_tier": 5,
		"cargo": 5,
		"resource": "emerald"
	},

	Vector2i(4, 4): {
		"name": "Diamond",
		"material_tier": 5,
		"cargo": 6,
		"resource": "diamond",
		"mining_hazard": {
			"chance_per_tick": 0.15,
			"damage": 3.0,
			"prevented_by_var": "drill_tier",
			"safe_tier": 4    # Diamond drill (tier 4 in 0-indexed) prevents it
		}
	},

	# ============================
	# ROW 5 — HAZARDS
	# ============================

	Vector2i(0, 5): {
		"name": "Lava",
		"material_tier": 99,
		"cargo": 0,
		"resource": null,
		"hazard": "lava",
		"contact_damage": 25.0,
		"hazards": {
			"heat": {
				"damage": 2.0,
				"radius": 2,
				"protection_var": "heat_shield_tier",
				"protection_levels": [0.0, 0.5, 0.8, 1.0]
			}
		}
	},

	Vector2i(1, 5): {
		"name": "Gas Pocket",
		"material_tier": 1,
		"cargo": 0,
		"resource": null,
		"hazard": "gas",
		"fuel_damage": 20.0,
		"contact_damage": 0.0,
		"fuel_protection_var": "cabin_tier",
		"fuel_protection_levels": [0.0, 0.5, 0.75, 1.0]
	},

	Vector2i(2, 5): {
		"name": "Ice",
		"material_tier": 3,
		"cargo": 0,
		"resource": null,
		"hazard": "ice",
		"contact_damage": 0.0
	},

	Vector2i(3, 5): {
		"name": "Acid",
		"material_tier": 99,
		"cargo": 0,
		"resource": null,
		"hazard": "acid",
		"contact_damage": 15.0
	},

	# ============================
	# ROW 6 — SPECIAL
	# ============================

	Vector2i(0, 6): {
		"name": "Obsidian",
		"material_tier": 5,
		"cargo": 3,
		"resource": "obsidian"
	},

	Vector2i(1, 6): {
		"name": "Uranium",
		"material_tier": 6,
		"cargo": 4,
		"resource": "uranium",
		"contact_damage": 5.0,
		"hazards": {
			"radiation": {
				"damage": 5.0,
				"radius": 2,
				"protection_var": "cabin_tier",
				"protection_levels": [0.0, 0.5, 0.75, 1.0]
			}
		}
	},

	Vector2i(2, 6): {
		"name": "Mythril",
		"material_tier": 6,
		"cargo": 4,
		"resource": "mythril"
	},

	Vector2i(3, 6): {
		"name": "Adamantium",
		"material_tier": 6,
		"cargo": 8,
		"resource": "adamantium"
	},

	Vector2i(4, 6): {
		"name": "Concrete",
		"material_tier": 99,
		"cargo": 0,
		"resource": null
	},
}
