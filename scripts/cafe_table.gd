class_name CafeTable
extends Node3D
## A round table with a chair on each side (child nodes ChairL / ChairR).

var seats: Array[Seat] = []
var unlocked := true


func _ready() -> void:
	CozyLook.stylize(self)
	CozyLook.add_blob(self, Vector2(1.5, 1.5))
	for chair in [get_node("ChairL"), get_node("ChairR")]:
		CozyLook.add_blob(chair, Vector2(0.6, 0.6))
	seats.append(Seat.new(self, get_node("ChairL"), -1.0))
	seats.append(Seat.new(self, get_node("ChairR"), 1.0))


## Locked tables stay in place as see-through previews of what the shop sells.
func set_unlocked(value: bool, animate := false) -> void:
	var was := unlocked
	unlocked = value
	CozyLook.ghostify(self, not value)
	if value and animate and not was:
		FX.pop_in(self, 0.5)
		FX.sparkles(get_parent(), global_position + Vector3(0, 0.8, 0), 26)


func obstacle_points() -> Array:
	return [
		[global_position, 0.62],
		[get_node("ChairL").global_position, 0.32],
		[get_node("ChairR").global_position, 0.32],
	]
