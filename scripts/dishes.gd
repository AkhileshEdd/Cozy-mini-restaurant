class_name Dishes
extends RefCounted
## Spawns styled 3D dish models by menu id.

const MODELS := {
	"latte": "res://assets/models/food_latte.glb",
	"cake": "res://assets/models/food_cake.glb",
	"pancakes": "res://assets/models/food_pancakes.glb",
	"soup": "res://assets/models/food_soup.glb",
	"sundae": "res://assets/models/food_sundae.glb",
}

static var _scenes: Dictionary = {}


static func spawn(dish: String) -> Node3D:
	if not _scenes.has(dish):
		_scenes[dish] = load(MODELS[dish])
	var n: Node3D = (_scenes[dish] as PackedScene).instantiate()
	n.name = dish
	CozyLook.stylize(n, true)
	return n
