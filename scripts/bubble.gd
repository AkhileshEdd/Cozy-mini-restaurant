class_name Bubble
extends MeshInstance3D
## Floating order / progress bubble (see shaders/bubble.gdshader).

const SHADER := preload("res://shaders/bubble.gdshader")

var _mat: ShaderMaterial
var _tween: Tween


func _init(size := 0.7, tail := true) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = 10
	_mat.set_shader_parameter("show_tail", 1.0 if tail else 0.0)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func set_icon(tex: Texture2D) -> void:
	_mat.set_shader_parameter("icon", tex)


func set_progress(value: float, color: Color) -> void:
	_mat.set_shader_parameter("progress", clampf(value, 0.0, 1.0))
	_mat.set_shader_parameter("ring_color", color)


func set_ring_visible(on: bool) -> void:
	_mat.set_shader_parameter("show_ring", 1.0 if on else 0.0)


func pop_in() -> void:
	visible = true
	scale = Vector3.ONE * 0.2
	_kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func pop_out() -> void:
	if not visible:
		return
	_kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3.ONE * 0.1, 0.18).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): visible = false)


func wobble() -> void:
	_kill()
	scale = Vector3.ONE
	_tween = create_tween()
	for i in 2:
		_tween.tween_property(self, "scale", Vector3(1.22, 0.84, 1.0), 0.07)
		_tween.tween_property(self, "scale", Vector3(0.9, 1.1, 1.0), 0.07)
	_tween.tween_property(self, "scale", Vector3.ONE, 0.08)


func pulse() -> void:
	_kill()
	visible = true
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "scale", Vector3.ONE * 1.12, 0.35).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_SINE)


func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
