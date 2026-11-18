class_name VirtualJoystick
extends Control
## Joystick virtual dinâmico: aparece onde o dedo toca dentro da área deste Control.
## Suporta multitoque (dá para andar e apertar botões ao mesmo tempo).

const RADIUS := 34.0
const KNOB := 15.0

var _touch := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rest_position() -> Vector2:
	return Vector2(70, size.y - 62)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and Game.ui_lock == 0 \
				and get_global_rect().has_point(event.position):
			_touch = event.index
			_base = event.position - global_position
			_knob = _base
			_update()
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		var local: Vector2 = event.position - global_position
		_knob = _base + (local - _base).limit_length(RADIUS)
		_update()


func _release() -> void:
	_touch = -1
	Game.joystick_vector = Vector2.ZERO
	queue_redraw()


func _process(_d: float) -> void:
	if Game.ui_lock > 0 and _touch != -1:
		_release()


func _update() -> void:
	var v := (_knob - _base) / RADIUS
	Game.joystick_vector = v if v.length() > 0.18 else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var base := _base if _touch != -1 else _rest_position()
	var knob := _knob if _touch != -1 else base
	var a := 0.85 if _touch != -1 else 0.4
	draw_circle(base, RADIUS + 4, Color(0.17, 0.13, 0.09, 0.35 * a))
	draw_arc(base, RADIUS + 4, 0, TAU, 40, Color(0.91, 0.87, 0.73, 0.6 * a), 2.0)
	draw_circle(knob, KNOB, Color(0.91, 0.87, 0.73, 0.75 * a))
	draw_arc(knob, KNOB, 0, TAU, 28, Color(0.46, 0.32, 0.22, a), 2.0)
	draw_circle(knob, 4, Color(0.47, 0.58, 0.36, a))
