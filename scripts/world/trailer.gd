class_name Trailer
extends Node2D
## Caçamba engatada no trator: segue atrás dele (do lado oposto ao que o trator olha) e guarda itens
## (Game.trailer["items"], CARGO_SIZE espaços). Parada, toque com a mão para abrir a carga.
## Arte: tools/import_tractor.py (trailer_<direção do trator>.png).

const CARGO_SIZE := 24
const TEX := {0: preload("res://assets/sprites/tractor/trailer_down.png"),
	1: preload("res://assets/sprites/tractor/trailer_left.png"),
	2: preload("res://assets/sprites/tractor/trailer_right.png"),
	3: preload("res://assets/sprites/tractor/trailer_up.png")}
## Onde fica, em relação à base do trator, conforme a direção do trator (0 baixo, 1 esquerda, 2 direita, 3 cima)
const BEHIND := {0: Vector2(0, -34), 1: Vector2(62, 2), 2: Vector2(-62, 2), 3: Vector2(0, 42)}

signal open_requested

var dir := 0
var _wheel := 0.0          # quanto as rodas já giraram (em quadros)
var _sprite: Sprite2D
var _use: Interactable


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	_use = Interactable.new()
	_use.label = "Abrir a caçamba"
	_use.reach = 34.0
	_use.position = Vector2(0, -8)
	_use.interacted.connect(func(_w): open_requested.emit())
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
	_sprite.position = Vector2(-t.get_width() / WHEEL_FRAMES / 2.0, -t.get_height() + 2)


## Vai para trás do trator (com uma suavizada, para parecer puxada).
func follow(tractor_pos: Vector2, tractor_dir: int, delta: float) -> void:
	var target: Vector2 = tractor_pos + BEHIND[tractor_dir]
	var before := global_position
	if tractor_dir != dir:
		set_dir(tractor_dir)
		global_position = target        # virou: encaixa na hora (sem atravessar o trator)
	else:
		global_position = global_position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
		roll(global_position.distance_to(before))


static func items() -> Array:
	var a = Game.trailer.get("items", [])
	if not (a is Array) or a.size() != CARGO_SIZE:
		a = []
		a.resize(CARGO_SIZE)
		Game.trailer["items"] = a
	return a


## Passa uma pilha da mochila para a carga (to_cargo) ou ao contrário. Devolve false se não coube.
static func move_stack(from: Array, to: Array, i: int) -> bool:
	var s = from[i]
	if s == null:
		return false
	var qty: int = int(s["qty"])
	var q: int = int(s.get("q", 0))
	if ItemDB.is_stackable(s["id"]):
		for t in to:
			if t != null and t["id"] == s["id"] and int(t.get("q", 0)) == q and t["qty"] < ItemDB.MAX_STACK:
				var add: int = mini(qty, ItemDB.MAX_STACK - int(t["qty"]))
				t["qty"] += add
				qty -= add
				if qty <= 0:
					break
	while qty > 0:
		var idx := to.find(null)
		if idx == -1:
			break
		var add: int = mini(qty, ItemDB.MAX_STACK) if ItemDB.is_stackable(s["id"]) else 1
		to[idx] = {"id": s["id"], "qty": add} if q == 0 else {"id": s["id"], "qty": add, "q": q}
		qty -= add
	if qty <= 0:
		from[i] = null
	else:
		s["qty"] = qty
	Game.inventory_changed.emit()
	return qty <= 0
