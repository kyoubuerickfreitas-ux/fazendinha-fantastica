class_name Tractor
extends Node2D
## Trator: fica estacionado no mapa; toque com a mão para subir. Com o jogador em cima, vira filho do
## jogador (scripts/player/player.gd: mount/dismount), mostra o personagem sentado na cabine e anda bem
## mais rápido. Arte: tools/import_tractor.py. 8 direções: 0 baixo, 1 esquerda, 2 direita, 3 cima,
## 4 baixo-esquerda, 5 baixo-direita, 6 cima-esquerda, 7 cima-direita.

const TRAILER_DIR := 0
const TEX := [preload("res://assets/sprites/tractor/down.png"), preload("res://assets/sprites/tractor/left.png"),
	preload("res://assets/sprites/tractor/right.png"), preload("res://assets/sprites/tractor/up.png"),
	preload("res://assets/sprites/tractor/down_left.png"), preload("res://assets/sprites/tractor/down_right.png"),
	preload("res://assets/sprites/tractor/up_left.png"), preload("res://assets/sprites/tractor/up_right.png")]
## Quadro do personagem usado em cada direção (as diagonais usam o de frente ou o de costas)
const RIDER_FACE := [0, 1, 2, 3, 0, 0, 3, 3]
const PLAYER_SHEET := preload("res://assets/sprites/player.png")
## Personagem sentado (desenhado por cima do banco): canto de cima do recorte em relação à base do trator,
## e quais linhas do quadro parado aparecem (cabeça e ombros), por direção (0 baixo, 1 esquerda, 2 direita, 3 cima)
const RIDER_POS := [Vector2(-32, -46), Vector2(-25, -46), Vector2(-39, -46), Vector2(-32, -47),
	Vector2(-25, -45), Vector2(-39, -45), Vector2(-27, -40), Vector2(-37, -40)]
const RIDER_ROWS := [Vector2i(10, 29), Vector2i(10, 30), Vector2i(10, 30), Vector2i(10, 26),
	Vector2i(10, 27), Vector2i(10, 27), Vector2i(10, 24), Vector2i(10, 24)]

signal mount_requested

var dir := 0
var _wheel := 0.0          # quanto as rodas já giraram (em quadros)
var mounted := false
var trailer: Trailer            # caçamba engatada (opcional)
var _sprite: Sprite2D
var _rider: Sprite2D
var _rider_hair: Sprite2D
var _use: Interactable
var _bob := 0.0


func _ready() -> void:
	# o personagem vem antes (fica atrás do trator: aparece pelas aberturas da cabine)
	_rider = Sprite2D.new()
	_rider.texture = PLAYER_SHEET
	_rider.centered = false
	_rider.region_enabled = true
	_rider.visible = false
	add_child(_rider)
	_rider_hair = Sprite2D.new()
	_rider_hair.centered = false
	_rider_hair.region_enabled = true
	_rider.add_child(_rider_hair)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	_use = Interactable.new()
	_use.label = "Subir no trator"
	_use.reach = 34.0
	_use.position = Vector2(0, -8)
	_use.interacted.connect(func(_w): mount_requested.emit())
	add_child(_use)
	set_dir(dir)


const WHEEL_FRAMES := 4
## Quadros por pixel andado (as rodas giram conforme a distância, então param quando o trator para).
const WHEEL_SPEED := 0.12


## Gira as rodas pela distância andada.
func roll(distance: float) -> void:
	_wheel = fmod(_wheel + distance * WHEEL_SPEED, float(WHEEL_FRAMES))
	if _sprite:
		_sprite.frame = _wheel_frame()


## Na vista "left" e na de costas os quadros vão ao contrário (as rodas giram para o outro lado).
func _wheel_frame() -> int:
	var f := int(_wheel) % WHEEL_FRAMES
	return (WHEEL_FRAMES - 1 - f) if dir in [1, 3] else f


func set_dir(d: int) -> void:
	dir = d
	if _sprite == null:
		return
	var t: Texture2D = TEX[d]
	_sprite.texture = t
	_sprite.hframes = WHEEL_FRAMES          # tira com as rodas girando (tools/import_tractor.py)
	_sprite.frame = _wheel_frame()
	_sprite.position = Vector2(-t.get_width() / WHEEL_FRAMES / 2.0, -t.get_height() + 2 + _bob)
	_rider.position = RIDER_POS[d] + Vector2(0, _bob)
	var rows: Vector2i = RIDER_ROWS[d]
	# folha nova: quadros de 128 com escala 0,5 (cabeça maior: mostra mais linhas, com a base no mesmo lugar)
	var top := 4
	var bottom := 70
	var cut := Rect2(0, RIDER_FACE[d] * 128 + top, 128, bottom - top)
	_rider.scale = Vector2.ONE * 0.5
	_rider.position = RIDER_POS[d] + Vector2(0, _bob + (rows.y - rows.x) - (bottom - top) * 0.5)
	_rider.z_index = 1
	_rider.region_rect = cut
	_rider_hair.region_rect = cut


## Com alguém dirigindo: mostra o personagem (com a aparência escolhida) e esconde o "Subir".
func set_mounted(on: bool, look_mat: Material = null, hair: Texture2D = null, hair_color := Color.WHITE) -> void:
	mounted = on
	_rider.visible = on
	_rider.material = look_mat
	_rider_hair.texture = hair
	_rider_hair.visible = hair != null
	_rider_hair.modulate = hair_color
	if on:
		_use.remove_from_group("interactable")
	else:
		_use.add_to_group("interactable")
	set_dir(dir)


func attach_trailer(t: Trailer) -> void:
	trailer = t
	t.set_dir(dir)
	t.global_position = global_position + Trailer.BEHIND[dir]


var _last_pos := Vector2.INF


func _process(delta: float) -> void:
	if is_inside_tree():
		if _last_pos != Vector2.INF:
			roll(global_position.distance_to(_last_pos))
		_last_pos = global_position
	if trailer and is_inside_tree() and trailer.is_inside_tree():
		trailer.follow(global_position, dir, delta)


## Balanço do motor quando está andando.
func shake(moving: bool, delta: float) -> void:
	_bob = (0.0 if not moving else (1.0 if fmod(Time.get_ticks_msec() / 90.0, 2.0) < 1.0 else 0.0))
	set_dir(dir)
