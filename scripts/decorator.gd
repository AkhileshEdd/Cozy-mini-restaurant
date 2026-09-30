class_name Decorator
extends Node
## Decorate mode: pick up tables and décor, move them around the café floor,
## rotate or store décor, and place new pieces from storage. Every change is
## checked so guests and the chef can still reach every seat and station.

const SNAP := 0.25
const MIN_X := -2.95
const MAX_X := 2.95
const MIN_Z := -2.72  # keeps the walkway in front of the stations clear
const MAX_Z := 2.55

var main: CafeGame
var active := false
var selected: Node3D = null
var held_id := ""
var _ring: MeshInstance3D
var _ring_tween: Tween


func _init(game: CafeGame) -> void:
	main = game


func begin() -> void:
	active = true
	selected = null
	held_id = ""
	_refresh_ui()


func end() -> void:
	_select(null)
	held_id = ""
	active = false
	save_layout()


## Placed décor wrappers live here.
func decor_root() -> Node3D:
	return main.decor.get_node("Placed")


func movables() -> Array:
	var out: Array = []
	for t in main.tables:
		out.append(t)
	out.append(main.decor.get_node("MenuBoard"))
	out.append_array(decor_root().get_children())
	return out


func spawn_decor(id: String, pos: Vector3, rot := 0.0) -> Node3D:
	var def := GameState.decor_def(id)
	var holder := Node3D.new()
	holder.name = "Decor"
	holder.set_meta("decor_id", id)
	holder.set_meta("radius", float(def["radius"]))
	holder.add_to_group("obstacle")
	var model: Node3D = load("res://assets/models/%s.glb" % def["model"]).instantiate()
	holder.add_child(model)
	CozyLook.stylize(model, true)
	CozyLook.add_blob(holder, Vector2.ONE * float(def["radius"]) * 2.4)
	decor_root().add_child(holder)
	holder.global_position = pos
	holder.rotation.y = rot
	return holder


# -- input ---------------------------------------------------------------------

func tap(screen: Vector2) -> void:
	if held_id != "":
		_place_new(screen)
		return
	var hit := _pick(screen)
	if hit != null:
		_select(null if hit == selected else hit)
		Audio.play("tap")
		return
	if selected != null:
		_move_selected(screen)


func take_from_storage(id: String) -> void:
	if GameState.decor_in_storage(id) <= 0:
		return
	_select(null)
	held_id = id
	Audio.play("pickup")
	_refresh_ui()


func rotate_selected() -> void:
	if selected == null or selected is CafeTable:
		main.hud.toast("Tables always face the same way", CozyTheme.INK)
		return
	selected.rotation.y += PI / 4.0
	FX.squash(selected, 0.1, 0.2)
	Audio.play("tap", 1.2)
	save_layout()


func store_selected() -> void:
	if selected == null or not selected.has_meta("decor_id"):
		main.hud.toast("Only décor can be stored", CozyTheme.INK)
		return
	var node := selected
	_select(null)
	node.get_parent().remove_child(node)
	node.queue_free()
	Audio.play("pickup", 0.9)
	save_layout()
	main.rebuild_grid()
	_refresh_ui()


# -- moving and placing -----------------------------------------------------------

func _move_selected(screen: Vector2) -> void:
	var hit = main.floor_point(screen)
	if hit == null:
		return
	var old := selected.global_position
	selected.global_position = _snap(hit)
	var problem := check(selected)
	if problem != "":
		selected.global_position = old
		main.rebuild_grid()
		main.hud.toast(problem, CozyTheme.INK)
		Audio.play("nope")
		return
	FX.pop_in(selected, 0.25)
	Audio.play("pickup", 1.2)
	_select(selected)
	save_layout()


func _place_new(screen: Vector2) -> void:
	var hit = main.floor_point(screen)
	if hit == null:
		return
	var id := held_id
	var node := spawn_decor(id, _snap(hit))
	var problem := check(node)
	if problem != "":
		decor_root().remove_child(node)
		node.queue_free()
		main.rebuild_grid()
		main.hud.toast(problem, CozyTheme.INK)
		Audio.play("nope")
		return
	held_id = ""
	FX.pop_in(node, 0.35)
	FX.sparkles(main.decor, node.global_position + Vector3(0, 0.6, 0), 14)
	Audio.play("buy", 1.3)
	_select(node)
	save_layout()


func _snap(p: Vector3) -> Vector3:
	return Vector3(snappedf(p.x, SNAP), 0.0, snappedf(p.z, SNAP))


## Returns "" when the layout with `item` where it is now is fine, or why not.
func check(item: Node3D) -> String:
	var mine := _footprint(item)
	for fp in mine:
		var p: Vector3 = fp[0]
		var r: float = fp[1]
		if p.x - r < MIN_X or p.x + r > MAX_X or p.z + r > MAX_Z:
			return "Too close to the wall"
		if p.z - r < MIN_Z:
			return "Keep the kitchen walkway clear"
		if Vector2(p.x - main.DOOR_INSIDE.x, p.z - main.DOOR_INSIDE.z).length() < r + 0.5:
			return "That blocks the door"
	for other in movables() + main.get_tree().get_nodes_in_group("obstacle"):
		if other == item or not (other as Node3D).is_visible_in_tree():
			continue
		for a in mine:
			for b in _footprint(other):
				var d := Vector2(a[0].x - b[0].x, a[0].z - b[0].z).length()
				if d < float(a[1]) + float(b[1]) - 0.04:
					return "Not enough room there"
	main.rebuild_grid()
	var grid: FloorGrid = main.grid
	for st in main.stations.values():
		if st.unlocked and not grid.reachable(main.CHEF_START, st.interaction_point()):
			return "Chef Mochi couldn't reach a station"
	for seat in main.seats:
		if seat.table.unlocked and not grid.reachable(main.DOOR_INSIDE, seat.approach_point()):
			return "Guests couldn't reach a seat"
	return ""


func _footprint(node: Node3D) -> Array:
	if node is CafeTable:
		return (node as CafeTable).obstacle_points()
	return [[node.global_position, float(node.get_meta("radius", 0.35))]]


func _pick(screen: Vector2) -> Node3D:
	var best: Node3D = null
	var best_d := 1.0
	for m in movables():
		var anchor: Vector3 = m.global_position + Vector3(0, 0.45, 0)
		if main.camera.is_position_behind(anchor):
			continue
		var d := main.camera.unproject_position(anchor).distance_to(screen) / 95.0
		if d < best_d:
			best_d = d
			best = m
	return best


func _select(node: Node3D) -> void:
	selected = node
	if _ring_tween and _ring_tween.is_valid():
		_ring_tween.kill()
	if _ring:
		_ring.queue_free()
		_ring = null
	if node != null:
		_ring = MeshInstance3D.new()
		var mesh := TorusMesh.new()
		var r := 1.05 if node is CafeTable else float(node.get_meta("radius", 0.35)) + 0.12
		mesh.inner_radius = r
		mesh.outer_radius = r + 0.07
		mesh.rings = 32
		mesh.ring_segments = 6
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = m
		_ring.mesh = mesh
		main.decor.add_child(_ring)
		_ring.global_position = node.global_position + Vector3(0, 0.03, 0)
		_ring.scale = Vector3(1, 0.12, 1)
		_ring_tween = _ring.create_tween().set_loops()
		_ring_tween.tween_property(_ring, "scale", Vector3(1.08, 0.12, 1.08), 0.35).set_trans(Tween.TRANS_SINE)
		_ring_tween.tween_property(_ring, "scale", Vector3(1, 0.12, 1), 0.35).set_trans(Tween.TRANS_SINE)
	_refresh_ui()


func _refresh_ui() -> void:
	if not active:
		return
	var hint := "Tap a table or décor to pick it, then tap the floor to move it."
	if held_id != "":
		hint = "Tap the floor to place the %s." % GameState.decor_def(held_id)["name"].to_lower()
	elif selected != null:
		var what: String = "table" if selected is CafeTable else ("menu board" if not selected.has_meta("decor_id") else GameState.decor_def(selected.get_meta("decor_id"))["name"].to_lower())
		hint = "Tap the floor to move the %s." % what
	main.hud.update_decorate(hint)


# -- persistence ----------------------------------------------------------------------

func save_layout() -> void:
	var tables := {}
	for i in main.tables.size():
		var p: Vector3 = main.tables[i].global_position
		tables[str(i)] = [p.x, p.z]
	var menu: Node3D = main.decor.get_node("MenuBoard")
	var decor: Array = []
	for d in decor_root().get_children():
		if d.is_queued_for_deletion():
			continue
		decor.append({"id": d.get_meta("decor_id"), "x": d.global_position.x, "z": d.global_position.z, "rot": d.rotation.y})
	GameState.layout = {"tables": tables, "menu": [menu.global_position.x, menu.global_position.z, menu.rotation.y], "decor": decor}
	GameState.save_game()
	_refresh_ui()


func load_layout() -> void:
	var layout := GameState.layout
	var tables: Dictionary = layout.get("tables", {})
	for key in tables:
		var i := int(key)
		if i < main.tables.size():
			var xz: Array = tables[key]
			main.tables[i].global_position = Vector3(float(xz[0]), 0.0, float(xz[1]))
	var menu_xz: Array = layout.get("menu", [])
	if menu_xz.size() == 3:
		var menu: Node3D = main.decor.get_node("MenuBoard")
		menu.global_position = Vector3(float(menu_xz[0]), 0.0, float(menu_xz[1]))
		menu.rotation.y = float(menu_xz[2])
	var counts := {}
	for entry in layout.get("decor", []):
		var id := str(entry.get("id", ""))
		if not GameState.DECOR.has(id):
			continue
		counts[id] = int(counts.get(id, 0)) + 1
		if counts[id] > int(GameState.decor_owned.get(id, 0)):
			continue
		spawn_decor(id, Vector3(float(entry["x"]), 0.0, float(entry["z"])), float(entry.get("rot", 0.0)))
