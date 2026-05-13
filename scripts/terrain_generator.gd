extends TileMapLayer

@export var world_width = 50
@export var world_depth = 200

var dirt_tile = Vector2i(1, 0)
var stone_tile = Vector2i(0, 0)
var ore_tile = Vector2i(2, 0)


func _ready():
	randomize()
	generate_world()


func generate_world():

	for x in range(-world_width, world_width):

		for y in range(5, world_depth):

			var tile = Vector2i(1, 0) # dirt default

			# 🌱 Surface layer
			if y < 8:
				tile = Vector2i(0, 0) # grass

			# 🌍 Dirt layer (small ore chance)
			elif y < 25:
				tile = Vector2i(1, 0) # dirt

				if randf() < 0.03:
					tile = Vector2i(4, 0) # basic ore

			# 🪨 Stone layer (copper starts appearing)
			elif y < 60:
				tile = Vector2i(2, 0) # stone

				var r = randf()
				if r < 0.02:
					tile = Vector2i(5, 0) # copper
				elif r < 0.05:
					tile = Vector2i(4, 0) # basic ore

			# 🧱 Hard stone layer (iron + crystal)
			else:
				tile = Vector2i(3, 0) # hard stone

				var r2 = randf()
				if r2 < 0.015:
					tile = Vector2i(7, 0) # crystal
				elif r2 < 0.04:
					tile = Vector2i(6, 0) # iron

			set_cell(Vector2i(x, y), 2, tile)
