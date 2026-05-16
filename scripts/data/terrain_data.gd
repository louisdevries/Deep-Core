# terrain_data.gd
extends Node

const TERRAIN_TYPES = {

	# GRASS
	Vector2i(0, 0): {
		"name": "Grass",
		"required_power": 1,
		"cargo": 0,
		"resource": null
	},

	# DIRT
	Vector2i(1, 0): {
		"name": "Dirt",
		"required_power": 1,
		"cargo": 0,
		"resource": null
	},

	# STONE
	Vector2i(2, 0): {
		"name": "Stone",
		"required_power": 2,
		"cargo": 0,
		"resource": null
	},

	# HARD STONE
	Vector2i(3, 0): {
		"name": "Hard Stone",
		"required_power": 4,
		"cargo": 0,
		"resource": null
	},

	# BASIC ORE
	Vector2i(4, 0): {
		"name": "Basic Ore",
		"required_power": 2,
		"cargo": 1,
		"resource": null
	},

	# COPPER
	Vector2i(5, 0): {
		"name": "Copper",
		"required_power": 3,
		"cargo": 2,
		"resource": "copper"
	},

	# IRON
	Vector2i(6, 0): {
		"name": "Iron",
		"required_power": 5,
		"cargo": 3,
		"resource": "iron"
	},

	# CRYSTAL
	Vector2i(7, 0): {
		"name": "Crystal",
		"required_power": 6,
		"cargo": 5,
		"resource": "crystal"
	}
}
