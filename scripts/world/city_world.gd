class_name CityWorld
extends FarmWorld
## A cidade: um mapa à parte (como a mina e a casa), aonde se chega pela estrada leste da fazenda
## (entra-se pelo oeste da cidade). Vila em volta de uma praça calçada (poço, bancos, canteiros): a
## Pousada no alto, lojas em volta (Ferraria, Restaurante, Feira com a horta, Peixaria junto do rio,
## Roupas embaixo), casas em grupos, um coreto e o moinho. Caminhos de terra retos (esquinas
## arredondadas) ligam tudo; o rio corre na borda leste, com cais. Arte: tools/import_city.py (assets/sprites/city/).
## Não se ara, não se planta e não se constrói aqui.

signal exit_used                       ## saiu pela estrada de volta à fazenda
signal building_used(kind: String)     ## tocou na porta de uma loja/casa (ver BUILDINGS)

const DIR := "res://assets/sprites/city/"
const PLAZA_TEX := preload("res://assets/sprites/city/cobble.png")      # calçamento de pedra
const SAND_TEX := preload("res://assets/sprites/city/sand.png")         # terra clara dos caminhos
const PATH_W := 62.0              # largura dos caminhos (px)
const SAND_EDGE := Color(0.6, 0.44, 0.24, 0.9)
const CURB := Color(0.22, 0.15, 0.1, 0.55)

## Caminhos de terra: linhas retas (só na horizontal e na vertical, como o resto do jogo) por pontos em
## quadrados, com 2 quadrados de largura; as esquinas ficam arredondadas
const PATHS := [
	[Vector2(0, 17.5), Vector2(19.5, 17.5)],                       # estrada da fazenda até a praça
	[Vector2(3, 9.9), Vector2(44, 9.9)],                           # rua de cima (lojas e Pousada)
	[Vector2(30.5, 16), Vector2(43, 16), Vector2(43, 33)],         # praça -> Peixaria -> cais -> margem
	[Vector2(25.5, 19), Vector2(25.5, 24)],                        # praça -> rua das casas
	[Vector2(2, 24), Vector2(43, 24)],                             # rua das casas
	[Vector2(12, 17.5), Vector2(12, 24)],
	[Vector2(22.5, 24), Vector2(22.5, 33)],
	[Vector2(31, 24), Vector2(31, 33)],
	[Vector2(4, 33), Vector2(43, 33)],                             # rua de baixo
]
## Praça central (piso de lajotas) e os canteiros de flores dela
const PLAZA := Rect2i(19, 11, 13, 9)
const BEDS := [Rect2i(19, 11, 2, 2), Rect2i(30, 11, 2, 2), Rect2i(19, 18, 2, 2), Rect2i(30, 18, 2, 2)]
## Rio na borda leste: a margem faz curva (x da margem em cada linha) e os cais entram nele
const RIVER_X := 45
const DOCKS := [Rect2i(43, 19, 5, 2), Rect2i(43, 32, 4, 2)]
## Horta ao lado da Feira (terra arada com fileiras de verduras)
const FIELD := Rect2i(2, 11, 6, 5)
const FIELD_CROPS := ["carrot", "kale", "beet", "pumpkin", "radish"]

## Prédios: [arte, centro x (em quadrados), linha da base, tipo, rótulo da porta]
## A base fica na borda de cima da linha (a porta dá para o caminho).
const BUILDINGS := [
	["windmill", 3.6, 8, "windmill", "Moinho"],
	["house_red_green", 8.6, 9, "home", "Casa de morador"],
	["blacksmith", 16.6, 9, "smith", "Ferraria"],
	["inn", 25.5, 9, "inn", "Pousada"],
	["notice_board", 30.6, 9, "board", "Quadro de avisos"],
	["restaurant", 39.0, 9, "restaurant", "Restaurante"],
	["market", 11.0, 17, "market", "Feira"],
	["fountain", 25.5, 17, "well", "Chafariz"],
	["fish_shop", 38.6, 15, "fish", "Peixaria"],
	["house_red", 4.4, 23, "home", "Casa de morador"],
	["house_red_blue", 8.6, 23, "home", "Casa de morador"],
	["barn_house", 16.4, 23, "home", "Casa de morador"],
	["bakery", 34.6, 23, "bakery", "Padaria"],
	["house_red_purple", 39.4, 23, "home", "Casa de morador"],
	["barn_house_red", 5.6, 32, "home", "Casa de morador"],
	["gazebo", 12.6, 31, "gazebo", "Coreto"],
	["inn_red", 18.8, 32, "home", "Casa grande"],
	["tailor", 26.6, 32, "tailor", "Ateliê de Roupas"],
	["barn_house_blue", 36.8, 32, "home", "Casa de morador"],
	["signpost", 3.2, 17, "sign", "Placa"],
]
## Enfeites: [arte, x, linha da base]
const DECOR := [
	# praça: bancos em volta do chafariz e postes nos cantos
	["bench", 22.4, 15], ["bench", 28.6, 15], ["bench", 23.0, 19], ["bench", 28.0, 19],
	["lamp_post", 21.6, 11], ["lamp_post", 29.4, 11], ["lamp_post", 21.6, 18], ["lamp_post", 29.4, 18],
	# coreto: bancos dos lados
	["bench", 10.2, 31], ["bench", 15.0, 31],
	["boat", 46.6, 22],
	# na frente das lojas
	["barrel", 13.8, 9], ["crate", 19.4, 9], ["barrel", 20.0, 9],
	["bench", 35.8, 9], ["barrel", 41.8, 9], ["crate", 42.4, 9],
	["crate", 8.6, 17], ["barrel", 13.6, 17], ["crate", 14.2, 17],
	["barrel", 35.9, 15], ["crate", 41.4, 15],
	["banner_post", 23.9, 32], ["barrel", 29.2, 32], ["crate", 29.8, 32],
	# postes nas ruas
	["lamp_post", 6.8, 17], ["lamp_post", 34.0, 15], ["lamp_post", 10.4, 26], ["lamp_post", 20.6, 26],
	["lamp_post", 33.0, 26], ["lamp_post", 41.0, 26], ["lamp_post", 45.6, 9], ["lamp_post", 41.6, 21],
]
## Flores (último estágio da planta): [planta, x, y] em quadrados (canteiros, jardins e o coreto)
const FLOWERS := [
	["tulip", 19.6, 11.9], ["rose", 20.4, 12.6], ["daisy", 19.5, 12.9], ["lavender", 20.5, 11.7],
	["sunflower", 30.6, 11.9], ["hydrangea", 31.4, 12.6], ["tulip", 30.5, 12.9], ["pink_tulip", 31.5, 11.8],
	["rose", 19.6, 18.9], ["lavender", 20.4, 19.6], ["pink_tulip", 19.5, 19.9], ["daisy", 20.5, 18.7],
	["hydrangea", 30.6, 18.9], ["sunflower", 31.4, 19.6], ["daisy", 30.5, 19.9], ["tulip", 31.5, 18.7],
]
## Canteiros de flores (retângulos em quadrados, enchidos com flores sorteadas)
const FLOWER_BEDS := [Rect2i(10, 27, 6, 1), Rect2i(14, 20, 3, 1), Rect2i(2, 20, 2, 2), Rect2i(37, 18, 4, 2),
	Rect2i(32, 27, 3, 2), Rect2i(24, 26, 4, 2), Rect2i(19, 26, 2, 2), Rect2i(6, 26, 3, 2),
	Rect2i(27, 6, 3, 1), Rect2i(21, 6, 2, 1), Rect2i(37, 28, 4, 2)]
const FLOWER_KINDS := ["daisy", "tulip", "lavender", "pink_tulip", "rose", "hydrangea", "sunflower"]
## Cercas (tools/make_city_fence.py): ["h", x0, x1, linha] ou ["v", coluna, y0, y1] (inclusive).
## Onde a cerca cruza um caminho, um prédio ou a água, aquele pedaço fica de fora (vira porteira).
const FENCES := [
	["v", 1, 11, 15], ["v", 8, 11, 15],                          # horta
	["h", 9, 16, 25], ["v", 9, 26, 31], ["v", 16, 26, 31],       # jardim do coreto
	["h", 2, 8, 25], ["h", 32, 41, 25],                          # jardins na beira da rua das casas
	["h", 36, 41, 17],                                           # quintal da Peixaria
]
## Bosques (árvores e arbustos sorteados): o resto da grama, longe dos caminhos e dos prédios
const PARKS := [Rect2i(0, 0, 50, 38)]
## Topo da chaminé na imagem (tools/import_city.py): fumaça animada. As variações de cor usam a mesma.
const CHIMNEYS := {"house_red": Vector2(94, 11), "restaurant": Vector2(83, 14), "inn": Vector2(114, 14)}
const LAMP_AT := Vector2(10, 15)        # lampião na imagem do poste
const ROW_DECOR := ["bench", "barrel", "crate"]

## Chegar aqui pela estrada oeste e sair por ela
const GATE := Rect2(0, 16 * 32, 2 * 32, 4 * 32)
const ARRIVE := Vector2(3 * 32 + 16, 17 * 32 + 26)

## Moradores que passeiam pela cidade (os que não cuidam de loja) e onde cada um gosta de ficar
const STROLL := {"carpa": Vector2i(44, 20), "pipoca": Vector2i(23, 13), "estrelo": Vector2i(13, 33),
	"raiz": Vector2i(8, 18)}

var spawn_pos := ARRIVE
var doors := {}        # tipo do prédio -> posição da porta (para voltar da loja)
var _plaza_cells := {}
var _dock_cells := {}
var _shore_cells := {}
var _field_cells := {}


func region_id() -> String:
	return "city"


func water_kind(_c: Vector2i) -> String:
	return ""


func _is_free_grass(_c: Vector2i) -> bool:
	return false        # não se ara na cidade


func can_place(_kind: String, _target: Vector2i) -> bool:
	return false


## Saída da cidade: perto da borda oeste, na estrada.
func exit_at(pos: Vector2) -> String:
	return "farm" if GATE.has_point(pos) else ""


func generate(_saved: Dictionary) -> void:
	ground.resize(W * H)
	variant.resize(W * H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	for i in W * H:
		ground[i] = Ground.GRASS
		var r := rng.randf()
		variant[i] = 1 if r < 0.06 else (2 if r < 0.16 else 0)
	for line in PATHS:
		_dirt_line(line)
	for y in range(PLAZA.position.y, PLAZA.end.y):
		for x in range(PLAZA.position.x, PLAZA.end.x):
			ground[y * W + x] = Ground.PATH
			_plaza_cells[Vector2i(x, y)] = true
	for b in BEDS:
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				ground[y * W + x] = Ground.GRASS
				_plaza_cells.erase(Vector2i(x, y))
				blocked[Vector2i(x, y)] = true
	for y in H:
		for x in range(river_edge(y), W):
			ground[y * W + x] = Ground.WATER
		ground[y * W + river_edge(y) - 1] = Ground.PATH          # prainha de terra na beira do rio
		_shore_cells[Vector2i(river_edge(y) - 1, y)] = true
	for d in DOCKS:
		for y in range(d.position.y, d.end.y):
			for x in range(d.position.x, d.end.x):
				var c := Vector2i(x, y)
				if ground_at(c) == Ground.WATER:
					_dock_cells[c] = true
				ground[y * W + x] = Ground.PATH
	for y in range(FIELD.position.y, FIELD.end.y):
		for x in range(FIELD.position.x, FIELD.end.x):
			_field_cells[Vector2i(x, y)] = true
			blocked[Vector2i(x, y)] = true
	_build_world_bounds()
	_build_water_collision()
	for b in BUILDINGS:
		_add_building(b[0], b[1], b[2], b[3], b[4])
	_add_fences()
	for d in DECOR:
		_add_decor(d[0], d[1], d[2])
	for f in FLOWERS:
		_add_flower(f[0], f[1], f[2])
	var frng := RandomNumberGenerator.new()
	frng.seed = 777
	for bed in FLOWER_BEDS:
		for y in range(bed.position.y, bed.end.y):
			for x in range(bed.position.x, bed.end.x):
				var c := Vector2i(x, y)
				if ground_at(c) != Ground.GRASS or blocked.has(c):
					continue
				blocked[c] = true
				for k in 2:
					_add_flower(FLOWER_KINDS[frng.randi() % FLOWER_KINDS.size()], x + 0.3 + k * 0.45, y + 0.6 + k * 0.3)
	for y in range(FIELD.position.y, FIELD.end.y):          # horta: uma fileira de cada verdura
		var crop: String = FIELD_CROPS[(y - FIELD.position.y) % FIELD_CROPS.size()]
		for x in range(FIELD.position.x, FIELD.end.x):
			_add_flower(crop, x + 0.5, y + 0.85)
	_add_trees(rng)
	_spawn_strollers.call_deferred()
	if Game.tractor.get("owned", false) and Game.tractor.get("where", "farm") == "city":
		spawn_tractor(Vector2(float(Game.tractor["x"]), float(Game.tractor["y"])))     # ficou estacionado aqui
	_ground_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ground_layer.modulate = CropDB.season(Game.season_id()).tint
	_ground_layer.queue_redraw()


## Margem do rio (primeira coluna de água) na linha y: faz uma curva suave.
func river_edge(y: int) -> int:
	return RIVER_X + int(round(sin(y / 5.0) * 1.2 + sin(y / 2.3) * 0.4))


## Caminho de terra por uma linha de pontos (2 quadrados de largura).
func _dirt_line(pts: Array) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(ceil(a.distance_to(b) * 3.0)) + 1
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			for dy in [-1, 0]:
				for dx in [-1, 0]:
					var c := Vector2i(int(floor(p.x + dx + 0.5)), int(floor(p.y + dy + 0.5)))
					if is_inside(c):
						ground[c.y * W + c.x] = Ground.PATH


## Uma faixa de caminho pela linha de pontos (quadrados): retângulos e círculos nas juntas.
func _draw_path(pts: Array, w: float, edge: bool) -> void:
	var ts := SAND_TEX.get_size()
	for i in pts.size():
		var a: Vector2 = pts[i] * TILE
		if i > 0 and i < pts.size() - 1:
			_path_poly(_circle_pts(a, w / 2.0), edge, ts)       # esquina: arredondada
		if i < pts.size() - 1:
			var b: Vector2 = pts[i + 1] * TILE
			var d := (b - a).normalized()
			# pontas da rua: retas, meia largura para fora (cobrem o cruzamento como a esquina)
			if i == 0:
				a -= d * (w / 2.0)
			if i + 1 == pts.size() - 1:
				b += d * (w / 2.0)
			var n := d.orthogonal() * (w / 2.0)
			_path_poly(PackedVector2Array([a + n, b + n, b - n, a - n]), edge, ts)


func _path_poly(poly: PackedVector2Array, edge: bool, ts: Vector2) -> void:
	if edge:
		_ground_layer.draw_colored_polygon(poly, SAND_EDGE)
		return
	var uvs := PackedVector2Array()
	for p in poly:
		uvs.append(p / ts)
	_ground_layer.draw_polygon(poly, PackedColorArray([Color.WHITE]), uvs, SAND_TEX)


static func _circle_pts(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 20:
		out.append(c + Vector2.from_angle(TAU * k / 20.0) * r)
	return out


func _sprite_at(art: String, cx: float, base_row: int) -> Array:
	var holder := StaticBody2D.new()
	holder.position = Vector2(cx * TILE, base_row * TILE)
	var s := Sprite2D.new()
	s.texture = load(DIR + art + ".png")
	s.position = Vector2(0, -s.texture.get_height() / 2.0 + 2)
	holder.add_child(s)
	entities.add_child(holder)
	return [holder, s]


func _add_building(art: String, cx: float, base_row: int, kind: String, label: String) -> void:
	var hs := _sprite_at(art, cx, base_row)
	var holder: StaticBody2D = hs[0]
	var s: Sprite2D = hs[1]
	var w := s.texture.get_width()
	var h := s.texture.get_height()
	var small := kind in ["well", "board", "sign", "gazebo"] or art.begins_with("market")
	var deep := 22.0 if small else 30.0
	_add_rect_collision(holder, Vector2(w - 14, deep), Vector2(0, -deep / 2.0 - 2))
	var c0 := int(floor(cx - w / 2.0 / TILE))
	var c1 := int(ceil(cx + w / 2.0 / TILE)) - 1
	for y in range(base_row - int(ceil(h / float(TILE))), base_row):
		for x in range(c0, c1 + 1):
			blocked[Vector2i(x, y)] = true       # nada de árvore atrás do prédio
	for key in CHIMNEYS:
		if art.begins_with(key):
			var sm := FX.spawn_loop(s, "chimney", _img_pt(s, CHIMNEYS[key] + Vector2(0, -12)))
			sm.z_index = 1
	if not small and kind != "windmill":
		# jardinzinho: arbusto e flor dos dois lados da casa
		for side in [c0 - 1, c1 + 1]:
			var bc := Vector2i(side, base_row - 1)
			if is_inside(bc) and ground_at(bc) == Ground.GRASS and not blocked.has(bc) and not props.has(bc):
				_spawn_prop("bush", bc, -1, int(cx * 7 + side))
	var door := Interactable.new()
	door.label = label
	door.reach = 30.0
	door.position = holder.position + Vector2(0, 8 if small else 4)
	door.interacted.connect(func(_w): building_used.emit(kind))
	if not doors.has(kind):
		doors[kind] = door.position
	entities.add_child(door)


func _add_decor(art: String, cx: float, base_row: int) -> void:
	var hs := _sprite_at(art, cx, base_row)
	var holder: StaticBody2D = hs[0]
	var s: Sprite2D = hs[1]
	var w := s.texture.get_width()
	var h := s.texture.get_height()
	if art.begins_with("market"):
		_add_rect_collision(holder, Vector2(w - 14, 22), Vector2(0, -13))
		for y in range(base_row - int(ceil(h / float(TILE))), base_row):
			for x in range(int(floor(cx - w / 2.0 / TILE)), int(ceil(cx + w / 2.0 / TILE))):
				blocked[Vector2i(x, y)] = true
	else:
		_add_rect_collision(holder, Vector2(maxf(8.0, w - 6.0), 8), Vector2(0, -6))
		blocked[Vector2i(int(cx), base_row - 1)] = true
	if art == "lamp_post":
		add_glow(s, _img_pt(s, LAMP_AT), 48.0)


## Uma flor (o último estágio da planta) plantada no canteiro, sem colisão.
func _add_flower(id: String, x: float, y: float) -> void:
	var tex: Texture2D = load("res://assets/sprites/crops/%s.png" % id)
	if tex == null:
		return
	var at := AtlasTexture.new()
	at.atlas = tex
	var n := int(tex.get_width() / 32)
	at.region = Rect2((n - 1) * 32, 0, 32, tex.get_height())
	var s := Sprite2D.new()
	s.texture = at
	s.centered = false
	s.offset = Vector2(-16, -tex.get_height())
	s.position = Vector2(x * TILE, y * TILE + 6)
	entities.add_child(s)


## Árvores e arbustos: nas bordas e na grama que sobra (não podem ser cortados aqui).
func _add_trees(rng: RandomNumberGenerator) -> void:
	for x in range(0, river_edge(0) - 1, 3):
		_spawn_prop("old_tree", Vector2i(x, 0), -1, rng.randi())
		_spawn_prop("pine", Vector2i(x + 1, 1), -1, rng.randi())
	for x in range(0, river_edge(H - 1) - 1, 3):
		if ground_at(Vector2i(x, H - 1)) == Ground.GRASS:
			_spawn_prop("pine", Vector2i(x, H - 1), -1, rng.randi())
	for y in range(2, H - 2, 2):
		if y < 15 or y > 20:          # a estrada oeste fica livre
			_spawn_prop("pine", Vector2i(0, y), -1, rng.randi())
	for park in PARKS:
		for y in range(park.position.y, park.end.y):
			for x in range(park.position.x, park.end.x):
				var c := Vector2i(x, y)
				if ground_at(c) != Ground.GRASS or blocked.has(c) or x >= river_edge(y) - 1:
					continue
				var r := rng.randf()
				var edge := mini(mini(x, y - 2), H - 1 - y)
				if edge < 4 and not _covers_street(c) and not _near_building(c):
					if r < 0.6 and _can_place_tree(c, 0):          # bosque fechado em volta da vila
						_spawn_prop("tree", c, -1, rng.randi())
					elif r < 0.85:
						_spawn_prop("bush", c, -1, rng.randi())
					continue
				if r > 0.88 and not _next_to_path(c):           # tufinhos de flores na grama
					_add_flower(FLOWER_KINDS[rng.randi() % FLOWER_KINDS.size()], x + 0.35, y + 0.7)
					if r > 0.94:
						_add_flower(FLOWER_KINDS[rng.randi() % FLOWER_KINDS.size()], x + 0.8, y + 0.95)
					continue
				if not _covers_street(c) and not _near_building(c):
					if r < 0.4 and _can_place_tree(c, 1):
						_spawn_prop("tree", c, -1, rng.randi())
					elif r < 0.62:
						_spawn_prop("bush", c, -1, rng.randi())
				elif r < 0.16 and not _next_to_path(c) and not blocked.has(c + Vector2i.UP):
					_spawn_prop("bush", c, -1, rng.randi())      # arbustinhos entre as casas
	# cerquinha embaixo da horta
	for x in range(FIELD.position.x, FIELD.end.x, 1):
		_spawn_prop("fence", Vector2i(x, FIELD.end.y), -1, 0)


## Cercas de madeira (FENCES): um trecho por quadrado, com colisão.
func _add_fences() -> void:
	var th: Texture2D = load(DIR + "fence_h.png")
	var tv: Texture2D = load(DIR + "fence_v.png")
	for f in FENCES:
		var cells := []
		if f[0] == "h":
			for x in range(f[1], f[2] + 1):
				cells.append([Vector2i(x, f[3]), th])
		else:
			for y in range(f[2], f[3] + 1):
				cells.append([Vector2i(f[1], y), tv])
		for it in cells:
			var c: Vector2i = it[0]
			if not is_inside(c) or ground_at(c) != Ground.GRASS or blocked.has(c) or _field_cells.has(c):
				continue
			var holder := StaticBody2D.new()
			holder.position = Vector2((c.x + 0.5) * TILE, (c.y + 1) * TILE - 4)
			var sp := Sprite2D.new()
			sp.texture = it[1]
			sp.offset = Vector2(0, -sp.texture.get_height() / 2.0)
			holder.add_child(sp)
			_add_rect_collision(holder, Vector2(TILE - 2 if f[0] == "h" else 10, 8), Vector2(0, -4))
			entities.add_child(holder)
			blocked[c] = true


func _next_to_path(c: Vector2i) -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_inside(c + d) and ground_at(c + d) == Ground.PATH:
			return true
	return false


## Perto de um prédio ou da praça (a copa sobe uns 4 quadrados: cobriria a fachada logo acima)?
func _near_building(c: Vector2i) -> bool:
	for dy in range(-5, 2):
		for dx in range(-2, 3):
			var n := c + Vector2i(dx, dy)
			if blocked.has(n) or _plaza_cells.has(n):
				return true
	return false


## Árvore aqui cobriria a rua com a copa (rua logo acima) ou ficaria colada nela?
func _covers_street(c: Vector2i) -> bool:
	for dy in range(-3, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if is_inside(n) and ground_at(n) == Ground.PATH:
				return true
	return false


func _draw_ground() -> void:
	for y in H:
		for x in W:
			var i := y * W + x
			var c := Vector2i(x, y)
			var dest := Rect2(x * TILE, y * TILE, TILE, TILE)
			if _dock_cells.has(c) or ground[i] == Ground.WATER:
				var up := y > 0 and ground[i - W] != Ground.WATER and not _dock_cells.has(c + Vector2i.UP)
				_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_WATER_BANK if up and not _dock_cells.has(c) else T_WATER))
			elif _field_cells.has(c):
				_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_TILLED))
			else:
				_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_GRASS[variant[i]]))
	# caminhos de terra: faixas lisas que fazem curva (borda escura e a terra por cima)
	for pass_i in 2:
		for line in PATHS:
			_draw_path(line, PATH_W + (5.0 if pass_i == 0 else 0.0), pass_i == 0)
	for c in _shore_cells:
		var r := Rect2(c.x * TILE - 6, c.y * TILE, TILE + 6, TILE)
		_ground_layer.draw_rect(Rect2(r.position - Vector2(3, 0), r.size + Vector2(3, 0)), SAND_EDGE)
		_ground_layer.draw_texture_rect_region(SAND_TEX, r, Rect2(r.position, r.size))
	# a margem do rio: beirada de terra molhada
	for y in H:
		var x := river_edge(y)
		if not _dock_cells.has(Vector2i(x, y)):
			_ground_layer.draw_rect(Rect2(x * TILE, y * TILE, 4, TILE), Color(0.45, 0.32, 0.18, 0.9))
	for c in _plaza_cells:
		var dest := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
		_ground_layer.draw_texture_rect_region(PLAZA_TEX, dest, dest)
	for d in _dock_cells:
		_ground_layer.draw_texture(BRIDGE_TEX, Vector2(d.x * TILE, d.y * TILE - 6))
	# beirada escura onde as lajotas da praça encontram a terra ou a grama
	for c in _plaza_cells:
		var p := Vector2(c.x * TILE, c.y * TILE)
		if not _plaza_cells.has(c + Vector2i.UP):
			_ground_layer.draw_rect(Rect2(p, Vector2(TILE, 2)), CURB)
		if not _plaza_cells.has(c + Vector2i.DOWN):
			_ground_layer.draw_rect(Rect2(p + Vector2(0, TILE - 3), Vector2(TILE, 3)), CURB)
		if not _plaza_cells.has(c + Vector2i.LEFT):
			_ground_layer.draw_rect(Rect2(p, Vector2(2, TILE)), CURB)
		if not _plaza_cells.has(c + Vector2i.RIGHT):
			_ground_layer.draw_rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, TILE)), CURB)


var passersby: Array[Passerby] = []


func _spawn_strollers() -> void:
	# gente andando pelas ruas (tools/import_townsfolk.py): começa espalhada pelo calçamento
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var street_cells := []
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if ground_at(c) == Ground.PATH and not blocked.has(c) and x > 3:
				street_cells.append(c)
	for i in Passerby.PEOPLE.size():
		var pb := Passerby.new()
		pb.setup(i, self)
		pb.position = cell_center(street_cells[rng.randi() % street_cells.size()])
		entities.add_child(pb)
		passersby.append(pb)

	for id in Villagers.all_ids():
		var d := Villagers.get_npc(id)
		if d.shop != "":
			continue
		var npc := NPC.new()
		npc.setup(d, self)
		npc.home_cell = STROLL.get(id, Vector2i(25, 24))
		npc.position = cell_center(nearest_passable(npc.home_cell))
		npc.interacted.connect(func(_w): villager_used.emit(id))
		entities.add_child(npc)
		villagers.append(npc)


## Ferramentas não fazem nada na cidade (as árvores e o chão daqui não são seus).
func would_act(item_id: String, c: Vector2i) -> bool:
	return item_id == "" and can_interact_cell(c)


func use_item(item_id: String, c: Vector2i) -> String:
	if item_id == "":
		return interact_cell(c)
	if ItemDB.get_item(item_id).get("type", "") in ["tool", "seed", "placeable", "fertilizer"]:
		return "Na cidade não dá para usar isso."
	return ""
