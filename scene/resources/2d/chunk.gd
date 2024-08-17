class_name Chunk extends Resource

const SIZE := Vector2i(32, 32)
const TILE_SIZE := 1

static var NULL_BYTES := PackedByteArray()

var data: PackedInt32Array
var coords: Vector2i
var modified_time := 1
var shape_updated_time := 0
var area_owner := -1
var body_owner := -1
var overlap_count := 0

static func _static_init():
	NULL_BYTES.resize(SIZE.x * SIZE.y * TILE_SIZE * 4)

func _init(data: PackedInt32Array):
	data.resize(SIZE.x * SIZE.y * TILE_SIZE)
	self.data = data

func serialize() -> PackedByteArray:
	return data.to_byte_array()

static func deserialize(bytes: PackedByteArray) -> Chunk:
	return Chunk.new(bytes.to_int32_array())

func get_cell_pixel(coords: Vector2i) -> int:
	var tile_index := (coords.y * SIZE.x + coords.x) * TILE_SIZE
	return data[tile_index]

func set_cell_pixel(coords: Vector2i, pixel: int) -> void:
	var tile_index := (coords.y * SIZE.x + coords.x) * TILE_SIZE
	data[tile_index] = pixel
	modified_time += 1
