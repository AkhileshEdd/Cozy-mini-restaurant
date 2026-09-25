class_name Critter
extends Node3D
## Shared body for the chef and the guests: loads a character .glb, follows
## paths on the floor and animates its parts procedurally (no skeleton).

const PARTS := ["Body", "Head", "ArmL", "ArmR", "FootL", "FootR", "Hold"]

var model: Node3D
var parts: Dictionary = {}
var base: Dictionary = {}
var path := PackedVector3Array()
var speed := 1.6
var walking := false
var holding := false
var eating := false
var nervous := 0.0
var yaw_target := 0.0
var jump := 0.0

var _t := 0.0
var _idle_t := 0.0


const SCALE := 1.12

var _blob: MeshInstance3D


func load_model(scene: PackedScene) -> void:
	var rig := Node3D.new()
	rig.name = "Rig"
	rig.scale = Vector3.ONE * SCALE
	add_child(rig)
	model = scene.instantiate()
	rig.add_child(model)
	_blob = CozyLook.blob(Vector2(0.8, 0.8))
	add_child(_blob)
	CozyLook.stylize(model, true)
	for n in PARTS:
		var p := model.find_child(n, true, false) as Node3D
		if p:
			parts[n] = p
			base[n] = p.position
	_idle_t = randf() * 10.0


func set_path(points: PackedVector3Array) -> void:
	path = points
	walking = not path.is_empty()


## Moves along the current path; returns true on the frame the path is finished.
func step_path(delta: float) -> bool:
	if path.is_empty():
		walking = false
		return false
	var target := path[0]
	var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var dist := to.length()
	var step := speed * delta
	if dist > 0.001:
		yaw_target = atan2(to.x, to.z)
	if dist <= step:
		global_position = Vector3(target.x, global_position.y, target.z)
		path.remove_at(0)
		if path.is_empty():
			walking = false
			return true
	else:
		global_position += to / dist * step
	return false


func face(point: Vector3) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		yaw_target = atan2(d.x, d.z)


func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw_target, 1.0 - exp(-12.0 * delta))
	_animate(delta)
	if _blob:
		_blob.global_position = Vector3(global_position.x, 0.014, global_position.z)
		_blob.visible = global_position.y < 0.2


func _animate(delta: float) -> void:
	if parts.is_empty():
		return
	_idle_t += delta
	var body: Node3D = parts.get("Body")
	var head: Node3D = parts.get("Head")
	var arm_l: Node3D = parts.get("ArmL")
	var arm_r: Node3D = parts.get("ArmR")
	var foot_l: Node3D = parts.get("FootL")
	var foot_r: Node3D = parts.get("FootR")
	var bob := 0.0
	var arm_swing := 0.0
	var roll := 0.0
	if walking:
		_t += delta * (6.0 + speed * 2.2)
		var s := sin(_t)
		bob = absf(s) * 0.07
		arm_swing = s * 0.55
		roll = s * 0.07
		foot_l.position = base["FootL"] + Vector3(0, maxf(0.0, s) * 0.07, maxf(0.0, s) * 0.05)
		foot_r.position = base["FootR"] + Vector3(0, maxf(0.0, -s) * 0.07, maxf(0.0, -s) * 0.05)
	else:
		_t = 0.0
		foot_l.position = foot_l.position.lerp(base["FootL"], 1.0 - exp(-14.0 * delta))
		foot_r.position = foot_r.position.lerp(base["FootR"], 1.0 - exp(-14.0 * delta))
		bob = (sin(_idle_t * 2.2) * 0.5 + 0.5) * 0.012
	if nervous > 0.0:
		roll += sin(_idle_t * 22.0) * 0.06 * nervous
	model.position.y = bob + jump
	model.rotation.z = roll
	body.scale = Vector3(1.0, 1.0 + sin(_idle_t * 2.2) * 0.012, 1.0)
	var head_nod := 0.0
	if eating:
		head_nod = sin(_idle_t * 11.0) * 0.12 + 0.04
	head.rotation.x = lerpf(head.rotation.x, head_nod, 1.0 - exp(-10.0 * delta))
	head.rotation.z = sin(_idle_t * 1.3) * 0.04
	if holding:
		arm_l.rotation = Vector3(-1.25, 0.0, -0.25)
		arm_r.rotation = Vector3(-1.25, 0.0, 0.25)
	else:
		arm_l.rotation = Vector3(arm_swing, 0.0, 0.0)
		arm_r.rotation = Vector3(-arm_swing, 0.0, 0.0)


func hop_to(target: Vector3, yaw: float, time := 0.35) -> Tween:
	yaw_target = yaw
	var start := global_position
	var arc := func(k: float) -> void:
		var p := start.lerp(target, k)
		p.y += sin(k * PI) * 0.35
		global_position = p
	var t := create_tween()
	t.tween_method(arc, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func(): FX.squash(model, 0.14, 0.25))
	return t


func happy_jump() -> void:
	var t := create_tween()
	t.tween_property(self, "jump", 0.3, 0.16).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "jump", 0.0, 0.18).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): FX.squash(model, 0.15, 0.22))
