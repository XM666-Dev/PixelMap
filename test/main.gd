class_name Main extends Node2D

static var node: Main
static var font := SystemFont.new()
static var save_id := 0
static var saves_dir := IS.open("user://saves")
static var save_dir := IS.open_dir(saves_dir, str(save_id))
static var chunks_dir := IS.open_dir(Main.save_dir, "chunks")

func _init():
	Main.node = self
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	var cursor := preload("res://test/textures/mouse_cursor_big.png")
	DisplayServer.cursor_set_custom_image(cursor, DisplayServer.CURSOR_ARROW, Vector2(20, 20))
