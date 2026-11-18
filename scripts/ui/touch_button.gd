class_name TouchButton
extends Control
## Botão redondo com suporte a multitoque (funciona enquanto o outro dedo
## está no joystick). Também aceita mouse ao testar no PC.

signal pressed

@export var icon: Texture2D
@export var radius := 24.0
@export var icon_scale := 2.0

var _touch := -1
var _down := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2, radius * 2)
	size = custom_minimum_size


func _center() -> Vector2:
	return size / 2.0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var inside: bool = (event.position - global_position - _center()).length() <= radius + 4
		if event.pressed and inside and _touch == -1 and (Game.ui_lock == 0 or name == "Close"):
			_touch = event.index
			_down = true
			queue_redraw()
			pressed.emit()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			_touch = -1
			_down = false
			queue_redraw()


func _draw() -> void:
	var c := _center()
	var off := Vector2(0, 2) if _down else Vector2.ZERO
	draw_circle(c + Vector2(0, 3), radius, Color(0.1, 0.07, 0.05, 0.35))
	draw_circle(c + off, radius, Color("765137"))
	draw_circle(c + off, radius - 3, Color("a8784f") if not _down else Color("8e6340"))
	draw_circle(c + off, radius - 6, Color("e9ddbb"))
	draw_arc(c + off, radius, 0, TAU, 40, Color("2b2118"), 1.5)
	if icon:
		var s := Vector2(16, 16) * icon_scale  # tamanho fixo, seja o ícone 16 ou 32 px
		draw_texture_rect(icon, Rect2(c + off - s / 2.0, s), false)
