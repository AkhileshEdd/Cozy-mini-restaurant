class_name IconFactory
extends Node
## Renders tiny transparent snapshots of the 3D models for the HUD, shop and
## order bubbles, so every icon matches the in-game assets exactly.

const SIZE := 192
const SPECS := {
	"latte": {"model": "food_latte", "pitch": 42.0},
	"cake": {"model": "food_cake", "pitch": 38.0},
	"pancakes": {"model": "food_pancakes", "pitch": 40.0},
	"soup": {"model": "food_soup", "pitch": 50.0},
	"sundae": {"model": "food_sundae", "pitch": 22.0},
	"coin": {"model": "coin", "pitch": 8.0, "yaw": 18.0},
	"table": {"model": "table", "pitch": 28.0},
	"speed": {"model": "chef_cat", "pitch": 12.0},
	"plant": {"model": "plant_big", "pitch": 20.0},
	"cook": {"model": "station_oven", "pitch": 24.0},
	"rug": {"model": "rug", "pitch": 60.0},
	"tray": {"model": "tray", "pitch": 50.0},
	"lights": {"model": "lamp_pendant", "pitch": 10.0, "center": Vector3(0, 0.05, 0), "radius": 0.3},
	"heart": {"model": "emote_heart", "pitch": 0.0},
}

static var icons: Dictionary = {}


static func get_icon(id: String) -> Texture2D:
	if icons.has(id):
		return icons[id]
	return _placeholder(Color("f3e6d8"))


func build() -> void:
	if DisplayServer.get_name() == "headless":
		for id in SPECS:
			var tint := Color("f3e6d8")
			if GameState.DISHES.has(id):
				tint = GameState.DISHES[id]["tint"]
			icons[id] = _placeholder(tint)
		return
	var jobs := {}
	for id in SPECS:
		jobs[id] = _stage(SPECS[id])
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for id in jobs:
		var vp: SubViewport = jobs[id]
		var img := vp.get_texture().get_image()
		if img == null or img.is_empty():
			icons[id] = _placeholder(Color("f3e6d8"))
		else:
			img.generate_mipmaps()
			icons[id] = ImageTexture.create_from_image(img)
		vp.queue_free()


func _stage(spec: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := WorldEnvironment.new()
	var e := CozyLook.make_environment()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_energy = 0.75
	env.environment = e
	vp.add_child(env)
	var sun := CozyLook.make_sun()
	sun.shadow_enabled = false
	sun.light_energy = 0.7
	vp.add_child(sun)

	var model: Node3D = load("res://assets/models/%s.glb" % spec["model"]).instantiate()
	vp.add_child(model)
	CozyLook.stylize(model, true)
	var cooking := model.find_child("Cooking", true, false)
	if cooking:
		cooking.visible = false

	var box := _aabb(model)
	var center: Vector3 = spec.get("center", box.get_center())
	var radius: float = spec.get("radius", box.size.length() * 0.5)
	var cam := Camera3D.new()
	cam.fov = 28.0
	var pitch := deg_to_rad(float(spec.get("pitch", 35.0)))
	var yaw := deg_to_rad(float(spec.get("yaw", 0.0)))
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.02
	vp.add_child(cam)
	cam.position = center + dir * dist
	cam.look_at(center, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	cam.current = true
	return vp


static func _aabb(root: Node) -> AABB:
	var result := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var local: AABB = _relative_transform(root, mi) * mi.get_aabb()
		result = local if first else result.merge(local)
		first = false
	return result


static func _relative_transform(root: Node, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			if Vector2(x - 31.5, y - 31.5).length() < 22.0:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
