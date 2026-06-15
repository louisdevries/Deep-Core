# resource_data.gd
extends Node

const RESOURCES = {

	# ORES (row 1)
	"basic_ore": {
		"display_name": "Basic Ore",
		"value": 10,
		"color": Color(0.7, 0.55, 0.35, 1.0)
	},
	"copper": {
		"display_name": "Copper",
		"value": 25,
		"color": Color(1.0, 0.5, 0.1, 1.0)
	},
	"tin": {
		"display_name": "Tin",
		"value": 30,
		"color": Color(0.85, 0.85, 0.8, 1.0)
	},
	"coal": {
		"display_name": "Coal",
		"value": 15,
		"color": Color(0.3, 0.3, 0.3, 1.0)
	},
	"sulfur": {
		"display_name": "Sulfur",
		"value": 35,
		"color": Color(0.95, 0.9, 0.3, 1.0)
	},

	# METALS (row 2)
	"iron": {
		"display_name": "Iron",
		"value": 50,
		"color": Color(0.7, 0.75, 0.8, 1.0)
	},
	"silver": {
		"display_name": "Silver",
		"value": 120,
		"color": Color(0.95, 0.95, 0.95, 1.0)
	},
	"aluminum": {
		"display_name": "Aluminum",
		"value": 70,
		"color": Color(0.75, 0.8, 0.85, 1.0)
	},
	"lead": {
		"display_name": "Lead",
		"value": 60,
		"color": Color(0.45, 0.5, 0.55, 1.0)
	},
	"zinc": {
		"display_name": "Zinc",
		"value": 80,
		"color": Color(0.6, 0.65, 0.7, 1.0)
	},

	# PRECIOUS (row 3)
	"gold": {
		"display_name": "Gold",
		"value": 250,
		"color": Color(1.0, 0.85, 0.3, 1.0)
	},
	"platinum": {
		"display_name": "Platinum",
		"value": 400,
		"color": Color(0.95, 0.9, 0.85, 1.0)
	},
	"titanium": {
		"display_name": "Titanium",
		"value": 600,
		"color": Color(0.6, 0.7, 0.8, 1.0)
	},
	"tungsten": {
		"display_name": "Tungsten",
		"value": 900,
		"color": Color(0.4, 0.45, 0.5, 1.0)
	},

	# GEMS (row 4)
	"crystal": {
		"display_name": "Crystal",
		"value": 150,
		"color": Color(0.2, 1.0, 1.0, 1.0)
	},
	"ruby": {
		"display_name": "Ruby",
		"value": 500,
		"color": Color(0.95, 0.2, 0.2, 1.0)
	},
	"sapphire": {
		"display_name": "Sapphire",
		"value": 550,
		"color": Color(0.2, 0.4, 0.95, 1.0)
	},
	"emerald": {
		"display_name": "Emerald",
		"value": 700,
		"color": Color(0.15, 0.75, 0.45, 1.0)
	},
	"diamond": {
		"display_name": "Diamond",
		"value": 2000,
		"color": Color(0.8, 0.95, 1.0, 1.0)
	},

	# SPECIALS (row 6)
	"obsidian": {
		"display_name": "Obsidian",
		"value": 300,
		"color": Color(0.4, 0.3, 0.5, 1.0)
	},
	"uranium": {
		"display_name": "Uranium",
		"value": 1500,
		"color": Color(0.3, 0.9, 0.3, 1.0)
	},
	"mythril": {
		"display_name": "Mythril",
		"value": 3000,
		"color": Color(0.7, 0.9, 1.0, 1.0)
	},
	"adamantium": {
		"display_name": "Adamantium",
		"value": 5000,
		"color": Color(0.4, 0.5, 0.6, 1.0)
	},
}

# Helper: list materials in display order (categories grouped, valuable last)
const DISPLAY_ORDER = [
	"basic_ore", "copper", "tin", "coal", "sulfur",
	"iron", "silver", "aluminum", "lead", "zinc",
	"gold", "platinum", "titanium", "tungsten",
	"crystal", "ruby", "sapphire", "emerald", "diamond",
	"obsidian", "uranium", "mythril", "adamantium",
]
