class_name PixelMap extends Node2D

@export var pixel_set: PixelSet
var render_extents: Vector2i
var texture := Texture2DRD.new()
@export var process_extents: Vector2i
var previous_process_rect: Rect2i
var chunks: Dictionary
var loading_chunks: Dictionary
var unloading_chunks: Dictionary

static var rd := RenderingServer.get_rendering_device()
static var shader: RID
static var pipeline: RID

var tex_pixel_set: RID
var buf_pixel_set: RID
var img_map: RID
var buf_map: RID
var buf_chunks: RID

var uniform_set: RID

func get_size() -> Vector2i:
	return render_extents * Chunk.SIZE

func get_render_extents() -> Vector2i:
	var rect := IS.get_viewport_rect_global(self)
	return Vector2i((rect.size / Vector2(Chunk.SIZE)).ceil()) + Vector2i.ONE

func get_render_rect() -> Rect2i:
	var rect := IS.get_viewport_rect_global(self)
	var rect_position := Vector2i((rect.position / Vector2(Chunk.SIZE)).floor())
	var rect_end := Vector2i((rect.end / Vector2(Chunk.SIZE)).ceil())
	return IS.rect2i_range(rect_position, rect_end)

func get_process_rect() -> Rect2i:
	var rect := IS.get_viewport_rect_global(self)
	var center := Vector2i((rect.get_center() / Vector2(Chunk.SIZE)).floor())
	return IS.rect2i_range(center - process_extents, center + process_extents)

func has_chunk(coords: Vector2i) -> bool:
	return chunks.has(coords)

func get_chunk(coords: Vector2i) -> Chunk:
	return chunks[coords]

func local_to_chunk(coords: Vector2i) -> Vector2i:
	return IS.floor_divide(coords, Chunk.SIZE)

func local_to_cell(coords: Vector2i) -> Vector2i:
	return IS.floor_modulo(coords, Chunk.SIZE)

func set_cell_pixel(coords: Vector2i, pixel: int) -> void:
	var chunk_coords := local_to_chunk(coords)
	if not has_chunk(chunk_coords): return
	var chunk := get_chunk(chunk_coords)
	var cell_coords := local_to_cell(coords)
	chunk.set_cell_pixel(cell_coords, pixel)

static func _static_init():
	prepare_shader()

func _ready():
	render_extents = get_render_extents()
	prepare_pixel_set()
	prepare_map()
	prepare_chunks()
	prepare_uniform_set()

static func prepare_shader():
	var shader_file := preload("res://servers/rendering/renderer_rd/shaders/pixels.glsl")
	var shader_spirv := shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

func prepare_pixel_set():
	var format = RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.width = pixel_set.texture.get_width()
	format.height = pixel_set.texture.get_height()
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	tex_pixel_set = rd.texture_create(format, RDTextureView.new(), [pixel_set.texture.get_image().get_data()])
	buf_pixel_set = rd.storage_buffer_create(pixel_set.data.size(), pixel_set.data)

func prepare_map():
	var size := get_size()
	var format = RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.width = size.x
	format.height = size.y
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	img_map = rd.texture_create(format, RDTextureView.new())
	buf_map = rd.uniform_buffer_create(16)
	texture.texture_rd_rid = img_map

func prepare_chunks():
	var size := get_size()
	var size_bytes := size.x * size.y * Chunk.TILE_SIZE * 4
	buf_chunks = rd.storage_buffer_create(size_bytes)

func prepare_uniform_set():
	var uni_tex_pixel_set := RDUniform.new()
	uni_tex_pixel_set.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uni_tex_pixel_set.binding = 0
	uni_tex_pixel_set.add_id(rd.sampler_create(RDSamplerState.new()))
	uni_tex_pixel_set.add_id(tex_pixel_set)

	var uni_buf_pixel_set := RDUniform.new()
	uni_buf_pixel_set.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uni_buf_pixel_set.binding = 1
	uni_buf_pixel_set.add_id(buf_pixel_set)

	var uni_img_map := RDUniform.new()
	uni_img_map.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uni_img_map.binding = 2
	uni_img_map.add_id(img_map)

	var uni_buf_map := RDUniform.new()
	uni_buf_map.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	uni_buf_map.binding = 3
	uni_buf_map.add_id(buf_map)

	var uni_buf_chunks := RDUniform.new()
	uni_buf_chunks.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uni_buf_chunks.binding = 4
	uni_buf_chunks.add_id(buf_chunks)

	uniform_set = rd.uniform_set_create(
		[uni_tex_pixel_set, uni_buf_pixel_set, uni_img_map, uni_buf_map, uni_buf_chunks], shader, 0
	)

func prepare_compute_list():
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, render_extents.x, render_extents.y, 1)
	rd.compute_list_end()

func _process(_delta):
	var render_rect := get_render_rect()
	var data := PackedInt32Array([
		render_rect.position.x, render_rect.position.y,
		Time.get_ticks_msec() / (1000.0 / 60.0)
	]).to_byte_array()
	rd.buffer_update(buf_map, 0, 16, data)
	for y in IS.column(render_rect):
		for x in IS.row(render_rect):
			var coords := Vector2i(x, y)
			if not has_chunk(coords): continue
			var chunk := get_chunk(coords)
			var bytes := chunk.data.to_byte_array()
			var size := bytes.size()
			var render_coords := IS.vector2i_posmodv(coords, render_extents)
			var render_index := render_coords.y * render_extents.x + render_coords.x
			rd.buffer_update(buf_chunks, render_index * size, size, bytes)
	prepare_compute_list()
	queue_redraw()

func _draw():
	var rect := IS.get_viewport_rect_global(self)
	draw_texture_rect_region(texture, rect, rect)

func _physics_process(_delta):
	if Main.chunks_dir != null:
		var process_rect := get_process_rect()
		for y in IS.column(process_rect):
			for x in IS.row(process_rect):
				var coords := Vector2i(x, y)
				if not has_chunk(coords):
					chunks[coords] = Chunk.new()
