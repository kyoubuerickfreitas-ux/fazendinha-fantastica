class_name WeatherFX
extends CanvasLayer
## Efeitos visuais do clima, por cima do mundo e por baixo da interface:
## chuva (leve/forte), tempestade com relâmpagos, neve, neblina, vento com folhas e calor.

var _rain: CPUParticles2D
var _snow: CPUParticles2D
var _leaves: CPUParticles2D
var _fog: ColorRect
var _flash: ColorRect
var _heat: ColorRect
var _kind := ""
var _flash_t := 0.0


func _ready() -> void:
	layer = 5
	_rain = _particles(Color(0.75, 0.85, 0.95, 0.55), Vector2(-0.25, 1), 380, 460, 0.9, Vector2(1, 2))
	_snow = _particles(Color(1, 1, 1, 0.85), Vector2(-0.15, 1), 35, 60, 6.0, Vector2(1.5, 3))
	_snow.spread = 25
	_leaves = _particles(Color(0.62, 0.72, 0.36, 0.9), Vector2(1, 0.25), 180, 260, 3.5, Vector2(2, 3))
	_leaves.emission_rect_extents = Vector2(10, 260)
	_leaves.position = Vector2(-30, 180)
	_leaves.angular_velocity_min = -200
	_leaves.angular_velocity_max = 200
	_fog = _overlay(Color(0.86, 0.9, 0.92, 0.0))
	_heat = _overlay(Color(1.0, 0.7, 0.35, 0.0))
	_flash = _overlay(Color(1, 1, 1, 0.0))
	set_weather("sunny")


func _particles(color: Color, dir: Vector2, vmin: float, vmax: float, life: float, scl: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 160
	p.lifetime = life
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(420, 10)
	p.position = Vector2(340, -20)
	p.direction = dir
	p.spread = 2
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = scl.x
	p.scale_amount_max = scl.y
	p.color = color
	p.preprocess = life
	p.emitting = false
	p.visible = false
	add_child(p)
	return p


func _overlay(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func set_weather(id: String) -> void:
	var wd := CropDB.weather(id)
	_kind = wd.particles if wd else ""
	_toggle(_rain, _kind in ["rain", "heavy", "storm"])
	_rain.amount = 160 if _kind == "rain" else 320
	_rain.color = Color(0.75, 0.85, 0.95, 0.55 if _kind == "rain" else 0.7)
	_toggle(_snow, _kind == "snow")
	_toggle(_leaves, _kind == "wind" or _kind == "storm")
	_leaves.amount = 18 if _kind == "wind" else 30
	_fog.color.a = 0.32 if _kind == "fog" else 0.0
	_heat.color.a = 0.07 if _kind == "heat" else 0.0
	_flash.color.a = 0.0
	_flash_t = randf_range(3.0, 7.0)


func _toggle(p: CPUParticles2D, on: bool) -> void:
	p.emitting = on
	p.visible = on


func _process(delta: float) -> void:
	if _kind == "fog":
		_fog.color.a = 0.28 + sin(Time.get_ticks_msec() / 2500.0) * 0.06
	elif _kind == "heat":
		_heat.color.a = 0.06 + sin(Time.get_ticks_msec() / 700.0) * 0.02
	elif _kind == "storm":
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash_t = randf_range(4.0, 10.0)
			var tw := create_tween()
			tw.tween_property(_flash, "color:a", 0.55, 0.05)
			tw.tween_property(_flash, "color:a", 0.0, 0.12)
			tw.tween_property(_flash, "color:a", 0.35, 0.05)
			tw.tween_property(_flash, "color:a", 0.0, 0.3)
