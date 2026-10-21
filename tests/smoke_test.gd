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

	_check(GameState.xp > 0, "earned café XP (xp=%d, level %d)" % [GameState.xp, GameState.cafe_level()])
	_check(GameState.make_order("bear").size() == 2, "Bruno always orders two dishes")
	var friend_points := 0
	for kind in GameState.GUESTS:
		friend_points += int(GameState.friend(kind)["points"])
	_check(friend_points > 0, "regulars gained friendship (%d points)" % friend_points)
	_check(not GameState.dish_counts.is_empty(), "served dishes are counted for the book")
	_check(GameState.stickers.has("first_guest"), "Grand opening sticker unlocked")
	for tab in ["regulars", "menu", "stickers"]:
		main.hud.open_book(tab)
		await get_tree().process_frame
		await _shot("55_book_" + tab)
	_check(main.hud.is_book_open(), "collection book opens")
	main.hud.close_book()
	# friendship gifts and heart maths
	var coins_before := GameState.coins
	GameState.friend("frog")["points"] = 0
	GameState.record_visit("frog", 5.0, ["soup"], false)
	_check(GameState.hearts("frog") == 1 and GameState.coins > coins_before, "first heart pays a gift")
	# save / load keeps the new progress
	GameState.save_game()
	var saved_stickers := GameState.stickers.size()
	GameState.stickers = []
	GameState.load_game()
	_check(GameState.stickers.size() == saved_stickers and GameState.hearts("frog") == 1, "stickers and hearts survive save/load")
	var sweet := GameState.make_order("bunny")
	_check(sweet.size() >= 1 and not sweet.has("latte"), "Pip only orders desserts")

	# level gating: the freezer needs café level 3
	var saved_xp := GameState.xp
	GameState.xp = 0
	GameState.coins = 999
	_check(not GameState.buy("freezer"), "freezer is locked below café level 3")
	GameState.xp = GameState.LEVELS[2]["xp"]
	_check(GameState.cafe_level() == 3, "XP threshold reaches level 3")
	_check(GameState.buy("freezer"), "freezer can be bought at café level 3")
	GameState.upgrades.erase("freezer")
	GameState.xp = saved_xp
	GameState.coins = 0

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

	# -- step 3: style shop, outfits, decorate mode --------------------------
	GameState.coins = 1000
	_check(GameState.buy_style("wall", "mint"), "bought the mint wallpaper")
	_check(_room_has_color(Color(GameState.STYLES["wall"]["mint"]["colors"]["peach"])), "walls turned mint")
	_check(not GameState.buy_style("outfit", "mint"), "Lily's outfit needs 3 hearts")
	GameState.friend("frog")["points"] = GameState.HEARTS[2]
	_check(GameState.buy_style("outfit", "mint"), "Lily's outfit claimed at 3 hearts")
	_check(GameState.equipped["outfit"] == "mint", "outfit equipped")
	_check(GameState.buy_decor("fern") and GameState.buy_decor("flowers"), "bought décor")

	main.hud._modal(main.hud._day_card, false)
	await get_tree().create_timer(0.7).timeout  # let the new table finish popping in
	main._start_decorating()
	await get_tree().process_frame
	var deco: Decorator = main.decorator
	var fern := deco.spawn_decor("fern", Vector3(0, 0, -0.25))
	_check(deco.check(fern) == "", "fern fits in the middle aisle (%s)" % deco.check(fern))
	fern.global_position = main.DOOR_INSIDE
	_check(deco.check(fern) != "", "décor can't block the door")
	fern.global_position = Vector3(0, 0, -3.0)
	_check(deco.check(fern) != "", "décor can't block the kitchen walkway")
	fern.global_position = Vector3(0, 0, -0.25)
	var t0: CafeTable = main.tables[0]
	var home := t0.global_position
	t0.global_position = main.tables[1].global_position
	_check(deco.check(t0) != "", "tables can't overlap")
	t0.global_position = home
	deco.save_layout()
	_check(GameState.charm() == 1 and GameState.decor_in_storage("fern") == 0, "placed fern adds charm")
	await _shot("70_decorate")
	main._stop_decorating()
	await get_tree().process_frame
	GameState.save_game()
	GameState.layout = {}
	GameState.load_game()
	_check(GameState.placed_decor().size() == 1 and GameState.equipped["wall"] == "mint", "layout and style survive save/load")
	GameState.buy_style("wall", "peach")
	GameState.buy_style("outfit", "classic")

	# -- step 4: helpers, events, seasons --------------------------------------
	GameState.xp = GameState.LEVELS[2]["xp"]
	GameState.coins = 1000
	_check(GameState.buy("busser") and GameState.buy("waiter"), "hired Nibbles and Pepper")
	main._apply_upgrades(false)
	_check(main.helpers.size() == 2, "both helpers are in the café")
	main._prepare_day(false)
	main.hud._modal(main.hud._day_card, false)
	main._open_day()
	Engine.time_scale = TIME_SCALE
	var t := 0.0
	while t < 50.0:
		_cook_only_bot()
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	Engine.time_scale = 1.0
	await _shot("80_helpers")
	_check(main.stats["served"] > 0, "Pepper served guests without the chef (served=%d)" % main.stats["served"])
	_check(main.stats["earned"] > 0, "Nibbles collected tips (earned=%d)" % main.stats["earned"])

	GameState.today_event = "rain"
	var soups := 0
	for i in 300:
		if GameState._weighted(["soup", "cake"], GameState.event_def()["dish_weights"]) == "soup":
			soups += 1
	_check(soups > 180, "rainy days favour soup (%d/300)" % soups)
	GameState.today_event = "rush"
	var calm := GameState.spawn_interval()
	main._update_rush(0.5)
	_check(GameState.rush_active and GameState.spawn_interval() < calm, "rush hour speeds up guests")
	main._set_rush(false)
	GameState.today_event = ""
	GameState.season_override = "winter"
	_check(GameState.weather() == "snow" and GameState.dish_price("latte") == 10, "winter: snow and pricier lattes")
	GameState.season_override = ""

	# -- ads and "Remove ads" (mock backend) ----------------------------------------
	_check(Monetization.backend == Monetization.Backend.MOCK, "debug builds use the mock ad backend")
	GameState.premium = false
	GameState.premium_gift_given = false
	GameState.free_coins_day = 0
	GameState.free_coins_claimed = 0
	var cooled := Time.get_ticks_msec() - Monetization.AD_COOLDOWN_MSEC - 1
	Monetization._last_fullscreen_msec = cooled
	GameState.day = 2
	_check(not Monetization.interstitial_due(), "no interstitials in the first days")
	GameState.day = 5
	_check(Monetization.interstitial_due(), "interstitial due on later days")
	await _ads_shots()
	Monetization.instant = true
	Monetization._last_fullscreen_msec = cooled
	await Monetization.maybe_show_interstitial()
	_check(not Monetization.interstitial_due(), "interstitials are spaced out")
	GameState.day = 7
	_check(not Monetization.interstitial_due(), "cooldown between full-screen ads")
	Monetization._last_fullscreen_msec = cooled
	_check(Monetization.interstitial_due(), "interstitial due again two days later")

	main.stats["earned"] = 40
	main._coins_doubled = false
	var before_double := GameState.coins
	await main._double_coins()
	await main._double_coins()
	_check(GameState.coins == before_double + 40, "rewarded ad doubles today's coins once (%d -> %d)" % [before_double, GameState.coins])
	var before_free := GameState.coins
	for i in GameState.FREE_COINS_PER_DAY + 1:
		await main._free_coins()
	_check(GameState.coins == before_free + GameState.FREE_COINS * GameState.FREE_COINS_PER_DAY and GameState.free_coins_left() == 0, "free coins: %d ads a day" % GameState.FREE_COINS_PER_DAY)
	GameState.day += 1
	_check(GameState.free_coins_left() == GameState.FREE_COINS_PER_DAY, "free coins come back the next day")

	_check(not GameState.buy_style("outfit", "golden"), "golden outfit needs Remove ads")
	var before_premium := GameState.coins
	Monetization.buy_remove_ads()
	await get_tree().process_frame
	_check(GameState.premium and GameState.coins == before_premium + GameState.PREMIUM_GIFT, "Remove ads: premium on, +%d coins" % GameState.PREMIUM_GIFT)
	Monetization._last_fullscreen_msec = cooled
	_check(not Monetization.interstitial_due(), "no interstitials after Remove ads")
	_check(Monetization.rewarded_ready(), "rewarded ads stay available (opt-in)")
	_check(GameState.buy_style("outfit", "golden"), "golden outfit unlocked")
	_check(GameState.set_premium(true) == 0, "premium gift is paid only once")
	GameState.save_game()
	GameState.premium = false
	GameState.load_game()
	_check(GameState.premium, "premium survives save/load")
	GameState.reset()
	_check(GameState.premium, "premium survives Start over")
	if shots_dir != "":
		main.hud._set_paused(true)
		await get_tree().create_timer(0.4).timeout
		await _shot("95_premium_pause")
		main.hud._set_paused(false)

	# -- step 5: idle earnings and safe saves --------------------------------------
	var epoch := 1_000_000
	GameState.idle_pending = {}
	GameState.last_seen = epoch
	GameState.check_idle(epoch + 120)
	_check(GameState.idle_pending.is_empty(), "two minutes away pays nothing")
	GameState.last_seen = epoch
	GameState.check_idle(epoch + 3 * 3600)
	var hourly := GameState.idle_rate()
	_check(hourly > 0 and int(GameState.idle_pending.get("coins", 0)) == roundi(hourly * 3.0), "three hours away pays 3x the hourly rate (%d/h)" % hourly)
	GameState.idle_pending = {}
	GameState.last_seen = epoch
	GameState.check_idle(epoch + 48 * 3600)
	_check(int(GameState.idle_pending.get("seconds", 0)) == GameState.IDLE_MAX_SECONDS, "idle earnings stop at 8 hours")
	GameState.idle_pending = {}
	GameState.last_seen = epoch
	GameState.check_idle(epoch - 3600)
	_check(GameState.idle_pending.is_empty(), "a clock set backwards pays nothing")
	GameState.idle_pending = {"coins": 90, "seconds": 7200}
	main.hud.show_welcome(GameState.idle_pending)
	await get_tree().create_timer(0.4).timeout
	_check(main.hud.is_welcome_open(), "welcome-back card shows")
	await _shot("96_welcome_back")
	var before_idle := GameState.coins
	main.hud._close_welcome(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(GameState.coins == before_idle + 180 and GameState.idle_pending.is_empty(), "rewarded ad doubles idle coins (%d -> %d)" % [before_idle, GameState.coins])
	_check(not main.hud.is_welcome_open(), "welcome-back card closes")

	GameState.save_game()
	GameState.save_game()
	var good_coins := GameState.coins
	var broken := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	broken.store_string("{\"coins\": 12")
	broken.close()
	GameState.coins = 0
	GameState.load_game()
	_check(GameState.coins == good_coins, "a damaged save falls back to the backup")
	_check(not FileAccess.file_exists(GameState.SAVE_PATH + ".tmp"), "no temp file left behind")

	GameState.premium = false
	GameState.premium_gift_given = false
	Monetization.instant = false

	GameState.reset()
	if failures.is_empty():
		print("SMOKE OK: served=%d coins_after_day=%d" % [main.stats.get("served", 0), main.stats.get("earned", 0)])
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)


## Screenshots of the ad and store UI (mock backend, real UI).
func _ads_shots() -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	main.hud.flush_toasts()
	main.hud.show_results({"day": 4, "stars": 4.5, "served": 12, "earned": 164, "grumpy": 0, "xp": 60})
	await get_tree().create_timer(2.0).timeout  # let the last toast fade
	await _shot("90_results_ads")
	Monetization.show_rewarded()
	await get_tree().create_timer(0.3).timeout
	await _shot("91_mock_ad")
	Monetization._mock_closed.emit(false)
	await get_tree().process_frame
	Monetization.buy_remove_ads()
	await get_tree().create_timer(0.3).timeout
	await _shot("92_mock_store")
	Monetization._mock_closed.emit(false)
	await get_tree().process_frame
	main.hud._modal(main.hud._results, false)
	main.hud._set_paused(true)
	await get_tree().create_timer(0.4).timeout
	await _shot("93_pause_store")
	main.hud._set_paused(false)


## A tiny player: serve what we carry, pick up what's ready, cook what's wanted, tidy tables.
func _bot() -> void:
	var chef: Chef = main.chef
	if chef == null or not chef.queue.is_empty() or not chef.current.is_empty():
		return
	for c in main.customers:
		if not c.is_waiting():
			continue
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


## Only cooks: the helpers have to carry dishes and collect tips.
func _cook_only_bot() -> void:
	var chef: Chef = main.chef
	if chef == null or not chef.queue.is_empty() or not chef.current.is_empty():
		return
	for c in main.customers:
		if not c.is_waiting():
			continue
		for dish in c.orders:
			var st: Station = main.stations[GameState.DISHES[dish]["station"]]
			if st.state == Station.State.IDLE:
				main._task_id += 1
				chef.enqueue({"type": "station", "target": st, "point": st.interaction_point(), "face": st.global_position, "id": main._task_id})
				return


func _do(task: Dictionary) -> void:
	main._task_id += 1
	task["id"] = main._task_id
	main.chef.enqueue(task)


func _room_has_color(c: Color) -> bool:
	for node in main.get_node("Cafe").find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m and m.albedo_color.is_equal_approx(c):
				return true
	return false


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
