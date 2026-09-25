class_name Hud
extends CanvasLayer
## All 2D UI: top bar, tray + hint panel, toasts, day card, results/shop and pause.

signal open_pressed
signal next_day_pressed
signal buy_pressed(id: String)
signal pause_changed(paused: bool)
signal reset_confirmed

const TIPS := [
	"Tap a station to start cooking. Tap it again when the dish is ready.",
	"You can queue up to five taps. Chef Mochi will do them in order.",
	"Serve guests quickly for bigger tips!",
	"Coins wait on the table until you tap them. Tidy tables welcome new guests.",
	"Each station matches its dish colour. Look at the order bubbles!",
	"A red ring means a guest is about to leave. Hurry!",
]

var root: Control
var _coin_label: Label
var _coin_pill: Control
var _coin_icon: TextureRect
var _day_label: Label
var _day_fill: Panel
var _rating_label: Label
var _hint: Label
var _tray_box: HBoxContainer
var _toast: Label
var _overlay: ColorRect
var _day_card: PanelContainer
var _results: PanelContainer
var _pause_menu: PanelContainer
var _shop_list: VBoxContainer
var _shop_coins: Label
var _sound_btn: Button
var _music_btn: Button
var _reset_btn: Button
var _reset_armed := false
var _shown_coins := 0
var _top_margin: MarginContainer
var _bottom_margin: MarginContainer


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = CozyTheme.build()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_top_bar()
	_build_bottom()
	_build_toast()
	_overlay = ColorRect.new()
	_overlay.color = Color(0.29, 0.21, 0.19, 0.28)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	root.add_child(_overlay)
	_build_day_card()
	_build_results()
	_build_pause()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_shown_coins = GameState.coins
	set_coins(GameState.coins, false)
	GameState.coins_changed.connect(func(c: int): _refresh_shop_coins(c))


# -- building ----------------------------------------------------------------

func _pill() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Pill"
	return p


func _label(text: String, size := 28, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", size)
	return l


func _hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _icon(tex: Texture2D, size := 48) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _build_top_bar() -> void:
	_top_margin = MarginContainer.new()
	_top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		_top_margin.add_theme_constant_override("margin_" + side, 18)
	root.add_child(_top_margin)
	var bar := _hbox(10)
	_top_margin.add_child(bar)

	_coin_pill = _pill()
	var coin_row := _hbox(6)
	_coin_icon = _icon(null, 50)
	coin_row.add_child(_coin_icon)
	_coin_label = _label("0", 34)
	_coin_label.custom_minimum_size.x = 70
	coin_row.add_child(_coin_label)
	_coin_pill.add_child(coin_row)
	bar.add_child(_coin_pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	var day_pill := _pill()
	var day_col := _vbox(4)
	_day_label = _label("Day 1", 26)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_col.add_child(_day_label)
	var track := Panel.new()
	track.custom_minimum_size = Vector2(150, 10)
	track.add_theme_stylebox_override("panel", CozyTheme.box(CozyTheme.LINEN, 5, 0))
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_fill = Panel.new()
	_day_fill.add_theme_stylebox_override("panel", CozyTheme.box(CozyTheme.GINGER, 5, 0))
	_day_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_fill.size = Vector2(0, 10)
	track.add_child(_day_fill)
	day_col.add_child(track)
	day_pill.add_child(day_col)
	bar.add_child(day_pill)

	var spacer2 := spacer.duplicate()
	bar.add_child(spacer2)

	var rating_pill := _pill()
	var rating_row := _hbox(6)
	var star := Widgets.StarRow.new(30, 1)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rating_row.add_child(star)
	_rating_label = _label("4.0", 30)
	rating_row.add_child(_rating_label)
	rating_pill.add_child(rating_row)
	bar.add_child(rating_pill)

	var pause := Button.new()
	pause.theme_type_variation = "RoundButton"
	pause.custom_minimum_size = Vector2(66, 66)
	pause.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause.tooltip_text = "Pause"
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(Widgets.Glyph.new("pause", 28))
	pause.add_child(center)
	pause.pressed.connect(func(): _set_paused(true))
	bar.add_child(pause)


func _build_bottom() -> void:
	_bottom_margin = MarginContainer.new()
	_bottom_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		_bottom_margin.add_theme_constant_override("margin_" + side, 18)
	root.add_child(_bottom_margin)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Row"
	panel.add_theme_stylebox_override("panel", CozyTheme.box(CozyTheme.WHITE, 34, 18, true))
	_bottom_margin.add_child(panel)
	var row := _hbox(14)
	panel.add_child(row)
	var text_col := _vbox(2)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_child(_label("Tray", 28))
	_hint = _label("", 22, "Body")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(250, 58)
	text_col.add_child(_hint)
	row.add_child(text_col)
	_tray_box = _hbox(10)
	_tray_box.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(_tray_box)
	set_tray([], GameState.carry_capacity())


func _build_toast() -> void:
	_toast = _label("", 44)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", CozyTheme.CREAM)
	_toast.add_theme_constant_override("outline_size", 16)
	_toast.add_theme_color_override("font_color", CozyTheme.TOMATO)
	_toast.position = Vector2(-300, 190)
	_toast.size = Vector2(600, 60)
	_toast.pivot_offset = Vector2(300, 30)
	_toast.modulate.a = 0.0
	root.add_child(_toast)


func _centered_card(variation := "Card", width := 600.0) -> PanelContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = variation
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.custom_minimum_size = Vector2(width, 0)
	c.visible = false
	root.add_child(c)
	return c


func _build_day_card() -> void:
	_day_card = _centered_card("Card", 600)


func _build_results() -> void:
	_results = PanelContainer.new()
	_results.theme_type_variation = "Sheet"
	_results.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.visible = false
	root.add_child(_results)


func _build_pause() -> void:
	_pause_menu = _centered_card("Card", 520)
	var col := _vbox(18)
	_pause_menu.add_child(col)
	var title := _label("Paused", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func(): _set_paused(false))
	col.add_child(resume)
	_sound_btn = Button.new()
	_sound_btn.theme_type_variation = "SoftButton"
	_sound_btn.pressed.connect(func():
		GameState.sound_on = not GameState.sound_on
		GameState.save_game()
		_refresh_pause())
	col.add_child(_sound_btn)
	_music_btn = Button.new()
	_music_btn.theme_type_variation = "SoftButton"
	_music_btn.pressed.connect(func():
		GameState.music_on = not GameState.music_on
		GameState.save_game()
		Audio.apply_settings()
		_refresh_pause())
	col.add_child(_music_btn)
	_reset_btn = Button.new()
	_reset_btn.theme_type_variation = "SoftButton"
	_reset_btn.pressed.connect(_on_reset_pressed)
	col.add_child(_reset_btn)
	_refresh_pause()


func _apply_safe_area() -> void:
	var top := 20.0
	var bottom := 22.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		var vp := root.get_viewport_rect().size
		if screen.y > 0:
			top += safe.position.y * vp.y / screen.y
			bottom += maxf(0.0, screen.y - safe.end.y) * vp.y / screen.y
	_top_margin.add_theme_constant_override("margin_top", int(top))
	_bottom_margin.add_theme_constant_override("margin_bottom", int(bottom))


# -- live values ---------------------------------------------------------------

## Call once the 3D icon snapshots exist.
func refresh_icons() -> void:
	_coin_icon.texture = IconFactory.get_icon("coin")
	set_tray([], GameState.carry_capacity())


func refresh_shop() -> void:
	if _results.visible and _shop_list and is_instance_valid(_shop_list):
		_fill_shop()


func set_coins(amount: int, bump := true) -> void:
	_shown_coins = amount
	_coin_label.text = str(amount)
	if bump:
		_bump(_coin_pill)


func set_day(day: int, frac: float, clock: String) -> void:
	_day_label.text = "Day %d · %s" % [day, clock]
	_day_fill.size = Vector2(150.0 * clampf(frac, 0.0, 1.0), 10)


func set_rating(value: float) -> void:
	_rating_label.text = "%.1f" % value


func set_hint(text: String) -> void:
	if _hint.text != text:
		_hint.text = text


func set_tray(dishes: Array, capacity: int) -> void:
	for c in _tray_box.get_children():
		c.queue_free()
	for i in capacity:
		var slot := PanelContainer.new()
		slot.theme_type_variation = "Slot"
		slot.custom_minimum_size = Vector2(88, 88)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < dishes.size():
			var tint: Color = GameState.DISHES[dishes[i]]["tint"]
			slot.add_theme_stylebox_override("panel", CozyTheme.box(tint.lightened(0.55), 26, 4))
			slot.add_child(_icon(IconFactory.get_icon(dishes[i]), 76))
		_tray_box.add_child(slot)


func toast(text: String, color := CozyTheme.TOMATO) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	var t := create_tween()
	_toast.scale = Vector2.ONE * 0.6
	_toast.modulate.a = 1.0
	t.tween_property(_toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.3)
	t.tween_property(_toast, "modulate:a", 0.0, 0.4)


func coin_target() -> Vector2:
	return _coin_icon.get_global_rect().get_center()


## Coins fly from a screen point into the coin pill, then `done` is called.
func fly_coins(from: Vector2, amount: int, done: Callable) -> void:
	var n := clampi(amount / 6 + 2, 3, 8)
	var target := coin_target()
	for i in n:
		var c := _icon(IconFactory.get_icon("coin"), 44)
		c.position = from - Vector2(22, 22) + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		root.add_child(c)
		var mid := c.position.lerp(target - Vector2(22, 22), 0.5) + Vector2(randf_range(-120, 120), -120)
		var start := c.position
		var end := target - Vector2(22, 22)
		var curve := func(k: float) -> void:
			c.position = start.lerp(mid, k).lerp(mid.lerp(end, k), k)
		var t := create_tween()
		t.tween_interval(i * 0.05)
		t.tween_method(curve, 0.0, 1.0, 0.55).set_ease(Tween.EASE_IN)
		t.tween_callback(c.queue_free)
		if i == n - 1:
			t.tween_callback(done)


# -- modal screens ---------------------------------------------------------------

func _modal(panel: Control, on: bool) -> void:
	_overlay.visible = on
	panel.visible = on
	if on:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2.ONE * 0.85
		panel.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)


func any_modal_open() -> bool:
	return _day_card.visible or _results.visible or _pause_menu.visible


func show_day_card(day: int, menu: Array[String]) -> void:
	for c in _day_card.get_children():
		c.queue_free()
	var col := _vbox(16)
	_day_card.add_child(col)
	var title := _label("Day %d" % day, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := _label("Welcome to Mochi's café! Today's menu:" if day == 1 else "Today's menu", 26, "Body")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var dishes := _hbox(8)
	dishes.alignment = BoxContainer.ALIGNMENT_CENTER
	for d in menu:
		var item := _vbox(0)
		item.add_child(_icon(IconFactory.get_icon(d), 96))
		var price := _label(str(GameState.dish_price(d)), 24)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(price)
		dishes.add_child(item)
	col.add_child(dishes)
	var tip := _label(TIPS[(day - 1) % TIPS.size()], 22, "Body")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.custom_minimum_size = Vector2(520, 0)
	col.add_child(tip)
	var open := Button.new()
	open.text = "Open café"
	open.custom_minimum_size = Vector2(0, 92)
	open.pressed.connect(func():
		Audio.play("tap")
		_modal(_day_card, false)
		open_pressed.emit())
	col.add_child(open)
	_modal(_day_card, true)
	_center(_day_card)


func show_results(summary: Dictionary) -> void:
	for c in _results.get_children():
		c.queue_free()
	var col := _vbox(16)
	_results.add_child(col)
	col.add_child(_spacer(_top_margin.get_theme_constant("margin_top") + 10))

	var head := PanelContainer.new()
	head.theme_type_variation = "Card"
	var head_col := _vbox(10)
	head.add_child(head_col)
	var title := _label("Day %d done!" % summary["day"], 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head_col.add_child(title)
	var stars := Widgets.StarRow.new(46, 5)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stars.set_value(summary["stars"])
	head_col.add_child(stars)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	for pair in [[str(summary["served"]), "guests served"], [str(summary["earned"]), "coins earned"], [str(summary["grumpy"]), "left grumpy"]]:
		var cell := _vbox(0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var big := _label(pair[0], 40)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(big)
		var small := _label(pair[1], 20, "Body")
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(small)
		grid.add_child(cell)
	head_col.add_child(grid)
	col.add_child(head)

	var shop_head := _hbox(10)
	var shop_title := _label("Café shop", 38)
	shop_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_head.add_child(shop_title)
	var coin_pill := _pill()
	var coin_row := _hbox(6)
	coin_row.add_child(_icon(IconFactory.get_icon("coin"), 40))
	_shop_coins = _label(str(GameState.coins), 30)
	coin_row.add_child(_shop_coins)
	coin_pill.add_child(coin_row)
	shop_head.add_child(coin_pill)
	col.add_child(shop_head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_list = _vbox(12)
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_shop_list)
	col.add_child(scroll)
	_fill_shop()

	var next := Button.new()
	next.text = "Open day %d" % (summary["day"] + 1)
	next.custom_minimum_size = Vector2(0, 96)
	next.pressed.connect(func():
		Audio.play("tap")
		_modal(_results, false)
		next_day_pressed.emit())
	col.add_child(next)
	col.add_child(_spacer(_bottom_margin.get_theme_constant("margin_bottom")))
	_modal(_results, true)


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _fill_shop() -> void:
	for c in _shop_list.get_children():
		c.queue_free()
	for u in GameState.UPGRADES:
		var id: String = u["id"]
		var cost := GameState.next_cost(id)
		var lvl := GameState.level(id)
		var max_lvl: int = u["costs"].size()
		var row := PanelContainer.new()
		row.theme_type_variation = "Row"
		var h := _hbox(14)
		row.add_child(h)
		var icon_bg := PanelContainer.new()
		icon_bg.add_theme_stylebox_override("panel", CozyTheme.box(_upgrade_tint(id), 22, 2))
		icon_bg.custom_minimum_size = Vector2(84, 84)
		icon_bg.add_child(_icon(IconFactory.get_icon(u["icon"]), 78))
		h.add_child(icon_bg)
		var text := _vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_text: String = u["name"]
		if max_lvl > 1:
			name_text += "  %d/%d" % [lvl, max_lvl]
		text.add_child(_label(name_text, 26))
		var desc := _label(u["desc"], 20, "Body")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(300, 0)
		text.add_child(desc)
		h.add_child(text)
		if cost < 0:
			var owned := _label("Owned", 24)
			owned.add_theme_color_override("font_color", CozyTheme.MINT_INK)
			owned.custom_minimum_size = Vector2(118, 0)
			owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			owned.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(owned)
		else:
			var buy := Button.new()
			buy.theme_type_variation = "BuyButton"
			buy.text = str(cost)
			buy.custom_minimum_size = Vector2(118, 72)
			buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			buy.disabled = GameState.coins < cost
			buy.pressed.connect(func(): buy_pressed.emit(id))
			h.add_child(buy)
		_shop_list.add_child(row)


func _refresh_shop_coins(c: int) -> void:
	if _shop_coins and is_instance_valid(_shop_coins):
		_shop_coins.text = str(c)


func _upgrade_tint(id: String) -> Color:
	match id:
		"griddle": return Color("fff3cc")
		"soup": return Color("e3f0fa")
		"freezer": return Color("eee8fa")
		"plants", "cook": return CozyTheme.MINT_BG
		"lights", "speed": return Color("fde6ea")
	return Color("fff1e0")


func _set_paused(on: bool) -> void:
	Audio.play("tap")
	_reset_armed = false
	_refresh_pause()
	_modal(_pause_menu, on)
	if on:
		_center(_pause_menu)
	pause_changed.emit(on)


func _refresh_pause() -> void:
	_sound_btn.text = "Sound: %s" % ("On" if GameState.sound_on else "Off")
	_music_btn.text = "Music: %s" % ("On" if GameState.music_on else "Off")
	_reset_btn.text = "Tap again to start over" if _reset_armed else "Start over"


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_refresh_pause()
		return
	_reset_armed = false
	_modal(_pause_menu, false)
	pause_changed.emit(false)
	reset_confirmed.emit()


func is_paused_menu_open() -> bool:
	return _pause_menu.visible


func open_pause() -> void:
	if not any_modal_open():
		_set_paused(true)


func _center(panel: Control) -> void:
	await get_tree().process_frame
	panel.reset_size()
	panel.position = (root.get_viewport_rect().size - panel.size) * 0.5
	panel.pivot_offset = panel.size * 0.5


func _bump(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE * 1.12, 0.08)
	t.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
