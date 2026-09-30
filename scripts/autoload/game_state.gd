extends Node
## Progress, economy tables and save data. Autoloaded as `GameState`.

signal coins_changed(coins: int)
signal upgrades_changed
signal leveled_up(level: int)
signal friendship_up(kind: String, hearts: int, gift: int)
signal sticker_unlocked(id: String)

const SAVE_PATH := "user://cozy_save.json"
const SAVE_VERSION := 1

## Every dish on the menu. `station` must match a Station's `station_id`.
const DISHES := {
	"latte": {"name": "Latte", "station": "coffee", "time": 3.0, "price": 8, "tint": Color("9ed9b8")},
	"cake": {"name": "Strawberry cake", "station": "oven", "time": 5.0, "price": 14, "tint": Color("f48fa0")},
	"pancakes": {"name": "Fluffy pancakes", "station": "griddle", "time": 6.0, "price": 20, "tint": Color("ffd66b")},
	"soup": {"name": "Pumpkin soup", "station": "soup", "time": 8.0, "price": 28, "tint": Color("9ccbeb")},
	"sundae": {"name": "Berry sundae", "station": "freezer", "time": 7.0, "price": 34, "tint": Color("c6b4e8")},
}

const STATION_NAMES := {
	"coffee": "coffee machine",
	"oven": "bakery oven",
	"griddle": "griddle",
	"soup": "soup pot",
	"freezer": "freezer",
}

const STARTING_STATIONS := ["coffee", "oven"]
const STARTING_TABLES := 2

## Shop items in display order. Station upgrades share their id with the station.
## `req` is the café level each tier needs (same length as `costs`).
const UPGRADES := [
	{"id": "griddle", "name": "Fluffy pancakes", "desc": "Adds the griddle and pancakes to the menu", "costs": [80], "req": [1], "icon": "pancakes"},
	{"id": "speed", "name": "Speedy paws", "desc": "Chef Mochi walks 15% faster", "costs": [60, 140, 260], "req": [1, 2, 4], "icon": "speed"},
	{"id": "table", "name": "Extra table", "desc": "Two more seats for hungry guests", "costs": [120, 260], "req": [1, 3], "icon": "table"},
	{"id": "plants", "name": "Cozy plants", "desc": "Guests wait 15% longer", "costs": [90], "req": [1], "icon": "plant"},
	{"id": "soup", "name": "Pumpkin soup", "desc": "Adds the soup pot and soup to the menu", "costs": [180], "req": [2], "icon": "soup"},
	{"id": "cook", "name": "Quick kitchen", "desc": "Everything cooks 15% faster", "costs": [100, 220, 380], "req": [2, 3, 5], "icon": "cook"},
	{"id": "rug", "name": "Fluffy rug", "desc": "Guests drop by more often", "costs": [110], "req": [2], "icon": "rug"},
	{"id": "tray", "name": "Big tray", "desc": "Carry three dishes at once", "costs": [160], "req": [2], "icon": "tray"},
	{"id": "lights", "name": "Fairy lights", "desc": "Guests tip 25% more", "costs": [150], "req": [3], "icon": "lights"},
	{"id": "freezer", "name": "Berry sundae", "desc": "Adds the freezer and sundaes to the menu", "costs": [320], "req": [3], "icon": "sundae"},
]

## The regulars. Each species has one personality trait.
##   patience / tip: multipliers   items: dishes per order   likes: allowed dishes
##   fancy: orders the priciest dish on the menu   critic: stars and XP count double
const GUESTS := {
	"bunny": {"fav": "cake", "name": "Pip", "trait": "Sweet tooth", "desc": "Only orders desserts", "patience": 1.0, "tip": 1.15, "likes": ["cake", "pancakes", "sundae"]},
	"bear": {"fav": "pancakes", "name": "Bruno", "trait": "Big appetite", "desc": "Always orders two dishes", "patience": 1.35, "tip": 1.0, "items": 2},
	"frog": {"fav": "soup", "name": "Lily", "trait": "Easygoing", "desc": "Waits a long time but tips a little less", "patience": 1.45, "tip": 0.8},
	"chick": {"fav": "latte", "name": "Sunny", "trait": "In a hurry", "desc": "Short on patience, big on tips", "patience": 0.65, "tip": 1.7},
	"panda": {"fav": "sundae", "name": "Bao", "trait": "Food critic", "desc": "Orders the fanciest dish. His stars count double", "patience": 1.0, "tip": 1.3, "fancy": true, "critic": true},
}

## Café levels: XP comes from happy guests (their stars). Each level has a name.
const LEVELS := [
	{"xp": 0, "title": "Tiny Kiosk"},
	{"xp": 35, "title": "Cozy Corner"},
	{"xp": 100, "title": "Neighbourhood Nook"},
	{"xp": 200, "title": "Sweet Spot"},
	{"xp": 340, "title": "Town Favourite"},
	{"xp": 530, "title": "Famous Café"},
	{"xp": 800, "title": "Legendary Bistro"},
]
## Friendship points needed for each heart (five hearts in total).
const HEARTS := [3, 8, 15, 25, 40]
## Hearts perks: at 3 hearts a regular tips 10% more, at 5 they wait 20% longer.
const TIP_HEART := 3
const PATIENCE_HEART := 5

## Stickers (achievements) for the collection book. `reward` is paid on unlock.
const STICKERS := [
	{"id": "first_guest", "name": "Grand opening", "desc": "Serve your first guest", "icon": "heart", "reward": 10},
	{"id": "guests_50", "name": "Busy bee", "desc": "Serve 50 guests", "icon": "latte", "reward": 80},
	{"id": "guests_200", "name": "Café celebrity", "desc": "Serve 200 guests", "icon": "cake", "reward": 200},
	{"id": "combos_10", "name": "Combo king", "desc": "Finish 10 combo orders", "icon": "pancakes", "reward": 100},
	{"id": "perfect_day", "name": "Perfect day", "desc": "Serve 5+ guests in a day with nobody grumpy", "icon": "heart", "reward": 50},
	{"id": "all_dishes", "name": "Full menu", "desc": "Serve every dish at least once", "icon": "sundae", "reward": 150},
	{"id": "critic", "name": "Critic's choice", "desc": "Get 5 stars from Bao the food critic", "icon": "soup", "reward": 60},
	{"id": "good_friends", "name": "Good friends", "desc": "Reach 3 hearts with a regular", "icon": "heart", "reward": 40},
	{"id": "all_friends", "name": "Everyone's friend", "desc": "Reach 2 hearts with every regular", "icon": "heart", "reward": 120},
	{"id": "best_friends", "name": "Best friends", "desc": "Reach 5 hearts with a regular", "icon": "heart", "reward": 150},
	{"id": "level_4", "name": "Sweet Spot", "desc": "Reach café level 4", "icon": "cook", "reward": 100},
	{"id": "coins_1000", "name": "Piggy bank", "desc": "Earn 1000 coins in total", "icon": "coin", "reward": 100},
]

## Combo (two-dish) orders start at this café level.
const COMBO_LEVEL := 2
const COMBO_BONUS := 1.3

var coins := 0
var day := 1
var upgrades: Dictionary = {}
var total_served := 0
var rating := 4.0
var xp := 0
## kind -> {"points", "visits"}
var friends: Dictionary = {}
## dish -> times served
var dish_counts: Dictionary = {}
var stickers: Array[String] = []
var combos_total := 0
var coins_total := 0
var perfect_days := 0
var critic_five := false
var sound_on := true
var music_on := true


func _ready() -> void:
	load_game()


# -- progression ---------------------------------------------------------------

func level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


## Café level needed for the next tier of an upgrade (0 when maxed out).
func required_level(id: String) -> int:
	var def := upgrade_def(id)
	var req: Array = def.get("req", [])
	var lvl := level(id)
	if lvl >= def.get("costs", []).size():
		return 0
	return int(req[lvl]) if lvl < req.size() else 1


func is_level_locked(id: String) -> bool:
	return required_level(id) > cafe_level()


## Cost of the next level, or -1 when the upgrade is maxed out.
func next_cost(id: String) -> int:
	var costs: Array = upgrade_def(id).get("costs", [])
	var lvl := level(id)
	return int(costs[lvl]) if lvl < costs.size() else -1


func buy(id: String) -> bool:
	var cost := next_cost(id)
	if cost < 0 or coins < cost or is_level_locked(id):
		return false
	coins -= cost
	upgrades[id] = level(id) + 1
	coins_changed.emit(coins)
	upgrades_changed.emit()
	save_game()
	return true


func add_coins(amount: int) -> void:
	coins += amount
	if amount > 0:
		coins_total += amount
	coins_changed.emit(coins)


func is_station_unlocked(station_id: String) -> bool:
	return station_id in STARTING_STATIONS or level(station_id) > 0


func menu() -> Array[String]:
	var out: Array[String] = []
	for dish in DISHES:
		if is_station_unlocked(DISHES[dish]["station"]):
			out.append(dish)
	return out


func dish_name(dish: String) -> String:
	return DISHES[dish]["name"]


func dish_price(dish: String) -> int:
	return int(DISHES[dish]["price"])


func tables_unlocked() -> int:
	return STARTING_TABLES + level("table")


func chef_speed() -> float:
	return 2.4 * pow(1.15, level("speed"))


func cook_time(dish: String) -> float:
	return float(DISHES[dish]["time"]) * pow(0.85, level("cook"))


func carry_capacity() -> int:
	return 3 if level("tray") > 0 else 2


func patience() -> float:
	var base := 44.0 - mini(day - 1, 8) * 1.6
	return base * (1.15 if level("plants") > 0 else 1.0)


func tip_multiplier() -> float:
	return 1.25 if level("lights") > 0 else 1.0


func spawn_interval() -> float:
	var base := maxf(3.4, 8.0 - (day - 1) * 0.45)
	return base * (0.85 if level("rug") > 0 else 1.0)


func day_length() -> float:
	return minf(180.0, 110.0 + (day - 1) * 10.0)


func record_rating(stars: float) -> void:
	rating = clampf(lerpf(rating, stars, 0.12), 1.0, 5.0)


# -- guests and orders -----------------------------------------------------------

func guest(kind: String) -> Dictionary:
	return GUESTS.get(kind, {})


## Build an order (one or two dishes) that fits this guest's trait and the menu.
func make_order(kind: String) -> Array[String]:
	var g := guest(kind)
	var pool: Array = menu()
	var likes: Array = g.get("likes", [])
	if not likes.is_empty():
		var liked := pool.filter(func(d: String): return likes.has(d))
		if not liked.is_empty():
			pool = liked
	if g.get("fancy", false):
		pool.sort_custom(func(a: String, b: String): return dish_price(a) > dish_price(b))
		pool = pool.slice(0, 2)
	var fav: String = g.get("fav", "")
	if pool.has(fav) and randf() < 0.35:
		pool = [fav]
	var count := int(g.get("items", 1))
	if count == 1 and cafe_level() >= COMBO_LEVEL and randf() < 0.25:
		count = 2
	var out: Array[String] = []
	for i in count:
		var choices := pool.filter(func(d: String): return not out.has(d))
		if choices.is_empty():
			choices = pool
		out.append(choices.pick_random())
	return out


# -- friendship --------------------------------------------------------------------

func friend(kind: String) -> Dictionary:
	if not friends.has(kind):
		friends[kind] = {"points": 0, "visits": 0}
	return friends[kind]


func hearts(kind: String) -> int:
	var pts := int(friend(kind)["points"])
	var h := 0
	for need in HEARTS:
		if pts >= int(need):
			h += 1
	return h


## 0..1 progress towards the next heart.
func heart_progress(kind: String) -> float:
	var h := hearts(kind)
	if h >= HEARTS.size():
		return 1.0
	var lo := 0 if h == 0 else int(HEARTS[h - 1])
	var hi := int(HEARTS[h])
	return clampf(float(int(friend(kind)["points"]) - lo) / float(hi - lo), 0.0, 1.0)


## Coins a regular gives when you reach a heart.
func heart_gift(heart: int) -> int:
	return 10 * heart


func friend_patience(kind: String) -> float:
	return 1.2 if hearts(kind) >= PATIENCE_HEART else 1.0


func friend_tip(kind: String) -> float:
	return 1.1 if hearts(kind) >= TIP_HEART else 1.0


## Records a finished visit and returns friendship points gained.
func record_visit(kind: String, stars: float, served: Array, combo: bool) -> int:
	var f := friend(kind)
	f["visits"] = int(f["visits"]) + 1
	for dish in served:
		dish_counts[dish] = int(dish_counts.get(dish, 0)) + 1
	if stars < 3.0:
		check_stickers()
		return 0
	if combo:
		combos_total += 1
	if kind == "panda" and stars >= 5.0:
		critic_five = true
	var gained := 2 if stars >= 4.5 else 1
	if served.has(guest(kind).get("fav", "")):
		gained += 1
	var before := hearts(kind)
	f["points"] = int(f["points"]) + gained
	for h in range(before + 1, hearts(kind) + 1):
		var gift := heart_gift(h)
		add_coins(gift)
		friendship_up.emit(kind, h, gift)
	check_stickers()
	return gained


# -- stickers ----------------------------------------------------------------------

func sticker_def(id: String) -> Dictionary:
	for st in STICKERS:
		if st["id"] == id:
			return st
	return {}


## [current, target] progress for a sticker.
func sticker_progress(id: String) -> Array:
	var best_hearts := 0
	var min_hearts := 99
	for kind in GUESTS:
		best_hearts = maxi(best_hearts, hearts(kind))
		min_hearts = mini(min_hearts, hearts(kind))
	match id:
		"first_guest": return [mini(total_served, 1), 1]
		"guests_50": return [mini(total_served, 50), 50]
		"guests_200": return [mini(total_served, 200), 200]
		"combos_10": return [mini(combos_total, 10), 10]
		"perfect_day": return [mini(perfect_days, 1), 1]
		"all_dishes": return [DISHES.keys().filter(func(d): return int(dish_counts.get(d, 0)) > 0).size(), DISHES.size()]
		"critic": return [1 if critic_five else 0, 1]
		"good_friends": return [mini(best_hearts, 3), 3]
		"all_friends": return [mini(min_hearts, 2), 2]
		"best_friends": return [mini(best_hearts, 5), 5]
		"level_4": return [mini(cafe_level(), 4), 4]
		"coins_1000": return [mini(coins_total, 1000), 1000]
	return [0, 1]


## Unlocks every sticker whose goal is met, pays its reward and returns the new ids.
func check_stickers() -> Array[String]:
	var fresh: Array[String] = []
	for st in STICKERS:
		var id: String = st["id"]
		if stickers.has(id):
			continue
		var p := sticker_progress(id)
		if int(p[0]) >= int(p[1]):
			stickers.append(id)
			fresh.append(id)
			add_coins(int(st["reward"]))
			sticker_unlocked.emit(id)
	return fresh


# -- café level --------------------------------------------------------------------

func cafe_level() -> int:
	var lvl := 1
	for i in LEVELS.size():
		if xp >= int(LEVELS[i]["xp"]):
			lvl = i + 1
	return lvl


func level_title(lvl := -1) -> String:
	if lvl < 1:
		lvl = cafe_level()
	return LEVELS[clampi(lvl, 1, LEVELS.size()) - 1]["title"]


func is_max_level() -> bool:
	return cafe_level() >= LEVELS.size()


## 0..1 progress from the current level to the next.
func level_progress() -> float:
	var lvl := cafe_level()
	if lvl >= LEVELS.size():
		return 1.0
	var lo := int(LEVELS[lvl - 1]["xp"])
	var hi := int(LEVELS[lvl]["xp"])
	return clampf(float(xp - lo) / float(hi - lo), 0.0, 1.0)


func xp_to_next() -> int:
	var lvl := cafe_level()
	return 0 if lvl >= LEVELS.size() else int(LEVELS[lvl]["xp"]) - xp


## Adds XP and returns how many levels were gained.
func add_xp(amount: int) -> int:
	var before := cafe_level()
	xp += maxi(0, amount)
	var after := cafe_level()
	for l in range(before + 1, after + 1):
		leveled_up.emit(l)
	return after - before


## Coin gift handed out when reaching a level.
func level_gift(lvl: int) -> int:
	return 25 * lvl


## Short lines describing what a café level opens up.
func level_unlocks(lvl: int) -> Array[String]:
	var out: Array[String] = []
	if lvl == COMBO_LEVEL:
		out.append("combo orders (+30%)")
	for u in UPGRADES:
		var req: Array = u["req"]
		for tier in req.size():
			if int(req[tier]) == lvl:
				out.append(u["name"] + (" %d" % (tier + 1) if req.size() > 1 else ""))
	return out


# -- persistence ---------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"coins": coins,
		"day": day,
		"upgrades": upgrades,
		"total_served": total_served,
		"rating": rating,
		"xp": xp,
		"friends": friends,
		"dish_counts": dish_counts,
		"stickers": stickers,
		"combos_total": combos_total,
		"coins_total": coins_total,
		"perfect_days": perfect_days,
		"critic_five": critic_five,
		"sound_on": sound_on,
		"music_on": music_on,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	coins = int(parsed.get("coins", 0))
	day = maxi(1, int(parsed.get("day", 1)))
	total_served = int(parsed.get("total_served", 0))
	rating = float(parsed.get("rating", 4.0))
	xp = maxi(0, int(parsed.get("xp", 0)))
	combos_total = int(parsed.get("combos_total", 0))
	coins_total = int(parsed.get("coins_total", 0))
	perfect_days = int(parsed.get("perfect_days", 0))
	critic_five = bool(parsed.get("critic_five", false))
	friends = {}
	var saved_friends = parsed.get("friends", {})
	if typeof(saved_friends) == TYPE_DICTIONARY:
		for kind in saved_friends:
			if GUESTS.has(kind) and typeof(saved_friends[kind]) == TYPE_DICTIONARY:
				friends[kind] = {"points": int(saved_friends[kind].get("points", 0)), "visits": int(saved_friends[kind].get("visits", 0))}
	dish_counts = {}
	var saved_dishes = parsed.get("dish_counts", {})
	if typeof(saved_dishes) == TYPE_DICTIONARY:
		for d in saved_dishes:
			if DISHES.has(d):
				dish_counts[d] = int(saved_dishes[d])
	stickers = []
	var saved_stickers = parsed.get("stickers", [])
	if typeof(saved_stickers) == TYPE_ARRAY:
		for id in saved_stickers:
			if not sticker_def(str(id)).is_empty():
				stickers.append(str(id))
	sound_on = bool(parsed.get("sound_on", true))
	music_on = bool(parsed.get("music_on", true))
	upgrades = {}
	var saved = parsed.get("upgrades", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for id in saved:
			if not upgrade_def(id).is_empty():
				upgrades[id] = int(saved[id])


func reset() -> void:
	coins = 0
	day = 1
	upgrades = {}
	total_served = 0
	rating = 4.0
	xp = 0
	friends = {}
	dish_counts = {}
	stickers = []
	combos_total = 0
	coins_total = 0
	perfect_days = 0
	critic_five = false
	coins_changed.emit(coins)
	upgrades_changed.emit()
	save_game()
