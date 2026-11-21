class_name VirtualJoystick
extends Control
## Joystick virtual dinâmico: aparece onde o dedo toca dentro da área deste Control.
## Suporta multitoque (dá para andar e apertar botões ao mesmo tempo).

const RADIUS := 34.0
const BASE_TEX := preload("res://assets/sprites/ui/hud/joy_base.png")
const KNOB_TEX := preload("res://assets/sprites/ui/hud/joy_knob.png")
const KNOB := 15.0

var _touch := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
			get_viewport().set_input_as_handled()
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
	# arte de tools/import_hud.py: base de madeira com setas e o botão com a folhinha
	var d := (RADIUS + 10.0) * 2.0
	var tint := Color(1, 1, 1, 0.95 if _touch != -1 else 0.7)
	var bs := BASE_TEX.get_size()
	var bsz := Vector2(d, d * bs.y / bs.x)
	draw_texture_rect(BASE_TEX, Rect2(base - bsz / 2.0, bsz), false, tint)
	var kd := d * float(HudLayout.L["joy"]["knob_d"])
	draw_texture_rect(KNOB_TEX, Rect2(knob - Vector2(kd, kd) / 2.0, Vector2(kd, kd)), false, tint)
