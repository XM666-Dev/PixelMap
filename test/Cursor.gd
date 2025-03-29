extends Node2D

var drawing: bool
var pixel_index: int
var max_draw_size := Vector2i(32, 32)
var draw_size := Vector2i(16, 16)
var resize_time: int

func _input(event):
	var pixel_map := %PixelMap as PixelMap
	if event.is_action_pressed("previous"):
		if Input.is_key_pressed(KEY_CTRL):
			resize_time = Main.time
			draw_size = (draw_size - Vector2i.ONE).clamp(Vector2i.ONE, max_draw_size)
		elif Input.is_key_pressed(KEY_ALT):
			var camera := %Player/Camera2D as Camera2D
			camera.zoom = (camera.zoom - Vector2(0.2, 0.2)).clamp(Vector2(2, 2), Vector2(16, 16))
		else:
			pixel_index = (pixel_index - 1) % pixel_map.pixel_set.pixels.size()
	if event.is_action_pressed("next"):
		if Input.is_key_pressed(KEY_CTRL):
			resize_time = Main.time
			draw_size = (draw_size + Vector2i.ONE).clamp(Vector2i.ONE, max_draw_size)
		elif Input.is_key_pressed(KEY_ALT):
			var camera := %Player/Camera2D as Camera2D
			camera.zoom = (camera.zoom + Vector2(0.2, 0.2)).clamp(Vector2(2, 2), Vector2(16, 16))
		else:
			pixel_index = (pixel_index + 1) % pixel_map.pixel_set.pixels.size()
	if event.is_action("fire"):
		drawing = event.pressed
	if event.is_action_pressed("spawn"):
		var rigid_body_scene := preload("res://test/scene/rigid_body_2d.tscn")
		var rigid_body := rigid_body_scene.instantiate()
		%PixelMap.add_child(rigid_body)
		rigid_body.position = get_global_mouse_position()

func _physics_process(_delta):
	var pixel_map := %PixelMap as PixelMap
	if drawing:
		var rect := Rect2i(pixel_map.get_local_mouse_position().floor(), draw_size)
		for coords in IS.rect2i_to_points(rect):
			pixel_map.set_cell_pixel(coords, pixel_index)

func _process(_delta):
	queue_redraw()

func _draw():
	var pixel_map := %PixelMap as PixelMap
	var texture := pixel_map.pixel_set.pixels[pixel_index].texture
	var rect := Rect2i(pixel_map.get_local_mouse_position().floor(), draw_size)
	if texture != null:
		draw_texture_rect_region(texture, rect, rect)
	var max_frame := 30
	var frame := Main.time % max_frame
	if frame > max_frame / 2:
		frame = max_frame - frame
	var alpha := 0.1 + 0.05 * 2 * frame / max_frame
	draw_rect(rect, Color(Color.WHITE, alpha))
	draw_rect(rect, Color(Color.WHITE, 0.5), false)
