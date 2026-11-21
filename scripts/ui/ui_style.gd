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


# ------------------------------------------------------------------ arte das janelas (tools/import_windows.py)
const WIN := "res://assets/sprites/ui/win/"


static func tex_box(path: String, margins: Array, content: Array, modulate := Color.WHITE) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	s.texture_margin_left = margins[0]
	s.texture_margin_top = margins[1]
	s.texture_margin_right = margins[2]
	s.texture_margin_bottom = margins[3]
	s.content_margin_left = content[0]
	s.content_margin_top = content[1]
	s.content_margin_right = content[2]
	s.content_margin_bottom = content[3]
	s.modulate_color = modulate
	return s


## Moldura das janelas: viga de madeira em cima (onde ficam o título e o X), pergaminho e folhinhas.
static func window_frame() -> StyleBoxTexture:
	return tex_box(WIN + "frame.png", [28, 42, 28, 30], [14, 7, 14, 16])


## Plaquinha creme do título da janela.
static func title_plate() -> StyleBoxTexture:
	return tex_box(WIN + "title.png", [14, 6, 14, 6], [12, 3, 12, 4])


static func close_box(modulate := Color.WHITE) -> StyleBoxTexture:
	return tex_box(WIN + "close.png", [0, 0, 0, 0], [0, 0, 0, 0], modulate)


## Botão de madeira (red = vermelho, para ações perigosas como "Novo jogo").
static func wood_button(red := false, modulate := Color.WHITE) -> StyleBoxTexture:
	return tex_box(WIN + ("button_red.png" if red else "button.png"), [10, 8, 10, 8], [10, 4, 10, 5], modulate)


static func make_red(b: Button) -> void:
	for st in [["normal", Color.WHITE], ["hover", Color(1.1, 1.1, 1.1)], ["pressed", Color(0.85, 0.82, 0.8)]]:
		b.add_theme_stylebox_override(st[0], wood_button(true, st[1]))


static func wood_panel() -> StyleBoxFlat:
	var s := panel(WOOD, WOOD_DARK, 2, 6)
	s.set_content_margin_all(4)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12
	t.set_color("font_color", "Label", INK)

	for st in [["normal", Color.WHITE], ["hover", Color(1.1, 1.08, 1.05)], ["pressed", Color(0.82, 0.78, 0.74)],
			["disabled", Color(0.72, 0.66, 0.6, 0.8)]]:
		t.set_stylebox(st[0], "Button", wood_button(false, st[1]))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_outline_color", "Button", Color("3b2414"))
	t.set_constant("outline_size", "Button", 3)
	# controle deslizante: trilho marrom, parte cheia verde e a bolinha de madeira
	var track := StyleBoxFlat.new()
	track.bg_color = Color("8a5a3a")
	track.set_corner_radius_all(4)
	track.set_border_width_all(1)
	track.border_color = Color("3b2414")
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var full := track.duplicate() as StyleBoxFlat
	full.bg_color = Color("6aa83a")
	full.border_color = Color("2f4f1a")
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", full)
	t.set_stylebox("grabber_area_highlight", "HSlider", full)
	var knob: Texture2D = load(WIN + "knob.png")
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
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
