# furnace_data.gd
extends Node

const RECIPES = {

	# COMMON METALS
	"copper_bar": {
		"name": "Copper Bar",
		"inputs": { "copper": 3 },
		"output_resource": "copper_bar",
		"output_amount": 1,
		"duration_seconds": 60,    # 1 minute
		"sell_value": 100          # 3 raw copper ~ 75; bar = 100 (33% bonus)
	},

	"tin_bar": {
		"name": "Tin Bar",
		"inputs": { "tin": 3 },
		"output_resource": "tin_bar",
		"output_amount": 1,
		"duration_seconds": 60,
		"sell_value": 90
	},

	"iron_bar": {
		"name": "Iron Bar",
		"inputs": { "iron": 3 },
		"output_resource": "iron_bar",
		"output_amount": 1,
		"duration_seconds": 90,
		"sell_value": 200
	},

	# ALLOYS (combine two metals)
	"bronze_bar": {
		"name": "Bronze Bar",
		"inputs": { "copper": 4, "tin": 2 },
		"output_resource": "bronze_bar",
		"output_amount": 1,
		"duration_seconds": 120,
		"sell_value": 250
	},

	"steel_bar": {
		"name": "Steel Bar",
		"inputs": { "iron": 4, "coal": 2 },     # carbon for steel
		"output_resource": "steel_bar",
		"output_amount": 1,
		"duration_seconds": 180,
		"sell_value": 400
	},

	"brass_bar": {
		"name": "Brass Bar",
		"inputs": { "copper": 3, "zinc": 2 },
		"output_resource": "brass_bar",
		"output_amount": 1,
		"duration_seconds": 150,
		"sell_value": 320
	},

	# PRECIOUS
	"silver_ingot": {
		"name": "Silver Ingot",
		"inputs": { "silver": 3 },
		"output_resource": "silver_ingot",
		"output_amount": 1,
		"duration_seconds": 240,
		"sell_value": 600
	},

	"gold_ingot": {
		"name": "Gold Ingot",
		"inputs": { "gold": 3 },
		"output_resource": "gold_ingot",
		"output_amount": 1,
		"duration_seconds": 360,
		"sell_value": 1200
	},

	# HARD METALS
	"titanium_ingot": {
		"name": "Titanium Ingot",
		"inputs": { "titanium": 3 },
		"output_resource": "titanium_ingot",
		"output_amount": 1,
		"duration_seconds": 480,    # 8 minutes
		"sell_value": 2500
	},

	"tungsten_ingot": {
		"name": "Tungsten Ingot",
		"inputs": { "tungsten": 3 },
		"output_resource": "tungsten_ingot",
		"output_amount": 1,
		"duration_seconds": 600,    # 10 minutes
		"sell_value": 4000
	},

	# CHEMICAL / EXOTIC
	"gunpowder": {
		"name": "Gunpowder",
		"inputs": { "sulfur": 4, "coal": 2 },
		"output_resource": "gunpowder",
		"output_amount": 2,         # makes 2 per batch
		"duration_seconds": 120,
		"sell_value": 80
	},

	"uranium_rod": {
		"name": "Refined Uranium",
		"inputs": { "uranium": 3, "lead": 5 },    # lead for shielding
		"output_resource": "uranium_rod",
		"output_amount": 1,
		"duration_seconds": 900,    # 15 minutes
		"sell_value": 8000
	},

	# ENDGAME
	"mythril_bar": {
		"name": "Mythril Bar",
		"inputs": { "mythril": 3, "crystal": 5 },
		"output_resource": "mythril_bar",
		"output_amount": 1,
		"duration_seconds": 1200,   # 20 minutes
		"sell_value": 12000
	},

	"adamantine_plate": {
		"name": "Adamantine Plate",
		"inputs": { "adamantium": 4, "tungsten": 3 },
		"output_resource": "adamantine_plate",
		"output_amount": 1,
		"duration_seconds": 1800,   # 30 minutes
		"sell_value": 20000
	}
}
