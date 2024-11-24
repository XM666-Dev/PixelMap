class_name Chunk

const SIZE := Vector2i(256, 256)
const TILE_SIZE := 1

static var NULL_BYTES := PackedByteArray()

var data: PackedInt32Array
var modified_time := 0
var shaped_time := -1
var shapes: PackedInt32Array

static func _static_init():
	NULL_BYTES.resize(SIZE.x * SIZE.y * TILE_SIZE * 4)

func get_cell_pixel(coords: Vector2i) -> int:
	var tile_index := (coords.y * SIZE.x + coords.x) * TILE_SIZE
	return data[tile_index]

func set_cell_pixel(coords: Vector2i, pixel: int) -> void:
	var tile_index := (coords.y * SIZE.x + coords.x) * TILE_SIZE
	data[tile_index] = pixel
	modified_time += 1
