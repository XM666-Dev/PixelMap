class_name PixelMap extends Node2D

@export var pixel_set: PixelSet
var render_extents: Vector2i
var texture := Texture2DRD.new()

@export var process_extents: Vector2i
var previous_process_rect: Rect2i
var chunks: Dictionary[Vector2i, Chunk]
var streams: Dictionary[Vector2i, bool]
var load_streams: Array[Vector2i]
var save_streams: Array[Vector2i]
var load_back: int = -1
var save_back: int = -1
@onready var load_task := WorkerThreadPool.add_task(func() -> void:
	while true:
		for i in mini(load_back, 128):
			var stream := load_streams[load_back]
			load_back -= 1
			if previous_process_rect.has_point(stream):
				chunks[stream] = force_load_chunk(stream)
			streams.erase(stream)
		await get_tree().create_timer(1 / 30).timeout
)
@onready var save_task := WorkerThreadPool.add_task(func() -> void:
	while true:
		for i in mini(save_back, 128):
			var stream := save_streams[save_back]
			save_back -= 1
			if not previous_process_rect.has_point(stream):
				force_save_chunk(stream)
			if not previous_process_rect.has_point(stream):
				remove_chunk(stream)
			streams.erase(stream)
		if close_requested:
			break
		await get_tree().create_timer(1 / 30).timeout
)
var node_streams: Dictionary[Vector2i, bool]
var load_node_streams: Array[Vector2i]
var save_node_streams: Array[Vector2i]
var load_node_back: int = -1
var save_node_back: int = -1
@onready var load_node_task := WorkerThreadPool.add_task(func() -> void:
	while true:
		for i in mini(load_node_back, 128):
			var stream := load_node_streams[load_node_back]
			load_node_back -= 1
			if previous_process_rect.has_point(stream):
				var file := FileAccess.open(get_chunk_node_path(stream), FileAccess.READ)
				if file != null:
					var scenes = file.get_var(true)
					if scenes != null:
						for scene in scenes:
							add_child.call_deferred(scene.instantiate())
			node_streams.erase(stream)
		await get_tree().create_timer(1 / 30).timeout
)
@onready var save_node_task := WorkerThreadPool.add_task(func() -> void:
	while true:
		for i in mini(save_node_back, 128):
			var stream := save_node_streams[save_node_back]
			save_node_back -= 1
			var children := get_children().filter(func(child: Node) -> bool:
				return child is Node2D and Rect2(stream * Chunk.SIZE, Chunk.SIZE).has_point(child.position)
			)
			if not children.is_empty():
				if not previous_process_rect.has_point(stream):
					var file := FileAccess.open(get_chunk_node_path(stream), FileAccess.WRITE)
					var scenes: Array[PackedScene]
					for child: Node2D in children:
						var found_children := child.find_children("*")
						for found_child in found_children:
							found_child.owner = child
						var scene := PackedScene.new()
						scene.pack(child)
						scenes.push_back(scene)
					file.store_var(scenes, true)
				if not previous_process_rect.has_point(stream):
					for child in children:
						remove_child(child)
			node_streams.erase(stream)
		if close_requested:
			break
		await get_tree().create_timer(1 / 30).timeout
)
var close_requested: bool

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

static func get_chunk_node_path(coords: Vector2i) -> String:
	return Main.chunks_dir.get_current_dir().path_join("n" + str(coords))

static func _static_init():
	prepare_shader()

func _ready():
	render_extents = get_render_extents()
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
	rd.compute_list_dispatch(compute_list, render_rect.size.x * Chunk.SIZE.x / 32, render_rect.size.y * Chunk.SIZE.y / 32, 1)
	rd.compute_list_end()

func _process(_delta):
	var render_rect := get_render_rect()
	var data := PackedInt32Array([
		render_extents.x, render_extents.y,
		render_rect.position.x, render_rect.position.y,
		Main.time
	]).to_byte_array()
	rd.buffer_update(buf_map, 0, data.size(), data)
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

	#var render_rect := get_render_rect()
	#for coords in IS.rect2i_to_points(render_rect):
		#var chunk := get_chunk(coords)
		#if chunk == null: continue
		#for shape in chunk.shapes:
			#draw_set_transform_matrix(PhysicsServer2D.body_get_shape_transform(body, shape))
			#var polygon_shape := PhysicsServer2D.body_get_shape(body, shape)
			#var polygon := PhysicsServer2D.shape_get_data(polygon_shape) as PackedVector2Array
			#draw_polygon(polygon, [Color(Color.WHITE, 0.2)])
			#polygon.push_back(polygon[0])
			#draw_polyline(polygon, Color.WHITE)
	#draw_set_transform(Vector2.ZERO)
	#var mouse_position := get_local_mouse_position()
	#var chunk_coords := local_to_chunk(mouse_position)
	#draw_rect(Rect2(chunk_coords * Chunk.SIZE, Chunk.SIZE), Color.WHITE, false)
	##var render_coords := IS.vector2i_posmodv(chunk_coords, render_extents)
	##var render_index := render_coords.y * render_extents.x + render_coords.x
	#draw_string(
		#Main.font,
		#chunk_coords * Chunk.SIZE,
		#"%s: %s" % [chunk_coords, get_chunk(chunk_coords)],
		#HORIZONTAL_ALIGNMENT_LEFT,
		#-1,
		#8
	#)

func _physics_process(_delta):
	var process_rect := get_process_rect()
	var load_rects := IS.clip_rects(process_rect, previous_process_rect).map(IS.rect2i_to_points)
	var save_rects := IS.clip_rects(previous_process_rect, process_rect).map(IS.rect2i_to_points)
	previous_process_rect = process_rect
	for points in load_rects:
		for coords in points:
			load_chunk(coords)
	for points in save_rects:
		for coords in points:
			save_chunk(coords)

	#if Input.is_action_just_pressed("ui_down"):
		#print("CHUNKS: %s" % chunks.size())
		#var count := 0
		#for callables: Array[Callable] in streams:
			#for callable in callables:
				#if callable.is_null(): break
				#count = count + 1
		#print("STREAMS: %s" % count)

func _close_requested() -> void:
	set_physics_process(false)
	previous_process_rect = Rect2i()
	close_requested = true
	WorkerThreadPool.wait_for_task_completion(save_task)
	WorkerThreadPool.wait_for_task_completion(save_node_task)
	streams.clear()
	node_streams.clear()
	for coords in chunks.keys():
		save_chunk(coords)
	for i in save_back + 1:
		force_save_chunk(save_streams[i])
	for i in save_node_back + 1:
		var stream := save_node_streams[i]
		var children := get_children().filter(func(child: Node) -> bool:
			return child is Node2D and Rect2(stream * Chunk.SIZE, Chunk.SIZE).has_point(child.position)
		)
		if not children.is_empty():
			var file := FileAccess.open(get_chunk_node_path(stream), FileAccess.WRITE)
			var scenes: Array[PackedScene]
			for child: Node2D in children:
				var found_children := child.find_children("*")
				for found_child in found_children:
					found_child.owner = child
				var scene := PackedScene.new()
				scene.pack(child)
				scenes.push_back(scene)
			file.store_var(scenes, true)

func chunk_remove_shape(chunk: Chunk) -> void:
	for shape in chunk.shapes:
		PhysicsServer2D.body_set_shape_disabled(body, shape, true)
	shapes.append_array(chunk.shapes)
	chunk.shapes.clear()

func remove_chunk(coords: Vector2i) -> void:
	chunk_remove_shape(chunks[coords])
	chunks.erase(coords)

func load_chunk(coords: Vector2i) -> void:
	load_chunk_node(coords)
	var chunk := get_chunk(coords)
	if chunk != null or streams.has(coords): return
	streams[coords] = true
	if load_back + 1 < load_streams.size():
		load_streams[load_back + 1] = coords
	else:
		load_streams.push_back(coords)
	load_back += 1

func load_chunk_node(coords: Vector2i) -> void:
	var chunk := get_chunk(coords)
	if chunk != null or node_streams.has(coords): return
	node_streams[coords] = true
	if load_node_back + 1 < load_node_streams.size():
		load_node_streams[load_node_back + 1] = coords
	else:
		load_node_streams.push_back(coords)
	load_node_back += 1

func save_chunk(coords: Vector2i) -> void:
	save_chunk_node(coords)
	var chunk := get_chunk(coords)
	if chunk == null or streams.has(coords): return
	if chunk.modified_time == 0: remove_chunk(coords); return
	streams[coords] = true
	if save_back + 1 < save_streams.size():
		save_streams[save_back + 1] = coords
	else:
		save_streams.push_back(coords)
	save_back += 1

func save_chunk_node(coords: Vector2i) -> void:
	var chunk := get_chunk(coords)
	if chunk == null or node_streams.has(coords): return
	node_streams[coords] = true
	if save_node_back + 1 < save_node_streams.size():
		save_node_streams[save_node_back + 1] = coords
	else:
		save_node_streams.push_back(coords)
	save_node_back += 1

func force_load_chunk(coords: Vector2i) -> Chunk:
	var chunk := Chunk.new()
	var file := FileAccess.open(get_chunk_path(coords), FileAccess.READ)
	if file != null:
		chunk.data = file.get_buffer(Chunk.SIZE.x * Chunk.SIZE.y * Chunk.TILE_SIZE * 4).to_int32_array()
	else:
		chunk.data.resize(Chunk.SIZE.x * Chunk.SIZE.y * Chunk.TILE_SIZE)
		chunk.modified_time = 1
	return chunk

func force_save_chunk(coords: Vector2i) -> void:
	var chunk := get_chunk(coords)
	var file := FileAccess.open(get_chunk_path(coords), FileAccess.WRITE)
	if file != null:
		file.store_buffer(chunk.data.to_byte_array())

func shape_chunk(coords: Vector2i):
	var chunk := get_chunk(coords)
	if chunk == null or chunk.shaped_time == chunk.modified_time: return
	chunk.shaped_time = chunk.modified_time
	chunk_remove_shape(chunk)
	var bit_map := chunk_get_bit_map(chunk)
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

func chunk_get_bit_map(chunk: Chunk) -> BitMap:
	var bit_map := BitMap.new()
	bit_map.create(Chunk.SIZE)
	for coords in IS.rect2i_to_points(Rect2i(Vector2i.ZERO, Chunk.SIZE)):
		bit_map.set_bitv(coords, pixel_set.indexed_pixels[chunk.get_cell_pixel(coords)].state == Pixel.States.SOLID)
	return bit_map
