@tool
class_name PixelSet extends Resource

@export var pixels: Array[Pixel]:
	set(_pixels):
		pixels = _pixels
		emit_changed()
@export_storage var data: PackedByteArray
@export_storage var texture: ImageTexture
@export_storage var indexed_pixels: Array[Pixel]

func _init():
	if Engine.is_editor_hint(): connect(&"changed", changed)

func changed():
	var textures := [] as Array[Texture2D]
	for pixel in pixels:
		for pixel_texture in pixel.textures:
			textures.push_back(pixel_texture)
	var atlas := IS.make_atlas(textures, Image.FORMAT_RGBA8)
	var ints := PackedInt32Array()
	var i := 0
	for pixel in pixels:
		pixel.id = i
		indexed_pixels.resize(i + 1)
		indexed_pixels[i] = pixel
		var size := pixel.textures.size()
		for j in size:
			ints.push_back(int(atlas.atlas_textures[i].region.position.x))
			ints.push_back(int(atlas.atlas_textures[i].region.position.y))
			ints.push_back(int(atlas.atlas_textures[i].region.size.x))
			ints.push_back(int(atlas.atlas_textures[i].region.size.y))
			ints.push_back(size)
			ints.push_back(0)
			i += 1
	data = ints.to_byte_array()
	texture = atlas.texture
