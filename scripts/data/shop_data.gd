extends Node

const CONSUMABLES = {

	"repair_kit": {
		"name": "Repair Kit",
		"description": "Restores 30 health.",
		"cost": 100,
		"effect_type": "health",
		"effect_amount": 30,
	},

	"sonar_reset": {
		"name": "Sonar Battery",
		"description": "Instantly resets sonar cooldown.",
		"cost": 80,
		"effect_type": "sonar_reset",
		"effect_amount": 0,
	},
}

const DISPLAY_ORDER = [
	"repair_kit", "sonar_reset"
]
