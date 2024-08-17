class_name PixelMap extends Node2D

@export var pixel_set: PixelSet
var render_extents: Vector2i
var texture := Texture2DRD.new()

@export var process_extents: Vector2i
var previous_process_rect: Rect2i
var chunk_operations: Array[ChunkOperation]
var operation_task := 0
var chunks: Dictionary

@onready var area := $Area2D as Area2D
@onready var body := $StaticBody2D as StaticBody2D

class ChunkOperation:
	var coords: Vector2i
	var type: Type

	enum Type {
		LOAD,
		SAVE
	}

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

func get_chunk(coords: Vector2i) -> Chunk:
	return chunks.get(coords)

func local_to_chunk(coords: Vector2i) -> Vector2i:
	return IS.vector2i_posdivv(coords, Chunk.SIZE)

func local_to_cell(coords: Vector2i) -> Vector2i:
	return IS.vector2i_posmodv(coords, Chunk.SIZE)

func set_cell_pixel(coords: Vector2i, pixel: int) -> void:
	var chunk_coords := local_to_chunk(coords)
	var chunk := get_chunk(chunk_coords)
	if chunk == null: return
	var cell_coords := local_to_cell(coords)
	chunk.set_cell_pixel(cell_coords, pixel)

static func get_chunk_path(coords: Vector2i) -> String:
	return Main.chunks_dir.get_current_dir().path_join(str(coords))

static func _static_init():
	prepare_shader()

func _ready():
	render_extents = get_render_extents()
	prepare_pixel_set()
	prepare_map()
	prepare_chunks()
	prepare_uniform_set()
	var tree := get_tree()
	tree.root.connect("close_requested", _close_requested)
	area.position = Chunk.SIZE / 2

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
	buf_map = rd.uniform_buffer_create(32)
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
	var render_rect := get_render_rect()
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, render_rect.size.x, render_rect.size.y, 1)
	rd.compute_list_end()

func _process(_delta):
	var render_rect := get_render_rect()
	var data := PackedInt32Array([
		render_extents.x, render_extents.y,
		render_rect.position.x, render_rect.position.y,
		Main.time
	]).to_byte_array()
	rd.buffer_update(buf_map, 0, 16, data)
	for coords in IS.rect2i_to_points(render_rect):
		var chunk := get_chunk(coords)
		var bytes := chunk.data.to_byte_array() if chunk != null else Chunk.NULL_BYTES
		var size := bytes.size()
		var render_coords := IS.vector2i_posmodv(coords, render_extents)
		var render_index := render_coords.y * render_extents.x + render_coords.x
		rd.buffer_update(buf_chunks, render_index * size, size, bytes)
	prepare_compute_list()
	queue_redraw()

func _draw():
	var rect := IS.get_viewport_rect_global(self)
	draw_texture_rect_region(texture, rect, rect)

	#var draw_rect := get_render_rect().intersection(get_process_rect())
	#for coords in IS.rect2i_to_points(draw_rect):
		#var chunk := get_chunk(coords)
		#if chunk == null: continue
		#draw_set_transform_matrix(area.shape_owner_get_transform(chunk.area_owner))
		#if chunk.overlap_count > 0:
			#draw_rect(Rect2(Vector2(), area.shape_owner_get_shape(chunk.area_owner, 0).size), Color(Color.BLUE, 0.1))
			#draw_rect(Rect2(Vector2(), area.shape_owner_get_shape(chunk.area_owner, 0).size), Color(Color.BLUE, 0.1), false)
		#elif chunk.area_owner == -1:
			#print(area.shape_owner_get_shape_count(chunk.area_owner), area.shape_owner_get_shape(chunk.area_owner, 0))
			#draw_rect(Rect2(Vector2(), area.shape_owner_get_shape(chunk.area_owner, 0).size), Color(Color.GREEN, 0.1))
			#draw_rect(Rect2(Vector2(), area.shape_owner_get_shape(chunk.area_owner, 0).size), Color(Color.GREEN, 0.1), false)
		#elif area.shape_owner_get_shape_count(chunk.area_owner) > 0:
			#draw_rect(Rect2(Vector2(), area.shape_owner_get_shape(chunk.area_owner, 0).size), Color(Color.RED, 0.1))
			#draw_rect(Rect2(Vector2(), area.shape_owner_get_shape(chunk.area_owner, 0).size), Color(Color.RED, 0.1), false)
		#else:
			#draw_rect(Rect2(Vector2(), Chunk.SIZE), Color(Color.YELLOW, 0.1))
			#draw_rect(Rect2(Vector2(), Chunk.SIZE), Color(Color.YELLOW, 0.1), false)
		#if chunk.body_owner == -1: continue
		#draw_set_transform_matrix(body.shape_owner_get_transform(chunk.body_owner))
		#for i in body.shape_owner_get_shape_count(chunk.body_owner):
			#var points := body.shape_owner_get_shape(chunk.body_owner, i).points as PackedVector2Array
			#points.push_back(points[0])
			#draw_polyline(points, Color.WHITE)

	#draw_set_transform(Vector2.ZERO)
	#var mouse_position := get_local_mouse_position()
	#var chunk_coords := local_to_chunk(mouse_position)
	#draw_rect(Rect2(chunk_coords * Chunk.SIZE, Chunk.SIZE), Color.WHITE, false)
	#var render_coords := IS.vector2i_posmodv(chunk_coords, render_extents)
	#var render_index := render_coords.y * render_extents.x + render_coords.x
	#draw_string(Main.font, chunk_coords * Chunk.SIZE, str(chunk_coords, ", ", render_coords, render_index, ": ", get_chunk(chunk_coords)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)

func _physics_process(_delta):
	var process_rect := get_process_rect()
	var load_rects := IS.clip_rects(process_rect, previous_process_rect).map(IS.rect2i_to_points)
	var save_rects := IS.clip_rects(previous_process_rect, process_rect).map(IS.rect2i_to_points)
	previous_process_rect = process_rect
	for points in load_rects:
		for coords in points:
			if not can_load(coords): continue
			var chunk_operation := ChunkOperation.new()
			chunk_operation.coords = coords
			chunk_operation.type = ChunkOperation.Type.LOAD
			chunk_operations.push_back(chunk_operation)
	for points in save_rects:
		for coords in points:
			if not can_save(coords): continue
			var chunk_operation := ChunkOperation.new()
			chunk_operation.coords = coords
			chunk_operation.type = ChunkOperation.Type.SAVE
			chunk_operations.push_back(chunk_operation)
	if not chunk_operations.is_empty() and (operation_task == 0 or WorkerThreadPool.is_task_completed(operation_task)):
		operation_task = WorkerThreadPool.add_task(func():
			while true:
				var chunk_operation := chunk_operations.pop_back() as ChunkOperation
				if chunk_operation == null: return
				if chunk_operation.type == ChunkOperation.Type.LOAD:
					load_chunk(chunk_operation.coords)
				elif chunk_operation.type == ChunkOperation.Type.SAVE:
					save_chunk(chunk_operation.coords)
		)

	for coords in IS.rect2i_to_points(process_rect):
		var chunk := get_chunk(coords)
		if chunk == null or chunk.overlap_count == 0: continue
		chunk_update_shape(chunk)

	if Input.is_action_just_pressed("ui_accept"):
		print("CHUNK SIZE: ", chunks.size())
		print("OPERATIONS: ", chunk_operations.size())

func can_load(coords: Vector2i) -> bool:
	var chunk := get_chunk(coords)
	return chunk == null and previous_process_rect.has_point(coords)

func can_save(coords: Vector2i) -> bool:
	var chunk := get_chunk(coords)
	return chunk != null and not previous_process_rect.has_point(coords) and chunk.modified_time != 1

func load_chunk(coords: Vector2i) -> void:
	if not can_load(coords):
		#print("Chunk %s stop loading" % coords)
		return
	var path := PixelMap.get_chunk_path(coords)
	var chunk := Chunk.deserialize(FileAccess.get_file_as_bytes(path))
	if not can_load(coords):
		#print("Chunk %s stop loading caused by unload" % coords)
		return
	chunks[coords] = chunk

	chunk.coords = coords
	chunk.area_owner = area.create_shape_owner(chunk)
	var shape = RectangleShape2D.new()
	shape.size = Chunk.SIZE
	area.shape_owner_add_shape(chunk.area_owner, shape)
	area.shape_owner_set_transform(chunk.area_owner, Transform2D(0, coords * Chunk.SIZE))

func save_chunk(coords: Vector2i) -> void:
	if not can_save(coords):
		#print("Chunk %s stop saving" % coords)
		return
	var path := PixelMap.get_chunk_path(coords)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	var chunk := get_chunk(coords)
	file.store_buffer(chunk.serialize())
	if not can_save(coords):
		#print("Chunk %s stop saving caused by load" % coords)
		return
	chunks.erase(coords)

	area.remove_shape_owner(chunk.area_owner)
	if chunk.body_owner != -1:
		body.remove_shape_owner(chunk.body_owner)

func _close_requested():
	previous_process_rect = Rect2i()
	for coords in chunks.keys():
		save_chunk(coords)

func chunk_get_bit_map(chunk: Chunk) -> BitMap:
	var bit_map := BitMap.new()
	bit_map.create(Chunk.SIZE)
	for coords in IS.rect2i_to_points(Rect2i(Vector2i.ZERO, Chunk.SIZE)):
		bit_map.set_bitv(coords, pixel_set.id_pixels[chunk.get_cell_pixel(coords)].state == Pixel.States.SOLID)
	return bit_map

func chunk_update_shape(chunk: Chunk):
	if chunk.shape_updated_time == chunk.modified_time: return
	chunk.shape_updated_time = chunk.modified_time
	if chunk.body_owner == -1:
		chunk.body_owner = body.create_shape_owner(chunk)
		body.shape_owner_set_transform(chunk.body_owner, Transform2D(0, chunk.coords * Chunk.SIZE))
	else:
		body.shape_owner_clear_shapes(chunk.body_owner)
	var bit_map := chunk_get_bit_map(chunk)
	var polygons := bit_map.opaque_to_polygons(Rect2i(Vector2i.ZERO, Chunk.SIZE))
	for polygon in polygons:
		var shape := ConvexPolygonShape2D.new()
		shape.points = polygon
		body.shape_owner_add_shape(chunk.body_owner, shape)

func _body_shape_entered(_body_rid, _body, _body_shape_index, local_shape_index):
	var shape_owner := area.shape_find_owner(local_shape_index)
	var chunk := area.shape_owner_get_owner(shape_owner) as Chunk
	if chunk == null: return
	chunk.overlap_count += 1
	chunk_update_shape(chunk)

func _body_shape_exited(_body_rid, _body, _body_shape_index, local_shape_index):
	var shape_owner := area.shape_find_owner(local_shape_index)
	var chunk := area.shape_owner_get_owner(shape_owner) as Chunk
	if chunk == null: return
	chunk.overlap_count -= 1
