class_name PixelMap extends Node2D

const GROUP_SIZE := Vector2i(32, 32)

@export var pixel_set: PixelSet
var size: Vector2i
var texture := Texture2DRD.new()

@export var process_extents: Vector2i
var previous_process_rect: Rect2i
var chunks: Dictionary[Vector2i, Chunk]
var streams: Dictionary[Vector2i, bool]
var load_streams: Array[Vector2i]
var save_streams: Array[Vector2i]
var load_count: int = 0
var save_count: int = 0
@onready var load_task := WorkerThreadPool.add_task(func() -> void:
	while true:
		for i in mini(load_count, 32):
			var stream := load_streams[load_count - 1]
			load_count -= 1

			if previous_process_rect.has_point(stream):
				add_chunk(stream, load_chunk(stream))

			streams.erase(stream)
		await get_tree().create_timer(1 / 15).timeout
)
@onready var save_task := WorkerThreadPool.add_task(func() -> void:
	while true:
		for i in mini(save_count, 32):
			var stream := save_streams[save_count - 1]
			save_count -= 1

			if not previous_process_rect.has_point(stream):
				save_chunk(stream)
				if not previous_process_rect.has_point(stream):
					erase_chunk(stream)

			streams.erase(stream)
		await get_tree().create_timer(1 / 15).timeout
)
var node_streams: Dictionary[Vector2i, bool]
var load_node_streams: Array[Vector2i]
var save_node_streams: Array[Vector2i]
var load_node_count: int = 0
var save_node_count: int = 0
@onready var load_node_task := WorkerThreadPool.add_task(func() -> void:
	while true:
		for i in mini(load_node_count, 32):
			var stream := load_node_streams[load_node_count - 1]
			load_node_count -= 1

			if previous_process_rect.has_point(stream):
				add_chunk_nodes(load_chunk_nodes(stream))

			node_streams.erase(stream)
		await get_tree().create_timer(1 / 15).timeout
)
@onready var save_node_task := WorkerThreadPool.add_task(func() -> void:
	while true:
		for i in mini(save_node_count, 32):
			var stream := save_node_streams[save_node_count - 1]
			save_node_count -= 1

			if not previous_process_rect.has_point(stream):
				save_chunk_nodes(stream)
				if not previous_process_rect.has_point(stream):
					clear_chunk_nodes(stream)

			node_streams.erase(stream)
		await get_tree().create_timer(1 / 15).timeout
)

var body := PhysicsServer2D.body_create()
var shapes := PackedInt32Array()

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
	return IS.get_viewport_rect_global(self).size.ceil() + Vector2.ONE

func get_chunk_extents() -> Vector2i:
	return (Vector2(size) / Vector2(Chunk.SIZE)).ceil() + Vector2.ONE

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
	return Main.chunks_dir.get_current_dir().path_join("c%s,%s.bin" % [coords.x, coords.y])

static func get_chunk_nodes_path(coords: Vector2i) -> String:
	return Main.chunks_dir.get_current_dir().path_join("n%s,%s.bin" % [coords.x, coords.y])

static func _static_init():
	prepare_shader()

func _ready():
	size = get_size()
	prepare_pixel_set()
	prepare_map()
	prepare_chunks()
	prepare_uniform_set()

	get_tree().root.connect("close_requested", _close_requested)

	PhysicsServer2D.body_set_space(body, get_world_2d().space)
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_STATIC)

static func prepare_shader():
	var shader_file := preload("res://servers/rendering/renderer_rd/shaders/pixels.glsl")
	var shader_spirv := shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	var constants := [RDPipelineSpecializationConstant.new(), RDPipelineSpecializationConstant.new()]
	constants[0].constant_id = 0
	constants[0].value = Chunk.SIZE.x
	constants[1].constant_id = 1
	constants[1].value = Chunk.SIZE.y
	pipeline = rd.compute_pipeline_create(shader, constants)

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
	var format := RDTextureFormat.new()
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
	var chunk_extents := get_chunk_extents()
	var size_bytes := chunk_extents.x * chunk_extents.y * Chunk.SIZE.x * Chunk.SIZE.y * Chunk.TILE_SIZE * 4
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

	uniform_set = rd.uniform_set_create([uni_tex_pixel_set, uni_buf_pixel_set, uni_img_map, uni_buf_map, uni_buf_chunks], shader, 0)

func prepare_compute_list():
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	var viewport_rect := IS.get_viewport_rect_global(self)
	var groups := Vector2i(((viewport_rect.end.ceil() - viewport_rect.position.floor()) / Vector2(GROUP_SIZE)).ceil())
	rd.compute_list_dispatch(compute_list, groups.x, groups.y, 1)
	rd.compute_list_end()

func _process(_delta):
	var chunk_extents := get_chunk_extents()
	var render_rect := get_render_rect()
	var cell_position := Vector2i(IS.get_viewport_rect_global(self).position.floor())
	var data := PackedInt32Array([
		cell_position.x, cell_position.y,
		Engine.get_process_frames()
	]).to_byte_array()
	rd.buffer_update(buf_map, 0, data.size(), data)
	for coords in IS.rect2i_to_points(render_rect):
		var chunk := get_chunk(coords)
		var bytes := chunk.data.to_byte_array() if chunk != null else Chunk.NULL_BYTES
		var size_bytes := bytes.size()
		var render_coords := IS.vector2i_posmodv(coords, chunk_extents)
		var render_index := render_coords.y * chunk_extents.x + render_coords.x
		rd.buffer_update(buf_chunks, render_index * size_bytes, size_bytes, bytes)
	prepare_compute_list()
	queue_redraw()

func _draw():
	var rect := IS.get_viewport_rect_global(self)
	draw_texture_rect_region(texture, rect, rect)

	var render_rect := get_render_rect()
	for coords in IS.rect2i_to_points(render_rect):
		var chunk := get_chunk(coords)
		if chunk == null: continue
		for shape in chunk.shapes:
			draw_set_transform_matrix(PhysicsServer2D.body_get_shape_transform(body, shape))
			var polygon_shape := PhysicsServer2D.body_get_shape(body, shape)
			var polygon := PhysicsServer2D.shape_get_data(polygon_shape) as PackedVector2Array
			draw_polygon(polygon, [Color(Color.WHITE, 0.2)])
			polygon.push_back(polygon[0])
			draw_polyline(polygon, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	var mouse_position := get_local_mouse_position()
	var chunk_coords := local_to_chunk(mouse_position)
	draw_rect(Rect2(chunk_coords * Chunk.SIZE, Chunk.SIZE), Color.WHITE, false)
	var focus_chunk := get_chunk(chunk_coords)
	draw_string(
		Main.font,
		chunk_coords * Chunk.SIZE,
		"%s: %s" % [chunk_coords, "null" if focus_chunk == null else "Chunk"],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		8
	)

func _physics_process(_delta):
	var process_rect := get_process_rect()
	var load_rects := IS.clip_rects(process_rect, previous_process_rect).map(IS.rect2i_to_points)
	var save_rects := IS.clip_rects(previous_process_rect, process_rect).map(IS.rect2i_to_points)
	previous_process_rect = process_rect
	for points in load_rects:
		for coords in points:
			stack_load_chunk(coords)
	for points in save_rects:
		for coords in points:
			stack_save_chunk(coords)

	if Input.is_action_just_pressed("ui_down"):
		print("CHUNKS: %s" % chunks.size())
		print(size)

func _close_requested() -> void:
	WorkerThreadPool.wait_for_task_completion(load_task)
	WorkerThreadPool.wait_for_task_completion(save_task)
	WorkerThreadPool.wait_for_task_completion(load_node_task)
	WorkerThreadPool.wait_for_task_completion(save_node_task)
	set_physics_process(false)
	previous_process_rect = Rect2i()
	streams.clear()
	node_streams.clear()
	for coords in chunks.keys():
		stack_save_chunk(coords)
	for i in save_count:
		save_chunk(save_streams[i])
	for i in save_node_count:
		save_chunk_nodes(save_node_streams[i])

func add_chunk(coords: Vector2i, chunk: Chunk) -> void:
	chunks.get_or_add(coords, chunk)

func erase_chunk(coords: Vector2i) -> void:
	clear_chunk_shapes(coords)
	chunks.erase(coords)

func clear_chunk_shapes(coords: Vector2i) -> void:
	var chunk := get_chunk(coords)
	for shape in chunk.shapes:
		PhysicsServer2D.body_set_shape_disabled(body, shape, true)
	shapes.append_array(chunk.shapes)
	chunk.shapes.clear()

func get_chunk_nodes(coords: Vector2i) -> Array[Node]:
	return get_children().filter(func(child: Node) -> bool:
		return child is Node2D and Rect2(coords * Chunk.SIZE, Chunk.SIZE).has_point(child.position)
	)

func add_chunk_nodes(nodes: Array) -> void:
	for node in nodes:
		add_child.call_deferred(node)

func clear_chunk_nodes(coords: Vector2i) -> void:
	for child in get_chunk_nodes(coords):
		remove_child(child)

func stack_load_chunk(coords: Vector2i) -> void:
	var chunk := get_chunk(coords)
	if not streams.has(coords) and chunk == null:
		streams[coords] = true
		if load_count < load_streams.size():
			load_streams[load_count] = coords
		else:
			load_streams.push_back(coords)
		load_count += 1
	if not node_streams.has(coords) and chunk == null:
		node_streams[coords] = true
		if load_node_count < load_node_streams.size():
			load_node_streams[load_node_count] = coords
		else:
			load_node_streams.push_back(coords)
		load_node_count += 1

func stack_save_chunk(coords: Vector2i) -> void:
	var chunk := get_chunk(coords)
	if not streams.has(coords) and chunk != null:
		if chunk.modified_time > 0:
			streams[coords] = true
			if save_count < save_streams.size():
				save_streams[save_count] = coords
			else:
				save_streams.push_back(coords)
			save_count += 1
		else:
			erase_chunk(coords)
	if not node_streams.has(coords) and chunk != null:
		node_streams[coords] = true
		if save_node_count < save_node_streams.size():
			save_node_streams[save_node_count] = coords
		else:
			save_node_streams.push_back(coords)
		save_node_count += 1

func load_chunk(coords: Vector2i) -> Chunk:
	var chunk := Chunk.new()
	var file := FileAccess.open(get_chunk_path(coords), FileAccess.READ)
	if file != null:
		chunk.data = file.get_buffer(Chunk.SIZE.x * Chunk.SIZE.y * Chunk.TILE_SIZE * 4).to_int32_array()
	else:
		chunk.data.resize(Chunk.SIZE.x * Chunk.SIZE.y * Chunk.TILE_SIZE)
		preload("res://test/resources/world_gen.tres").gen(coords, chunk)
	return chunk

func save_chunk(coords: Vector2i) -> void:
	var chunk := get_chunk(coords)
	var file := FileAccess.open(get_chunk_path(coords), FileAccess.WRITE)
	if file != null:
		file.store_buffer(chunk.data.to_byte_array())

func load_chunk_nodes(coords: Vector2i) -> Array:
	var nodes := []
	var file := FileAccess.open(get_chunk_nodes_path(coords), FileAccess.READ)
	if file != null:
		nodes = bytes_to_var_with_objects(file.get_buffer(file.get_length())).map(IS.unpack_node)
	return nodes

func save_chunk_nodes(coords: Vector2i) -> void:
	var nodes := get_chunk_nodes(coords)
	if nodes.is_empty():
		DirAccess.remove_absolute(get_chunk_nodes_path(coords))
		return
	var file := FileAccess.open(get_chunk_nodes_path(coords), FileAccess.WRITE)
	if file != null:
		file.store_buffer(var_to_bytes_with_objects(nodes.map(IS.pack_node)))

func shape_chunk(coords: Vector2i):
	var chunk := get_chunk(coords)
	if chunk == null or chunk.shaped_time == chunk.modified_time: return
	chunk.shaped_time = chunk.modified_time
	clear_chunk_shapes(coords)
	var bit_map := get_chunk_bit_map(coords)
	var polygons := bit_map.opaque_to_polygons(Rect2i(Vector2i.ZERO, Chunk.SIZE))
	for polygon in polygons:
		for points in Geometry2D.decompose_polygon_in_convex(polygon):
			var shape := PhysicsServer2D.convex_polygon_shape_create()
			PhysicsServer2D.shape_set_data(shape, points)
			var index: int
			if shapes.is_empty():
				index = PhysicsServer2D.body_get_shape_count(body)
				PhysicsServer2D.body_add_shape(body, shape)
			else:
				index = shapes[-1]
				shapes.remove_at(shapes.size() - 1)
				PhysicsServer2D.body_set_shape(body, index, shape)
				PhysicsServer2D.body_set_shape_disabled(body, index, false)
			PhysicsServer2D.body_set_shape_transform(body, index, Transform2D(0, coords * Chunk.SIZE))
			chunk.shapes.push_back(index)

func get_chunk_bit_map(coords: Vector2i) -> BitMap:
	var bit_map := BitMap.new()
	bit_map.create(Chunk.SIZE)
	for point in IS.rect2i_to_points(Rect2i(Vector2i.ZERO, Chunk.SIZE)):
		var state := pixel_set.pixels[chunks[coords].get_cell_pixel(point)].state
		bit_map.set_bitv(point, state == Pixel.State.SOLID)
	return bit_map
