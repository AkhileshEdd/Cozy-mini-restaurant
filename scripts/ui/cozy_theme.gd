class_name CozyTheme
extends RefCounted
## UI theme built from the art sheet: Fredoka type, cream cards, pill buttons.

const INK := Color("4a3530")
const INK_SOFT := Color("6b5048")
const CREAM := Color("fff6ec")
const PEACH := Color("fad7c0")
const WHITE := Color("ffffff")
const GINGER := Color("f4a259")
const GINGER_DARK := Color("e08e45")
const TOMATO := Color("c94f45")
const TOMATO_DARK := Color("a83f37")
const MINT_BG := Color("e4f5ec")
const MINT_INK := Color("2f6b4e")
const LINEN := Color("f3e6d8")
const FONT := preload("res://assets/fonts/Fredoka-SemiBold.ttf")
const FONT_BODY := preload("res://assets/fonts/Fredoka-Medium.ttf")


static func box(color: Color, radius := 28, pad := 16, shadow := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = Color(0.29, 0.21, 0.19, 0.14)
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 5)
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 28

	t.set_color("font_color", "Label", INK)
	t.set_font("font", "Label", FONT)

	t.set_type_variation("Body", "Label")
	t.set_font("font", "Body", FONT_BODY)
	t.set_font_size("font_size", "Body", 24)
	t.set_color("font_color", "Body", INK_SOFT)

	t.set_type_variation("Title", "Label")
	t.set_font_size("font_size", "Title", 52)

	t.set_type_variation("Pill", "PanelContainer")
	t.set_stylebox("panel", "Pill", box(WHITE, 40, 10, true))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(CREAM, 36, 24, true))
	t.set_type_variation("Row", "PanelContainer")
	t.set_stylebox("panel", "Row", box(WHITE, 30, 14))
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", box(PEACH, 44, 22, true))
	t.set_type_variation("Slot", "PanelContainer")
	var slot := box(LINEN, 26, 6)
	t.set_stylebox("panel", "Slot", slot)

	_button(t, "Button", TOMATO, TOMATO_DARK, WHITE, 34)
	_button(t, "BuyButton", GINGER, GINGER_DARK, Color("3a2420"), 30)
	_button(t, "SoftButton", WHITE, LINEN, INK, 28)
	_button(t, "RoundButton", WHITE, LINEN, INK, 28, 999, 0)
	return t


static func _button(t: Theme, type: String, bg: Color, pressed: Color, fg: Color, size: int, radius := 999, pad := 18) -> void:
	if type != "Button":
		t.set_type_variation(type, "Button")
	var normal := box(bg, radius, pad, true)
	normal.content_margin_left = pad + 10
	normal.content_margin_right = pad + 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.06)
	var down := normal.duplicate() as StyleBoxFlat
	down.bg_color = pressed
	down.shadow_size = 3
	down.shadow_offset = Vector2(0, 2)
	var off := normal.duplicate() as StyleBoxFlat
	off.bg_color = LINEN
	off.shadow_size = 0
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, down)
	t.set_stylebox("hover_pressed", type, down)
	t.set_stylebox("disabled", type, off)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, fg)
	t.set_color("font_hover_color", type, fg)
	t.set_color("font_pressed_color", type, fg)
	t.set_color("font_hover_pressed_color", type, fg)
	t.set_color("font_focus_color", type, fg)
	t.set_color("font_disabled_color", type, INK_SOFT)
	t.set_font_size("font_size", type, size)
