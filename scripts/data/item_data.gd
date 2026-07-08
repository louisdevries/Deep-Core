extends Node

# One-time use items. use_type:
#   "instant"      — effect applied immediately on use
#   "place"        — spawns a Node2D at player position with a fuse timer
#   "place_return" — phase beacon: first use places it, second teleports back

const ITEMS: Dictionary = {

	# ── TIER 1 ────────────────────────────────────────────────────────────────
	"fuel_can": {
		"name": "Fuel Can",
		"description": "Restores 50 fuel.",
		"cost": 50,
		"tier": 1,
		"use_type": "instant",
	},
	"repair_kit": {
		"name": "Repair Kit",
		"description": "Restores 30 health.",
		"cost": 100,
		"tier": 1,
		"use_type": "instant",
	},
	"sonar_battery": {
		"name": "Sonar Battery",
		"description": "Instantly resets sonar cooldown.",
		"cost": 80,
		"tier": 1,
		"use_type": "instant",
	},

	# ── TIER 2 ────────────────────────────────────────────────────────────────
	"dynamite": {
		"name": "Dynamite",
		"description": "Placed explosive. 1.5s fuse. Destroys 3x3 area.\nBreaks 1 tier above drill. 30% resource loss.\nDamages player if within 64px!",
		"cost": 250,
		"tier": 2,
		"use_type": "place",
		"icon_path": "res://assets/Art/Tools/dynamite.png",
		"fuse_time": 1.5,
		"tier_bonus": 1,
	},
	"large_fuel_can": {
		"name": "Large Fuel Can",
		"description": "Fully refills fuel.",
		"cost": 200,
		"tier": 2,
		"use_type": "instant",
	},
	"teleport_charge": {
		"name": "Teleport Charge",
		"description": "Instantly return to refuel zone. Cargo preserved.",
		"cost": 500,
		"tier": 2,
		"use_type": "instant",
	},

	# ── TIER 3 ────────────────────────────────────────────────────────────────
	"shaped_charge": {
		"name": "Shaped Charge",
		"description": "Placed explosive. Short fuse. Blasts a vertical column 10 tiles deep.\nBreaks 2 tiers above drill. Resources not collected.",
		"cost": 600,
		"tier": 3,
		"use_type": "place",
		"icon_path": "res://assets/Art/Tools/vertical_charge.png",
		"fuse_time": 1.5,
		"tier_bonus": 2,
	},
	"mineral_detector": {
		"name": "Mineral Detector",
		"description": "Reveals all valuable tiles on screen for 30 seconds.",
		"cost": 400,
		"tier": 3,
		"use_type": "instant",
	},
	"phase_beacon": {
		"name": "Phase Beacon",
		"description": "Place a beacon, then teleport back to it once.\nConsumes the item when placed.",
		"cost": 1000,
		"tier": 3,
		"use_type": "place_return",
		"icon_path": "res://assets/Art/Tools/phase_beacon.png",
	},
}

const SHOP_ORDER: Array[String] = [
	"fuel_can",
	"repair_kit",
	"sonar_battery",
	"dynamite",
	"large_fuel_can",
	"teleport_charge",
	"shaped_charge",
	"mineral_detector",
	"phase_beacon",
]
