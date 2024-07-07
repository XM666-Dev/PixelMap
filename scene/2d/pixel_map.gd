class_name PixelMap extends Node2D

@export var pixel_set: PixelSet
var render_extents: Vector2i
var texture := Texture2DRD.new()
@export var loading_extents: Vector2i
var chunks: Dictionary
var loading_chunks: Dictionary
var unloading_chunks: Dictionary
var chunks_dir := IS.open(Main.node.save_dir, "chunks")

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

func get_render_rect() -> Rect2i:
	var rect := IS.get_viewport_rect_global(self)
	var rect_position := IS.floor_divide(rect.position, Vector2(Chunk.SIZE)) as Vector2
	var rect_end := IS.ceil_divide(rect.end, Vector2(Chunk.SIZE)) as Vector2 + Vector2.ONE
	return IS.rect_from_to(rect_position, rect_end)

func get_loading_rect() -> Rect2i:
	var rect := IS.get_viewport_rect_global(self)
	var center := IS.floor_divide(rect.get_center(), Vector2(Chunk.SIZE)) as Vector2
	return IS.rect_from_to(center - Vector2(loading_extents), center + Vector2(loading_extents))

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
	if not has_chunk(chunk_coords):
		chunks[chunk_coords] = Chunk.new()
	var chunk := get_chunk(chunk_coords)
	var cell_coords := local_to_cell(coords)
	chunk.set_cell_pixel(cell_coords, pixel)

static func _init():
	prepare_shader()

func _ready():
	render_extents = get_render_rect().size
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
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	)
	img_map = rd.texture_create(format, RDTextureView.new())
	buf_map = rd.uniform_buffer_create(16)
	texture.texture_rd_rid = img_map

func prepare_chunks():
	var size := get_size()
	var size_bytes := size.x * size.y * 4
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

func _physics_process(_delta):
	if chunks_dir != null:
		pass
		#var loading_rect := get_loading_rect()
		#for y in IS.column(loading_rect):
			#for x in IS.row(loading_rect):
				#if
		#for coords in chunks:
			#if not loading_rect.has_point(coords):
				#var chunk := get_chunk(coords)
				#chunks.erase(coords)
				#unloading_chunks[coords] = chunk
