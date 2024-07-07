class_name Main extends Node2D

static var node: Main
static var save_dir := IS.make_dir_recursive_absolute_and_open("user://save")

var pixel_index := 0
var draw_size := Vector2i(8, 8)

func _init():
	Main.node = self
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _physics_process(_delta):
	var pixel_map := %PixelMap as PixelMap
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var rect := Rect2i(pixel_map.get_local_mouse_position(), draw_size)
		for y in IS.column(rect):
			for x in IS.row(rect):
				pixel_map.set_cell_pixel(Vector2i(x, y), pixel_map.pixel_set.pixels[pixel_index].id)

func _input(event):
	var pixel_map := %PixelMap as PixelMap
	var event_mouse_button := event as InputEventMouseButton
	if event_mouse_button and event_mouse_button.pressed:
		if event_mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			pixel_index = wrapi(pixel_index - 1, 0, pixel_map.pixel_set.pixels.size())
		elif event_mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pixel_index = wrapi(pixel_index + 1, 0, pixel_map.pixel_set.pixels.size())

func _process(_delta):
	queue_redraw()

func _draw():
	var pixel_map := %PixelMap as PixelMap
	var texture := pixel_map.pixel_set.pixels[pixel_index].textures[0]
	var rect := Rect2i(get_local_mouse_position(), draw_size)
	draw_texture_rect(texture, rect, true)
