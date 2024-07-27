class_name Main extends Node2D

static var node: Main
static var font := SystemFont.new()
static var save_id := 0
static var saves_dir := IS.open("user://saves")
static var save_dir := IS.open_dir(saves_dir, str(save_id))
static var chunks_dir := IS.open_dir(Main.save_dir, "chunks")

var is_drawing: bool
var pixel_index: int
var draw_size := Vector2i(32, 32)

func _init():
	Main.node = self
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _input(event):
	var pixel_map := %PixelMap as PixelMap
	var event_mouse_button := event as InputEventMouseButton
	if event_mouse_button and event_mouse_button.pressed:
		if event_mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			pixel_index = wrapi(pixel_index - 1, 0, pixel_map.pixel_set.pixels.size())
		elif event_mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pixel_index = wrapi(pixel_index + 1, 0, pixel_map.pixel_set.pixels.size())
	if event_mouse_button:
		if event_mouse_button.button_index == MOUSE_BUTTON_LEFT:
			is_drawing = event_mouse_button.pressed

func _physics_process(_delta):
	var pixel_map := %PixelMap as PixelMap
	if is_drawing:
		var rect := Rect2i(pixel_map.get_local_mouse_position(), draw_size)
		for coords in IS.rect2i_to_points(rect):
			pixel_map.set_cell_pixel(coords, pixel_map.pixel_set.pixels[pixel_index].id)


func _process(_delta):
	queue_redraw()

func _draw():
	var pixel_map := %PixelMap as PixelMap
	var texture := pixel_map.pixel_set.pixels[pixel_index].textures[0]
	var rect := Rect2i(get_local_mouse_position(), draw_size)
	draw_texture_rect(texture, rect, true)
	#var a := Rect2i(100, 100, 100, 100)
	#var b := Rect2i(120, -20, 60, 60)
	#draw_rect(a, Color.RED, false)
	#draw_rect(b, Color.BLUE, false)
	#var rects := IS.clip_rects(a, b)
	#var colors := PackedColorArray([Color.WEB_GRAY, Color.ANTIQUE_WHITE, Color.AQUAMARINE, Color.FOREST_GREEN])
	#var i := 0
	#for rect1 in rects:
		#draw_rect(rect1.grow(-1), colors[i], false)
		#i = i + 1
