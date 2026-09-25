class_name FX
extends RefCounted
## Small bits of juice: squash and pop tweens, sparkles, steam, floating text and emotes.

const FONT := preload("res://assets/fonts/Fredoka-SemiBold.ttf")
const SPARKLE_COLORS := [Color("ffd66b"), Color("f48fa0"), Color("9ed9b8"), Color("9ccbeb"), Color("c6b4e8")]

static var _sphere: SphereMesh
static var _emotes: Dictionary = {}


static func squash(node: Node3D, amount := 0.15, time := 0.28) -> void:
	if node == null or not node.is_inside_tree():
		return
	var base := Vector3.ONE
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector3(1 + amount, 1 - amount, 1 + amount), time * 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", base, time * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func pop_in(node: Node3D, time := 0.35) -> void:
	node.scale = Vector3.ONE * 0.15
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector3.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _dot_mesh() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.035
		_sphere.height = 0.07
		_sphere.radial_segments = 8
		_sphere.rings = 4
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sphere.material = m
	return _sphere


static func sparkles(parent: Node, pos: Vector3, amount := 18) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _dot_mesh()
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -4.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	var init := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in SPARKLE_COLORS.size():
		offsets.append(float(i) / SPARKLE_COLORS.size())
		colors.append(SPARKLE_COLORS[i])
	init.offsets = offsets
	init.colors = colors
	init.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = init
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


static func make_steam() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 8
	mesh.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	mesh.material = m
	p.mesh = mesh
	p.amount = 10
	p.lifetime = 1.4
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.6
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1, 1.3))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.75))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = grad
	return p


static func float_text(parent: Node, pos: Vector3, text: String, color := Color("b4533f"), size := 72) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = size
	l.pixel_size = 0.0045
	l.outline_size = 20
	l.outline_modulate = Color("fff6ec")
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	parent.add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.3
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "position:y", l.position.y + 0.9, 1.2).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


static func emote(parent: Node, pos: Vector3, kind: String) -> void:
	var path := "res://assets/models/emote_%s.glb" % kind
	if not _emotes.has(kind):
		_emotes[kind] = load(path)
	var e: Node3D = (_emotes[kind] as PackedScene).instantiate()
	CozyLook.stylize(e, true)
	parent.add_child(e)
	e.global_position = pos
	e.scale = Vector3.ONE * 0.1
	var t := e.create_tween()
	t.tween_property(e, "scale", Vector3.ONE * 1.4, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(e, "position:y", e.position.y + 0.5, 1.1).set_ease(Tween.EASE_OUT)
	t.tween_property(e, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	t.tween_callback(e.queue_free)
	var spin := e.create_tween().set_loops(3)
	spin.tween_property(e, "rotation:y", 0.35, 0.18)
	spin.tween_property(e, "rotation:y", -0.35, 0.18)
