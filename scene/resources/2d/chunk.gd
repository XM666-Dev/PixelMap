class_name Chunk extends Resource

const SIZE := Vector2i(16, 16)
const AREA := SIZE.x * SIZE.y
const TILE_SIZE := 1

var data: PackedInt32Array

func _init():
	data.resize(AREA * TILE_SIZE)
	data.fill(-1)

func get_cell_substance(coords: Vector2i) -> int:
	var tile_index := (coords.y * SIZE.x + coords.x) * TILE_SIZE
	return data[tile_index + 0]

func set_cell_substance(coords: Vector2i, subtance_id: int) -> void:
	var tile_index := (coords.y * SIZE.x + coords.x) * TILE_SIZE
	data[tile_index + 0] = subtance_id
