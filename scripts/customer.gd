class_name Customer
extends Critter
## A guest: walks in, sits, orders one or two dishes, waits (patience ring),
## eats, pays and leaves. Each species has a trait (see GameState.GUESTS).

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
## Dishes still to be served, first one shown in the bubble.
var orders: Array[String] = []
var served: Array[String] = []
var patience_max := 40.0
var patience := 40.0
var stars := 5.0
## Café XP this guest earned (set when they pay).
var xp := 0

var _timer := 0.0
var _bubble: Bubble
var _dishes: Array[Node3D] = []
var _exit_path := PackedVector3Array()


func setup(kind_id: String, target_seat: Seat, dishes: Array[String], patience_seconds: float, entry: PackedVector3Array, exit: PackedVector3Array) -> void:
	kind = kind_id
	display_name = KINDS[kind]["name"]
	seat = target_seat
	seat.occupant = self
	orders = dishes.duplicate()
	patience_max = patience_seconds * float(trait_info().get("patience", 1.0)) * (1.35 if orders.size() > 1 else 1.0) * GameState.friend_patience(kind)
	patience = patience_max
	_exit_path = exit
	load_model(KINDS[kind]["scene"])
	speed = randf_range(1.35, 1.6)
	_bubble = Bubble.new(0.66, true)
	add_child(_bubble)
	_bubble.position = Vector3(0, 1.55, 0)
	_refresh_bubble()
	set_path(entry)


func trait_info() -> Dictionary:
	return GameState.guest(kind)


func is_waiting() -> bool:
	return state == State.WAITING


func is_combo() -> bool:
	return orders.size() + served.size() > 1


func wants(dish: String) -> bool:
	return orders.has(dish)


## The dish shown first in the bubble (or "" once everything is served).
func current_order() -> String:
	return orders[0] if not orders.is_empty() else ""


## Human-readable order, e.g. "latte + strawberry cake".
func order_text() -> String:
	return " + ".join(PackedStringArray(orders.map(func(d: String): return GameState.dish_name(d).to_lower())))


func _refresh_bubble() -> void:
	if orders.is_empty():
		return
	var second: Texture2D = IconFactory.get_icon(orders[1]) if orders.size() > 1 else null
	_bubble.set_icon(IconFactory.get_icon(orders[0]), second)


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
	t.tween_callback(func():
		Audio.play("tap", 1.4, -8.0)
		FX.float_text(get_parent(), global_position + Vector3(0, 1.35, 0), trait_info().get("trait", ""), Color("6b5048"), 44))


func _start_waiting() -> void:
	state = State.WAITING
	_bubble.set_ring_visible(true)
	_bubble.set_progress(1.0, _mood_color(1.0))
	_bubble.pop_in()
	Audio.play("pickup", 1.5, -4.0)


## Serve one dish. Returns true if the guest wanted it. The guest starts
## eating once every dish of the order has arrived.
func serve(dish: String) -> bool:
	if state != State.WAITING or not orders.has(dish):
		_bubble.wobble()
		return false
	orders.erase(dish)
	served.append(dish)
	var d := Dishes.spawn(dish)
	get_parent().add_child(d)
	var spread := 0.0 if not is_combo() else (-0.11 if served.size() == 1 else 0.11)
	d.global_position = seat.dish_position() + Vector3(0, 0, spread)
	d.rotation.y = randf() * TAU
	FX.pop_in(d)
	_dishes.append(d)
	if dish == trait_info().get("fav", ""):
		FX.float_text(get_parent(), global_position + Vector3(0, 1.4, 0), "Favourite!", Color("e07a8c"), 52)
	if not orders.is_empty():
		_refresh_bubble()
		_bubble.wobble()
		happy_jump()
		return true
	var k := patience / patience_max
	stars = 5.0 if k > 0.6 else 4.5 if k > 0.4 else 4.0 if k > 0.25 else 3.0 if k > 0.1 else 2.5
	state = State.EATING
	nervous = 0.0
	eating = true
	_timer = EAT_TIME + (1.2 if is_combo() else 0.0)
	_bubble.pop_out()
	FX.emote(get_parent(), global_position + Vector3(0, 1.45, 0), "heart")
	happy_jump()
	return true


func tip_fraction() -> float:
	return clampf(patience / patience_max, 0.0, 1.0)


func _pay_and_leave() -> void:
	eating = false
	for d in _dishes:
		d.queue_free()
	_dishes.clear()
	var price := 0
	for dish in served:
		price += GameState.dish_price(dish)
	if is_combo():
		price = roundi(price * GameState.COMBO_BONUS)
	var tip_rate: float = (0.1 + 0.45 * tip_fraction()) * GameState.tip_multiplier() * float(trait_info().get("tip", 1.0)) * GameState.friend_tip(kind)
	var tip := roundi(price * tip_rate)
	seat.leave_coins(price + tip)
	FX.float_text(get_parent(), seat.dish_position() + Vector3(0, 0.3, 0), ("Combo! +%d" if is_combo() else "+%d") % (price + tip))
	Audio.play("coin", 1.15, -3.0)
	var critic: bool = trait_info().get("critic", false)
	GameState.record_rating(stars)
	if critic:
		GameState.record_rating(stars)
	xp = roundi(stars) * (2 if critic else 1) + (2 if is_combo() else 0)
	_leave()


func _leave_angry() -> void:
	stars = 1.0
	nervous = 0.0
	xp = 0
	_bubble.pop_out()
	for d in _dishes:
		d.queue_free()
	_dishes.clear()
	FX.emote(get_parent(), global_position + Vector3(0, 1.5, 0), "cloud")
	Audio.play("grumble")
	GameState.record_rating(1.0)
	if trait_info().get("critic", false):
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
