# upgrade_data.gd
extends Node

const CATEGORY_DRILLING := "Drilling"
const CATEGORY_EQUIPMENT := "Equipment"
const CATEGORY_CAPACITY := "Capacity"

# Each upgrade is a chain: id -> array of tier dicts (tier index = array index + 1)
# Each tier has: cost, resources_required, effect (applied to player when bought)
const UPGRADES := {

	"drill_power": {
		"name": "Drill Power",
		"category": CATEGORY_DRILLING,
		"description": "Break harder rocks and ores.",
		"player_var": "drill_power",
		"tiers": [
			{ "money": 50,   "resources": {} },
			{ "money": 250,  "resources": { "copper": 5 } },
			{ "money": 750,  "resources": { "copper": 15, "iron": 5 } },
			{ "money": 2000, "resources": { "iron": 20 } },
			{ "money": 5000, "resources": { "iron": 25, "crystal": 10 } },
		]
	},

	"drill_swivel": {
		"name": "Drill Swivel",
		"category": CATEGORY_DRILLING,
		"description": "Drill sideways. Tier 1: stop-to-swivel. Tier 2: free swivel.",
		"player_var": "drill_swivel_tier",
		"tiers": [
			{ "money": 500,  "resources": { "copper": 10 } },
			{ "money": 2500, "resources": { "copper": 20, "iron": 10 } },
		]
	},

	"sonar_range": {
		"name": "Sonar Range",
		"category": CATEGORY_EQUIPMENT,
		"description": "Extends sonar detection radius.",
		"player_var": "sonar_range",
		"tiers": [
			{ "money": 200,  "resources": {} },
			{ "money": 600,  "resources": { "copper": 8 } },
			{ "money": 1500, "resources": { "copper": 15, "iron": 5 } },
		]
	},

	"cargo_capacity": {
		"name": "Cargo Capacity",
		"category": CATEGORY_CAPACITY,
		"description": "Carry more before needing to return.",
		"player_var": "max_cargo",
		"tiers": [
			{ "money": 150,  "resources": {} },
			{ "money": 500,  "resources": { "copper": 6 } },
			{ "money": 1500, "resources": { "iron": 10 } },
		]
	},

	"fuel_tank": {
		"name": "Fuel Tank",
		"category": CATEGORY_CAPACITY,
		"description": "Larger maximum fuel capacity.",
		"player_var": "max_fuel",
		"tiers": [
			{ "money": 200,  "resources": {} },
			{ "money": 700,  "resources": { "copper": 8 } },
			{ "money": 2000, "resources": { "iron": 12 } },
		]
	},

	"cable_length": {
		"name": "Cable Length",
		"category": CATEGORY_EQUIPMENT,
		"description": "How far down the cable can extend.",
		"player_var": "max_cable_length",
		"tiers": [
			{ "money": 300,  "resources": {} },
			{ "money": 1000, "resources": { "copper": 10 } },
			{ "money": 3000, "resources": { "iron": 15 } },
			{ "money": 8000, "resources": { "iron": 20, "crystal": 10 } },
		]
	},
}


# Helper: derive starting tier for each upgrade (used to count current level vs max)
const STARTING_VALUES := {
	"drill_power": 1,
	"drill_swivel_tier": 1,
	"sonar_range": 8,
	"max_cargo": 20,
	"max_fuel": 100.0,
	"max_cable_length": 800.0
}


# How much each tier upgrade changes the player_var
# For most things this is +1; for capacity/range we want bigger jumps
const TIER_INCREMENTS := {
	"drill_power": 1,
	"drill_swivel_tier": 1,
	"sonar_range": 3,    # +3 tiles per tier
	"max_cargo": 15,     # +15 per tier
	"max_fuel": 50.0,     # +50 per tier
	"max_cable_length": 400.0    # +25 tiles per upgrade
}
