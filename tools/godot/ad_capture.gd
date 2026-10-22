extends Node
## Records gameplay shots for the video ad with Godot's Movie Maker.
##
##   xvfb-run -s "-screen 0 1200x2000x24" godot --rendering-driver opengl3 --path . \
##     --resolution 1080x1920 --fixed-fps 30 --write-movie build/ad/capture.avi \
##     res://tools/godot/ad_capture.tscn -- --out=build/ad
##
## Every frame is written to the movie; `shots.json` in --out lists which
## frames belong to which shot, so the warm-up can be cut away.
## Overwrites (then resets) the local save, like the smoke test.

const MAIN := preload("res://scenes/main.tscn")
const FPS := 30.0

var main: CafeGame
var out_dir := "build/ad"
var frame := 0
var shots := {}
var _follow: Node3D
var _follow_dist := 0.0
var _cam_target := Vector3.ZERO
var _cam_dist := 0.0
var _cam_on := false
var _default_cam := Transform3D()
var _bot_on := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_stage_progress()
	main = MAIN.instantiate()
	add_child(main)
	while main.phase != main.Phase.PREP:
		await get_tree().process_frame
	GameState.today_event = ""
	main._prepare_day(false)
	await _seconds(0.5)
	_place_decor()
	main.hud._modal(main.hud._day_card, false)
	main._open_day()

	# Warm-up: fast-forward until the café is busy (cut from the ad).
	Engine.time_scale = 6.0
	var t := 0
	while t < 150 and main.customers.size() < 7:
		_bot()
		await get_tree().process_frame
		t += 1
	Engine.time_scale = 1.0
	_quiet_hud()

	await _shot("busy", 6.5)
	main.hud.visible = false
	_follow = main.chef
	_follow_dist = 6.0
	await _shot("chef", 4.0)
	_follow = null
	_aim(Vector3(0, 0.3, -0.6), 9.5)
	_shot_styles()
	await _shot("styles", 4.6)
	# Chef Mochi poses on the rug, facing the camera, for the outfit changes.
	_bot_on = false
	main.chef.clear_tasks()
	main.chef.drop_all()
	main.chef.global_position = Vector3(0, 0, 0.5)
	main.chef.yaw_target = 0.0
	main.chef.rotation.y = 0.0
	_aim(Vector3(0, 0.65, 0.5), 4.8)
	main.camera.position = _cam_target + _default_cam.basis.z * _cam_dist
	_shot_outfits()
	await _shot("outfits", 4.0)
	_bot_on = true
	_aim(Vector3(0, 0.2, 0.0), 11.0)
	await _shot("helpers", 3.6)

	main.hud.visible = true
	_cam_on = false
	main.camera.transform = _default_cam
	main.stats["served"] += 22
	main.stats["earned"] += 431
	main.stats["stars_sum"] += 22 * 4.8
	main.stats["stars_n"] += 22
	main.stats["grumpy"] = 0
	GameState.coins += 431
	main._end_day()
	await _shot("results", 3.0)

	var f := FileAccess.open(out_dir.path_join("shots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": FPS, "shots": shots}, "  "))
	f.close()
	GameState.reset()
	GameState.save_game()
	get_tree().quit()



func _process(delta: float) -> void:
	frame += 1
	if main == null or not is_instance_valid(main) or main.phase == main.Phase.LOADING:
		return
	if _default_cam == Transform3D():
		_default_cam = main.camera.transform
	if _bot_on and (main.phase == main.Phase.OPEN or main.phase == main.Phase.CLOSING):
		_bot()
	var back := _default_cam.basis.z
	var want: Vector3
	if _follow and is_instance_valid(_follow):
		want = _follow.global_position + Vector3(0, 0.55, 0) + back * _follow_dist
	elif _cam_on:
		want = _cam_target + back * _cam_dist
	else:
		return
	var k := 1.0 - exp(-3.5 * delta)
	main.camera.position = main.camera.position.lerp(want, k)


func _aim(target: Vector3, dist: float) -> void:
	_cam_target = target
	_cam_dist = dist
	_cam_on = true


## Records `seconds` of footage under `name`.
func _shot(name: String, seconds: float) -> void:
	var start := frame
	await _seconds(seconds)
	shots[name] = [start, frame]
	print("shot %s: frames %d-%d" % [name, start, frame])


func _seconds(seconds: float) -> void:
	var n := int(round(seconds * FPS))
	for i in n:
		await get_tree().process_frame


## Wallpapers and floors change every 0.9 s with a sparkle burst.
func _shot_styles() -> void:
	var walls := ["lavender", "sky", "butter", "peach", "mint"]
	var floors := ["cherry", "birch", "cocoa", "honey", "honey"]
	for i in walls.size():
		await _seconds(0.75)
		GameState.equipped["wall"] = walls[i]
		GameState.equipped["floor"] = floors[i]
		main.apply_style()
		Audio.play("sparkle")
		for p in [Vector3(-2.4, 1.6, -2.9), Vector3(0, 1.8, -3.0), Vector3(2.4, 1.6, -2.9), Vector3(-2.9, 1.4, 0.5), Vector3(2.9, 1.4, 0.5)]:
			FX.sparkles(main.decor, p, 14)


func _shot_outfits() -> void:
	for id in ["strawberry", "mint", "sunny", "lavender", "night", "golden"]:
		await _seconds(0.62)
		GameState.equipped["outfit"] = id
		main.apply_style()
		main.chef.happy_jump()
		FX.sparkles(main.actors, main.chef.global_position + Vector3(0, 1.0, 0), 22)
	await _seconds(0.3)
	FX.emote(main.actors, main.chef.global_position + Vector3(0, 1.5, 0), "heart")


## Keeps the HUD tidy for the camera: no hints or toasts.
func _quiet_hud() -> void:
	main.hud.flush_toasts()
	main.hud._toast.visible = false


func _stage_progress() -> void:
	GameState.reset()
	GameState.sound_on = false
	GameState.music_on = false
	GameState.day = 6
	GameState.xp = GameState.LEVELS[4]["xp"] + 40
	GameState.coins = 1460
	for u in GameState.UPGRADES:
		GameState.upgrades[u["id"]] = u["costs"].size()
	for kind in GameState.GUESTS:
		GameState.friends[kind] = {"points": 20, "visits": 10}
	for st in GameState.STICKERS:
		GameState.stickers.append(st["id"])
	GameState.equipped = {"wall": "mint", "floor": "honey", "outfit": "classic"}
	GameState.decor_owned = {"fern": 2, "flowers": 1, "lamp": 1}
	GameState.premium = true
	GameState.premium_gift_given = true
	GameState.today_event = ""
	GameState.save_game()


func _place_decor() -> void:
	var deco: Decorator = main.decorator
	var spots: Array[Vector3] = []
	for z in [2.0, 1.4, 0.8, 0.2, -0.4, -1.0, -1.6]:
		for x in [-2.2, 2.2, -1.7, 1.7]:
			spots.append(Vector3(x, 0, z))
	for id in ["lamp", "fern", "flowers", "fern"]:
		var item := deco.spawn_decor(id, spots[0])
		var placed := false
		for p in spots:
			item.global_position = p
			if deco.check(item) == "":
				placed = true
				break
		if placed:
			deco.save_layout()
			main.rebuild_grid()
		else:
			item.queue_free()


## Serve what we carry, pick up what's ready, cook what's wanted, tidy tables.
func _bot() -> void:
	var chef: Chef = main.chef
	if chef == null or not chef.queue.is_empty() or not chef.current.is_empty():
		return
	for c in main.customers:
		if c.is_waiting():
			for dish in chef.carrying:
				if c.wants(dish):
					_do({"type": "serve", "target": c, "point": c.seat.approach_point(), "face": c.global_position})
					return
	for c in main.customers:
		if not c.is_waiting():
			continue
		for dish in c.orders:
			if chef.carrying.has(dish):
				continue
			var st: Station = main.stations[GameState.DISHES[dish]["station"]]
			if (st.state == Station.State.READY and chef.can_carry()) or st.state == Station.State.IDLE:
				_do({"type": "station", "target": st, "point": st.interaction_point(), "face": st.global_position})
				return
	for s in main.seats:
		if s.coins > 0:
			_do({"type": "collect", "target": s, "point": s.approach_point(), "face": s.dish_position()})
			return


func _do(task: Dictionary) -> void:
	main._task_id += 1
	task["id"] = main._task_id
	main.chef.enqueue(task)
