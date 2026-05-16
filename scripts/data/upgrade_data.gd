# upgrade_data.gd
extends Node

const DRILL_UPGRADES = {

	1: {
		"money": 50,
		"resources": {}
	},

	2: {
		"money": 250,
		"resources": {
			"copper": 5
		}
	},

	3: {
		"money": 750,
		"resources": {
			"copper": 15,
			"iron": 5
		}
	},

	4: {
		"money": 2000,
		"resources": {
			"iron": 20
		}
	},

	5: {
		"money": 5000,
		"resources": {
			"iron": 25,
			"crystal": 10
		}
	}
}
