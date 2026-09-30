extends Node
## Progress, economy tables and save data. Autoloaded as `GameState`.

signal coins_changed(coins: int)
signal upgrades_changed
signal leveled_up(level: int)
signal friendship_up(kind: String, hearts: int, gift: int)
signal sticker_unlocked(id: String)
signal style_changed

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

## Café style: each entry recolours palette materials of the room or the chef.
## Unlocks: `cost` coins, optionally `req_level` (café level) or
## `req_friend` ([guest kind, hearts]) which makes the item a free gift.
const STYLES := {
	"wall": {
		"peach": {"name": "Peach wallpaper", "cost": 0, "colors": {"peach": "fad7c0", "peach_light": "fde4d3", "peach_dark": "f7c4a8", "strawberry": "f48fa0", "strawberry_dark": "e07a8c"}},
		"mint": {"name": "Mint garden", "cost": 90, "colors": {"peach": "c9eedb", "peach_light": "e4f5ec", "peach_dark": "b5e3cb", "strawberry": "f9b8c8", "strawberry_dark": "e07a8c"}},
		"butter": {"name": "Butter sunshine", "cost": 90, "colors": {"peach": "fff0c2", "peach_light": "fff6da", "peach_dark": "fbe3a0", "strawberry": "9ccbeb", "strawberry_dark": "7ab3db"}},
		"lavender": {"name": "Lavender dream", "cost": 120, "req_level": 2, "colors": {"peach": "e3d9f5", "peach_light": "eee8fa", "peach_dark": "d3c6ee", "strawberry": "ffd66b", "strawberry_dark": "f2c14e"}},
		"sky": {"name": "Sky breeze", "cost": 120, "req_level": 3, "colors": {"peach": "dceffa", "peach_light": "eaf5fc", "peach_dark": "c7e4f5", "strawberry": "e8665a", "strawberry_dark": "c94f45"}},
		"cocoa": {"name": "Cocoa evening", "cost": 200, "req_level": 4, "colors": {"peach": "9e7e70", "peach_light": "ad8f82", "peach_dark": "8c6a5c", "strawberry": "ffd66b", "strawberry_dark": "f2c14e"}},
	},
	"floor": {
		"honey": {"name": "Honey planks", "cost": 0, "colors": {"wood": "e8b98a", "wood_mid": "d9a273", "wood_light": "f0c9a0", "mint_light": "c9eedb"}},
		"birch": {"name": "Pale birch", "cost": 80, "colors": {"wood": "f3dec0", "wood_mid": "e8cda8", "wood_light": "faebd5", "mint_light": "dceffa"}},
		"cherry": {"name": "Cherry wood", "cost": 110, "req_level": 2, "colors": {"wood": "c98e62", "wood_mid": "b87850", "wood_light": "d6a07a", "mint_light": "f9d3dc"}},
		"cocoa": {"name": "Walnut", "cost": 150, "req_level": 3, "colors": {"wood": "a8704a", "wood_mid": "966240", "wood_light": "b8825c", "mint_light": "e3d9f5"}},
	},
	"outfit": {
		"classic": {"name": "Classic whites", "cost": 0, "colors": {"chef_hat": "ffffff", "chef_band": "f3e6d8", "chef_apron": "ffffff", "chef_pocket": "f48fa0", "chef_scarf": "e8665a"}},
		"strawberry": {"name": "Strawberry chef", "cost": 120, "colors": {"chef_hat": "f9b8c8", "chef_band": "f48fa0", "chef_apron": "fde6ea", "chef_pocket": "e8505b", "chef_scarf": "f48fa0"}},
		"mint": {"name": "Lily's mint set", "cost": 0, "req_friend": ["frog", 3], "colors": {"chef_hat": "c9eedb", "chef_band": "9ed9b8", "chef_apron": "e4f5ec", "chef_pocket": "6faf8e", "chef_scarf": "7bb86f"}},
		"sunny": {"name": "Sunny's yellow set", "cost": 0, "req_friend": ["chick", 3], "colors": {"chef_hat": "fff1b8", "chef_band": "ffd66b", "chef_apron": "fff6da", "chef_pocket": "f2a65a", "chef_scarf": "ffd66b"}},
		"lavender": {"name": "Bao's critic coat", "cost": 0, "req_friend": ["panda", 3], "colors": {"chef_hat": "e3d9f5", "chef_band": "c6b4e8", "chef_apron": "eee8fa", "chef_pocket": "a994d6", "chef_scarf": "c6b4e8"}},
		"night": {"name": "Midnight chef", "cost": 300, "req_level": 5, "colors": {"chef_hat": "5a4a48", "chef_band": "ffd66b", "chef_apron": "6b5048", "chef_pocket": "ffd66b", "chef_scarf": "c6b4e8"}},
	},
}
const STYLE_TITLES := {"wall": "Wallpaper", "floor": "Floor", "outfit": "Chef outfit"}

## Décor you buy and place freely in decorate mode. Each placed piece adds
## `charm`; every charm point is +2% tips (up to +30%).
const DECOR := {
	"fern": {"name": "Potted fern", "model": "plant_big", "cost": 40, "radius": 0.34, "charm": 1},
	"bush": {"name": "Round bush", "model": "bush", "cost": 45, "radius": 0.4, "charm": 1},
	"flowers": {"name": "Flower tub", "model": "flower_tub", "cost": 60, "radius": 0.38, "charm": 2},
	"lamp": {"name": "Floor lamp", "model": "floor_lamp", "cost": 70, "radius": 0.26, "charm": 2, "req_level": 2},
	"bookcase": {"name": "Bookcase", "model": "bookcase", "cost": 110, "radius": 0.5, "charm": 3, "req_level": 3},
}

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
## "cat:id" entries, e.g. "wall:mint". Free defaults are always owned.
var owned_styles: Array[String] = []
var equipped: Dictionary = {"wall": "peach", "floor": "honey", "outfit": "classic"}
## décor id -> number bought
var decor_owned: Dictionary = {}
## Saved positions: "tables" -> {index: [x, z]}, "decor" -> [{id, x, z, rot}], "menu" -> [x, z, rot]
var layout: Dictionary = {}
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
	return (1.25 if level("lights") > 0 else 1.0) * (1.0 + charm_bonus())


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


# -- style and décor ---------------------------------------------------------------

func style_def(cat: String, id: String) -> Dictionary:
	return STYLES.get(cat, {}).get(id, {})


func owns_style(cat: String, id: String) -> bool:
	var def := style_def(cat, id)
	if def.is_empty():
		return false
	if int(def["cost"]) == 0 and not def.has("req_friend") and not def.has("req_level"):
		return true
	return owned_styles.has(cat + ":" + id)


## Why a style item can't be taken yet ("" when it can).
func style_lock(cat: String, id: String) -> String:
	var def := style_def(cat, id)
	if def.has("req_level") and cafe_level() < int(def["req_level"]):
		return "Level %d" % int(def["req_level"])
	if def.has("req_friend"):
		var need: Array = def["req_friend"]
		if hearts(need[0]) < int(need[1]):
			return "%s %d hearts" % [guest(need[0])["name"], int(need[1])]
	return ""


## Buys (or claims a gift) and equips it. Returns false if not possible.
func buy_style(cat: String, id: String) -> bool:
	var def := style_def(cat, id)
	if def.is_empty() or style_lock(cat, id) != "":
		return false
	if not owns_style(cat, id):
		var cost := int(def["cost"])
		if coins < cost:
			return false
		coins -= cost
		owned_styles.append(cat + ":" + id)
		coins_changed.emit(coins)
	equipped[cat] = id
	style_changed.emit()
	save_game()
	return true


func style_colors(cat: String) -> Dictionary:
	var out := {}
	var colors: Dictionary = style_def(cat, equipped.get(cat, "")).get("colors", {})
	for name in colors:
		out[name] = Color(colors[name])
	return out


func decor_def(id: String) -> Dictionary:
	return DECOR.get(id, {})


func decor_lock(id: String) -> String:
	var def := decor_def(id)
	if def.has("req_level") and cafe_level() < int(def["req_level"]):
		return "Level %d" % int(def["req_level"])
	return ""


func buy_decor(id: String) -> bool:
	var def := decor_def(id)
	if def.is_empty() or decor_lock(id) != "" or coins < int(def["cost"]):
		return false
	coins -= int(def["cost"])
	decor_owned[id] = int(decor_owned.get(id, 0)) + 1
	coins_changed.emit(coins)
	save_game()
	return true


func placed_decor() -> Array:
	return layout.get("decor", [])


## How many of a décor item are bought but not placed yet.
func decor_in_storage(id: String) -> int:
	var placed := 0
	for d in placed_decor():
		if d["id"] == id:
			placed += 1
	return int(decor_owned.get(id, 0)) - placed


func charm() -> int:
	var total := 0
	for d in placed_decor():
		total += int(decor_def(d["id"]).get("charm", 0))
	return total


func charm_bonus() -> float:
	return minf(0.3, charm() * 0.02)


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
		"owned_styles": owned_styles,
		"equipped": equipped,
		"decor_owned": decor_owned,
		"layout": layout,
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
	owned_styles = []
	var saved_owned = parsed.get("owned_styles", [])
	if typeof(saved_owned) == TYPE_ARRAY:
		for entry in saved_owned:
			owned_styles.append(str(entry))
	equipped = {"wall": "peach", "floor": "honey", "outfit": "classic"}
	var saved_eq = parsed.get("equipped", {})
	if typeof(saved_eq) == TYPE_DICTIONARY:
		for cat in saved_eq:
			if not style_def(cat, str(saved_eq[cat])).is_empty():
				equipped[cat] = str(saved_eq[cat])
	decor_owned = {}
	var saved_decor = parsed.get("decor_owned", {})
	if typeof(saved_decor) == TYPE_DICTIONARY:
		for id in saved_decor:
			if DECOR.has(id):
				decor_owned[id] = int(saved_decor[id])
	var saved_layout = parsed.get("layout", {})
	layout = saved_layout if typeof(saved_layout) == TYPE_DICTIONARY else {}
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
	owned_styles = []
	equipped = {"wall": "peach", "floor": "honey", "outfit": "classic"}
	decor_owned = {}
	layout = {}
	coins_changed.emit(coins)
	upgrades_changed.emit()
	save_game()
