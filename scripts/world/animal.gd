class_name Animal
extends CharacterBody2D
## Animal fantástico da fazenda: passeia pelo pasto, recebe carinho
## e produz um item por dia quando foi bem cuidado no dia anterior.
## Spritesheet 4x4 de 64x64. Linhas: baixo, esquerda, direita, cima. Pés em y=58.

const SPECIES := {
	"moombor": {"name": "Moombor", "speed": 22.0, "product": "milk", "chance": 1.0,
		"body": Vector2(26, 10), "fps": 5.0},
	"fofranca": {"name": "Fofrança", "speed": 20.0, "product": "wool", "chance": 1.0,
		"body": Vector2(24, 10), "fps": 5.0},
	"catarrapio": {"name": "Catarrápio", "speed": 30.0, "product": "truffle", "chance": 0.6,
		"body": Vector2(20, 8), "fps": 7.0},
	"piuplum": {"name": "Piuplum", "speed": 34.0, "product": "egg", "chance": 1.0,
		"body": Vector2(12, 6), "fps": 8.0},
}

enum Dir { DOWN, LEFT, RIGHT, UP }

var species := ""
var nickname := ""
var friendship := 0          # 0..10 corações
var petted_today := false
var has_product := false
var area := Rect2()          # pasto onde ele passeia (em pixels)

var _sprite: Sprite2D
var _bubble: Sprite2D
var _interact: Interactable
var _dir := Dir.DOWN
var _target := Vector2.ZERO
var _wait := 0.0
var _anim := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_species: String, p_area: Rect2, pos: Vector2) -> void:
	species = p_species
	nickname = SPECIES[species]["name"]
	area = p_area
	position = pos
	_target = pos


func _ready() -> void:
	_rng.randomize()
	_wait = _rng.randf_range(0.5, 3.0)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/animals/%s.png" % species)
	_sprite.hframes = 4
	_sprite.vframes = 4
	_sprite.position = Vector2(0, -26)
	add_child(_sprite)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = SPECIES[species]["body"]
	col.shape = shape
	col.position = Vector2(0, -shape.size.y / 2)
	add_child(col)

	_bubble = Sprite2D.new()
	_bubble.visible = false
	_bubble.position = Vector2(0, -50)
	add_child(_bubble)

	_interact = Interactable.new()
	_interact.reach = 30.0
	_interact.position = Vector2(0, -6)
	_interact.interacted.connect(_on_interact)
	add_child(_interact)
	_refresh()


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
	else:
		var to := _target - position
		if to.length() < 3.0:
			_wait = _rng.randf_range(1.5, 5.0)
		else:
			v = to.normalized() * float(SPECIES[species]["speed"])
	velocity = v
	var before := position
	move_and_slide()
	if v != Vector2.ZERO and position.distance_to(before) < 0.05:
		_wait = _rng.randf_range(0.5, 2.0)   # esbarrou em algo: desiste

	if v.length() > 0.1:
		if abs(v.x) > abs(v.y):
			_dir = Dir.RIGHT if v.x > 0 else Dir.LEFT
		else:
			_dir = Dir.DOWN if v.y > 0 else Dir.UP
		_anim += delta * float(SPECIES[species]["fps"])
		_sprite.frame = _dir * 4 + int(_anim) % 4
	else:
		_sprite.frame = _dir * 4
	_bubble.position.y = -50 + sin(Time.get_ticks_msec() / 300.0) * 1.5


func _pick_target() -> void:
	_target = Vector2(
		_rng.randf_range(area.position.x, area.end.x),
		_rng.randf_range(area.position.y, area.end.y))
	if position.distance_to(_target) > 120:
		_target = position + (_target - position).limit_length(120)


func _on_interact(_who: Node) -> void:
	_wait = 2.5   # para e olha para o jogador
	if has_product:
		var item: String = SPECIES[species]["product"]
		if Game.add_item(item, 1) == 0:
			has_product = false
			_float_text("+1 %s" % ItemDB.item_name(item))
			FX.spawn(get_parent(), "harvest", position + Vector2(0, -20))
	elif not petted_today:
		petted_today = true
		friendship = mini(friendship + 1, 10)
		_float_heart()
		Game.toast.emit("%s adorou o carinho! (%d/10 ♥)" % [nickname, friendship])
	else:
		Game.toast.emit("%s já está feliz hoje." % nickname)
	_refresh()


## Chamado ao começar um novo dia.
func new_day() -> void:
	if petted_today and not has_product:
		has_product = _rng.randf() < float(SPECIES[species]["chance"]) + friendship * 0.04
	petted_today = false
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if has_product:
		_interact.label = "Coletar"
		_bubble.texture = ItemDB.icon(SPECIES[species]["product"])
		_bubble.visible = true
	else:
		_interact.label = "Carinho" if not petted_today else nickname
		_bubble.visible = false


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
	l.size = Vector2(100, 14)
	l.position = position + Vector2(-50, -60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 50
	get_parent().add_child(l)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 18, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func serialize() -> Dictionary:
	return {"species": species, "x": position.x, "y": position.y, "friendship": friendship,
		"petted": petted_today, "product": has_product}


func restore(d: Dictionary) -> void:
	position = Vector2(float(d.get("x", position.x)), float(d.get("y", position.y)))
	_target = position
	friendship = int(d.get("friendship", 0))
	petted_today = bool(d.get("petted", false))
	has_product = bool(d.get("product", false))
	_refresh()
