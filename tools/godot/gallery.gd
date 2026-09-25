extends Node3D
## Asset contact sheet: lays out generated models in a grid and saves a PNG.
##
##   godot --path . res://tools/godot/gallery.tscn -- --models=chef_cat,cust_bunny --out=user://gallery.png
##
## Needs a real renderer (not --headless). Without --models every model is shown.

const MODEL_DIR := "res://assets/models/"


func _ready() -> void:
	var args := _parse_args()
	var names: PackedStringArray = []
	if args.has("models"):
		names = String(args["models"]).split(",")
	else:
		for f in DirAccess.get_files_at(MODEL_DIR):
			if f.ends_with(".glb") and f != "room.glb":
				names.append(f.get_basename())
	var pitch := float(args.get("pitch", "35"))
	var yaw := float(args.get("yaw", "0"))
	var out := String(args.get("out", "user://gallery.png"))

	var env := WorldEnvironment.new()
	env.environment = CozyLook.make_environment()
	add_child(env)
	add_child(CozyLook.make_sun())

	var cols := int(args.get("cols", str(int(ceil(sqrt(names.size()))))))
	var cursor := Vector3.ZERO
	var row_depth := 0.0
	var total := AABB()
	var first := true
	for i in names.size():
		var scene: PackedScene = load(MODEL_DIR + names[i] + ".glb")
		var inst := scene.instantiate() as Node3D
		add_child(inst)
		CozyLook.stylize(inst, names[i] != "room")
		var cooking := inst.find_child("Cooking", true, false)
		if cooking and args.get("cooking", "0") == "0":
			cooking.visible = false
		var box := _aabb(inst)
		inst.position = cursor - Vector3(box.position.x, 0, box.end.z)
		var placed := AABB(box.position + inst.position, box.size)
		total = placed if first else total.merge(placed)
		first = false
		cursor.x += box.size.x + 0.25
		row_depth = max(row_depth, box.size.z)
		if (i + 1) % cols == 0:
			cursor.x = 0
			cursor.z -= row_depth + 0.35
			row_depth = 0.0

	var cam := Camera3D.new()
	cam.fov = 30
	var vp := get_viewport().get_visible_rect().size
	if vp.x > vp.y:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	var center := total.get_center()
	var radius := total.size.length() * 0.5
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * float(args.get("zoom", "0.9"))
	var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
	cam.position = center + dir * dist
	cam.look_at(center)
	cam.current = true

	for k in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", ProjectSettings.globalize_path(out))
	get_tree().quit()


func _aabb(root: Node) -> AABB:
	var result := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var local: AABB = m.global_transform * m.get_aabb()
		result = local if first else result.merge(local)
		first = false
	return result


func _parse_args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			d[kv[0]] = kv[1]
	return d
