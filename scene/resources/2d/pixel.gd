@tool
class_name Pixel extends Resource

enum State {
	SOLID,
	LIQUID,
	GAS
}

@export var name: StringName
@export var texture: Texture2D
@export var state: State
