class_name CozyLook
extends RefCounted
## Shared art direction for the whole game: soft wrapped diffuse, a light rim,
## a warm key light and a peach/lavender ambient fill (see the art sheet).
##
## Imported .glb materials are swapped for one shared material per palette
## colour, which keeps the look consistent and the draw state small.

const BACKGROUND := Color("fbe1d3")
const AMBIENT := Color("f6e2ee")
const SUN_COLOR := Color("fff1de")

static var _materials: Dictionary = {}
static var _ghost: StandardMaterial3D


## Swap imported materials for shared cozy ones. `rim` adds a soft edge light,
## which suits characters and props but not big room surfaces.
static func stylize(root: Node, rim := false) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if src != null:
				mi.set_surface_override_material(s, material_for(src, rim))


static func material_for(src: StandardMaterial3D, rim := false) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [src.resource_name, src.albedo_color.to_html(), rim]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = src.resource_name
	m.albedo_color = src.albedo_color
	m.roughness = src.roughness
	m.metallic = src.metallic
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.rim_enabled = rim
	m.rim = 0.25
	m.rim_tint = 0.8
	if src.emission_enabled:
		m.emission_enabled = true
		m.emission = src.emission
		m.emission_energy_multiplier = 0.55
	if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.rim_enabled = false
	_materials[key] = m
	return m


## A see-through pastel look used for things that are not bought yet.
static func ghostify(root: Node, enabled: bool) -> void:
	if _ghost == null:
		_ghost = StandardMaterial3D.new()
		_ghost.albedo_color = Color(1, 1, 1, 0.38)
		_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name == "Blob":
			mi.visible = not enabled
			continue
		mi.material_override = _ghost if enabled else null
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static var _blob_mat: StandardMaterial3D


## Soft round contact shadow lying on the floor.
static func blob(size: Vector2) -> MeshInstance3D:
	if _blob_mat == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_texture = tex
		_blob_mat.albedo_color = Color(0.36, 0.22, 0.2, 0.3)
		_blob_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mi.mesh = plane
	mi.material_override = _blob_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Blob"
	return mi


static func add_blob(parent: Node3D, size: Vector2, offset := Vector3.ZERO) -> MeshInstance3D:
	var b := blob(size)
	parent.add_child(b)
	b.position = offset + Vector3(0, 0.012, 0)
	return b


static func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = 0.66
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	return env


static func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = SUN_COLOR
	sun.light_energy = 0.46
	# No shadow maps: the Compatibility renderer draws shadowed lights in an
	# extra pass that blends in sRGB space and blows out the palette. Soft blob
	# shadows (see blob()) ground things instead, and they are cheaper on phones.
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-58, -32, 0)
	return sun
