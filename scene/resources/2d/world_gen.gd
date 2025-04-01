class_name WorldGen extends Resource

@export var noise: FastNoiseLite

const pixel_set := preload("res://test/resources/pixel_set.tres")
const scale := 8
var heights: Dictionary[int, int]
var values: Dictionary[int, int]

func get_height_impl(x: int) -> int:
	if heights.has(x):
		return heights[x]
	return heights.get_or_add(x, int(noise.get_noise_1d(x) * scale * 1000))

func get_height(x: int) -> int:
	var height_left := get_height_impl(IS.posdiv(x, scale))
	var height_right := get_height_impl(IS.posdiv(x, scale) + 1)
	return lerp(height_left, height_right, posmod(x, scale) / scale)


func gen(coords: Vector2i, chunk: Chunk) -> void:
	for point in IS.rect2i_to_points(Rect2i(Vector2i(), Chunk.SIZE)):
		var sample := point + coords * Chunk.SIZE
		#var height = get_height(sample.x)
		if sample.y > 0:
			chunk.set_cell_pixel(point, pixel_set.get_pixel("dirt"))
			#var value := noise.get_noise_2dv(sample / scale)
			#if value > 0.3:
				#chunk.set_cell_pixel(point, pixel_set.get_pixel("dirt"))
			#else:
				#chunk.set_cell_pixel(point, pixel_set.get_pixel("stone"))
