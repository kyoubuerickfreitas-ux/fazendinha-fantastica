class_name ClockIcon
extends Control
## Relógio de ponteiro do painel de cima: mostrador da arte (tools/import_weather_icons.py) e ponteiros
## desenhados na hora do jogo.

const FACE := preload("res://assets/sprites/ui/weather/clock_face.png")
const INK := Color("3b2414")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Game.time_changed.connect(func(_d, _m): queue_redraw())


func _draw() -> void:
	var side := minf(size.x, size.y)
	var r := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	draw_texture_rect(FACE, r, false)
	var c := r.get_center()
	var radius := side / 2.0
	var m := Game.minutes % (24 * 60)
	var hour_ang := float(m % 720) / 720.0 * TAU - PI / 2.0
	var min_ang := float(m % 60) / 60.0 * TAU - PI / 2.0
	draw_line(c, c + Vector2.from_angle(hour_ang) * radius * 0.34, INK, maxf(1.5, side * 0.09), true)
	draw_line(c, c + Vector2.from_angle(min_ang) * radius * 0.5, INK, maxf(1.0, side * 0.06), true)
	draw_circle(c, maxf(1.2, side * 0.06), Color("e08a2c"))
