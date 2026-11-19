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
	_sprite.position = Vector2(0, 32.0 - 58.0 * sc)   # pés sempre no chão
	_bubble.position = Vector2(0, (32.0 - 58.0 * sc) - 24.0 * sc - 6)
	_zzz.position = Vector2(4, _bubble.position.y - 6)
	# ícone de necessidade (um por vez, por prioridade)
	var tex: Texture2D = null
	if mode == Mode.SLEEP or mode == Mode.INSIDE:
		tex = null
	elif record.product_ready:
		tex = ItemDB.icon(s.product)
	elif record.hunger_days > 0 or record.health != "ok":
		tex = ItemDB.icon("hay")
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


func _pick_target() -> void:
	var t := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
	if record.personality == "sociável":
		var others := get_tree().get_nodes_in_group("animals")
		if others.size() > 1:
			var o: Node2D = others[_rng.randi() % others.size()]
			if o != self:
				t = o.position + Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-12, 12))
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
				FX.spawn(get_parent(), "harvest", position + Vector2(0, -20))
	elif not record.petted_today:
		record.petted_today = true
		record.happiness = mini(100, record.happiness + 5)
		_float_heart()
		Game.toast.emit("%s adorou o carinho!" % record.name)
	else:
		card_requested.emit(self)
	refresh()


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
