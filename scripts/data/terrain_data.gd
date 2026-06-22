# terrain_data.gd
extends Node

const TERRAIN_TYPES = {

	# ============================
	# ROW 0 — TERRAIN
	# ============================

	Vector2i(0, 0): {
		"name": "Grass",
		"required_power": 1,
		"cargo": 0,
		"resource": null
	},

	Vector2i(1, 0): {
		"name": "Dirt",
		"required_power": 1,
		"cargo": 0,
		"resource": null
	},

	Vector2i(2, 0): {
		"name": "Stone",
		"required_power": 2,
		"cargo": 0,
		"resource": null
	},

	Vector2i(3, 0): {
		"name": "Hard Stone",
		"required_power": 4,
		"cargo": 0,
		"resource": null
	},

	Vector2i(4, 0): {
		"name": "Deep Stone",
		"required_power": 6,
		"cargo": 0,
		"resource": null
	},

	# ============================
	# ROW 1 — COMMON ORES
	# ============================

	Vector2i(0, 1): {
		"name": "Basic Ore",
		"required_power": 2,
		"cargo": 1,
		"resource": null,
		"is_ore": true
	},

	Vector2i(1, 1): {
		"name": "Copper",
		"required_power": 3,
		"cargo": 2,
		"resource": "copper"
	},

	Vector2i(2, 1): {
		"name": "Tin",
		"required_power": 3,
		"cargo": 2,
		"resource": "tin"
	},

	Vector2i(3, 1): {
		"name": "Coal",
		"required_power": 2,
		"cargo": 2,
		"resource": "coal"
	},

	Vector2i(4, 1): {
		"name": "Sulfur",
		"required_power": 3,
		"cargo": 1,
		"resource": "sulfur"
	},

	# ============================
	# ROW 2 — METALS
	# ============================

	Vector2i(0, 2): {
		"name": "Iron",
		"required_power": 5,
		"cargo": 3,
		"resource": "iron"
	},

	Vector2i(1, 2): {
		"name": "Silver",
		"required_power": 5,
		"cargo": 3,
		"resource": "silver"
	},

	Vector2i(2, 2): {
		"name": "Aluminum",
		"required_power": 4,
		"cargo": 2,
		"resource": "aluminum"
	},

	Vector2i(3, 2): {
		"name": "Lead",
		"required_power": 5,
		"cargo": 5,
		"resource": "lead"
	},

	Vector2i(4, 2): {
		"name": "Zinc",
		"required_power": 5,
		"cargo": 3,
		"resource": "zinc"
	},

	# ============================
	# ROW 3 — PRECIOUS
	# ============================

	Vector2i(0, 3): {
		"name": "Gold",
		"required_power": 6,
		"cargo": 4,
		"resource": "gold"
	},

	Vector2i(1, 3): {
		"name": "Platinum",
		"required_power": 7,
		"cargo": 4,
		"resource": "platinum"
	},

	Vector2i(2, 3): {
		"name": "Titanium",
		"required_power": 8,
		"cargo": 5,
		"resource": "titanium"
	},

	Vector2i(3, 3): {
		"name": "Tungsten",
		"required_power": 9,
		"cargo": 6,
		"resource": "tungsten"
	},

	# ============================
	# ROW 4 — CRYSTALS / GEMS
	# ============================

	Vector2i(0, 4): {
		"name": "Crystal",
		"required_power": 6,
		"cargo": 5,
		"resource": "crystal"
	},

	Vector2i(1, 4): {
		"name": "Ruby",
		"required_power": 7,
		"cargo": 5,
		"resource": "ruby"
	},

	Vector2i(2, 4): {
		"name": "Sapphire",
		"required_power": 7,
		"cargo": 5,
		"resource": "sapphire"
	},

	Vector2i(3, 4): {
		"name": "Emerald",
		"required_power": 7,
		"cargo": 5,
		"resource": "emerald"
	},

	Vector2i(4, 4): {
		"name": "Diamond",
		"required_power": 9,
		"cargo": 6,
		"resource": "diamond"
	},

	# ============================
	# ROW 5 — HAZARDS
	# ============================

	Vector2i(0, 5): {
		"name": "Lava",
		"required_power": 999,
		"cargo": 0,
		"resource": null,
		"hazard": "lava",
		"contact_damage": 25.0
	},

	Vector2i(1, 5): {
		"name": "Gas Pocket",
		"required_power": 1,
		"cargo": 0,
		"resource": null,
		"hazard": "gas",
		"fuel_damage": 20.0,
		"contact_damage": 0.0
	},

	Vector2i(2, 5): {
		"name": "Ice",
		"required_power": 4,
		"cargo": 0,
		"resource": null,
		"hazard": "ice",
		"contact_damage": 0.0
	},

	Vector2i(3, 5): {
		"name": "Acid",
		"required_power": 999,
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
		"required_power": 8,
		"cargo": 3,
		"resource": "obsidian"
	},

	Vector2i(1, 6): {
		"name": "Uranium",
		"required_power": 8,
		"cargo": 4,
		"resource": "uranium",
		"contact_damage": 5.0    # uranium also damages you over time when carrying it nearby? optional
	},

	Vector2i(2, 6): {
		"name": "Mythril",
		"required_power": 10,
		"cargo": 4,
		"resource": "mythril"
	},

	Vector2i(3, 6): {
		"name": "Adamantium",
		"required_power": 12,
		"cargo": 8,
		"resource": "adamantium"
	},
	
	Vector2i(4, 6): {
		"name": "Concrete",
		"required_power": 9999,    # effectively undrillable
		"cargo": 0,
		"resource": null
	},
}
