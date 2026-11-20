class_name PlayerPortrait
extends Control
## Desenho do jogador com a aparência escolhida (corpo pintado pelo shader + cabelo tingido).
## Usado no retrato da HUD (só o rosto) e na tela de criação (corpo inteiro, andando).

const SHEET := preload("res://assets/sprites/player.png")
const CELL := 64

var region := Rect2(0, 0, 64, 64)   # parte do quadro mostrada (o rosto, no retrato da HUD)
var look := {}                       # vazio = usa Game.look()
var walking := false                 # anima a caminhada (tela de criação)
var direction := 0                   # 0 baixo, 1 esquerda, 2 direita, 3 cima

var _body: TextureRect
var _hair: TextureRect
var _mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = PlayerLook.make_material()
	_body = _layer()
	_body.material = _mat
	_hair = _layer()
	refresh()


func _layer() -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func current_look() -> Dictionary:
	return look if not look.is_empty() else Game.look()


func refresh() -> void:
	if _body == null:
		return
	var l := current_look()
	PlayerLook.apply(_mat, l)
	_hair.modulate = PlayerLook.hair_color(l)
	_set_frame(int(_t) % 8 + 1 if walking else 0)


func _set_frame(col: int) -> void:
	var r := Rect2(region.position + Vector2(col * CELL, direction * CELL), region.size)
	var a := AtlasTexture.new()
	a.atlas = SHEET
	a.region = r
	_body.texture = a
	var ht := PlayerLook.hair_texture(current_look(), false)
	if ht:
		var h := AtlasTexture.new()
		h.atlas = ht
		h.region = r
		_hair.texture = h
	else:
		_hair.texture = null


func _process(delta: float) -> void:
	if not walking or _body == null:
		return
	var before := int(_t)
	_t += delta * 9.0
	if int(_t) != before:
		_set_frame(int(_t) % 8 + 1)
