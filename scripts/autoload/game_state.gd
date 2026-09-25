extends Node
## Progress, economy tables and save data. Autoloaded as `GameState`.

signal coins_changed(coins: int)
signal upgrades_changed

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
const UPGRADES := [
	{"id": "griddle", "name": "Fluffy pancakes", "desc": "Adds the griddle and pancakes to the menu", "costs": [80], "icon": "pancakes"},
	{"id": "speed", "name": "Speedy paws", "desc": "Chef Mochi walks 15% faster", "costs": [60, 140, 260], "icon": "speed"},
	{"id": "table", "name": "Extra table", "desc": "Two more seats for hungry guests", "costs": [120, 260], "icon": "table"},
	{"id": "plants", "name": "Cozy plants", "desc": "Guests wait 15% longer", "costs": [90], "icon": "plant"},
	{"id": "soup", "name": "Pumpkin soup", "desc": "Adds the soup pot and soup to the menu", "costs": [180], "icon": "soup"},
	{"id": "cook", "name": "Quick kitchen", "desc": "Everything cooks 15% faster", "costs": [100, 220, 380], "icon": "cook"},
	{"id": "rug", "name": "Fluffy rug", "desc": "Guests drop by more often", "costs": [110], "icon": "rug"},
	{"id": "tray", "name": "Big tray", "desc": "Carry three dishes at once", "costs": [160], "icon": "tray"},
	{"id": "lights", "name": "Fairy lights", "desc": "Guests tip 25% more", "costs": [150], "icon": "lights"},
	{"id": "freezer", "name": "Berry sundae", "desc": "Adds the freezer and sundaes to the menu", "costs": [320], "icon": "sundae"},
]

var coins := 0
var day := 1
var upgrades: Dictionary = {}
var total_served := 0
var rating := 4.0
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


## Cost of the next level, or -1 when the upgrade is maxed out.
func next_cost(id: String) -> int:
	var costs: Array = upgrade_def(id).get("costs", [])
	var lvl := level(id)
	return int(costs[lvl]) if lvl < costs.size() else -1


func buy(id: String) -> bool:
	var cost := next_cost(id)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	upgrades[id] = level(id) + 1
	coins_changed.emit(coins)
	upgrades_changed.emit()
	save_game()
	return true


func add_coins(amount: int) -> void:
	coins += amount
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


# -- persistence ---------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"coins": coins,
		"day": day,
		"upgrades": upgrades,
		"total_served": total_served,
		"rating": rating,
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
	coins_changed.emit(coins)
	upgrades_changed.emit()
	save_game()
