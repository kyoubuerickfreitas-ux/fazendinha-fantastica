class_name Passerby
extends Interactable
## Gente da cidade (assets/sprites/townsfolk/<n>.png, tools/import_townsfolk.py): anda pelas ruas
## calçadas, em linha reta de esquina em esquina, para de vez em quando e fala uma frase se você tocar.
## Quadros: 0 frente (descendo), 1 de lado (indo para a esquerda; espelhado para a direita),
## 2 3/4 de costas, 3 costas (subindo). De noite vão para casa (somem).

const SPEED := 26.0
const DAY_START := 7 * 60
const DAY_END := 20 * 60
## nome e frases de cada um (na ordem da folha)
const PEOPLE := [
	["Zeca", ["Bom dia! Indo buscar pão antes que acabe.", "Esse boné? Ganhei no torneio de pesca. Fiquei em último."]],
	["Dona Lina", ["Ai, minhas costas! Mas a feira não espera.", "Já provou a geleia da Feira? Uma delícia!"]],
	["Seu Juca", ["Sol bonito hoje. Bom para a colheita!", "Na minha época a gente carregava tudo no braço. Que inveja do seu trator!"]],
	["Rosinha", ["Estou levando ovos para a Padaria. Cuidado para não esbarrar!", "Você é quem cuida da fazenda depois da ponte? Que legal!"]],
	["Vovó Neném", ["Ah, que juventude bonita. Cuide bem das suas plantinhas.", "Faço tricô na praça toda tarde. Apareça!"]],
	["Seu Barnabé", ["Hum. Já andei por todos os caminhos deste vale.", "O lago esconde peixes que ninguém nunca viu. Acredite."]],
	["Lili", ["Olha o meu laço novo! A Mana Folha que fez!", "Quer brincar de pega-pega? Não? Tudo bem..."]],
	["Téo", ["Vou ser o melhor pescador do vale. Você vai ver!", "Corri da praça até o parque sem parar. Recorde!"]],
	["Musgo", ["...Shhh. Estou ouvindo o vento.", "O bosque está feliz hoje. Dá para sentir."]],
	["Bia", ["Aprendiz do Chef Brioche, ao seu dispor! Já queimei três pães hoje.", "O segredo é a manteiga. Ou foi o fermento? Esqueci."]],
	["Nico", ["Carta para você? Hmm... não, hoje não. Amanhã, quem sabe!", "Entrego cartas na cidade inteira. Conheço todo mundo!"]],
	["Andarilho", ["Venho de longe. Este vale é o mais bonito que já vi.", "Dizem que tem uma mina cheia de gemas por aqui. Você sabe onde fica?"]],
]

var index := 0
var world: FarmWorld
var _sprite: Sprite2D
var _t := 0.0
var _target := Vector2.ZERO
var _wait := 1.0
var _rng := RandomNumberGenerator.new()


func setup(i: int, w: FarmWorld) -> void:
	index = i
	world = w


func _ready() -> void:
	reach = 32.0
	label = "Conversar"
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/townsfolk/%d.png" % index)
	_sprite.hframes = 4
	_sprite.position = Vector2(0, -28)
	add_child(_sprite)
	_rng.seed = 7919 * (index + 1)
	_target = position
	_wait = _rng.randf_range(0.0, 3.0)
	interacted.connect(func(_w):
		var p: Array = PEOPLE[index % PEOPLE.size()]
		var lines: Array = p[1]
		Game.toast.emit("%s: %s" % [p[0], lines[_rng.randi() % lines.size()]])
		_wait = 2.5)


func person_name() -> String:
	return PEOPLE[index % PEOPLE.size()][0]


func _process(delta: float) -> void:
	_t += delta
	var awake := Game.minutes >= DAY_START + index * 6 and Game.minutes < DAY_END - index * 5
	if visible != awake:
		visible = awake
		if awake:
			add_to_group("interactable")
		else:
			remove_from_group("interactable")
	if not awake or world == null:
		return
	# para quando você chega perto (fica fácil conversar)
	if world.player and world.player.position.distance_to(position) < 40.0:
		_sprite.position.y = -28
		return
	var to := _target - position
	if to.length() > 1.0:
		var step := to.limit_length(SPEED * delta)
		position += step
		if absf(step.x) > absf(step.y):
			_sprite.frame = 1
			_sprite.flip_h = step.x > 0
		else:
			_sprite.frame = 0 if step.y > 0 else 3
			_sprite.flip_h = false
		_sprite.position.y = -28 - absf(sin(_t * 11.0)) * 1.5     # passinhos
		return
	_sprite.position.y = -28
	_wait -= delta
	if _wait <= 0.0:
		_wait = _rng.randf_range(1.0, 4.0)
		_target = _pick_target()


## Anda em linha reta pela rua (calçamento livre) até 2..9 quadrados numa direção.
func _pick_target() -> Vector2:
	var c := world.cell_of(position)
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for _i in 6:
		var d: Vector2i = dirs[_rng.randi() % 4]
		var n := _rng.randi_range(2, 9)
		var last := c
		for k in range(1, n + 1):
			var nc := c + d * k
			if world.ground_at(nc) != FarmWorld.Ground.PATH or world.blocked.has(nc):
				break
			last = nc
		if last != c:
			return world.cell_center(last)
	return position
