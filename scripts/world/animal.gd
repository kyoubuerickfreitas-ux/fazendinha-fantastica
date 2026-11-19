class_name Animal
extends CharacterBody2D
## O boneco de um animal no mapa. Os dados ficam em `record` (AnimalRecord).
## Rotina: de dia passeia pelo pasto (jeito muda com a personalidade);
## às 19h vai para o celeiro/galinheiro e some lá dentro; sem casa, dorme no pasto.
## Spritesheet 4x4 de 64x64. Linhas: baixo, esquerda, direita, cima. Pés em y=58.

signal card_requested(animal: Animal)

enum Dir { DOWN, LEFT, RIGHT, UP }
enum Mode { WANDER, GO_HOME, INSIDE, SLEEP }

const NIGHT := 19 * 60
const MORNING := 6 * 60

var record: AnimalRecord
var world: FarmWorld
var area := Rect2()               # pasto onde passeia (em pixels)
var home_door := Vector2.INF      # porta da casa (INF = sem casa)
var mode := Mode.WANDER

var _sprite: Sprite2D
var _bubble: Sprite2D
var _zzz: Label
var _interact: Interactable
var _col: CollisionShape2D
var _dir := Dir.DOWN
var _target := Vector2.ZERO
var _wait := 0.0
var _anim := 0.0
var _rng := RandomNumberGenerator.new()
var _speed_mul := 1.0
var _rest_mul := 1.0
var _range := 120.0
var _voice: AudioStreamPlayer2D
var _sfx: AudioStreamPlayer2D
var _talk_t := 0.0
var _hop := 0.0


func setup(r: AnimalRecord, p_area: Rect2, pos: Vector2) -> void:
	record = r
	area = p_area
	position = pos
	_target = pos


func species_data() -> SpeciesData:
	return record.data()


func _ready() -> void:
	_rng.randomize()
	_wait = _rng.randf_range(0.5, 3.0)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	match record.personality:
		"curioso":
			_range = 200.0
		"calmo":
			_rest_mul = 1.6
			_speed_mul = 0.85
		"brincalhão":
			_speed_mul = 1.35
			_rest_mul = 0.5
		"preguiçoso":
			_speed_mul = 0.7
			_rest_mul = 2.2
			_range = 80.0

	_sprite = Sprite2D.new()
	_sprite.texture = load(species_data().sprite_path())
	_sprite.hframes = 4
	_sprite.vframes = 4
	add_child(_sprite)

	_col = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = species_data().body
	_col.shape = shape
	_col.position = Vector2(0, -shape.size.y / 2)
	add_child(_col)

	_bubble = Sprite2D.new()
	_bubble.visible = false
	add_child(_bubble)
	_zzz = Label.new()
	_zzz.text = "z z"
	_zzz.add_theme_font_size_override("font_size", 9)
	_zzz.add_theme_color_override("font_color", Color("dfe6f2"))
	_zzz.add_theme_color_override("font_outline_color", Color("2b2118"))
	_zzz.add_theme_constant_override("outline_size", 3)
	_zzz.visible = false
	add_child(_zzz)

	_voice = AudioStreamPlayer2D.new()
	_voice.stream = load("res://assets/sounds/%s.wav" % record.species)
	_voice.max_distance = 420.0
	_voice.pitch_scale = 1.25 if record.stage() == "baby" else 1.0
	add_child(_voice)
	_sfx = AudioStreamPlayer2D.new()
	_sfx.max_distance = 420.0
	add_child(_sfx)
	_talk_t = _rng.randf_range(15.0, 50.0)

	_interact = Interactable.new()
	_interact.reach = 30.0
	_interact.position = Vector2(0, -6)
	_interact.interacted.connect(_on_interact)
	add_child(_interact)
	refresh()


## Atualiza tamanho (filhote/jovem/adulto), ícone e texto da mão.
func refresh() -> void:
	if _sprite == null:
		return
	var s := species_data()
	var sc := 1.0
	match record.stage():
		"baby":
			sc = s.baby_scale
		"young":
			sc = s.young_scale
	_sprite.scale = Vector2.ONE * sc
	_sprite.modulate = record.tint()
	_sprite.position = Vector2(0, 32.0 - 58.0 * sc)   # pés sempre no chão
	_bubble.position = Vector2(0, (32.0 - 58.0 * sc) - 24.0 * sc - 6)
	_zzz.position = Vector2(4, _bubble.position.y - 6)
	# ícone de necessidade (um por vez, por prioridade)
	var tex: Texture2D = null
	if mode == Mode.SLEEP or mode == Mode.INSIDE:
		tex = null
	elif record.product_ready:
		tex = ItemDB.icon(record.product_item if record.product_item != "" else s.product)
	elif record.health == "resfriado":
		tex = ItemDB.icon("herbal_tea")
	elif (record.hunger_days > 0 or record.health != "ok") and not record.ate_grass and not record.hand_fed:
		tex = ItemDB.icon("hay")
	elif record.hygiene < 30 and not record.brushed_today:
		tex = ItemDB.icon("brush")
	elif not record.petted_today:
		tex = ItemDB.ui_icon("heart")
	_bubble.visible = tex != null
	if tex:
		_bubble.texture = tex
		_bubble.scale = Vector2.ONE * (12.0 / tex.get_width())
	_zzz.visible = mode == Mode.SLEEP
	if record.product_ready:
		_interact.label = "Tosquiar" if s.produce_mode == "shears" else "Coletar"
	elif not record.petted_today:
		_interact.label = "Carinho"
	else:
		_interact.label = record.name


# ------------------------------------------------------------------ rotina
func _physics_process(delta: float) -> void:
	# de noite, ou com tempo muito ruim, quem tem casa fica lá dentro
	var night := Game.minutes >= NIGHT or Game.minutes < MORNING \
		or (Game.weather_data().animals_inside and home_door != Vector2.INF)
	if night and mode == Mode.WANDER:
		if home_door != Vector2.INF:
			mode = Mode.GO_HOME
			_target = home_door
			_wait = 0.0
		else:
			mode = Mode.SLEEP
			refresh()
	elif not night and mode != Mode.WANDER:
		wake_up()

	var v := Vector2.ZERO
	match mode:
		Mode.GO_HOME:
			var to := _target - position
			if to.length() < 6.0:
				_enter_home()
			else:
				v = to.normalized() * species_data().speed * 1.4
		Mode.WANDER:
			if _wait > 0.0:
				_wait -= delta
				if _wait <= 0.0:
					_pick_target()
			else:
				var to := _target - position
				if to.length() < 3.0:
					_wait = _rng.randf_range(1.5, 5.0) * _rest_mul
					_try_graze()
				else:
					v = to.normalized() * species_data().speed * _speed_mul
	velocity = v
	var before := position
	move_and_slide()
	if v != Vector2.ZERO and position.distance_to(before) < 0.05:
		if mode == Mode.GO_HOME:
			position = position.move_toward(_target, 2.0)   # não trava no caminho de casa
		else:
			_wait = _rng.randf_range(0.5, 2.0)

	# personalidade: o brincalhão dá pulinhos; os outros sons/curiosidade
	if record.personality == "brincalhão" and v.length() > 0.1:
		_hop += delta * 12.0
		_sprite.offset.y = -absf(sin(_hop)) * 3.0
	else:
		_sprite.offset.y = 0.0
	if mode == Mode.WANDER and visible:
		_talk_t -= delta
		if _talk_t <= 0.0:
			_talk_t = _rng.randf_range(25.0, 70.0)
			speak()
	if v.length() > 0.1:
		if abs(v.x) > abs(v.y):
			_dir = Dir.RIGHT if v.x > 0 else Dir.LEFT
		else:
			_dir = Dir.DOWN if v.y > 0 else Dir.UP
		_anim += delta * species_data().anim_fps * (1.4 if record.stage() == "baby" else 1.0)
		_sprite.frame = _dir * 4 + int(_anim) % 4
	else:
		_sprite.frame = _dir * 4
	if _bubble.visible:
		_bubble.position.y += sin(Time.get_ticks_msec() / 300.0) * 0.03
	record.pos = position


## Pastar: se ainda não comeu capim hoje, procura um tufo perto e come quando chega.
func _try_graze() -> bool:
	if world == null or record.ate_grass or not species_data().grazes:
		return false
	var here := world.cell_of(position + Vector2(0, -4))
	if world.eat_grass(here):
		record.ate_grass = true
		_wait = _rng.randf_range(2.0, 4.0)   # mastigando
		refresh()
		return true
	var g := world.nearest_grass(position, _range, area)
	if g != Vector2.INF:
		_target = g
		return true
	return false


func _pick_target() -> void:
	if _try_graze():
		return
	# curioso: às vezes vem ver o jogador de perto
	if record.personality == "curioso" and world and world.player and _rng.randf() < 0.35:
		var pp: Vector2 = world.player.position
		if pp.distance_to(position) < 220.0 and area.grow(40).has_point(pp):
			_target = pp + Vector2(_rng.randf_range(-28, 28), 18)
			return
	var t := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
	if record.personality == "sociável":
		var others := get_tree().get_nodes_in_group("animals")
		if others.size() > 1:
			var o: Node2D = others[_rng.randi() % others.size()]
			if o != self:
				t = o.position + Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-12, 12))
				if o.position.distance_to(position) < 40.0 and _rng.randf() < 0.3:
					_float_heart()   # sociável: carinho entre amigos
	if position.distance_to(t) > _range:
		t = position + (t - position).limit_length(_range)
	_target = t.clamp(area.position, area.end)


func _enter_home() -> void:
	mode = Mode.INSIDE
	visible = false
	_col.disabled = true
	_interact.remove_from_group("interactable")


func wake_up() -> void:
	mode = Mode.WANDER
	visible = true
	_col.disabled = false
	if not _interact.is_in_group("interactable"):
		_interact.add_to_group("interactable")
	if home_door != Vector2.INF:
		position = home_door + Vector2(_rng.randf_range(-10, 10), 6)
	_target = position
	_wait = _rng.randf_range(0.2, 2.0)
	refresh()


func _enter_tree() -> void:
	add_to_group("animals")


# ------------------------------------------------------------------ interação
func _on_interact(_who: Node) -> void:
	_wait = 2.5   # para e olha para o jogador
	if record.product_ready:
		var res := AnimalSystem.collect(record)
		if res.has("error"):
			Game.toast.emit(res["error"])
		elif not res.is_empty():
			if Game.add_item(res["item"], res["qty"], res["q"]) > 0:
				record.product_ready = true   # mochila cheia: devolve
			else:
				var qn := "" if res["q"] == 0 else " (%s)" % AnimalSystem.QUALITY_NAMES[res["q"]]
				_float_text("+%d %s%s" % [res["qty"], ItemDB.item_name(res["item"]), qn])
				_play("collect")
				FX.spawn(get_parent(), "harvest", position + Vector2(0, -20))
	elif _cure():
		pass
	elif _brush():
		pass
	elif _hand_feed():
		pass
	elif not record.petted_today:
		record.petted_today = true
		record.happiness = mini(100, record.happiness + 5)
		_float_heart()
		speak()
		Game.toast.emit("%s adorou o carinho!" % record.name)
	else:
		card_requested.emit(self)
	refresh()


func speak() -> void:
	if _voice and is_inside_tree():
		_voice.pitch_scale = (1.25 if record.stage() == "baby" else 1.0) * _rng.randf_range(0.92, 1.08)
		_voice.play()


func _play(name: String) -> void:
	_sfx.stream = load("res://assets/sounds/%s.wav" % name)
	_sfx.play()


## Chá de Ervas na mão cura resfriado/indisposição.
func _cure() -> bool:
	if Game.selected_item_id() != "herbal_tea" or record.health == "ok":
		return false
	Game.remove_from_slot(Game.selected_slot, 1)
	record.health = "ok"
	record.hunger_days = 0
	record.happiness = mini(100, record.happiness + 10)
	_float_heart()
	Game.toast.emit("%s já está melhor!" % record.name)
	return true


## Escova na mão: 1x por dia.
func _brush() -> bool:
	if Game.selected_item_id() != "brush" or record.brushed_today:
		return false
	record.brushed_today = true
	record.hygiene = 100
	record.friendship = mini(1000, record.friendship + 10)
	record.happiness = mini(100, record.happiness + 8)
	_play("brush")
	FX.spawn(get_parent(), "harvest", position + Vector2(0, -18))
	Game.toast.emit("%s ficou limpinho e feliz!" % record.name)
	return true


## Comida na mão: uma vez por dia; a favorita dá muito mais amizade.
func _hand_feed() -> bool:
	if record.hand_fed:
		return false
	var held := Game.selected_item_id()
	if held == "":
		return false
	var item := ItemDB.get_item(held)
	if not (held == "hay" or item.get("type", "") == "crop"):
		return false
	Game.remove_from_slot(Game.selected_slot, 1)
	record.hand_fed = true
	var fav := species_data().favorite_foods.has(held)
	record.friendship = mini(1000, record.friendship + (40 if fav else 10))
	record.happiness = mini(100, record.happiness + (15 if fav else 5))
	_float_heart()
	speak()
	Game.toast.emit("%s %s %s!" % [record.name, "ADOROU" if fav else "comeu", ItemDB.item_name(held)])
	return true


func _float_heart() -> void:
	var h := Sprite2D.new()
	h.texture = ItemDB.ui_icon("heart")
	h.position = position + Vector2(0, -48)
	h.z_index = 50
	get_parent().add_child(h)
	var tw := h.create_tween()
	tw.set_parallel()
	tw.tween_property(h, "position:y", h.position.y - 16, 0.9)
	tw.tween_property(h, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(h.queue_free)


func _float_text(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("fdf6e3"))
	l.add_theme_color_override("font_outline_color", Color("2b2118"))
	l.add_theme_constant_override("outline_size", 4)
	l.size = Vector2(140, 14)
	l.position = position + Vector2(-70, -60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 50
	get_parent().add_child(l)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 18, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)
