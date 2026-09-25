class_name Station
extends Node3D
## A cooking station. Tap once to start cooking; the dish appears on the
## counter when done and waits there until the chef picks it up.

signal became_ready(station: Station)

enum State { IDLE, COOKING, READY }

@export var station_id := "coffee"
@export var dish_id := "latte"

var state := State.IDLE
var unlocked := true
var progress := 0.0
var _cook_time := 1.0
var _model: Node3D
var _slot: Node3D
var _cooking: Node3D
var _dish: Node3D
var _bubble: Bubble
var _steam: CPUParticles3D


func _ready() -> void:
	_model = get_node("Model")
	CozyLook.stylize(_model)
	_slot = _model.find_child("Slot", true, false)
	_cooking = _model.find_child("Cooking", true, false)
	if _cooking:
		_cooking.visible = false
	var top := _model.find_child("Top", true, false) as Node3D
	_bubble = Bubble.new(0.62, false)
	add_child(_bubble)
	_bubble.position = top.position if top else Vector3(0, 1.5, 0)
	CozyLook.add_blob(self, Vector2(1.25, 1.0), Vector3(0, 0, 0.12))
	_steam = FX.make_steam()
	add_child(_steam)
	_steam.position = Vector3(0, 1.0, 0.0)


func set_unlocked(value: bool) -> void:
	unlocked = value
	CozyLook.ghostify(_model, not value)
	if not value:
		reset()


func interaction_point() -> Vector3:
	return global_position + Vector3(0, 0, 0.73)


func tap_anchor() -> Vector3:
	return global_position + Vector3(0, 0.8, 0.2)


func start_cooking() -> bool:
	if not unlocked or state != State.IDLE:
		return false
	state = State.COOKING
	progress = 0.0
	_cook_time = GameState.cook_time(dish_id)
	if _cooking:
		_cooking.visible = true
	_steam.emitting = true
	_bubble.set_icon(IconFactory.get_icon(dish_id))
	_bubble.set_ring_visible(true)
	_bubble.set_progress(0.0, Color("f4a259"))
	_bubble.pop_in()
	FX.squash(_model, 0.12)
	Audio.play("cook")
	return true


func take_dish() -> String:
	if state != State.READY:
		return ""
	reset()
	Audio.play("pickup", 1.1)
	return dish_id


func time_left() -> float:
	return (1.0 - progress) * _cook_time if state == State.COOKING else 0.0


func _process(delta: float) -> void:
	if state != State.COOKING:
		return
	progress += delta / _cook_time
	_bubble.set_progress(progress, Color("f4a259"))
	if progress >= 1.0:
		_finish()


func _finish() -> void:
	state = State.READY
	if _cooking:
		_cooking.visible = false
	_steam.emitting = false
	_dish = Dishes.spawn(dish_id)
	_slot.add_child(_dish)
	FX.pop_in(_dish)
	_bubble.set_ring_visible(true)
	_bubble.set_progress(1.0, Color("9ed9b8"))
	_bubble.pulse()
	FX.sparkles(get_parent(), _slot.global_position + Vector3(0, 0.2, 0))
	Audio.play("ready")
	became_ready.emit(self)


func reset() -> void:
	state = State.IDLE
	progress = 0.0
	if _cooking:
		_cooking.visible = false
	if _steam:
		_steam.emitting = false
	if _dish:
		_dish.queue_free()
		_dish = null
	if _bubble:
		_bubble.pop_out()
