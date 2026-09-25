class_name FloorGrid
extends RefCounted
## Walkable-floor grid for the café (x/z plane) with A* and path smoothing.

const CELL := 0.25
const MIN_X := -2.75
const MIN_Z := -3.25
const COLS := 22  # x: -2.75 .. 2.75
const ROWS := 23  # z: -3.25 .. 2.5

var astar := AStarGrid2D.new()


func _init() -> void:
	astar.region = Rect2i(0, 0, COLS, ROWS)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()


func clear() -> void:
	astar.fill_solid_region(astar.region, false)


func block_circle(center: Vector3, radius: float) -> void:
	for x in COLS:
		for y in ROWS:
			var w := world_of(Vector2i(x, y))
			if Vector2(w.x - center.x, w.z - center.z).length() < radius:
				astar.set_point_solid(Vector2i(x, y), true)


func cell_of(p: Vector3) -> Vector2i:
	var x := clampi(int(floor((p.x - MIN_X) / CELL)), 0, COLS - 1)
	var y := clampi(int(floor((p.z - MIN_Z) / CELL)), 0, ROWS - 1)
	return Vector2i(x, y)


func world_of(c: Vector2i) -> Vector3:
	return Vector3(MIN_X + (c.x + 0.5) * CELL, 0.0, MIN_Z + (c.y + 0.5) * CELL)


func is_open(p: Vector3) -> bool:
	if p.x < MIN_X or p.x > MIN_X + COLS * CELL or p.z < MIN_Z or p.z > MIN_Z + ROWS * CELL:
		return false
	return not astar.is_point_solid(cell_of(p))


func clamp_to_floor(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, MIN_X + 0.1, MIN_X + COLS * CELL - 0.1), 0.0, clampf(p.z, MIN_Z + 0.1, MIN_Z + ROWS * CELL - 0.1))


func nearest_open(c: Vector2i) -> Vector2i:
	if not astar.is_point_solid(c):
		return c
	for r in range(1, max(COLS, ROWS)):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
					var d := Vector2(dx, dy).length()
					if d < best_d:
						best_d = d
						best = n
		if best.x >= 0:
			return best
	return c


## World-space path from `from` to `to`, smoothed so characters walk in straight lines.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	from.y = 0.0
	to.y = 0.0
	var out := PackedVector3Array()
	if _line_open(from, to):
		out.append(to)
		return out
	var a := nearest_open(cell_of(from))
	var b := nearest_open(cell_of(to))
	var ids := astar.get_id_path(a, b, true)
	if ids.is_empty():
		out.append(to)
		return out
	var raw: Array[Vector3] = [from]
	for i in range(1, ids.size()):
		raw.append(world_of(ids[i]))
	if is_open(to) or ids[ids.size() - 1] == b:
		raw.append(to)
	# string pulling
	var anchor := 0
	var i := 1
	while i < raw.size():
		if i == raw.size() - 1 or not _line_open(raw[anchor], raw[i + 1]):
			out.append(raw[i])
			anchor = i
		i += 1
	return out


func _line_open(a: Vector3, b: Vector3) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var steps := int(ceil(d.length() / (CELL * 0.4)))
	for s in range(1, steps):
		var t := float(s) / steps
		var p := a.lerp(b, t)
		if not is_open(p):
			return false
	return true
