class_name HudBar
extends Control
## Preenchimento da barra de vida/energia, desenhado dentro do trilho da arte da HUD.

var color := Color.RED
var max_value := 100.0:
	set(v):
		max_value = v
		queue_redraw()
var value := 100.0:
	set(v):
		value = v
		queue_redraw()


func _draw() -> void:
	var f := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	if f <= 0.0:
		return
	var w := maxf(size.y, size.x * f)        # nunca mais fino que a altura (fica uma bolinha)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size.y / 2.0))
	sb.border_color = color.lightened(0.35)
	sb.border_width_top = 2
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(0, 0, w, size.y))
	# brilho embaixo mais escuro
	draw_line(Vector2(size.y / 2.0, size.y - 1), Vector2(w - size.y / 2.0, size.y - 1), color.darkened(0.25), 1.0)
