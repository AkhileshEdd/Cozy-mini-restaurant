extends Node3D
## Game controller: runs the day cycle, spawns guests, turns taps into chef
## tasks and applies shop upgrades to the café.

enum Phase { LOADING, PREP, OPEN, CLOSING, RESULTS }

const CUSTOMER_KINDS := ["bunny", "bear", "frog", "chick", "panda"]
const DOOR_INSIDE := Vector3(2.55, 0.0, 1.95)
const DOOR_OUTSIDE := Vector3(3.7, 0.0, 1.95)
const STREET := Vector3(6.6, 0.0, 1.85)
const CHEF_START := Vector3(0.0, 0.0, -2.45)
const OPEN_HOUR := 9.0
const CLOSE_HOUR := 17.0
## Horizontal field of view tuned for 9:16 phones, and the smallest vertical one we accept.
const H_FOV := 31.0
const MIN_V_FOV := 52.0

@onready var camera: Camera3D = $Camera
@onready var kitchen: Node3D = $Kitchen
@onready var dining: Node3D = $Dining
@onready var decor: Node3D = $Decor
@onready var actors: Node3D = $Actors
@onready var hud: Hud = $Hud

var grid := FloorGrid.new()
var chef: Chef
var stations: Dictionary = {}
var tables: Array[CafeTable] = []
var seats: Array[Seat] = []
var customers: Array[Customer] = []
var phase := Phase.LOADING
var day_time := 0.0
var spawn_timer := 0.0
var stats := {}

var _task_id := 0
var _hint_timer := 0.0
var _hands_full_warned := false
var _hour_hand: Node3D
var _minute_hand: Node3D
var _string_lights: Node3D


func _ready() -> void:
	CozyLook.stylize($Cafe)
	CozyLook.stylize(decor)
	CozyLook.stylize($Outside)
	_add_static_blobs()
	for s in kitchen.get_children():
		if s is Station:
			stations[s.station_id] = s
	for t in dining.get_children():
		if t is CafeTable:
			tables.append(t)
			seats.append_array(t.seats)
	_hour_hand = decor.find_child("HourHand", true, false)
	_minute_hand = decor.find_child("MinuteHand", true, false)
	_string_lights = $Cafe.find_child("Lights", true, false)
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()

	var icons := IconFactory.new()
	add_child(icons)
	await icons.build()
	hud.refresh_icons()

	chef = Chef.new()
	chef.name = "Chef"
	chef.grid = grid
	chef.performer = _perform
	actors.add_child(chef)
	chef.global_position = CHEF_START
	chef.carrying_changed.connect(func(d: Array[String]):
		hud.set_tray(d, GameState.carry_capacity())
		_hands_full_warned = false)

	hud.open_pressed.connect(_open_day)
	hud.next_day_pressed.connect(_prepare_day)
	hud.buy_pressed.connect(_buy)
	hud.pause_changed.connect(func(p: bool): get_tree().paused = p)
	hud.reset_confirmed.connect(_reset_progress)
	hud.set_coins(GameState.coins, false)
	hud.set_rating(GameState.rating)
	_apply_upgrades(false)
	_prepare_day()


func _add_static_blobs() -> void:
	for n in $Outside.get_children():
		var d := 1.9 if n.name.begins_with("Tree") else 1.0 if n.name.begins_with("Bush") else 0.55
		CozyLook.add_blob(n, Vector2(d, d))
	for n in decor.get_node("Plants").get_children():
		if n.name.begins_with("Plant"):
			CozyLook.add_blob(n, Vector2(0.8, 0.8))
	CozyLook.add_blob(decor.get_node("MenuBoard"), Vector2(0.7, 0.6))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		hud.open_pause()
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if phase == Phase.OPEN or phase == Phase.CLOSING:
			hud.open_pause()
		GameState.save_game()


func _fit_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var v_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(H_FOV) * 0.5) / aspect))
	if v_fov >= MIN_V_FOV:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = H_FOV
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = MIN_V_FOV


# -- day cycle -------------------------------------------------------------------

func _prepare_day() -> void:
	phase = Phase.PREP
	day_time = 0.0
	for c in customers:
		c.queue_free()
	customers.clear()
	for s in seats:
		s.occupant = null
		s.collect()
	for st in stations.values():
		(st as Station).reset()
	chef.clear_tasks()
	chef.drop_all()
	chef.global_position = CHEF_START
	chef.yaw_target = 0.0
	_update_clock(0.0)
	hud.show_day_card(GameState.day, GameState.menu())


func _open_day() -> void:
	phase = Phase.OPEN
	stats = {"served": 0, "earned": 0, "grumpy": 0, "stars_sum": 0.0, "stars_n": 0}
	spawn_timer = 1.2
	Audio.play("open")
	hud.toast("We're open!", CozyTheme.MINT_INK)


func _end_day() -> void:
	phase = Phase.RESULTS
	var leftover := 0
	for s in seats:
		leftover += s.collect()
	if leftover > 0:
		GameState.add_coins(leftover)
		stats["earned"] += leftover
	chef.clear_tasks()
	chef.drop_all()
	for st in stations.values():
		(st as Station).reset()
	var finished_day := GameState.day
	GameState.day += 1
	GameState.save_game()
	hud.set_coins(GameState.coins)
	Audio.play("close")
	var n: int = stats["stars_n"]
	hud.show_results({
		"day": finished_day,
		"stars": (stats["stars_sum"] / n) if n > 0 else 3.0,
		"served": stats["served"],
		"earned": stats["earned"],
		"grumpy": stats["grumpy"],
	})


func _process(delta: float) -> void:
	if phase == Phase.OPEN or phase == Phase.CLOSING:
		var length := GameState.day_length()
		if phase == Phase.OPEN:
			day_time += delta
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = GameState.spawn_interval() * randf_range(0.8, 1.25) if _try_spawn() else 1.0
			if day_time >= length:
				phase = Phase.CLOSING
				hud.toast("Closing time!")
				Audio.play("door", 0.8)
		elif customers.is_empty():
			_end_day()
			return
		_update_clock(day_time / length)
	_hint_timer -= delta
	if _hint_timer <= 0.0:
		_hint_timer = 0.4
		hud.set_hint(_hint())
		hud.set_rating(GameState.rating)


func _update_clock(frac: float) -> void:
	frac = clampf(frac, 0.0, 1.0)
	var hours := lerpf(OPEN_HOUR, CLOSE_HOUR, frac)
	var h := int(hours)
	var m := int((hours - h) * 60.0) / 10 * 10
	hud.set_day(GameState.day, frac, "%d:%02d" % [h, m])
	if _hour_hand:
		_hour_hand.rotation.z = -fmod(hours, 12.0) / 12.0 * TAU
	if _minute_hand:
		_minute_hand.rotation.z = -(hours - floorf(hours)) * TAU


# -- guests ------------------------------------------------------------------------

func _try_spawn() -> bool:
	var free: Array[Seat] = []
	for s in seats:
		if s.is_free():
			free.append(s)
	if free.is_empty():
		return false
	var seat: Seat = free.pick_random()
	var present := customers.map(func(c: Customer): return c.kind)
	var kinds := CUSTOMER_KINDS.filter(func(k: String): return not present.has(k))
	if kinds.is_empty():
		kinds = CUSTOMER_KINDS.duplicate()
	var c := Customer.new()
	actors.add_child(c)
	c.global_position = STREET + Vector3(0, 0, randf_range(-0.2, 0.2))
	var entry := PackedVector3Array([DOOR_OUTSIDE, DOOR_INSIDE])
	entry.append_array(grid.find_path(DOOR_INSIDE, seat.approach_point()))
	var exit := grid.find_path(seat.approach_point(), DOOR_INSIDE)
	exit.append(DOOR_OUTSIDE)
	exit.append(STREET)
	c.setup(kinds.pick_random(), seat, GameState.menu().pick_random(), GameState.patience(), entry, exit)
	c.left.connect(_on_customer_left)
	customers.append(c)
	Audio.play("door", 1.0, -6.0)
	return true


func _on_customer_left(c: Customer, happy: bool) -> void:
	customers.erase(c)
	if stats.is_empty():
		return
	stats["stars_sum"] += c.stars
	stats["stars_n"] += 1
	if not happy:
		stats["grumpy"] += 1


# -- input -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.OPEN and phase != Phase.CLOSING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)
		get_viewport().set_input_as_handled()


func _on_tap(pos: Vector2) -> void:
	var task := _pick(pos)
	if task.is_empty():
		var hit = _floor_point(pos)
		if hit == null:
			return
		var p: Vector3 = grid.clamp_to_floor(hit)
		if not grid.is_open(p):
			return
		task = {"type": "move", "point": p}
	_task_id += 1
	task["id"] = _task_id
	if chef.enqueue(task):
		Audio.play("tap")
		var target = task.get("target")
		if target is Station:
			FX.squash(target, 0.06, 0.2)
	else:
		Audio.play("nope")


## Screen-space picking: the nearest interactive thing within a finger-sized radius.
func _pick(pos: Vector2) -> Dictionary:
	var best := {}
	var best_score := 1.0
	var candidates: Array = []
	for c in customers:
		if c.is_waiting():
			candidates.append([c.tap_anchor(), 100.0, {"type": "serve", "target": c, "point": c.seat.approach_point(), "face": c.global_position}])
	for s in seats:
		if s.coins > 0:
			candidates.append([s.tap_anchor(), 85.0, {"type": "collect", "target": s, "point": s.approach_point(), "face": s.dish_position()}])
	for st in stations.values():
		if st.unlocked:
			candidates.append([st.tap_anchor(), 105.0, {"type": "station", "target": st, "point": st.interaction_point(), "face": st.global_position}])
	for cand in candidates:
		var anchor: Vector3 = cand[0]
		if camera.is_position_behind(anchor):
			continue
		var d := camera.unproject_position(anchor).distance_to(pos) / float(cand[1])
		if d < best_score:
			best_score = d
			best = cand[2]
	return best


func _floor_point(pos: Vector2):
	var from := camera.project_ray_origin(pos)
	var dir := camera.project_ray_normal(pos)
	if absf(dir.y) < 0.001:
		return null
	var t := -from.y / dir.y
	return from + dir * t if t > 0.0 else null


## Called by the chef on arrival. Returns seconds to wait before being asked again, or 0 when done.
func _perform(task: Dictionary) -> float:
	match task["type"]:
		"station":
			var st: Station = task["target"]
			match st.state:
				Station.State.READY:
					if chef.can_carry():
						chef.add_dish(st.take_dish())
						FX.squash(chef.model, 0.12, 0.2)
						return 0.0
					if not _hands_full_warned:
						_hands_full_warned = true
						hud.toast("Hands full!")
						Audio.play("nope")
					return 0.0
				Station.State.IDLE:
					st.start_cooking()
					FX.squash(chef.model, 0.1, 0.2)
					return 0.2 if chef.queue.is_empty() else 0.0
				Station.State.COOKING:
					if chef.queue.is_empty() or st.time_left() < 0.8:
						return 0.15
			return 0.0
		"serve":
			var c: Customer = task["target"]
			if not is_instance_valid(c) or not c.is_waiting():
				return 0.0
			if chef.carrying.has(c.order):
				chef.remove_dish(c.order)
				c.serve(c.order)
				Audio.play("serve")
				FX.sparkles(actors, c.global_position + Vector3(0, 1.2, 0))
				stats["served"] += 1
				GameState.total_served += 1
			else:
				c.serve("")
				Audio.play("nope")
				hud.toast("%s wants %s" % [c.display_name, GameState.dish_name(c.order).to_lower()], CozyTheme.INK)
			return 0.0
		"collect":
			var s: Seat = task["target"]
			if s.coins > 0:
				var amount := s.collect()
				stats["earned"] += amount
				var screen := camera.unproject_position(s.dish_position())
				Audio.play("sparkle", 1.2, -4.0)
				hud.fly_coins(screen, amount, func():
					GameState.add_coins(amount)
					hud.set_coins(GameState.coins)
					Audio.play("coin"))
			return 0.0
	return 0.0


func _hint() -> String:
	match phase:
		Phase.PREP:
			return "Tap Open café to welcome today's guests!"
		Phase.RESULTS, Phase.LOADING:
			return ""
	var waiting: Array[Customer] = []
	for c in customers:
		if c.is_waiting():
			waiting.append(c)
	for c in waiting:
		if chef.carrying.has(c.order):
			return "Tap %s to serve the %s." % [c.display_name, GameState.dish_name(c.order).to_lower()]
	for st in stations.values():
		if st.state == Station.State.READY:
			return "%s is ready! Tap the %s to pick it up." % [GameState.dish_name(st.dish_id), GameState.STATION_NAMES[st.station_id]]
	for c in waiting:
		var st: Station = stations[GameState.DISHES[c.order]["station"]]
		if st.state == Station.State.IDLE:
			return "%s wants %s. Tap the %s to cook." % [c.display_name, GameState.dish_name(c.order).to_lower(), GameState.STATION_NAMES[st.station_id]]
	for s in seats:
		if s.coins > 0:
			return "Tap the coins to tidy the table."
	if phase == Phase.CLOSING:
		return "Closing time. Finish the last orders!"
	if not waiting.is_empty():
		return "Cooking... Tap the station again to grab the dish."
	return "Guests are on their way..."


# -- shop ----------------------------------------------------------------------------

func _buy(id: String) -> void:
	if GameState.buy(id):
		Audio.play("buy")
		hud.set_coins(GameState.coins)
		_apply_upgrades(true)
	else:
		Audio.play("nope")
	hud.refresh_shop()


func _apply_upgrades(animate: bool) -> void:
	for st in stations.values():
		var was: bool = st.unlocked
		st.set_unlocked(GameState.is_station_unlocked(st.station_id))
		if animate and st.unlocked and not was:
			FX.pop_in(st.get_node("Model"), 0.5)
			FX.sparkles(kitchen, st.global_position + Vector3(0, 1.0, 0.3), 30)
	for i in tables.size():
		tables[i].set_unlocked(i < GameState.tables_unlocked(), animate)
	var plants := decor.get_node_or_null("Plants") as Node3D
	if plants:
		_toggle_decor(plants, GameState.level("plants") > 0, animate)
	var rug := decor.get_node_or_null("Rug") as Node3D
	if rug:
		_toggle_decor(rug, GameState.level("rug") > 0, animate)
	if _string_lights:
		_toggle_decor(_string_lights, GameState.level("lights") > 0, animate)
	if chef:
		hud.set_tray(chef.carrying, GameState.carry_capacity())
	_rebuild_grid()


func _toggle_decor(node: Node3D, on: bool, animate: bool) -> void:
	var was := node.visible
	node.visible = on
	if animate and on and not was:
		for c in node.get_children():
			if c is Node3D:
				FX.pop_in(c, 0.5)
		FX.sparkles(decor, node.global_position + Vector3(0, 1.0, 0), 24)


func _rebuild_grid() -> void:
	grid.clear()
	for t in tables:
		for o in t.obstacle_points():
			grid.block_circle(o[0], o[1])
	for n in get_tree().get_nodes_in_group("obstacle"):
		if (n as Node3D).is_visible_in_tree():
			grid.block_circle(n.global_position, float(n.get_meta("radius", 0.35)))


func _reset_progress() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().reload_current_scene()
