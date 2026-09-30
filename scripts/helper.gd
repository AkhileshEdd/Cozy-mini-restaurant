class_name Helper
extends Critter
## A hired helper. Pepper the penguin (waiter) carries finished dishes to the
## guests who want them; Nibbles the hamster (busser) collects tips from tables.
## Helpers never take a job the chef already has queued.

const MODELS := {
	"waiter": preload("res://assets/models/helper_penguin.glb"),
	"busser": preload("res://assets/models/helper_hamster.glb"),
}
const TRAY := preload("res://assets/models/tray.glb")
const DROP_AFTER := 20.0

var role := "waiter"
var game: CafeGame
var home := Vector3.ZERO
var carrying := ""
## What this helper is heading for: {"type", "target", "point"}
var job: Dictionary = {}

var _think := 0.0
var _held_for := 0.0
var _tray: Node3D
var _dish: Node3D


func setup(helper_role: String, cafe: CafeGame, home_point: Vector3) -> void:
	role = helper_role
	game = cafe
	home = home_point
	load_model(MODELS[role])
	speed = 1.9 if role == "waiter" else 1.7
	if role == "waiter":
		_tray = TRAY.instantiate()
		CozyLook.stylize(_tray, true)
		(parts["Hold"] as Node3D).add_child(_tray)
		_tray.position = Vector3(0, -0.02, 0.02)
		_tray.visible = false


func reset_to_home() -> void:
	_drop()
	job = {}
	set_path(PackedVector3Array())
	global_position = home
	yaw_target = 0.0


func is_targeting(obj: Object) -> bool:
	return not job.is_empty() and job.get("target") == obj


func _process(delta: float) -> void:
	super._process(delta)
	if game == null or not game.is_open():
		return
	if carrying != "":
		_held_for += delta
		if _held_for > DROP_AFTER and job.is_empty():
			_drop()
	if not job.is_empty():
		if walking:
			if step_path(delta):
				_arrive()
		else:
			_arrive()
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.3
	_choose_job()


func _choose_job() -> void:
	if role == "busser":
		for seat in game.seats:
			if seat.coins > 0 and not game.chef_targets(seat) and not game.helper_targets(seat, self):
				_go({"type": "collect", "target": seat, "point": seat.approach_point(), "face": seat.dish_position()})
				return
	elif carrying != "":
		var c := _guest_for(carrying)
		if c:
			_go({"type": "serve", "target": c, "point": c.seat.approach_point(), "face": c.global_position})
			return
	else:
		for st in game.stations.values():
			if st.state != Station.State.READY or game.chef_targets(st) or game.helper_targets(st, self):
				continue
			if _guest_for(st.dish_id) != null:
				_go({"type": "pickup", "target": st, "point": st.interaction_point(), "face": st.global_position})
				return
	if global_position.distance_to(home) > 0.4:
		_go({"type": "home", "target": null, "point": home})


## A waiting guest who wants `dish` and that nobody is already bringing it to.
func _guest_for(dish: String) -> Customer:
	for c in game.customers:
		if c.is_waiting() and c.wants(dish) and not game.chef.carrying.has(dish) and not game.helper_targets(c, self):
			return c
	for c in game.customers:
		if c.is_waiting() and c.wants(dish) and not game.helper_targets(c, self):
			return c
	return null


func _go(next: Dictionary) -> void:
	job = next
	set_path(game.grid.find_path(global_position, job["point"]))


func _arrive() -> void:
	var done := job
	job = {}
	if done.has("face"):
		face(done["face"])
	match done["type"]:
		"pickup":
			var st: Station = done["target"]
			if st.state == Station.State.READY:
				carrying = st.take_dish()
				_held_for = 0.0
				_show_dish()
				FX.squash(model, 0.12, 0.2)
		"serve":
			var c: Customer = done["target"]
			if is_instance_valid(c) and c.is_waiting() and c.wants(carrying):
				game.serve_customer(c, carrying)
				carrying = ""
				_show_dish()
		"collect":
			var seat: Seat = done["target"]
			if seat.coins > 0:
				game.collect_seat(seat)
				FX.squash(model, 0.12, 0.2)
	_think = 0.1


func _drop() -> void:
	carrying = ""
	_show_dish()


func _show_dish() -> void:
	if _dish:
		_dish.queue_free()
		_dish = null
	holding = carrying != ""
	if _tray:
		_tray.visible = holding
		if holding:
			_dish = Dishes.spawn(carrying)
			_tray.add_child(_dish)
			_dish.position = Vector3(0, 0.03, 0)
			_dish.scale = Vector3.ONE * 0.62
