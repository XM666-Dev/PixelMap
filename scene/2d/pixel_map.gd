class_name PixelMap extends Node2D

@export var tile_set: AtlasImageTexture
@export var render_extents: Vector2i
var chunks: Dictionary
var texture := Texture2DRD.new()

static var rd := RenderingServer.get_rendering_device()
static var shader: RID
static var pipeline: RID

var tex_tile_set: RID
var buf_tile_const: RID
var buf_map_data: RID
var buf_chunks: RID
var tex_map_image: RID

var uniform_set: RID

func get_map_size() -> Vector2i:
	return Chunk.SIZE * render_extents

func get_render_rect() -> Rect2i:
	var rect := IS.get_viewport_rect_global(self)
	var _position := IS.floor_divide(Vector2i(rect.position.floor()), Chunk.SIZE) as Vector2i
	var size := IS.ceil_divide(Vector2i(rect.end.floor()), Chunk.SIZE) - _position as Vector2i + Vector2i.ONE
	return Rect2i(_position, size)

func has_chunk(coords: Vector2i) -> bool:
	return chunks.has(coords)

func get_chunk(coords: Vector2i) -> Chunk:
	return chunks[coords]

func local_to_chunk(coords: Vector2i) -> Vector2i:
	return IS.floor_divide(coords, Chunk.SIZE)

func local_to_cell(coords: Vector2i) -> Vector2i:
	return IS.floor_modulo(coords, Chunk.SIZE)

func set_cell_substance(coords: Vector2i, subtance_id: int) -> void:
	var chunk_coords := local_to_chunk(coords)
	if not has_chunk(chunk_coords):
		chunks[chunk_coords] = Chunk.new()
	var chunk := get_chunk(chunk_coords)
	var cell_coords := local_to_cell(coords)
	chunk.set_cell_substance(cell_coords, subtance_id)

static func _init():
	prepare_shader()

func _ready():
	render_extents = get_render_rect().size
	prepare_tile_set()
	prepare_tile_const()
	prepare_map_data()
	prepare_chunks()
	prepare_map_image()
	prepare_uniform_set()

static func prepare_shader():
	var shader_file := preload("res://servers/rendering/renderer_rd/shaders/pixels.glsl")
	var shader_spirv := shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

func prepare_tile_set():
	var format = RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	format.width = tile_set.get_width()
	format.height = tile_set.get_height()
	tex_tile_set = rd.texture_create(
		format, RDTextureView.new(), [tile_set.get_image().get_data()]
	)

func prepare_tile_const():
	var ints := PackedInt32Array()
	for atlas_texture in tile_set.atlas_textures:
		ints.append(int(atlas_texture.region.position.x))
		ints.append(int(atlas_texture.region.position.y))
		ints.append(int(atlas_texture.region.size.x))
		ints.append(int(atlas_texture.region.size.y))
		ints.append(1)
		ints.append(0)
	var bytes := ints.to_byte_array()
	buf_tile_const = rd.storage_buffer_create(bytes.size(), bytes)

func prepare_map_data():
	buf_map_data = rd.uniform_buffer_create(16)

func prepare_chunks():
	var map_size := get_map_size()
	var size := map_size.x * map_size.y * 4
	buf_chunks = rd.storage_buffer_create(size)

func prepare_map_image():
	var map_size := get_map_size()
	var format = RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.width = map_size.x
	format.height = map_size.y
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT| \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	)
	tex_map_image = rd.texture_create(format, RDTextureView.new())
	texture.texture_rd_rid = tex_map_image

func prepare_uniform_set():
	var uni_tile_set := RDUniform.new()
	uni_tile_set.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uni_tile_set.binding = 0
	uni_tile_set.add_id(rd.sampler_create(RDSamplerState.new()))
	uni_tile_set.add_id(tex_tile_set)

	var uni_tile_const := RDUniform.new()
	uni_tile_const.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uni_tile_const.binding = 1
	uni_tile_const.add_id(buf_tile_const)

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
		[uni_tile_set, uni_tile_const, uni_map_data, uni_chunks, uni_map_image], shader, 0
	)

func prepare_compute_list():
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, render_extents.x, render_extents.y, 1)
	rd.compute_list_end()

func _process(_delta):
	var render_rect := get_render_rect()
	var map_data := PackedInt32Array([
		render_rect.position.x, render_rect.position.y,
		Time.get_ticks_msec() / (1000.0 / 60.0)
	]).to_byte_array()
	rd.buffer_update(buf_map_data, 0, 16, map_data)
	var rect := Rect2i(render_rect.position, render_extents)
	var i := 0
	for y in IS.column(rect):
		for x in IS.row(rect):
			var coords := Vector2i(x, y)
			if not has_chunk(coords):
				chunks[coords] = Chunk.new()
			var chunk := get_chunk(coords)
			var bytes := chunk.data.to_byte_array()
			var size := bytes.size()
			rd.buffer_update(buf_chunks, size * i, size, bytes)
			i = i + 1
	prepare_compute_list()
	queue_redraw()

func _draw():
	var render_rect := get_render_rect()
	draw_texture(texture, render_rect.position * Chunk.SIZE)
	if Input.is_action_just_pressed("ui_down"):
		var output_bytes := rd.buffer_get_data(buf_chunks)
		DisplayServer.clipboard_set(str(output_bytes))
