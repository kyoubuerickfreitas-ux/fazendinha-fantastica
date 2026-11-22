class_name Player
extends CharacterBody2D
## Personagem do jogador: movimento livre em 8 direções, animação em 4 direções.
## Spritesheet 9x4 de 128x128 desenhada com escala 0,5. Linhas: baixo, esquerda, direita, cima.
## Coluna 0 = parado, colunas 1..8 = caminhada (gerada por tools/import_player_v2.py).

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
const RUN_MULT := 1.7        # correndo
const RUN_DRAIN := 20.0      # fôlego gasto por segundo correndo (~5 s de corrida)
const RUN_REGEN := 16.0      # fôlego recuperado por segundo parado ou andando
const RUN_REST := 0.6        # espera antes de começar a recuperar
const RUN_RECOVER := 35.0    # depois de cansar, precisa disto para correr de novo
const RIDE_MULT := 2.3       # de trator
const ENGINE := preload("res://assets/music/tractor.ogg")
const REACH := 20.0
const AUTO_REACH := 52.0    # alcance da mira automática (~1,6 célula)
const TAP_REACH := 72.0     # alcance ao tocar direto na tela
const FACING_BIAS := 18.0   # quanto a direção do personagem pesa na escolha
const ACTION_TIME := 0.28
const COLS := 9
const CELL := 128            # tamanho do quadro nas folhas
const SPRITE_SCALE := 0.5
const WALK_FRAMES := 8

enum Dir { DOWN, LEFT, RIGHT, UP }

var world: FarmWorld
var fishing: Fishing
var facing := Vector2.DOWN
var _dir := Dir.DOWN
var _anim_t := 0.0
var _busy := 0.0
var running := false
var _dir8 := -1              # direção do trator (8 direções, Tractor.TEX)
var riding := false
var tractor: Tractor          # o trator em que está (filho do jogador enquanto dirige)
var _engine: AudioStreamPlayer
var _rest := 0.0
var _sprite: Sprite2D
var _hair: Sprite2D          # cabelo (mesmos quadros do corpo, tingido)
var _look_mat: ShaderMaterial
var _look_actions := false
var _action := {}   # animação de ferramenta em andamento
var _holding_rod := false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = COLS
	_sprite.vframes = 4
	_sprite.position = Vector2(0, -26)
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(_sprite)
	_look_mat = PlayerLook.make_material()
	_sprite.material = _look_mat
	_hair = Sprite2D.new()
	_sprite.add_child(_hair)
	refresh_look()
	Game.look_changed.connect(refresh_look)

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

	if riding:
		_update_run(Vector2.ZERO, delta)      # dirigindo não gasta fôlego (e ele recupera)
		velocity = v * SPEED * RIDE_MULT
	else:
		_update_run(v, delta)
		velocity = v * SPEED * Cooking.speed_mult() * (RUN_MULT if running else 1.0)
	move_and_slide()

	if riding:
		if v.length() > 0.15:
			_dir8 = dir8_of(v)
			facing = v.normalized()
			if abs(v.x) > abs(v.y) * 1.1:
				_dir = Dir.RIGHT if v.x > 0 else Dir.LEFT
			else:
				_dir = Dir.DOWN if v.y > 0 else Dir.UP
		tractor.set_dir(_dir8 if v.length() > 0.15 or _dir8 >= 0 else _dir)
		tractor.shake(v.length() > 0.15, delta)
		_engine.pitch_scale = lerpf(_engine.pitch_scale, 1.3 if v.length() > 0.15 else 0.9, delta * 4.0)
	elif not _action.is_empty() or _holding_rod:
		pass
	elif v.length() > 0.15:
		facing = v.normalized()
		if abs(v.x) > abs(v.y) * 1.1:
			_dir = Dir.RIGHT if v.x > 0 else Dir.LEFT
		else:
			_dir = Dir.DOWN if v.y > 0 else Dir.UP
		var before := int(_anim_t)
		_anim_t += delta * (8.0 + 6.0 * v.length()) * (1.5 if running else 1.0)
		if int(_anim_t) != before and int(_anim_t) % 4 == 0:
			_footstep()
		_sprite.frame = _dir * COLS + 1 + int(_anim_t) % WALK_FRAMES
	else:
		_anim_t = 0.0
		_sprite.frame = _dir * COLS

	_sync_hair()
	if world:
		var id := Game.selected_item_id()
		var c := target_cell()
		world.set_cursor(c, Game.ui_lock == 0, world.would_act(id, c) or world.can_interact_cell(c))


## Correr gasta o fôlego; parar de correr recupera. O bônus "Fôlego" da comida faz durar mais.
func _update_run(v: Vector2, delta: float) -> void:
	running = Game.run_held and v.length() > 0.2 and not Game.exhausted and Game.stamina > 0.0
	if running:
		_rest = 0.0
		Game.stamina = maxf(0.0, Game.stamina - RUN_DRAIN * Cooking.energy_mult() * delta)
		if Game.stamina <= 0.0:
			Game.exhausted = true
			Sound.play("deny", -8.0)
		return
	_rest += delta
	if _rest >= RUN_REST:
		Game.stamina = minf(Game.MAX_STAMINA, Game.stamina + RUN_REGEN * delta)
	if Game.exhausted and Game.stamina >= RUN_RECOVER:
		Game.exhausted = false


# ------------------------------------------------------------------ trator
## 8 direções para o trator: 0 baixo, 1 esquerda, 2 direita, 3 cima, 4 baixo-esq., 5 baixo-dir., 6 cima-esq., 7 cima-dir.
static func dir8_of(v: Vector2) -> int:
	var a := fposmod(rad_to_deg(v.angle()), 360.0)     # 0 = direita, 90 = baixo
	var sector := int(round(a / 45.0)) % 8
	return [2, 5, 0, 4, 1, 6, 3, 7][sector]

## Sobe no trator: ele passa a andar junto (filho do jogador) e o personagem aparece sentado.
func mount(t: Tractor) -> void:
	if riding or (fishing and fishing.is_active()):
		return
	riding = true
	tractor = t
	position = t.global_position - (get_parent() as Node2D).global_position
	t.get_parent().remove_child(t)
	add_child(t)
	t.position = Vector2.ZERO
	_dir8 = t.dir
	t.set_dir(_dir8)
	t.set_mounted(true, _look_mat, PlayerLook.hair_texture(Game.look(), false), PlayerLook.hair_color(Game.look()))
	_sprite.visible = false
	if _engine == null:
		_engine = AudioStreamPlayer.new()
		_engine.bus = "SFX"
		_engine.volume_db = -12.0
		var st: AudioStreamOggVorbis = ENGINE
		st.loop = true
		_engine.stream = st
		add_child(_engine)
	_engine.pitch_scale = 0.9
	_engine.play()
	Sound.play("engine_start")


## Desce: o trator fica estacionado aqui e o personagem desce ao lado.
func dismount() -> void:
	if not riding:
		return
	riding = false
	var t := tractor
	tractor = null
	if t.trailer:
		t.trailer.follow(position + (get_parent() as Node2D).global_position, t.dir, 1.0)
	remove_child(t)
	world.entities.add_child(t)
	t.position = position
	t.set_mounted(false)
	Game.tractor["x"] = t.position.x
	Game.tractor["y"] = t.position.y
	Game.tractor["where"] = "city" if world.region_id() == "city" else "farm"
	world.tractor = t
	if t.trailer:
		world.trailer = t.trailer
	_sprite.visible = true
	_restore_sheet()
	position += Vector2(30, 6) if _dir in [Dir.DOWN, Dir.UP] else Vector2(0, 22)
	if _engine:
		_engine.stop()


## Aplica a aparência escolhida (cores do corpo e cabelo).
func refresh_look() -> void:
	_look_actions = _sprite.texture == ACTIONS
	PlayerLook.apply(_look_mat, Game.look(), _look_actions)
	_hair.texture = PlayerLook.hair_texture(Game.look(), _look_actions)
	_hair.modulate = PlayerLook.hair_color(Game.look())
	_sync_hair()


## O cabelo acompanha o quadro do corpo (caminhada ou animação de ferramenta).
func _sync_hair() -> void:
	if (_sprite.texture == ACTIONS) != _look_actions:
		refresh_look()
		return
	if _hair.texture:
		_hair.hframes = _sprite.hframes
		_hair.vframes = _sprite.vframes
		_hair.frame = _sprite.frame


## Som de passo conforme o chão (grama, terra/caminho ou pedra da mina).
func _footstep() -> void:
	if world == null:
		return
	var s := "step_grass"
	if world is MineWorld:
		s = "step_stone"
	else:
		var c := world.cell_of(feet())
		if world.ground_at(c) == FarmWorld.Ground.PATH or world.soil.has(c):
			s = "step_path"
	Sound.play(s, -9.0, 1.0, 0.12)


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
			var pen := world.target_penalty(item_id, c)
			if pen == INF:
				continue
			score += pen
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
	if riding:
		Game.toast.emit("Desça do trator (botão da mão) para usar as ferramentas.")
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
	# comida na mão: come; receita na mão: aprende
	var itype: String = ItemDB.get_item(id).get("type", "")
	if itype == "food":
		var msg := Cooking.eat(id)
		if msg != "":
			Game.toast.emit(msg)
		return
	if itype == "recipe":
		var rid: String = ItemDB.get_item(id)["recipe"]
		if Cooking.learn(rid):
			Game.remove_from_slot(Game.selected_slot, 1)
			Game.toast.emit("Aprendeu a receita: %s! Cozinhe no Fogão." % Cooking.get_recipe(rid).name)
		else:
			Game.toast.emit("Você já sabe essa receita.")
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
		_has_dir[key] = not img.get_region(Rect2i(0, row * CELL, CELL * ACTION_FRAMES, CELL)).is_invisible()
	return _has_dir[key]


func _start_action(id: String, c: Vector2i) -> bool:
	if not _anim_available(id):
		return false
	_action = {"id": id, "cell": c, "t": 0.0, "done": false}
	_sprite.texture = ACTIONS
	_sprite.hframes = ACTION_FRAMES
	_sprite.vframes = ACTIONS.get_height() / CELL
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
	if riding:
		dismount()
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
		if not it.is_visible_in_tree() or not world.is_ancestor_of(it):
			continue      # só o que está no mundo atual (fazenda ou mina)
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
	tw.tween_property(_sprite, "scale", Vector2(1.12, 0.9) * SPRITE_SCALE, 0.07)
	tw.tween_property(_sprite, "scale", Vector2.ONE * SPRITE_SCALE, 0.12)
