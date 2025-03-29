@tool
class_name PixelSet extends Resource

@export var pixels: Array[Pixel]:
	set(_pixels):
		pixels = _pixels
		emit_changed()
@export_storage var data: PackedByteArray
@export_storage var texture: ImageTexture

func _init():
	if Engine.is_editor_hint(): connect(&"changed", changed)

func changed():
	var textures := pixels.map(func(pixel: Pixel) -> Texture2D: return pixel.texture)
	var atlas := IS.make_atlas(textures, Image.FORMAT_RGBA8)
	var ints := PackedInt32Array()
	for atlas_texture in atlas.atlas_textures:
		ints.push_back(int(atlas_texture.region.position.x))
		ints.push_back(int(atlas_texture.region.position.y))
		ints.push_back(int(atlas_texture.region.size.x))
		ints.push_back(int(atlas_texture.region.size.y))
	data = ints.to_byte_array()
	texture = atlas.texture
