class_name Tractor
extends Node2D
## Trator: fica estacionado no mapa; toque com a mão para subir. Com o jogador em cima, vira filho do
## jogador (scripts/player/player.gd: mount/dismount), mostra o personagem sentado na cabine e anda bem
## mais rápido. Arte: tools/import_tractor.py (4 direções: 0 baixo, 1 esquerda, 2 direita, 3 cima).

const TEX := [preload("res://assets/sprites/tractor/down.png"), preload("res://assets/sprites/tractor/left.png"),
	preload("res://assets/sprites/tractor/right.png"), preload("res://assets/sprites/tractor/up.png")]
const PLAYER_SHEET := preload("res://assets/sprites/player.png")
## Onde fica o personagem sentado, em cada direção (canto de cima do recorte, em relação à base do trator)
const RIDER_POS := [Vector2(-32, -62), Vector2(-26, -62), Vector2(-38, -62), Vector2(-32, -60)]
const RIDER_CUT := Rect2(0, 4, 64, 34)     # cabeça e tronco do quadro parado

signal mount_requested

var dir := 0
var mounted := false
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


func set_dir(d: int) -> void:
	dir = d
	if _sprite == null:
		return
	var t: Texture2D = TEX[d]
	_sprite.texture = t
	_sprite.position = Vector2(-t.get_width() / 2.0, -t.get_height() + 2 + _bob)
	_rider.position = RIDER_POS[d] + Vector2(0, _bob)
	var cut := Rect2(RIDER_CUT.position + Vector2(0, d * 64), RIDER_CUT.size)
	# de costas o encosto do banco cobriria o personagem: só a cabeça, desenhada por cima do banco
	_rider.z_index = 1 if d == 3 else 0
	if d == 3:
		cut = Rect2(Vector2(0, 3 * 64 + 6), Vector2(64, 19))
		_rider.position = Vector2(-32, -56 + _bob)
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


## Balanço do motor quando está andando.
func shake(moving: bool, delta: float) -> void:
	_bob = (0.0 if not moving else (1.0 if fmod(Time.get_ticks_msec() / 90.0, 2.0) < 1.0 else 0.0))
	set_dir(dir)
