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
	"thrusters": {
		"name": "Thrusters",
		"category": CATEGORY_EQUIPMENT,
		"description": "Vertical thrust for short bursts. Fast ascent at the cost of fuel.",
		"player_var": "has_thrusters",
		"tiers": [
			{ "money": 1500, "resources": { "copper": 15, "iron": 5 } },
		]
	},
	"furnace_slots": {
		"name": "Furnace Slots",
		"category": CATEGORY_EQUIPMENT,
		"description": "Refine multiple recipes simultaneously.",
		"player_var": "furnace_slot_count",
		"tiers": [
			{ "money": 500,   "resources": { "copper": 10 } },
			{ "money": 2000,  "resources": { "iron": 15 } },
			{ "money": 8000,  "resources": { "titanium": 8 } },
			{ "money": 25000, "resources": { "mythril": 3 } },
		]
	},
	"multi_drill": {
		"name": "Drill Array",
		"category": CATEGORY_DRILLING,
		"description": "Mount additional drill arms for parallel mining.",
		"player_var": "drill_count",
		"tiers": [
			{ "money": 3000, "resources": { "iron": 30, "copper": 25, "gold": 5 } },   # → 2 drills
			{ "money": 12000, "resources": { "platinum": 8, "titanium": 20, "gold": 15 } },  # → 3 drills
		]
	},
	
	"left_drill": {
		"name": "Left Drill Mount",
		"category": CATEGORY_DRILLING,
		"description": "Mounts a permanent drill on the left side.",
		"player_var": "has_left_drill",
		"tiers": [
			{ "money": 2500, "resources": { "iron": 20, "copper": 15 }, "result_value": true },
		]
	},

	"right_drill": {
		"name": "Right Drill Mount",
		"category": CATEGORY_DRILLING,
		"description": "Mounts a permanent drill on the right side.",
		"player_var": "has_right_drill",
		"tiers": [
			{ "money": 2500, "resources": { "iron": 20, "copper": 15 }, "result_value": true },
		]
	},
	"storage_capacity": {
		"name": "Storage Capacity",
		"category": CATEGORY_EQUIPMENT,
		"description": "Expand the safe storage at the refuel station.",
		"player_var": "max_storage",
		"tiers": [
			{ "money": 500,   "resources": { "iron": 10 } },
			{ "money": 2000,  "resources": { "iron": 25, "copper": 15 } },
			{ "money": 8000,  "resources": { "titanium": 10 } },
			{ "money": 25000, "resources": { "mythril": 5, "adamantium": 3 } },
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
	"max_cable_length": 1200.0,
	"has_thrusters": false,
	"drill_count": 1,
	"has_left_drill": false,
	"has_right_drill": false,
	"max_storage": 100,
}


# How much each tier upgrade changes the player_var
# For most things this is +1; for capacity/range we want bigger jumps
const TIER_INCREMENTS := {
	"drill_power": 1,
	"drill_swivel_tier": 1,
	"sonar_range": 3,    # +3 tiles per tier
	"max_cargo": 15,     # +15 per tier
	"max_fuel": 50.0,     # +50 per tier
	"max_cable_length": 400.0,   # +25 tiles per upgrade
	"has_thrusters": true,
	"drill_count": 1,    # +1 per tier
	"has_left_drill": true,
	"has_right_drill": true,
	"max_storage": 100,    # +100 storage per tier
}
