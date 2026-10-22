extends Node
## Renders big transparent portraits of the cast and dishes for the video ad.
##
##   xvfb-run godot --rendering-driver opengl3 --path . res://tools/godot/ad_portraits.tscn -- --out=build/ad/portraits

const SIZE := 720
## name -> [model, pitch, look-at height or -1 for the model's centre, radius or -1]
const SPECS := {
	"chef": ["chef_cat", 10.0, -1.0, -1.0],
	"bunny": ["cust_bunny", 10.0, -1.0, -1.0],
	"bear": ["cust_bear", 10.0, -1.0, -1.0],
	"frog": ["cust_frog", 10.0, -1.0, -1.0],
	"chick": ["cust_chick", 10.0, -1.0, -1.0],
	"panda": ["cust_panda", 10.0, -1.0, -1.0],
	"penguin": ["helper_penguin", 10.0, -1.0, -1.0],
	"hamster": ["helper_hamster", 10.0, -1.0, -1.0],
	"latte": ["food_latte", 40.0, -1.0, -1.0],
	"cake": ["food_cake", 36.0, -1.0, -1.0],
	"pancakes": ["food_pancakes", 38.0, -1.0, -1.0],
	"soup": ["food_soup", 46.0, -1.0, -1.0],
	"sundae": ["food_sundae", 22.0, -1.0, -1.0],
	"coin": ["coin", 8.0, -1.0, -1.0],
	"heart": ["emote_heart", 0.0, -1.0, -1.0],
}

var out_dir := "build/ad/portraits"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var jobs := {}
	for id in SPECS:
		jobs[id] = _stage(SPECS[id])
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for id in jobs:
		var img: Image = jobs[id].get_texture().get_image()
		img.save_png(out_dir.path_join(id + ".png"))
	print("portraits saved to ", out_dir)
	get_tree().quit()


func _stage(spec: Array) -> SubViewport:
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
	var model: Node3D = load("res://assets/models/%s.glb" % spec[0]).instantiate()
	vp.add_child(model)
	CozyLook.stylize(model, true)
	var cooking := model.find_child("Cooking", true, false)
	if cooking:
		cooking.visible = false
	var box := IconFactory._aabb(model)
	var center := box.get_center() if spec[2] < 0 else Vector3(0, spec[2], 0)
	var radius: float = maxf(box.size.y, box.size.x) * 0.56 if spec[3] < 0 else spec[3]
	var cam := Camera3D.new()
	cam.fov = 28.0
	var pitch := deg_to_rad(spec[1])
	var dir := Vector3(0, sin(pitch), cos(pitch))
	vp.add_child(cam)
	cam.position = center + dir * radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.04
	cam.look_at(center, Vector3.UP)
	cam.current = true
	return vp
