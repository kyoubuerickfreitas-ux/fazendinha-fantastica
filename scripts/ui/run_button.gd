class_name RunButton
extends TouchButton
## Botão de correr: segure para correr. O anel em volta mostra o fôlego (stamina própria,
## separada da energia): azul quando há fôlego, vermelho quando cansou e está recuperando.


func is_held() -> bool:
	return _down


func _draw() -> void:
	super._draw()
	var c := _center() + (Vector2(0, 2) if _down else Vector2.ZERO)
	# ícone: tênis com riscos de velocidade
	var ink := Color("553926")
	var o := c + Vector2(2, 0)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-6, 5), o + Vector2(-6, -6), o + Vector2(-1, -6),
		o + Vector2(0, -2), o + Vector2(5, -1), o + Vector2(9, 1), o + Vector2(10, 5)]), ink)
	draw_line(o + Vector2(-6, 4), o + Vector2(10, 4), Color("e9ddbb"), 1.2)          # sola
	draw_line(o + Vector2(-4, -3), o + Vector2(-1, -3), Color("e9ddbb"), 1.0)        # cadarço
	for i in 3:
		var y := -4.0 + i * 4.0
		draw_line(c + Vector2(-13 + i, y), c + Vector2(-7, y), ink, 1.6)
	# anel do fôlego
	var f := clampf(Game.stamina / Game.MAX_STAMINA, 0.0, 1.0)
	var col := Color("e0574a") if Game.exhausted else Color("5fb6e8")
	draw_arc(c, radius + 3, 0, TAU, 40, Color(0.1, 0.07, 0.05, 0.45), 3.5)
	if f > 0.0:
		draw_arc(c, radius + 3, -PI / 2, -PI / 2 + TAU * f, 40, col, 3.0)
