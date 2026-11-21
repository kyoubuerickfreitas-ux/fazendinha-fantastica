class_name RunButton
extends TouchButton
## Botão de correr (ícone do pé): segure para correr. O anel em volta mostra o fôlego (stamina própria,
## separada da energia): azul quando há fôlego, vermelho quando cansou e está recuperando.


func is_held() -> bool:
	return _down


func _draw() -> void:
	super._draw()
	var c := _center() + (Vector2(0, 2) if _down else Vector2.ZERO)
	# riscos de movimento atrás do pé (dentro da parte clara do botão)
	var ink := Color("553926")
	for i in 3:
		var y := -3.5 + i * 3.5
		var w := 6.0 if i == 1 else 4.0
		draw_line(c + Vector2(-11.0, y), c + Vector2(-11.0 + w, y), ink, 1.8)
	# anel do fôlego
	var f := clampf(Game.stamina / Game.MAX_STAMINA, 0.0, 1.0)
	var col := Color("e0574a") if Game.exhausted else Color("5fb6e8")
	draw_arc(c, radius + 3, 0, TAU, 40, Color(0.1, 0.07, 0.05, 0.45), 3.5)
	if f > 0.0:
		draw_arc(c, radius + 3, -PI / 2, -PI / 2 + TAU * f, 40, col, 3.0)
