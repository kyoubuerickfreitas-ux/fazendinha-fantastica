class_name UIStyle
## Estilo visual da interface: madeira rústica + natural minimalista.

const WOOD := Color("765137")
const WOOD_LIGHT := Color("a8784f")
const WOOD_DARK := Color("553926")
const GREEN := Color("78945b")
const GREEN_LIGHT := Color("b6c995")
const CREAM := Color("e9ddbb")
const EARTH := Color("776b52")
const INK := Color("2b2118")
const SLOT_BG := Color("4a3324")


static func panel(bg: Color = CREAM, border: Color = WOOD, border_w: int = 3, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.08, 0.05, 0.03, 0.35)
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 2)
	s.set_content_margin_all(6)
	return s


static func wood_panel() -> StyleBoxFlat:
	var s := panel(WOOD, WOOD_DARK, 2, 6)
	s.set_content_margin_all(4)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12
	t.set_color("font_color", "Label", INK)

	var btn := panel(WOOD_LIGHT, WOOD, 2, 5)
	btn.set_content_margin_all(4)
	btn.content_margin_left = 8
	btn.content_margin_right = 8
	var btn_h := btn.duplicate() as StyleBoxFlat
	btn_h.bg_color = Color("b98a5f")
	var btn_p := btn.duplicate() as StyleBoxFlat
	btn_p.bg_color = WOOD
	var btn_d := btn.duplicate() as StyleBoxFlat
	btn_d.bg_color = Color("bfae8c")
	btn_d.border_color = EARTH
	for st in [["normal", btn], ["hover", btn_h], ["pressed", btn_p], ["disabled", btn_d], ["focus", StyleBoxEmpty.new()]]:
		t.set_stylebox(st[0], "Button", st[1])
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color("8a7a5e"))
	t.set_font_size("font_size", "Button", 12)

	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())

	var bar_bg := panel(Color("3a2a1d"), WOOD_DARK, 1, 3)
	bar_bg.set_content_margin_all(0)
	bar_bg.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_constant("separation", "VBoxContainer", 4)
	t.set_constant("separation", "HBoxContainer", 4)
	return t


static func bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	s.border_color = color.lightened(0.25)
	s.border_width_top = 2
	return s


static func label(text: String, size: int = 12, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func outlined_label(text: String, size: int = 12) -> Label:
	var l := label(text, size, CREAM)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4)
	return l
