class_name IS

static func array(type: Variant, base: Array = []) -> Array:
	if type is int:
		return Array(base, type, &"", null)
	if type is StringName:
		return Array(base, TYPE_OBJECT, type, null)
	return Array(base, TYPE_OBJECT, (type as Script).get_instance_base_type(), type)

static func rect_from_to(position: Vector2, end: Vector2) -> Rect2:
	return Rect2(position, end - position)

static func row(rect: Rect2i):
	return range(rect.position.x, rect.end.x)

static func column(rect: Rect2i):
	return range(rect.position.y, rect.end.y)

static func modulo(x: Variant, y: Variant) -> Variant:
	return x % y if x is int else fmod(x, y)

static func floor_divide(x: Variant, y: Variant) -> Variant:
	if x is Vector2:
		return Vector2(floor_divide(x.x, y.x), floor_divide(x.y, y.y))
	if x is Vector2i:
		return Vector2i(floor_divide(x.x, y.x), floor_divide(x.y, y.y))
	var value: Variant = modulo(x, y)
	return x / y - 1 if value < 0 else x / y

static func floor_modulo(x: Variant, y: Variant) -> Variant:
	if x is Vector2:
		return Vector2(floor_modulo(x.x, y.x), floor_modulo(x.y, y.y))
	if x is Vector2i:
		return Vector2i(floor_modulo(x.x, y.x), floor_modulo(x.y, y.y))
	var value: Variant = modulo(x, y)
	return value + y if value < 0 else value

static func ceil_divide(x: Variant, y: Variant) -> Variant:
	if x is Vector2:
		return Vector2(ceil_divide(x.x, y.x), ceil_divide(x.y, y.y))
	if x is Vector2i:
		return Vector2i(ceil_divide(x.x, y.x), ceil_divide(x.y, y.y))
	var value: Variant = modulo(x, y)
	return x / y + 1 if value > 0 else x / y

static func ceil_modulo(x: Variant, y: Variant) -> Variant:
	if x is Vector2:
		return Vector2(ceil_modulo(x.x, y.x), ceil_modulo(x.y, y.y))
	if x is Vector2i:
		return Vector2i(ceil_modulo(x.x, y.x), ceil_modulo(x.y, y.y))
	var value: Variant = modulo(x, y)
	return value - y if value > 0 else value

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
	var texture := ImageTexture.new()
	for i in textures.size():
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = texture
		atlas_texture.region = Rect2(atlas.points[i], sizes[i])
		atlas_textures.append(atlas_texture)
		var src_image := textures[i].get_image()
		src_image.convert(format)
		image.blit_rect(src_image, Rect2i(Vector2i.ZERO, sizes[i]), atlas.points[i])
	texture.set_image(image)
	return {atlas_textures = atlas_textures, texture = texture}

static func make_dir_recursive_absolute_and_open(path: String) -> DirAccess:
	DirAccess.make_dir_recursive_absolute(path)
	return DirAccess.open(path)

static func open(dir: DirAccess, path: String) -> DirAccess:
	return IS.make_dir_recursive_absolute_and_open(dir.get_current_dir().path_join(path))

#enum CanvasLevel {
	#LOCAL,
	#PARENT,
	#GLOBAL,
	#VIEWPORT
#}
#
#const CANVAS_LEVEL_LOCAL = CanvasLevel.LOCAL
#const CANVAS_LEVEL_PARENT = CanvasLevel.PARENT
#const CANVAS_LEVEL_GLOBAL = CanvasLevel.GLOBAL
#const CANVAS_LEVEL_VIEWPORT = CanvasLevel.VIEWPORT
#
#static func get_transform(node: CanvasItem, level: CanvasLevel) -> Transform2D:
	#match level:
		#_:
			#return Transform2D()
		#CANVAS_LEVEL_PARENT:
			#return node.get_transform()
		#CANVAS_LEVEL_GLOBAL:
			#return node.get_global_transform()
		#CANVAS_LEVEL_VIEWPORT:
			#return node.get_global_transform() * node.get_viewport_transform()
#
#static func to(transform: Transform2D, from_level: CanvasLevel, to_level: CanvasLevel):
	#return get_transform(node, level).affine_inverse() * node.get_transform() * transform
#
#static func to_parent(node: CanvasItem, level: CanvasLevel, transform: Transform2D):
	#return get_transform(node, level).affine_inverse() * node.get_transform() * transform
	#
#static func set_transform(node: CanvasItem, level: CanvasLevel, transform: Transform2D):
	#var final_transform := get_transform(node, level).affine_inverse() * node.get_transform() * transform
	#var control := node as Control
	#if control:
		#control.position = final_transform.get_origin()
		#control.rotation = final_transform.get_rotation()
		#control.scale = final_transform.get_scale()
	#var node_2d := node as Node2D
	#if node_2d:
		#node_2d.transform = final_transform
#
#static func draw_set_level(node: CanvasItem, level: CanvasLevel) -> void:
	#node.draw_set_transform_matrix(get_transform(node, level).affine_inverse())

#class CanvasTransform:
	#enum Type{
		#LOCAL,
		#GLOBAL,
		#VIEWPORT
	#}
	#var type: Type
	#var node: CanvasItem
	#var transform: Transform2D
	#func _init(node: CanvasItem, type := Type.LOCAL):
		#self.type = type
		#self.node = node
	#func multiply(transform: Transform2D):
		#self.transform *= transform
	#func get_transform():
		#
#
#func do(node) -> CanvasTransform:
	#var transform := CanvasTransform.new(node)
	#transform.multiply(Transform2D())
	#return transform
