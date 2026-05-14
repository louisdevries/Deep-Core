# terrain_generator.gd
extends TileMapLayer

@export var world_width = 50
@export var world_depth = 200

const TILE_SOURCE_ID = 1


func _ready():
	randomize()
	generate_world()


func generate_world():

	clear()

	for x in range(-world_width, world_width):

		for y in range(5, world_depth):

			var tile = Vector2i(1, 0)

			# grass surface
			if y < 8:

				tile = Vector2i(0, 0)

			# dirt layer
			elif y < 25:

				tile = Vector2i(1, 0)

				if randf() < 0.03:
					tile = Vector2i(4, 0)

			# stone layer
			elif y < 60:

				tile = Vector2i(2, 0)

				var r = randf()

				if r < 0.02:
					tile = Vector2i(5, 0)

				elif r < 0.05:
					tile = Vector2i(4, 0)

			# hard stone layer
			else:

				tile = Vector2i(3, 0)

				var r2 = randf()

				if r2 < 0.015:
					tile = Vector2i(7, 0)

				elif r2 < 0.04:
					tile = Vector2i(6, 0)

			set_cell(Vector2i(x, y), TILE_SOURCE_ID, tile)
