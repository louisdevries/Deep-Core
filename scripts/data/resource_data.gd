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

	# REFINED (furnace outputs)
	"copper_bar": {
		"display_name": "Copper Bar",
		"value": 100,
		"color": Color(0.85, 0.45, 0.1, 1.0)
	},
	"tin_bar": {
		"display_name": "Tin Bar",
		"value": 90,
		"color": Color(0.75, 0.75, 0.7, 1.0)
	},
	"iron_bar": {
		"display_name": "Iron Bar",
		"value": 200,
		"color": Color(0.55, 0.6, 0.65, 1.0)
	},
	"bronze_bar": {
		"display_name": "Bronze Bar",
		"value": 250,
		"color": Color(0.8, 0.5, 0.2, 1.0)
	},
	"steel_bar": {
		"display_name": "Steel Bar",
		"value": 400,
		"color": Color(0.5, 0.55, 0.6, 1.0)
	},
	"brass_bar": {
		"display_name": "Brass Bar",
		"value": 320,
		"color": Color(0.85, 0.75, 0.3, 1.0)
	},
	"silver_ingot": {
		"display_name": "Silver Ingot",
		"value": 600,
		"color": Color(0.9, 0.9, 1.0, 1.0)
	},
	"gold_ingot": {
		"display_name": "Gold Ingot",
		"value": 1200,
		"color": Color(1.0, 0.85, 0.2, 1.0)
	},
	"titanium_ingot": {
		"display_name": "Titanium Ingot",
		"value": 2500,
		"color": Color(0.5, 0.65, 0.8, 1.0)
	},
	"tungsten_ingot": {
		"display_name": "Tungsten Ingot",
		"value": 4000,
		"color": Color(0.35, 0.4, 0.45, 1.0)
	},
	"gunpowder": {
		"display_name": "Gunpowder",
		"value": 80,
		"color": Color(0.25, 0.25, 0.2, 1.0)
	},
	"uranium_rod": {
		"display_name": "Uranium Rod",
		"value": 8000,
		"color": Color(0.2, 0.85, 0.2, 1.0)
	},
	"mythril_bar": {
		"display_name": "Mythril Bar",
		"value": 12000,
		"color": Color(0.6, 0.85, 1.0, 1.0)
	},
	"adamantine_plate": {
		"display_name": "Adamantine Plate",
		"value": 20000,
		"color": Color(0.35, 0.45, 0.55, 1.0)
	},
}

const DISPLAY_ORDER = [
	# Raw materials
	"basic_ore", "copper", "tin", "coal", "sulfur",
	"iron", "silver", "aluminum", "lead", "zinc",
	"gold", "platinum", "titanium", "tungsten",
	"crystal", "ruby", "sapphire", "emerald", "diamond",
	"obsidian", "uranium", "mythril", "adamantium",
	# Refined outputs
	"copper_bar", "tin_bar", "iron_bar", "bronze_bar", "steel_bar", "brass_bar",
	"silver_ingot", "gold_ingot", "titanium_ingot", "tungsten_ingot",
	"gunpowder", "uranium_rod", "mythril_bar", "adamantine_plate",
]
