class_name PixelMap extends Node2D

const CHUNK_SIZE := Vector2i(16, 16)

@export var tile_set: Atlas
@export var chunk_extents: Vector2i = Vector2i(16, 16)
@export var render_extents: Vector2i = Vector2i(16, 16)
var chunks: Array[PackedInt32Array]

var rd := RenderingServer.get_rendering_device()
var shader: RID
var pipeline: RID

var tex_tile_set: RID
var buf_sheet_const: RID
var buf_map_data: RID
var buf_chunks: RID
var tex_map_image: RID

var uniform_set: RID


func get_map_size() -> Vector2i:
	return CHUNK_SIZE * chunk_extents


func get_chunk(coords: Vector2i) -> PackedInt32Array:
	var chunk_coords := (coords / CHUNK_SIZE).clamp(Vector2i.ZERO, chunk_extents - Vector2i.ONE)
	var chunk_index := chunk_coords.x + chunk_coords.y * chunk_extents.x
	return chunks[chunk_index]


func get_tile_index(coords: Vector2i) -> int:
	var tile_coords := coords % CHUNK_SIZE
	return tile_coords.x + tile_coords.y * CHUNK_SIZE.x


func _ready():
	tile_set.init()
	prepare_shader()
	prepare_tile_set()
	prepare_sheet_const()
	prepare_map_data()
	prepare_chunks()
	prepare_map_image()
	prepare_uniform_set()
	var chunk_number := chunk_extents.x * chunk_extents.y
	chunks.resize(chunk_number)
	for i in chunk_number:
		var array := PackedInt32Array()
		array.resize(256)
		chunks[i] = array


func prepare_shader():
	var shader_file: RDShaderFile = preload("res://scene/2d/pixel_map/draw_tiles.glsl")
	var shader_spirv := shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)


func prepare_tile_set():
	var format = RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UINT
	format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	format.width = tile_set.texture.get_width()
	format.height = tile_set.texture.get_height()
	tex_tile_set = rd.texture_create(
		format, RDTextureView.new(), [tile_set.texture.get_image().get_data()]
	)


func prepare_sheet_const():
	var ints := PackedInt32Array()
	for i in tile_set.points.size():
		var point := tile_set.points[i]
		var size := tile_set.sizes[i]
		ints.append(point.x)
		ints.append(point.y)
		ints.append(size.x)
		ints.append(size.y)
		ints.append(1)
		ints.append(0)
	var bytes := ints.to_byte_array()
	buf_sheet_const = rd.storage_buffer_create(bytes.size(), bytes)


func prepare_map_data():
	buf_map_data = rd.uniform_buffer_create(16)


func prepare_chunks():
	var map_size := get_map_size()
	var size := map_size.x * map_size.y * 4
	buf_chunks = rd.storage_buffer_create(size)


func prepare_map_image():
	var map_size := get_map_size()
	var format = RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UINT
	format.width = map_size.x
	format.height = map_size.y
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	tex_map_image = rd.texture_create(format, RDTextureView.new())


func prepare_uniform_set():
	var uni_tile_set := RDUniform.new()
	uni_tile_set.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uni_tile_set.binding = 0
	uni_tile_set.add_id(rd.sampler_create(RDSamplerState.new()))
	uni_tile_set.add_id(tex_tile_set)

	var uni_sheet_const := RDUniform.new()
	uni_sheet_const.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uni_sheet_const.binding = 1
	uni_sheet_const.add_id(buf_sheet_const)

	var uni_map_data := RDUniform.new()
	uni_map_data.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	uni_map_data.binding = 2
	uni_map_data.add_id(buf_map_data)

	var uni_chunks := RDUniform.new()
	uni_chunks.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uni_chunks.binding = 3
	uni_chunks.add_id(buf_chunks)

	var uni_map_image := RDUniform.new()
	uni_map_image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uni_map_image.binding = 4
	uni_map_image.add_id(tex_map_image)

	uniform_set = rd.uniform_set_create(
		[uni_tile_set, uni_sheet_const, uni_map_data, uni_chunks, uni_map_image], shader, 0
	)


func prepare_compute_list():
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, chunk_extents.x, chunk_extents.y, 1)
	rd.compute_list_end()


var flag: bool


func _process(_delta):
	queue_redraw()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		flag = !flag
	if true:
		const CHUNK_BYTE_SIZE := CHUNK_SIZE.x * CHUNK_SIZE.y * 4
		for y in chunk_extents.y:
			for x in chunk_extents.x:
				var chunk_index := x + y * chunk_extents.x
				var chunk := chunks[chunk_index]
				var bytes := chunk.to_byte_array()
				var size := bytes.size()
				rd.buffer_update(buf_chunks, chunk_index * size, size, bytes)
		prepare_compute_list()


func _draw():
	var map_size := get_map_size()
	var output_bytes := rd.texture_get_data(tex_map_image, 0)
	var output := Image.create_from_data(
		map_size.x, map_size.y, false, Image.FORMAT_RGBA8, output_bytes
	)
#	if Input.is_action_just_pressed("ui_down"):
#		DisplayServer.clipboard_set(
#			str(RenderingServer.texture_2d_get(map_texture).data.data, output.data.data)
#		)
	var map_texture := RenderingServer.texture_2d_create(output)
	RenderingServer.canvas_item_add_texture_rect(
		get_canvas_item(), Rect2(Vector2.ZERO, map_size), map_texture
	)
