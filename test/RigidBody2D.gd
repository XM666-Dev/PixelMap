extends RigidBody2D

var force := 2000

func _ready() -> void:
	if self == null: printerr(666)
	$CollisionPolygon2D.polygon = $Polygon2D.polygon
	$Polygon2D.texture = [
		preload("res://test/textures/oak_planks.png"),
		preload("res://test/textures/stone.png"),
		preload("res://test/textures/sand.png")
	].pick_random()
	$Polygon2D.uv = $Polygon2D.polygon

func _physics_process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_LEFT):
		apply_force(Vector2(-force, 0))
	if Input.is_key_pressed(KEY_RIGHT):
		apply_force(Vector2(force, 0))
	if Input.is_key_pressed(KEY_UP):
		apply_force(Vector2(0, -force))
	if Input.is_key_pressed(KEY_DOWN):
		apply_force(Vector2(0, force))

	var rect: Rect2
	for shape_owner in get_shape_owners():
		var owner_transform := shape_owner_get_transform(shape_owner)
		owner_transform *= transform
		for id in shape_owner_get_shape_count(shape_owner):
			var shape := shape_owner_get_shape(shape_owner, id)
			var shape_rect := owner_transform * shape.get_rect()
			rect = shape_rect if rect == Rect2() else rect.merge(shape_rect)
	var rect_position := Vector2i((rect.position / Vector2(Chunk.SIZE)).floor())
	var rect_end := Vector2i((rect.end / Vector2(Chunk.SIZE)).ceil())
	rect = IS.rect2i_range(rect_position, rect_end)
	var pixel_map := Main.node.get_node("PixelMap") as PixelMap
	for coords in IS.rect2i_to_points(rect):
		pixel_map.shape_chunk(coords)
	freeze = not rect.intersects(pixel_map.previous_process_rect)
