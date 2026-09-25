class_name Seat
extends RefCounted
## One chair at a table: where a guest sits, where their dish goes and where
## the coins they leave behind wait to be collected.

const COIN_SCENE := preload("res://assets/models/coin.glb")

var table: CafeTable
var chair: Node3D
var side := -1.0
var occupant: Node3D = null
var coins := 0
var _coin_stack: Node3D


func _init(table_node: CafeTable, chair_node: Node3D, side_sign: float) -> void:
	table = table_node
	chair = chair_node
	side = side_sign


func is_free() -> bool:
	return occupant == null and coins == 0 and table.unlocked


func sit_position() -> Vector3:
	var s := chair.find_child("Seat", true, false) as Node3D
	return s.global_position if s else chair.global_position + Vector3(0, 0.36, 0)


## Face the table, turned a little toward the camera so faces stay visible.
func sit_yaw() -> float:
	var d := table.global_position - chair.global_position
	return atan2(d.x, d.z + 0.45)


## Floor spot in front of the chair, where guests hop on/off and the chef serves.
func approach_point() -> Vector3:
	var p := chair.global_position + Vector3(0, 0, 0.62)
	p.y = 0.0
	return p


func dish_position() -> Vector3:
	return table.global_position + Vector3(side * 0.24, 0.585, 0.06)


func tap_anchor() -> Vector3:
	return dish_position() + Vector3(0, 0.15, 0)


func leave_coins(amount: int) -> void:
	coins += amount
	if _coin_stack == null:
		_coin_stack = Node3D.new()
		table.get_parent().add_child(_coin_stack)
		_coin_stack.global_position = dish_position()
		var count := clampi(1 + amount / 10, 2, 5)
		for i in count:
			var c: Node3D = COIN_SCENE.instantiate()
			CozyLook.stylize(c, true)
			_coin_stack.add_child(c)
			c.rotation_degrees = Vector3(90, randf() * 360.0, 0)
			c.position = Vector3(randf_range(-0.02, 0.02), 0.02 + i * 0.038, randf_range(-0.02, 0.02))
			c.scale = Vector3.ONE * 0.62
		FX.pop_in(_coin_stack, 0.45)
		var bob := _coin_stack.create_tween().set_loops()
		bob.tween_property(_coin_stack, "position:y", _coin_stack.position.y + 0.05, 0.6).set_trans(Tween.TRANS_SINE)
		bob.tween_property(_coin_stack, "position:y", _coin_stack.position.y, 0.6).set_trans(Tween.TRANS_SINE)


func collect() -> int:
	var amount := coins
	coins = 0
	if _coin_stack:
		_coin_stack.queue_free()
		_coin_stack = null
	return amount
