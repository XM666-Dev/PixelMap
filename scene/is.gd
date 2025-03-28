class_name IS

static func rect2_range(position: Vector2, end: Vector2) -> Rect2:
	return Rect2(position, end - position)

static func rect2i_range(position: Vector2i, end: Vector2i) -> Rect2i:
	return Rect2i(position, end - position)

static func rect2i_to_points(rect: Rect2i) -> Array[Vector2i]:
	var points := [] as Array[Vector2i]
	points.resize(rect.size.x * rect.size.y)
	var row := range(rect.position.x, rect.end.x)
	var column := range(rect.position.y, rect.end.y)
	var i := 0
	for y in column:
		for x in row:
			points[i] = Vector2i(x, y)
			i = i + 1
	return points

static func posdiv(x: int, y: int) -> int:
	var value := x % y
	if value < 0 and y > 0 or value > 0 and y < 0:
		return x / y - 1
	return x / y

static func vector2i_posmodv(x: Vector2i, y: Vector2i) -> Vector2i:
	return Vector2i(posmod(x.x, y.x), posmod(x.y, y.y))

static func vector2i_posdivv(x: Vector2i, y: Vector2i) -> Vector2i:
	return Vector2i(posdiv(x.x, y.x), posdiv(x.y, y.y))

static func clip_rects(rect_a: Rect2i, rect_b: Rect2i) -> Array[Rect2i]:
	var rects := [] as Array[Rect2i]
	if rect_b.position.x > rect_a.position.x and rect_a.position.y < rect_b.end.y:
		rects.push_back(rect2i_range(rect_a.position, Vector2i(mini(rect_b.position.x, rect_a.end.x), mini(rect_b.end.y, rect_a.end.y))))
	if rect_b.position.y > rect_a.position.y and rect_a.end.x > rect_b.position.x:
		rects.push_back(rect2i_range(Vector2i(maxi(rect_b.position.x, rect_a.position.x), rect_a.position.y), Vector2i(rect_a.end.x, mini(rect_b.position.y, rect_a.end.y))))
	if rect_a.end.x > rect_b.end.x and rect_a.end.y > rect_b.position.y:
		rects.push_back(rect2i_range(Vector2i(maxi(rect_b.end.x, rect_a.position.x), maxi(rect_b.position.y, rect_a.position.y)), rect_a.end))
	if rect_a.end.y > rect_b.end.y and rect_a.position.x < rect_b.end.x:
		rects.push_back(rect2i_range(Vector2i(rect_a.position.x, maxi(rect_b.end.y, rect_a.position.y)), Vector2i(mini(rect_b.end.x, rect_a.end.x), rect_a.end.y)))
	return rects

static func get_viewport_rect_global(item: CanvasItem) -> Rect2:
	return item.get_viewport_transform().affine_inverse() * item.get_viewport_rect()

static func set_properties(object: Object, properties: Dictionary):
	for property_path in properties:
		assert(property_path in object)
		object.set_indexed(property_path, properties[property_path])

static func make_atlas(textures: Array[Texture2D], format: Image.Format) -> Dictionary:
	var sizes := PackedVector2Array(textures.map(func(texture): return texture.get_size()))
	var atlas := Geometry2D.make_atlas(sizes)
	var image := Image.create(atlas.size.x, atlas.size.y, false, format)
	var atlas_textures := [] as Array[AtlasTexture]
	var image_texture := ImageTexture.new()
	for i in textures.size():
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = image_texture
		atlas_texture.region = Rect2(atlas.points[i], sizes[i])
		atlas_textures.push_back(atlas_texture)
		var src_image := textures[i].get_image()
		src_image.convert(format)
		image.blit_rect(src_image, Rect2i(Vector2i.ZERO, sizes[i]), atlas.points[i])
	image_texture.set_image(image)
	return {atlas_textures = atlas_textures, texture = image_texture}

static func open(path: String) -> DirAccess:
	DirAccess.make_dir_recursive_absolute(path)
	return DirAccess.open(path)

static func open_dir(dir: DirAccess, file: String) -> DirAccess:
	return open(dir.get_current_dir().path_join(file))

static func pack_node(node: Node) -> Array[Variant]:
	return [node, node.get_children().map(pack_node)]

static func unpack_node(nodes: Array[Variant]) -> Node:
	for child in nodes[1]:
		nodes[0].add_child(unpack_node(child))
	return nodes[0]
