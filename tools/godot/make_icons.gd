extends SceneTree
## Rasterises icon.svg into the PNG launcher icons used by the export presets.
##
##   godot --headless --path . --script res://tools/godot/make_icons.gd

const OUT := "res://assets/icons/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	_save(svg, 192, "icon_192.png")
	_save(svg, 1024, "icon_1024.png")
	# Android adaptive icon: the cat alone, kept inside the centre safe zone.
	var fg := svg.replace('<rect width="256" height="256" rx="56" fill="#FAD7C0"/>', "")
	fg = fg.replace('viewBox="0 0 256 256"', 'viewBox="-80 -80 416 416"')
	_save(fg, 432, "adaptive_foreground_432.png")
	var bg := '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect width="256" height="256" fill="#FAD7C0"/></svg>'
	_save(bg, 432, "adaptive_background_432.png")
	quit()


func _save(svg: String, size: int, file: String) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, size / 256.0)
	if err != OK:
		push_error("could not rasterise %s" % file)
		return
	if img.get_width() != size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	img.save_png(OUT + file)
	print("wrote ", OUT + file, " ", img.get_size())
