extends Node
## Stages a busy, upgraded café and saves Google Play screenshots.
##
##   xvfb-run -s "-screen 0 1200x2000x24" godot --rendering-driver opengl3 \
##     --path . --resolution 1080x1920 res://tools/godot/store_shots.tscn -- --out=docs/store/screenshots
##
## Overwrites (then resets) the local save, like the smoke test.

const MAIN := preload("res://scenes/main.tscn")

var main: Node
var out_dir := "docs/store/screenshots"


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
	await _wait(0.8)
	_place_decor()
	await _wait(0.8)
	await _shot("phone_2_menu")

	main.hud._modal(main.hud._day_card, false)
	main._open_day()
	Engine.time_scale = 3.0
	var t := 0.0
	while t < 40.0 and main.customers.size() < 7:
		_bot()
		await _wait(0.25)
		t += 0.25
	for i in 8:
		_bot()
		await _wait(0.25)
	Engine.time_scale = 1.0
	main.hud.flush_toasts()
	main.hud._toast.modulate.a = 0.0
	await _wait(0.6)
	await _shot("phone_1_cafe")

	# A full day's numbers for the results screen.
	main.stats["served"] += 21
	main.stats["earned"] += 412
	main.stats["stars_sum"] += 21 * 4.7
	main.stats["stars_n"] += 21
	main.stats["grumpy"] = 0
	GameState.coins += 412
	main._end_day()
	await _wait(2.5)
	await _shot("phone_3_results")
	main.hud._shop_tab = "style"
	main.hud._fill_shop()
	await _wait(0.4)
	await _shot("phone_4_style")
	main.hud._shop_tab = "upgrades"
	main.hud.open_book("regulars")
	await _wait(0.5)
	await _shot("phone_5_regulars")
	main.hud.close_book()
	main.hud._modal(main.hud._results, false)
	main._prepare_day(false)
	main.hud._modal(main.hud._day_card, false)
	main._start_decorating()
	await _wait(0.6)
	await _shot("phone_6_decorate")
	main._stop_decorating()

	GameState.reset()
	GameState.premium = false
	GameState.premium_gift_given = false
	GameState.save_game()
	print("store shots saved to ", out_dir)
	get_tree().quit()


## A well-loved café on day 6: everything bought, helpers hired, friends made.
func _stage_progress() -> void:
	GameState.reset()
	GameState.sound_on = false
	GameState.music_on = false
	GameState.day = 6
	GameState.xp = GameState.LEVELS[4]["xp"] + 40
	GameState.coins = 1460
	for u in GameState.UPGRADES:
		GameState.upgrades[u["id"]] = u["costs"].size()
	var points := [40, 25, 15, 8, 3]
	var i := 0
	for kind in GameState.GUESTS:
		GameState.friends[kind] = {"points": points[i % points.size()], "visits": 12 - i}
		i += 1
	for d in GameState.DISHES:
		GameState.dish_counts[d] = 20
	GameState.owned_styles = ["wall:mint", "outfit:strawberry"]
	GameState.equipped = {"wall": "mint", "floor": "honey", "outfit": "strawberry"}
	GameState.decor_owned = {"fern": 2, "flowers": 1, "lamp": 1}
	for st in GameState.STICKERS:
		GameState.stickers.append(st["id"])
	GameState.today_event = ""
	GameState.save_game()


## Puts each décor piece on the first free spot along the walls.
func _place_decor() -> void:
	var deco: Decorator = main.decorator
	var spots: Array[Vector3] = []
	for z in [2.0, 1.4, 0.8, 0.2, -0.4, -1.0, -1.6]:
		for x in [-2.2, 2.2, -1.7, 1.7, -0.6, 0.6, 0.0]:
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
	deco.save_layout()


## Serve what we carry, pick up what's ready, cook what's wanted, tidy tables.
func _bot() -> void:
	var chef: Chef = main.chef
	if not chef.queue.is_empty() or not chef.current.is_empty():
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join(name + ".png"))
	print("  saved ", name)
