class_name Widgets
extends RefCounted
## Small custom-drawn UI pieces: stars, pause glyph, speaker glyph.


class StarRow extends Control:
	var value := 5.0
	var count := 5
	var star_size := 34.0
	var filled := Color("ffc94a")
	var edge := Color("e0a93a")
	var empty := Color("f3e6d8")

	func _init(size_px := 34.0, n := 5) -> void:
		star_size = size_px
		count = n
		custom_minimum_size = Vector2(size_px * n + (n - 1) * size_px * 0.18, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		value = v
		queue_redraw()

	func _draw() -> void:
		var step := star_size * 1.18
		for i in count:
			var c := Vector2(star_size * 0.5 + i * step, star_size * 0.52)
			var pts := _star(c, star_size * 0.5, star_size * 0.22)
			var fill := clampf(value - i, 0.0, 1.0)
			draw_colored_polygon(pts, empty)
			if fill >= 0.99:
				draw_colored_polygon(pts, filled)
			elif fill > 0.01:
				var clip := PackedVector2Array()
				var edge_x := c.x - star_size * 0.5 + star_size * fill
				for p in pts:
					clip.append(Vector2(minf(p.x, edge_x), p.y))
				draw_colored_polygon(clip, filled)
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, edge if fill > 0.01 else Color("e6d6c4"), 2.0, true)

	func _star(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2 + k * PI / 5
			var r := r_out if k % 2 == 0 else r_in
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts


class Glyph extends Control:
	var kind := "pause"
	var color := Color("4a3530")

	func _init(glyph := "pause", size_px := 28.0) -> void:
		kind = glyph
		custom_minimum_size = Vector2(size_px, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		match kind:
			"pause":
				var w := s.x * 0.16
				draw_line(Vector2(s.x * 0.32, s.y * 0.2), Vector2(s.x * 0.32, s.y * 0.8), color, w, true)
				draw_line(Vector2(s.x * 0.68, s.y * 0.2), Vector2(s.x * 0.68, s.y * 0.8), color, w, true)
				draw_circle(Vector2(s.x * 0.32, s.y * 0.2), w * 0.5, color)
				draw_circle(Vector2(s.x * 0.32, s.y * 0.8), w * 0.5, color)
				draw_circle(Vector2(s.x * 0.68, s.y * 0.2), w * 0.5, color)
				draw_circle(Vector2(s.x * 0.68, s.y * 0.8), w * 0.5, color)
