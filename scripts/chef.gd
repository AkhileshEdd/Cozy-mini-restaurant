class_name Chef
extends Critter
## Chef Mochi. Taps become tasks in a short queue; the chef walks to each one
## and asks the game what to do there via `performer`.

signal carrying_changed(dishes: Array[String])

const MAX_QUEUE := 5
const SCENE := preload("res://assets/models/chef_cat.glb")
const TRAY := preload("res://assets/models/tray.glb")

## Callable(task: Dictionary) -> float. Return 0 when the task is done, or a
## number of seconds to wait before asking again (e.g. while food finishes).
var performer: Callable
var grid: FloorGrid
var queue: Array[Dictionary] = []
var current: Dictionary = {}
var carrying: Array[String] = []

var _wait := 0.0
var _idle := 0.0
var _tray: Node3D
var _tray_items: Array[Node3D] = []
var _markers: Dictionary = {}


func _ready() -> void:
	load_model(SCENE)
	speed = GameState.chef_speed()
	var hold: Node3D = parts.get("Hold")
	_tray = TRAY.instantiate()
	CozyLook.stylize(_tray, true)
	hold.add_child(_tray)
	_tray.position = Vector3(0, -0.02, 0.02)
	_tray.visible = false


func enqueue(task: Dictionary) -> bool:
	if queue.size() + (0 if current.is_empty() else 1) >= MAX_QUEUE:
		return false
	for t in queue:
		if t.get("target") == task.get("target") and t["type"] == task["type"]:
			return false
	queue.append(task)
	_add_marker(task)
	return true


func clear_tasks() -> void:
	for t in queue:
		_remove_marker(t)
	queue.clear()
	if not current.is_empty():
		_remove_marker(current)
	current = {}
	set_path(PackedVector3Array())
	_wait = 0.0


func can_carry() -> bool:
	return carrying.size() < GameState.carry_capacity()


func add_dish(dish: String) -> void:
	carrying.append(dish)
	_refresh_tray()


func remove_dish(dish: String) -> bool:
	var i := carrying.find(dish)
	if i < 0:
		return false
	carrying.remove_at(i)
	_refresh_tray()
	return true


func drop_all() -> void:
	carrying.clear()
	_refresh_tray()


func _process(delta: float) -> void:
	super._process(delta)
	speed = GameState.chef_speed()
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_perform()
		return
	if current.is_empty():
		if queue.is_empty():
			_idle += delta
			if _idle > 1.6:
				yaw_target = 0.0
			return
		_idle = 0.0
		current = queue.pop_front()
		set_path(grid.find_path(global_position, current["point"]))
		if path.is_empty():
			_arrive()
		return
	if walking and step_path(delta):
		_arrive()


func _arrive() -> void:
	if current.has("face"):
		face(current["face"])
	_perform()


func _perform() -> void:
	var again := 0.0
	if performer.is_valid():
		again = performer.call(current)
	if again > 0.0:
		_wait = again
		return
	_remove_marker(current)
	current = {}


func _refresh_tray() -> void:
	for n in _tray_items:
		n.queue_free()
	_tray_items.clear()
	holding = not carrying.is_empty()
	_tray.visible = holding
	var offsets := [Vector3(0, 0, 0)]
	if carrying.size() == 2:
		offsets = [Vector3(-0.085, 0, 0.0), Vector3(0.085, 0, 0.0)]
	elif carrying.size() >= 3:
		offsets = [Vector3(-0.09, 0, -0.05), Vector3(0.09, 0, -0.05), Vector3(0, 0, 0.09)]
	for i in carrying.size():
		var d := Dishes.spawn(carrying[i])
		_tray.add_child(d)
		d.position = offsets[i] + Vector3(0, 0.03, 0)
		d.scale = Vector3.ONE * 0.62
		_tray_items.append(d)
	if holding:
		FX.squash(_tray, 0.2, 0.25)
	carrying_changed.emit(carrying)


func _add_marker(task: Dictionary) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.2
	mesh.outer_radius = 0.27
	mesh.rings = 24
	mesh.ring_segments = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = m
	ring.mesh = mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = Vector3(task["point"].x, 0.03, task["point"].z)
	ring.scale = Vector3(1, 0.15, 1)
	var t := ring.create_tween().set_loops()
	t.tween_property(ring, "scale", Vector3(1.2, 0.15, 1.2), 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(ring, "scale", Vector3(0.9, 0.15, 0.9), 0.4).set_trans(Tween.TRANS_SINE)
	_markers[_task_key(task)] = ring


func _remove_marker(task: Dictionary) -> void:
	var key := _task_key(task)
	if _markers.has(key):
		(_markers[key] as Node).queue_free()
		_markers.erase(key)


func _task_key(task: Dictionary) -> String:
	return "%s:%s" % [task.get("type", ""), str(task.get("id", 0))]
