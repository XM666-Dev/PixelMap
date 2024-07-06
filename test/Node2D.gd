extends Node2D

var tile_type := 0
var size := Vector2i(10, 10)

func _physics_process(_delta):
	if Input.is_key_pressed(KEY_A):
		position.x -= 10
	elif Input.is_key_pressed(KEY_D):
		position.x += 10
	if Input.is_key_pressed(KEY_W):
		position.y -= 10
	elif Input.is_key_pressed(KEY_S):
		position.y += 10

	var pixel_map: PixelMap = %PixelMap
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var rect := Rect2i(pixel_map.get_local_mouse_position(), size)
		for y in IS.column(rect):
			for x in IS.row(rect):
				pixel_map.set_cell_substance(Vector2i(x, y), tile_type)

func _process(delta):
	queue_redraw()

func _input(event):
	var pixel_map: PixelMap = %PixelMap
	var event_mouse_button := event as InputEventMouseButton
	if event_mouse_button:
		if event_mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			tile_type = wrapi(tile_type - 1, -1, pixel_map.tile_set.atlas_textures.size())
		elif event_mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tile_type = wrapi(tile_type + 1, -1, pixel_map.tile_set.atlas_textures.size())

func _draw():
	var pixel_map: PixelMap = %PixelMap
	if tile_type == -1: return
	var texture := pixel_map.tile_set.atlas_textures[tile_type]
	var rect := Rect2i(get_local_mouse_position(), size)
	var src_rect := Rect2i(Vector2i.ZERO, size)
	draw_texture_rect_region(texture, rect, src_rect)
