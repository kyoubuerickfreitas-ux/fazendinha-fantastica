class_name Player
extends CharacterBody2D
## Personagem do jogador: movimento livre em 8 direções, animação em 4 direções.
## Spritesheet 9x4 de 64x64. Linhas: baixo, esquerda, direita, cima.
## Coluna 0 = parado, colunas 1..8 = caminhada (gerada por tools/import_protagonist.py).

const SHEET := preload("res://assets/sprites/player.png")
const ACTIONS := preload("res://assets/sprites/player_actions.png")
## Animações de ferramenta (player_actions.png): linha = ferramenta * 4 + direção.
## impact = quadro em que a ação acontece de verdade (árvore treme, terra é arada...).
const ACTION_ANIMS := {
	"axe": {"tool": 0, "impact": 5},
	"hoe": {"tool": 1, "impact": 5},
	"pickaxe": {"tool": 2, "impact": 5},
	"watering_can": {"tool": 3, "impact": 4},
	"scythe": {"tool": 4, "impact": 4},
	"fishing_rod": {"tool": 5, "impact": 5},   # lançar; o último quadro é a pose de segurar a vara
}
const ACTION_FPS := 16.0
const ACTION_FRAMES := 9
## Direções que já têm animação desenhada, por ferramenta (as outras usam o golpe simples)
static var _has_dir := {}
const SPEED := 85.0
const REACH := 20.0
const AUTO_REACH := 52.0    # alcance da mira automática (~1,6 célula)
const TAP_REACH := 72.0     # alcance ao tocar direto na tela
const FACING_BIAS := 18.0   # quanto a direção do personagem pesa na escolha
const ACTION_TIME := 0.28
const COLS := 9
const WALK_FRAMES := 8

enum Dir { DOWN, LEFT, RIGHT, UP }

var world: FarmWorld
var fishing: Fishing
var facing := Vector2.DOWN
var _dir := Dir.DOWN
var _anim_t := 0.0
var _busy := 0.0
var _sprite: Sprite2D
var _action := {}   # animação de ferramenta em andamento
var _holding_rod := false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = COLS
	_sprite.vframes = 4
	_sprite.position = Vector2(0, -26)
	add_child(_sprite)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 8)
	col.shape = shape
	col.position = Vector2(0, -4)
	add_child(col)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	var v := Game.joystick_vector
	var key := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if key != Vector2.ZERO:
		v = key
	if v.length() > 1.0:
		v = v.normalized()
	if Game.ui_lock > 0 or _busy > 0.0 or not _action.is_empty():
		v = Vector2.ZERO
	if not _action.is_empty():
		_step_action(delta)
	elif _holding_rod and not (fishing and fishing.is_active()):
		_holding_rod = false
		_restore_sheet()
	if fishing and fishing.is_active():
		if fishing.blocks_movement():
			v = Vector2.ZERO
		elif v.length() > 0.3:
			fishing.cancel("Você recolheu a linha.")
	_busy = max(0.0, _busy - delta)

	velocity = v * SPEED
	move_and_slide()

	if not _action.is_empty() or _holding_rod:
		pass
	elif v.length() > 0.15:
		facing = v.normalized()
		if abs(v.x) > abs(v.y) * 1.1:
			_dir = Dir.RIGHT if v.x > 0 else Dir.LEFT
		else:
			_dir = Dir.DOWN if v.y > 0 else Dir.UP
		_anim_t += delta * (8.0 + 6.0 * v.length())
		_sprite.frame = _dir * COLS + 1 + int(_anim_t) % WALK_FRAMES
	else:
		_anim_t = 0.0
		_sprite.frame = _dir * COLS

	if world:
		var id := Game.selected_item_id()
		var c := target_cell()
		world.set_cursor(c, Game.ui_lock == 0, world.would_act(id, c) or world.can_interact_cell(c))


## Direção (4 lados) para a qual o personagem está virado.
func facing_vector() -> Vector2:
	match _dir:
		Dir.LEFT: return Vector2.LEFT
		Dir.RIGHT: return Vector2.RIGHT
		Dir.UP: return Vector2.UP
	return Vector2.DOWN


func feet() -> Vector2:
	return global_position + Vector2(0, -6)


func target_point() -> Vector2:
	return feet() + facing_vector() * REACH


## Mira inteligente: entre as células ao alcance, escolhe a mais próxima em que o item
## selecionado faz alguma coisa. A direção em que o personagem anda desempata.
## Se nada servir, devolve a célula logo à frente (para dar a mensagem certa).
func target_cell() -> Vector2i:
	return pick_target(Game.selected_item_id())


func pick_target(item_id: String) -> Vector2i:
	var f := feet()
	var pc := world.cell_of(f)
	var best := world.cell_of(target_point())
	var best_score := INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := pc + Vector2i(dx, dy)
			if not (world.would_act(item_id, c) or (item_id == "" and world.can_interact_cell(c))):
				continue
			var p := world.target_anchor(c)
			var to := p - f
			var d := to.length()
			if d > AUTO_REACH:
				continue
			var score := d - FACING_BIAS * facing.dot(to.normalized() if d > 0.1 else facing)
			score += world.target_penalty(item_id, c)
			if score < best_score:
				best_score = score
				best = c
	return best


func use_tool() -> void:
	use_at(target_cell())


## Usa o item selecionado numa célula específica (mira automática ou toque na tela).
func use_at(c: Vector2i) -> void:
	if Game.ui_lock > 0 or world == null:
		return
	var id := Game.selected_item_id()
	# pesca em andamento: o botão serve para fisgar/puxar (toques rápidos, sem espera)
	if fishing and fishing.is_active():
		if id == "fishing_rod":
			_report(fishing.on_use(c))
		else:
			fishing.cancel("Você recolheu a linha.")
		return
	if _busy > 0.0 or not _action.is_empty():
		return
	# itens de cuidar de animais: o botão de usar age no animal mais próximo
	if id in ["brush", "herbal_tea", "shears"]:
		interact()
		return
	# isca na mão: coloca na vara
	if ItemDB.get_item(id).get("type", "") == "bait":
		Game.equip_bait(id)
		Game.toast.emit("%s colocada na vara de pesca." % ItemDB.item_name(id))
		return
	if id == "fishing_rod":
		_face(world.target_anchor(c))
		if world.ground_at(c) == FarmWorld.Ground.WATER and _start_action(id, c):
			return
		_busy = ACTION_TIME
		_play_action_anim()
		_report(fishing.on_use(c))
		return
	_face(world.target_anchor(c))
	if _start_action(id, c):
		return
	_busy = ACTION_TIME
	_play_action_anim()
	_apply_tool(id, c)


func _apply_tool(id: String, c: Vector2i) -> void:
	if id == "fishing_rod":
		_report(fishing.on_use(c))
		return
	var msg: String
	if id != "" and not world.would_act(id, c) and world.can_interact_cell(c):
		msg = world.interact_cell(c)   # ex.: tocar numa colheita pronta com o machado na mão
	else:
		msg = world.use_item(id, c)
	if msg != "":
		Game.toast.emit(msg)


# ------------------------------------------------------------------ animações de ferramenta
func _anim_available(id: String) -> bool:
	if not ACTION_ANIMS.has(id):
		return false
	var key := "%s/%d" % [id, _dir]
	if not _has_dir.has(key):
		var row: int = ACTION_ANIMS[id]["tool"] * 4 + _dir
		var img := ACTIONS.get_image()
		_has_dir[key] = not img.get_region(Rect2i(0, row * 64, 64 * ACTION_FRAMES, 64)).is_invisible()
	return _has_dir[key]


func _start_action(id: String, c: Vector2i) -> bool:
	if not _anim_available(id):
		return false
	_action = {"id": id, "cell": c, "t": 0.0, "done": false}
	_sprite.texture = ACTIONS
	_sprite.hframes = ACTION_FRAMES
	_sprite.vframes = ACTIONS.get_height() / 64
	_sprite.frame = (ACTION_ANIMS[id]["tool"] * 4 + _dir) * ACTION_FRAMES
	return true


func _step_action(delta: float) -> void:
	var a := _action
	a["t"] += delta * ACTION_FPS
	var f := int(a["t"])
	var def: Dictionary = ACTION_ANIMS[a["id"]]
	if not a["done"] and f >= int(def["impact"]):
		a["done"] = true
		_apply_tool(a["id"], a["cell"])
	if f >= ACTION_FRAMES:
		_action = {}
		if a["id"] == "fishing_rod" and fishing and fishing.is_active():
			_holding_rod = true   # fica na última pose segurando a vara
			return
		_restore_sheet()
		return
	_sprite.frame = (int(def["tool"]) * 4 + _dir) * ACTION_FRAMES + f


func _restore_sheet() -> void:
	_sprite.texture = SHEET
	_sprite.hframes = COLS
	_sprite.vframes = 4
	_sprite.frame = _dir * COLS


func _report(msg: String) -> void:
	if msg != "":
		Game.toast.emit(msg)


func can_reach(point: Vector2) -> bool:
	return feet().distance_to(point) <= TAP_REACH


func interact() -> void:
	if Game.ui_lock > 0 or world == null:
		return
	if fishing and fishing.is_active():
		fishing.cancel("Você recolheu a linha.")
		return
	var it := find_interactable()
	if it:
		_face(it.global_position)
		it.interact(self)
		return
	var c := pick_target("")
	_face(world.target_anchor(c))
	var msg := world.interact_cell(c)
	if msg != "":
		Game.toast.emit(msg)


func find_interactable() -> Interactable:
	var best: Interactable = null
	var best_score := INF
	var f := feet()
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		var to := it.global_position - f
		var d := to.length()
		if d > it.reach + 14.0:
			continue
		var score := d - FACING_BIAS * facing.dot(to.normalized() if d > 0.1 else facing)
		if score < best_score:
			best = it
			best_score = score
	return best


func _face(point: Vector2) -> void:
	var to := point - feet()
	if to.length() < 2.0:
		return
	facing = to.normalized()
	if abs(to.x) > abs(to.y):
		_dir = Dir.RIGHT if to.x > 0 else Dir.LEFT
	else:
		_dir = Dir.DOWN if to.y > 0 else Dir.UP
	_sprite.frame = _dir * COLS


func _play_action_anim() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.12, 0.9), 0.07)
	tw.tween_property(_sprite, "scale", Vector2.ONE, 0.12)
