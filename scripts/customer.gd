class_name Customer
extends Critter
## A guest: walks in, sits, orders, waits (patience ring), eats, pays, leaves.

signal left(customer: Customer, happy: bool)

enum State { ARRIVING, THINKING, WAITING, EATING, LEAVING }

const KINDS := {
	"bunny": {"name": "Pip", "scene": preload("res://assets/models/cust_bunny.glb")},
	"bear": {"name": "Bruno", "scene": preload("res://assets/models/cust_bear.glb")},
	"frog": {"name": "Lily", "scene": preload("res://assets/models/cust_frog.glb")},
	"chick": {"name": "Sunny", "scene": preload("res://assets/models/cust_chick.glb")},
	"panda": {"name": "Bao", "scene": preload("res://assets/models/cust_panda.glb")},
}
const EAT_TIME := 3.6

var kind := "bunny"
var display_name := "Pip"
var state := State.ARRIVING
var seat: Seat
var order := ""
var patience_max := 40.0
var patience := 40.0
var stars := 5.0

var _timer := 0.0
var _bubble: Bubble
var _dish: Node3D
var _exit_path := PackedVector3Array()


func setup(kind_id: String, target_seat: Seat, dish: String, patience_seconds: float, entry: PackedVector3Array, exit: PackedVector3Array) -> void:
	kind = kind_id
	display_name = KINDS[kind]["name"]
	seat = target_seat
	seat.occupant = self
	order = dish
	patience_max = patience_seconds
	patience = patience_seconds
	_exit_path = exit
	load_model(KINDS[kind]["scene"])
	speed = randf_range(1.35, 1.6)
	_bubble = Bubble.new(0.66, true)
	add_child(_bubble)
	_bubble.position = Vector3(0, 1.55, 0)
	_bubble.set_icon(IconFactory.get_icon(order))
	set_path(entry)


func is_waiting() -> bool:
	return state == State.WAITING


func tap_anchor() -> Vector3:
	return global_position + Vector3(0, 0.75, 0)


func _process(delta: float) -> void:
	super._process(delta)
	match state:
		State.ARRIVING:
			if step_path(delta):
				_sit_down()
		State.THINKING:
			_timer -= delta
			if _timer <= 0.0:
				_start_waiting()
		State.WAITING:
			patience -= delta
			var k := patience / patience_max
			_bubble.set_progress(k, _mood_color(k))
			nervous = clampf((0.3 - k) / 0.3, 0.0, 1.0)
			if patience <= 0.0:
				_leave_angry()
		State.EATING:
			_timer -= delta
			if _timer <= 0.0:
				_pay_and_leave()
		State.LEAVING:
			if step_path(delta):
				left.emit(self, stars >= 3.0)
				queue_free()


func _sit_down() -> void:
	var t := hop_to(seat.sit_position(), seat.sit_yaw())
	state = State.THINKING
	_timer = 1.4 + randf() * 0.8
	t.tween_callback(func(): Audio.play("tap", 1.4, -8.0))


func _start_waiting() -> void:
	state = State.WAITING
	_bubble.set_ring_visible(true)
	_bubble.set_progress(1.0, _mood_color(1.0))
	_bubble.pop_in()
	Audio.play("pickup", 1.5, -4.0)


func serve(dish: String) -> bool:
	if state != State.WAITING or dish != order:
		_bubble.wobble()
		return false
	var k := patience / patience_max
	stars = 5.0 if k > 0.6 else 4.5 if k > 0.4 else 4.0 if k > 0.25 else 3.0 if k > 0.1 else 2.5
	state = State.EATING
	nervous = 0.0
	eating = true
	_timer = EAT_TIME
	_bubble.pop_out()
	_dish = Dishes.spawn(order)
	get_parent().add_child(_dish)
	_dish.global_position = seat.dish_position()
	_dish.rotation.y = randf() * TAU
	FX.pop_in(_dish)
	FX.emote(get_parent(), global_position + Vector3(0, 1.45, 0), "heart")
	happy_jump()
	return true


func tip_fraction() -> float:
	return clampf(patience / patience_max, 0.0, 1.0)


func _pay_and_leave() -> void:
	eating = false
	if _dish:
		_dish.queue_free()
		_dish = null
	var price := GameState.dish_price(order)
	var tip := roundi(price * (0.1 + 0.45 * tip_fraction()) * GameState.tip_multiplier())
	seat.leave_coins(price + tip)
	FX.float_text(get_parent(), seat.dish_position() + Vector3(0, 0.3, 0), "+%d" % (price + tip))
	Audio.play("coin", 1.15, -3.0)
	GameState.record_rating(stars)
	_leave()


func _leave_angry() -> void:
	stars = 1.0
	nervous = 0.0
	_bubble.pop_out()
	FX.emote(get_parent(), global_position + Vector3(0, 1.5, 0), "cloud")
	Audio.play("grumble")
	GameState.record_rating(1.0)
	_leave()


func _leave() -> void:
	state = State.LEAVING
	seat.occupant = null
	var t := hop_to(seat.approach_point(), seat.sit_yaw() + PI, 0.3)
	t.tween_callback(func(): set_path(_exit_path))


func _mood_color(k: float) -> Color:
	if k > 0.5:
		return Color("7fcf9f")
	if k > 0.25:
		return Color("f7c948")
	return Color("e8665a")
