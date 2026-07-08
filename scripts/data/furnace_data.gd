# furnace_data.gd
extends Node

# Coal is a required fuel in every recipe.
# duration_seconds: wall-clock time to complete the smelt.
const RECIPES = {

	# COMMON METALS
	"copper_bar": {
		"name": "Copper Bar",
		"inputs": { "copper": 3, "coal": 1 },
		"output_resource": "copper_bar",
		"output_amount": 1,
		"duration_seconds": 60,
	},
	"tin_bar": {
		"name": "Tin Bar",
		"inputs": { "tin": 3, "coal": 1 },
		"output_resource": "tin_bar",
		"output_amount": 1,
		"duration_seconds": 60,
	},
	"iron_bar": {
		"name": "Iron Bar",
		"inputs": { "iron": 3, "coal": 1 },
		"output_resource": "iron_bar",
		"output_amount": 1,
		"duration_seconds": 90,
	},

	# ALLOYS
	"bronze_bar": {
		"name": "Bronze Bar",
		"inputs": { "copper": 4, "tin": 2, "coal": 2 },
		"output_resource": "bronze_bar",
		"output_amount": 1,
		"duration_seconds": 120,
	},
	"steel_bar": {
		"name": "Steel Bar",
		"inputs": { "iron": 4, "coal": 3 },
		"output_resource": "steel_bar",
		"output_amount": 1,
		"duration_seconds": 180,
	},
	"brass_bar": {
		"name": "Brass Bar",
		"inputs": { "copper": 3, "zinc": 2, "coal": 2 },
		"output_resource": "brass_bar",
		"output_amount": 1,
		"duration_seconds": 150,
	},

	# PRECIOUS
	"silver_ingot": {
		"name": "Silver Ingot",
		"inputs": { "silver": 3, "coal": 2 },
		"output_resource": "silver_ingot",
		"output_amount": 1,
		"duration_seconds": 240,
	},
	"gold_ingot": {
		"name": "Gold Ingot",
		"inputs": { "gold": 3, "coal": 2 },
		"output_resource": "gold_ingot",
		"output_amount": 1,
		"duration_seconds": 360,
	},

	# HARD METALS
	"titanium_ingot": {
		"name": "Titanium Ingot",
		"inputs": { "titanium": 3, "coal": 3 },
		"output_resource": "titanium_ingot",
		"output_amount": 1,
		"duration_seconds": 480,
	},
	"tungsten_ingot": {
		"name": "Tungsten Ingot",
		"inputs": { "tungsten": 3, "coal": 3 },
		"output_resource": "tungsten_ingot",
		"output_amount": 1,
		"duration_seconds": 600,
	},

	# CHEMICAL
	"gunpowder": {
		"name": "Gunpowder",
		"inputs": { "sulfur": 4, "coal": 2 },
		"output_resource": "gunpowder",
		"output_amount": 2,
		"duration_seconds": 120,
	},

	# EXOTIC
	"uranium_rod": {
		"name": "Refined Uranium",
		"inputs": { "uranium": 3, "lead": 5, "coal": 4 },
		"output_resource": "uranium_rod",
		"output_amount": 1,
		"duration_seconds": 900,
	},

	# ENDGAME
	"mythril_bar": {
		"name": "Mythril Bar",
		"inputs": { "mythril": 3, "crystal": 5, "coal": 4 },
		"output_resource": "mythril_bar",
		"output_amount": 1,
		"duration_seconds": 1200,
	},
	"adamantine_plate": {
		"name": "Adamantine Plate",
		"inputs": { "adamantium": 4, "tungsten": 3, "coal": 5 },
		"output_resource": "adamantine_plate",
		"output_amount": 1,
		"duration_seconds": 1800,
	},
}
