extends Node
## Plays a full day with a simple bot and checks the core loop works:
## cook -> pick up -> serve -> collect coins -> results -> buy an upgrade.
##
##   godot --headless --path . res://tests/smoke_test.tscn
##
## Pass `-- --shots=<dir>` (with a real renderer) to also save screenshots.
## Exits with code 0 on success, 1 on failure.

const MAIN := preload("res://scenes/main.tscn")
const TIME_SCALE := 4.0

var main: Node
var failures: Array[String] = []
var shots_dir := ""
var _shot_times := [2.0, 12.0, 28.0, 45.0]
var _clock := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	GameState.reset()
	GameState.sound_on = false
	GameState.music_on = false
	main = MAIN.instantiate()
	add_child(main)
	await _wait_until(func(): return main.phase == main.Phase.PREP, 20.0)
	_check(main.phase == main.Phase.PREP, "day card shown after loading")
	await _shot("00_day_card")
	main.hud._modal(main.hud._day_card, false)
	main._open_day()
	Engine.time_scale = TIME_SCALE
	var day_len := GameState.day_length()
	var elapsed := 0.0
	while main.phase != main.Phase.RESULTS and elapsed < day_len + 90.0:
		_bot()
		await get_tree().create_timer(0.25).timeout
		elapsed += 0.25
		_clock += 0.25
		if not _shot_times.is_empty() and _clock >= _shot_times[0]:
			_shot_times.pop_front()
			await _shot("%02d_play" % int(_clock))
	Engine.time_scale = 1.0
	_check(main.phase == main.Phase.RESULTS, "day reached the results screen")
	_check(main.stats.get("served", 0) > 0, "served at least one guest (served=%s)" % main.stats.get("served"))
	_check(GameState.coins > 0, "earned coins (coins=%d)" % GameState.coins)
	_check(GameState.day == 2, "advanced to day 2")
	await _shot("50_results")

	GameState.coins = max(GameState.coins, 200)
	var before := GameState.tables_unlocked()
	main._buy("table")
	_check(GameState.tables_unlocked() == before + 1, "bought an extra table")
	main._buy("griddle")
	_check(GameState.is_station_unlocked("griddle"), "unlocked the griddle")
	_check("pancakes" in GameState.menu(), "pancakes joined the menu")
	await _shot("51_shop_after_buy")
	main.hud._modal(main.hud._results, false)
	main._prepare_day()
	await get_tree().process_frame
	_check(main.tables[2].unlocked, "third table open next day")
	_check(main.stations["griddle"].unlocked, "griddle station active next day")
	await _shot("60_day2")

	GameState.reset()
	if failures.is_empty():
		print("SMOKE OK: served=%d coins_after_day=%d" % [main.stats.get("served", 0), main.stats.get("earned", 0)])
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)


## A tiny player: serve what we carry, pick up what's ready, cook what's wanted, tidy tables.
func _bot() -> void:
	var chef: Chef = main.chef
	if chef == null or not chef.queue.is_empty() or not chef.current.is_empty():
		return
	for c in main.customers:
		if c.is_waiting() and chef.carrying.has(c.order):
			_do({"type": "serve", "target": c, "point": c.seat.approach_point(), "face": c.global_position})
			return
	for c in main.customers:
		if not c.is_waiting():
			continue
		var st: Station = main.stations[GameState.DISHES[c.order]["station"]]
		if st.state == Station.State.READY and chef.can_carry():
			_do({"type": "station", "target": st, "point": st.interaction_point(), "face": st.global_position})
			return
		if st.state == Station.State.IDLE:
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


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		failures.append(what)
		printerr("  FAIL ", what)


func _wait_until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()


func _shot(name: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(name + ".png"))
