class_name NPC
extends Interactable
## Habitante do vilarejo. Sem data = Fungo, o vendedor (fica parado na barraca).
## Com data (NPCData) = morador: anda em volta de casa de dia, some à noite.

const FUNGO_SHEET := preload("res://assets/sprites/npc_fungo.png")
const WALK_SPEED := 22.0
const DAY_START := 6 * 60
const DAY_END := 20 * 60

var npc_name := "Fungo"
var data: NPCData = null
var stationary := false     # fica parado (atrás do balcão da loja)
var home_cell := Vector2i(-999, -999)    # onde passeia (na cidade); senão a casa da ficha
var world: FarmWorld = null
var _sprite: Sprite2D
var _bubble: Sprite2D
var _t := 0.0
var _target := Vector2.ZERO
var _wait := 1.0
var _rng := RandomNumberGenerator.new()


## Morador: chamar antes de entrar na árvore.
func setup(d: NPCData, w: FarmWorld) -> void:
	data = d
	world = w
	npc_name = d.name


func _ready() -> void:
	reach = 40.0
	label = "Conversar"
	_sprite = Sprite2D.new()
	_sprite.texture = load(data.sheet) if data else FUNGO_SHEET
	_sprite.hframes = 2
	var sc := data.scale if data else 1.0
	_sprite.scale = Vector2.ONE * sc
	_sprite.position = Vector2(0, -26 * sc)
	add_child(_sprite)

	_bubble = Sprite2D.new()
	_bubble.texture = ItemDB.ui_icon("bubble")
	_bubble.position = Vector2(14, -54 * sc)
	add_child(_bubble)

	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 8)
	col.shape = shape
	col.position = Vector2(0, -4)
	body.add_child(col)
	add_child(body)
	_target = position
	_rng.seed = hash(npc_name)


func _process(delta: float) -> void:
	_t += delta
	_sprite.frame = int(_t * 2.0) % 2
	var sc := data.scale if data else 1.0
	_bubble.position.y = -54 * sc + sin(_t * 3.0) * 1.5
	if data == null:
		return
	# de noite está em casa
	var awake := Game.minutes >= DAY_START and Game.minutes < DAY_END
	if visible != awake:
		visible = awake
		if awake:
			add_to_group("interactable")
		else:
			remove_from_group("interactable")
	if not awake:
		return
	# não sai andando enquanto o jogador está perto (fica fácil conversar)
	var player_near := world != null and world.player != null and world.player.position.distance_to(position) < 48.0
	_bubble.visible = Villagers.is_birthday(data.id) or int(Villagers.rec(data.id)["talk_day"]) != Game.day
	if player_near or stationary:
		return
	var to := _target - position
	if to.length() > 1.0:
		var step := to.limit_length(WALK_SPEED * delta)
		position += step
		if absf(step.x) > 0.1:
			_sprite.flip_h = step.x < 0
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = _rng.randf_range(1.5, 4.5)
		_target = _pick_target()


## Um lugar livre perto de casa, com caminho reto sem obstáculos.
func _pick_target() -> Vector2:
	var home := home_cell if home_cell.x > -999 else data.home
	for _i in 8:
		var c := home + Vector2i(_rng.randi_range(-data.wander, data.wander), _rng.randi_range(-data.wander, data.wander))
		var p := world.cell_center(c)
		if world.straight_clear(position, p):
			return p
	return position
