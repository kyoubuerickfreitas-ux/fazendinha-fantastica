class_name ItemSlot
extends Control
## Um espaço de inventário (barra rápida ou mochila). Mostra ícone, quantidade
## e número do atalho. Responde a toque (multitoque) e mouse.

signal tapped(index: int)

var index := 0
var selected := false
var marked := false
## Se true, funciona mesmo com painéis abertos (para slots dentro da mochila).
var works_in_panel := false
var show_number := false
## A arte da barra rápida já desenha o espaço: aqui só o conteúdo e o destaque do selecionado.
var skin := false

var _touch := -1


func _init(p_index: int = 0, p_size: float = 36.0) -> void:
	index = p_index
	custom_minimum_size = Vector2(p_size, p_size)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	Game.inventory_changed.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventScreenTouch):
		return
	if not works_in_panel and Game.ui_lock > 0:
		return
	if event.pressed and _touch == -1 and get_global_rect().has_point(event.position):
		_touch = event.index
		tapped.emit(index)
		get_viewport().set_input_as_handled()
	elif not event.pressed and event.index == _touch:
		_touch = -1


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if skin:
		if selected:
			var sb := StyleBoxFlat.new()
			sb.draw_center = true
			sb.bg_color = Color(0.6, 0.85, 0.3, 0.12)
			sb.set_border_width_all(2)
			sb.border_color = Color("a6dc4f")
			sb.set_corner_radius_all(5)
			sb.shadow_color = Color(0.65, 0.9, 0.3, 0.45)
			sb.shadow_size = 3
			draw_style_box(sb, r.grow(1))
	else:
		var bg := UIStyle.SLOT_BG
		draw_rect(r, UIStyle.WOOD_DARK)
		draw_rect(r.grow(-2), UIStyle.WOOD_LIGHT if selected else UIStyle.WOOD)
		draw_rect(r.grow(-4), bg)
		if selected:
			draw_rect(r.grow(-1), UIStyle.GREEN_LIGHT, false, 2.0)
	if marked:
		draw_rect(r.grow(-1), Color("f2d16b"), false, 2.0)

	var font := get_theme_default_font()
	var s = Game.inventory[index] if index < Game.inventory.size() else null
	if s != null:
		var tex := ItemDB.icon(s["id"])
		var icon_size := Vector2(32, 32) if size.x >= 40 else Vector2(24, 24)
		draw_texture_rect(tex, Rect2((size - icon_size) / 2.0, icon_size), false)
		var qty_text := ""
		if s["id"] == "watering_can":
			qty_text = str(Game.water)
		elif s["qty"] > 1:
			qty_text = str(s["qty"])
		if qty_text != "":
			var pos := Vector2(size.x - 4 - font.get_string_size(qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, size.y - 4)
			draw_string_outline(font, pos, qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, UIStyle.INK)
			draw_string(font, pos, qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.CREAM)
	# isca: marca a que está na vara, e mostra a isca no canto da vara
	if s != null and s["id"] == "fishing_rod" and Game.equipped_bait != "":
		draw_texture_rect(ItemDB.icon(Game.equipped_bait), Rect2(Vector2(3, size.y - 17), Vector2(14, 14)), false)
	if s != null and s["id"] == Game.equipped_bait and Game.equipped_bait != "":
		draw_rect(Rect2(Vector2(size.x - 9, 3), Vector2(6, 6)), UIStyle.GREEN_LIGHT)
		draw_rect(Rect2(Vector2(size.x - 9, 3), Vector2(6, 6)), UIStyle.INK, false, 1.0)
	# estrela de qualidade
	if s != null and int(s.get("q", 0)) > 0:
		var c: Color = ItemDB.QUALITY_COLORS[int(s["q"])]
		var p := Vector2(6, size.y - 8)
		var pts := PackedVector2Array()
		for k in 10:
			var rr := 4.5 if k % 2 == 0 else 2.0
			var ang := -PI / 2 + k * PI / 5
			pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, c)
		draw_polyline(pts + PackedVector2Array([pts[0]]), UIStyle.INK, 1.0)
	if show_number:
		var n := str(index + 1)
		draw_string_outline(font, Vector2(5, 12), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, UIStyle.INK)
		draw_string(font, Vector2(5, 12), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIStyle.GREEN_LIGHT)
