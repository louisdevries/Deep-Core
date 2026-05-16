extends TileMapLayer

@export var sky_width = 80
@export var sky_height = 40

const TILE_SOURCE_ID = 0

const SKY_TILE = Vector2i(0, 0)
const CLOUD_TILE = Vector2i(1, 0)


func _ready():
	generate_sky()


func generate_sky():

	clear()

	# =========================
	# SKY BASE
	# =========================

	for x in range(-sky_width, sky_width):
		for y in range(-sky_height, 5):

			set_cell(Vector2i(x, y), TILE_SOURCE_ID, SKY_TILE)

	# =========================
	# CLOUD CLUSTERS
	# =========================

	var cloud_count = 25

	for i in range(cloud_count):

		# clouds stay high in sky
		var cloud_x = randi_range(-sky_width, sky_width)
		var cloud_y = randi_range(-sky_height, -10)

		# cloud size
		var cloud_width = randi_range(4, 12)
		var cloud_height = randi_range(2, 4)

		for x in range(cloud_x, cloud_x + cloud_width):
			for y in range(cloud_y, cloud_y + cloud_height):

				# soft blob shape
				var dx = float(x - cloud_x) / cloud_width
				var dy = float(y - cloud_y) / cloud_height

				var dist = abs(dx - 0.5) + abs(dy - 0.5)

				if dist < 0.55:

					set_cell(Vector2i(x, y), TILE_SOURCE_ID, CLOUD_TILE)
