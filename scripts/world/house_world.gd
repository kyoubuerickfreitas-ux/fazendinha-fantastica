class_name HouseWorld
extends FarmWorld
## Interior da casa. Reaproveita o mundo da fazenda (mira, colocar objetos, aquários, fogão) com um
## cômodo fixo: cama (dormir), lareira, mesa, estante, baú (guardar itens) e o fogão na cozinha.
## Os objetos colocados aqui dentro (aquários...) ficam em Game.house["placeables"].
## Arte provisória: tools/generate_house_interior.py (assets/sprites/house_in/).

signal exit_used
signal bed_used
signal chest_used

const DIR := "res://assets/sprites/house_in/"
const DARK := Color("1c130d")
## O piso do cômodo dentro do mapa
const ROOM := Rect2i(18, 14, 14, 8)
const DOOR_CELL := Vector2i(19, 14)          # porta na parede do fundo (sai para a fazenda)

var spawn_pos := Vector2.ZERO
var bed_spot := Vector2.ZERO
var kitchen: Interactable      # a bancada com pia e fogão (cozinhar)
var _floor: Texture2D
var _wall: Texture2D
var _side: Texture2D
var _rug: Texture2D
var _win: Texture2D
var _door: Texture2D


func region_id() -> String:
	return "house"


func is_indoor() -> bool:
	return true


func water_kind(_c: Vector2i) -> String:
	return ""


func _is_free_grass(_c: Vector2i) -> bool:
	return false      # não se ara o piso


func can_place(kind: String, target: Vector2i) -> bool:
	var r := Placeable.footprint(kind, target)
	var pc := cell_of(player.position) if player else Vector2i(-99, -99)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if not ROOM.has_point(c) or blocked.has(c) or occupied.has(c) or c == pc:
				return false
	return true


func generate(_saved: Dictionary) -> void:
	_floor = load(DIR + "floor_big.png")
	_wall = load(DIR + "wall_plain.png")
	_side = load(DIR + "wall_side.png")
	_rug = load(DIR + "rug.png")              # carregar aqui (não dentro do desenho: saía branco)
	_win = load(DIR + "wall_window.png")
	_door = load(DIR + "door.png")
	ground.resize(W * H)
	variant.resize(W * H)
	for i in W * H:
		ground[i] = Ground.PATH
	# tudo fora do cômodo é parede
	for y in H:
		for x in W:
			if not ROOM.has_point(Vector2i(x, y)):
				blocked[Vector2i(x, y)] = true
	var body := StaticBody2D.new()
	add_child(body)
	var rp := Vector2(ROOM.position * TILE)
	var rs := Vector2(ROOM.size * TILE)
	_add_rect_collision(body, Vector2(rs.x + 64, 32), rp + Vector2(rs.x / 2.0, -16))           # fundo
	_add_rect_collision(body, Vector2(rs.x + 64, 32), rp + Vector2(rs.x / 2.0, rs.y + 16))     # frente
	_add_rect_collision(body, Vector2(32, rs.y), rp + Vector2(-16, rs.y / 2.0))                # esquerda
	_add_rect_collision(body, Vector2(32, rs.y), rp + Vector2(rs.x + 16, rs.y / 2.0))          # direita

	# móveis (arte de tools/import_house_interior.py)
	var door := _use_point(DOOR_CELL, "Sair de casa")
	door.interacted.connect(func(_w): exit_used.emit())
	_furniture("bookshelf", Vector2i(21, 14), Vector2i(1, 1))
	_furniture("kitchen", Vector2i(23, 14), Vector2i(3, 1))
	kitchen = _use_point(Vector2i(24, 14), "Cozinhar")
	kitchen.interacted.connect(func(_w): stove_used.emit())
	_furniture("cupboard", Vector2i(26, 14), Vector2i(1, 1))
	var ch := _use_point(Vector2i(26, 14), "Abrir o armário")
	ch.interacted.connect(func(_w): chest_used.emit())
	_furniture("nightstand", Vector2i(29, 14), Vector2i(1, 1))
	_furniture("bed", Vector2i(30, 14), Vector2i(2, 2))
	bed_spot = cell_center(Vector2i(30, 16))
	var b := _use_point(Vector2i(30, 16), "Dormir")
	b.position.y -= 14
	b.interacted.connect(func(_w): bed_used.emit())
	_furniture("sofa", Vector2i(20, 17), Vector2i(3, 1))
	_furniture("coffee_table", Vector2i(21, 19), Vector2i(1, 1))
	_furniture("armchair", Vector2i(23, 19), Vector2i(1, 1))
	_furniture("tv_side", Vector2i(18, 19), Vector2i(1, 1))
	_furniture("side_table", Vector2i(27, 18), Vector2i(2, 1))
	_furniture("crate", Vector2i(31, 19), Vector2i(1, 1))
	_furniture("plant_pot", Vector2i(18, 21), Vector2i(1, 1))
	_furniture("flower_box", Vector2i(31, 21), Vector2i(1, 1))
	# objetos que você colocou aqui dentro
	for d in Game.house.get("placeables", []):
		if d is Dictionary and ItemDB.PLACEABLES.has(str(d.get("kind", ""))) and str(d["kind"]) != "stove":
			var pl := place(str(d["kind"]), Vector2i(int(d["x"]), int(d["y"])), true)
			if pl:
				pl.restore(d)
	spawn_pos = cell_center(DOOR_CELL + Vector2i(0, 1))
	_ground_layer.queue_redraw()


## Móvel: sprite com a base na base das células (centrado nelas); bloqueia as células (block=false: só enfeite).
func _furniture(name_: String, cell: Vector2i, size: Vector2i, block := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(DIR + name_ + ".png")
	s.centered = false
	var foot := Vector2(cell * TILE) + Vector2(size.x * TILE / 2.0, size.y * TILE)
	s.position = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height() + 2)
	var holder := Node2D.new()          # o nó fica na base (para ordenar por Y com o jogador)
	holder.position = foot
	holder.add_child(s)
	entities.add_child(holder)
	if block:
		for y in range(cell.y, cell.y + size.y):
			for x in range(cell.x, cell.x + size.x):
				blocked[Vector2i(x, y)] = true
		var body := StaticBody2D.new()
		_add_rect_collision(body, Vector2(size.x * TILE - 4, size.y * TILE - 10), Vector2(0, -size.y * TILE / 2.0 + 1))
		holder.add_child(body)
	return s


func _use_point(c: Vector2i, label: String) -> Interactable:
	var it := Interactable.new()
	it.label = label
	it.reach = 30.0
	it.position = cell_center(c)
	entities.add_child(it)
	return it


## Objetos colocados dentro de casa (para o save).
func serialize_house() -> Array:
	var out := []
	for p in placeables:
		if is_instance_valid(p):
			out.append(p.serialize())
	return out


func _draw_ground() -> void:
	var g := _ground_layer
	g.draw_rect(Rect2(0, 0, W * TILE, H * TILE), DARK)
	var r := Rect2(Vector2(ROOM.position * TILE), Vector2(ROOM.size * TILE))
	# piso: a tábua grande repetida (sem passar do cômodo)
	var fs := _floor.get_size()
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var x := r.position.x - (fs.x / 2.0 if row % 2 else 0.0)
		while x < r.end.x:
			var dst := Rect2(Vector2(x, y), fs).intersection(r)
			if dst.size.x > 0 and dst.size.y > 0:
				g.draw_texture_rect_region(_floor, dst, Rect2(dst.position - Vector2(x, y), dst.size))
			x += fs.x
		y += fs.y
		row += 1
	# tapete da sala
	var rug := _rug
	g.draw_texture(rug, Vector2(21 * TILE + 16 - rug.get_width() / 2.0, 18 * TILE + 26))
	# parede do fundo: reboco com lambri, a janela em cima da cozinha e a porta
	var wall_top := r.position.y - _wall.get_height() + 4
	var x0 := r.position.x
	while x0 < r.end.x:
		var w := minf(_wall.get_width(), r.end.x - x0)
		g.draw_texture_rect_region(_wall, Rect2(x0, wall_top, w, _wall.get_height()), Rect2(0, 0, w, _wall.get_height()))
		x0 += _wall.get_width() - 6
	var win := _win
	g.draw_texture(win, Vector2(24.5 * TILE - win.get_width() / 2.0, wall_top))
	var door := _door
	g.draw_texture(door, Vector2((DOOR_CELL.x + 0.5) * TILE - door.get_width() / 2.0, r.position.y - door.get_height() + 6))
	# laterais e frente
	for yy in range(ROOM.position.y - 2, ROOM.end.y + 1):
		g.draw_texture_rect(_side, Rect2(ROOM.position.x * TILE - 16, yy * TILE, 16, 32), false)
		g.draw_texture_rect(_side, Rect2(ROOM.end.x * TILE, yy * TILE, 16, 32), false)
	for xx in range(ROOM.position.x, ROOM.end.x):
		g.draw_texture_rect(_side, Rect2(xx * TILE, ROOM.end.y * TILE, 32, 14), true)
