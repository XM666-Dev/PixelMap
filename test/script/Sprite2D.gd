extends Sprite2D

func _ready():
	var pixel_map: PixelMap = %PixelMap
	#pixel_map.chunks.resize(pixel_map.chunk_extents.x * pixel_map.chunk_extents.y)
	#pixel_map.chunks.fill(PackedInt32Array())
	#pixel_map.chunks[0].resize(pixel_map.CHUNK_SIZE.x * pixel_map.CHUNK_SIZE.y)
	for i in 256:
		pixel_map.chunks[0][i]=1

func _process(_delta):
	if Input.is_key_pressed(KEY_A):
		position.x -= 10
	elif Input.is_key_pressed(KEY_D):
		position.x += 10
	if Input.is_key_pressed(KEY_W):
		position.y -= 10
	elif Input.is_key_pressed(KEY_S):
		position.y += 10

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var pixel_map: PixelMap = %PixelMap
		var rect := Rect2i(pixel_map.get_local_mouse_position(), Vector2i(10, 10))
		MathUtils.for_rect(rect, func(coord: Vector2i):
			var chunk := pixel_map.get_chunk(coord)
			var index := pixel_map.get_tile_index(coord)
			chunk[index] = 1
		)
	queue_redraw()

func _draw():
	var rect := Rect2i(get_local_mouse_position(),Vector2i(10,10))
	draw_rect(rect, Color.AQUA)
