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

	# porta (fixa) e móveis (podem ser mudados de lugar no modo decorar)
	var door := _use_point(DOOR_CELL, "Sair de casa")
	door.interacted.connect(func(_w): exit_used.emit())
	var layout: Dictionary = Game.house.get("layout", {})
	for id in DEFAULT_LAYOUT:
		var d: Array = DEFAULT_LAYOUT[id]
		var sv = layout.get(id)
		var cell := Vector2i(int(d[1]), int(d[2]))
		var view := 0
		if sv is Array and sv.size() >= 3:
			cell = Vector2i(int(sv[0]), int(sv[1]))
			view = int(sv[2])
		_add_furniture(id, str(d[0]), cell, view)
	_rebuild_blocked()
	# objetos que você colocou aqui dentro
	for d in Game.house.get("placeables", []):
		if d is Dictionary and ItemDB.PLACEABLES.has(str(d.get("kind", ""))) and str(d["kind"]) != "stove":
			var pl := place(str(d["kind"]), Vector2i(int(d["x"]), int(d["y"])), true)
			if pl:
				pl.restore(d)
	spawn_pos = cell_center(DOOR_CELL + Vector2i(0, 1))
	_floor_node = Node2D.new()
	_floor_node.z_index = -9
	_floor_node.material = _recolor_mat()
	_floor_node.draw.connect(_draw_floor)
	add_child(_floor_node)
	_wall_node = Node2D.new()
	_wall_node.z_index = -9
	_wall_node.material = _recolor_mat()
	_wall_node.draw.connect(_draw_walls)
	add_child(_wall_node)
	apply_colors()
	_ground_layer.queue_redraw()


## Móveis da casa: id -> [peça, x, y]. Peças em PIECES.
const DEFAULT_LAYOUT := {
	"bookshelf": ["bookshelf", 21, 14], "kitchen": ["kitchen", 23, 14], "cupboard": ["cupboard", 26, 14],
	"nightstand": ["nightstand", 29, 14], "bed": ["bed", 30, 14], "sofa": ["sofa", 20, 17],
	"rug": ["rug", 20, 19], "coffee_table": ["coffee_table", 21, 19], "armchair": ["armchair", 23, 19],
	"tv": ["tv", 18, 19], "side_table": ["side_table", 27, 18], "crate": ["crate", 31, 19],
	"plant1": ["plant_pot", 18, 21], "plant2": ["flower_box", 31, 21],
}
## Peça -> vistas [imagem, tamanho em células, espelhar]. A 1ª é de frente; as outras, de lado (Girar).
const PIECES := {
	"bed": [["bed", Vector2i(2, 2), false], ["bed_side", Vector2i(2, 1), false], ["bed_side", Vector2i(2, 1), true]],
	"armchair": [["armchair", Vector2i(1, 1), false], ["armchair_side", Vector2i(1, 1), false],
		["armchair_side", Vector2i(1, 1), true]],
	"tv": [["tv_side", Vector2i(1, 1), false], ["tv_side", Vector2i(1, 1), true], ["tv", Vector2i(2, 1), false]],
	"bookshelf": [["bookshelf", Vector2i(1, 1), false]], "kitchen": [["kitchen", Vector2i(3, 1), false]],
	"cupboard": [["cupboard", Vector2i(1, 1), false]], "nightstand": [["nightstand", Vector2i(1, 1), false]],
	"sofa": [["sofa", Vector2i(3, 1), false]], "coffee_table": [["coffee_table", Vector2i(1, 1), false]],
	"side_table": [["side_table", Vector2i(2, 1), false]], "crate": [["crate", Vector2i(1, 1), false]],
	"plant_pot": [["plant_pot", Vector2i(1, 1), false]], "flower_box": [["flower_box", Vector2i(1, 1), false]],
	"rug": [["rug", Vector2i(3, 2), false]],
}
const FLOOR_PIECES := ["rug"]       # ficam no chão (dá para andar e pôr móveis em cima)

var furniture := {}                 # id -> nó do móvel (Node2D com metadados)
var decorating := false
var _floor_node: Node2D
var _wall_node: Node2D

## Variações de cor da decoração: [nome, giro de matiz, saturação, brilho]. Para criar mais opções,
## é só acrescentar linhas aqui (o 1º item é a cor original da arte).
const COLORS := {
	"floor": [["Madeira natural", 0.0, 1.0, 1.0], ["Madeira escura", 0.0, 1.05, 0.7], ["Madeira clara", 0.01, 0.7, 1.2],
		["Mel", 0.03, 1.15, 1.1], ["Cinza rústico", 0.0, 0.15, 0.95], ["Avermelhada", -0.03, 1.2, 0.85]],
	"wall": [["Natural", 0.0, 1.0, 1.0], ["Rosa", -0.1, 1.25, 1.04], ["Verde-menta", 0.22, 1.1, 1.02],
		["Azul-céu", 0.48, 1.3, 1.04], ["Lilás", 0.68, 1.15, 1.04], ["Amarelo", 0.03, 1.5, 1.03], ["Cinza", 0.0, 0.1, 0.92],
		["Pêssego", -0.03, 1.3, 1.02]],
	"furniture": [["Original", 0.0, 1.0, 1.0], ["Madeira escura", 0.0, 1.05, 0.7], ["Madeira clara", 0.01, 0.7, 1.2],
		["Cinza", 0.0, 0.12, 1.0], ["Azulado", 0.5, 0.7, 1.0], ["Avermelhado", -0.05, 1.25, 0.95],
		["Esverdeado", 0.18, 0.9, 0.95], ["Lilás", 0.7, 0.6, 1.0]],
}
const RECOLOR := preload("res://assets/shaders/recolor.gdshader")
var selected: Node2D
var _bed_use: Interactable


func _add_furniture(id: String, piece: String, cell: Vector2i, view: int) -> void:
	var holder := Node2D.new()
	holder.name = "F_" + id
	holder.set_meta("id", id)
	holder.set_meta("piece", piece)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.name = "Sprite"
	holder.add_child(spr)
	if piece in FLOOR_PIECES:
		holder.z_index = -5
	else:
		var body := StaticBody2D.new()
		body.name = "Body"
		holder.add_child(body)
	# usos que vão junto com o móvel
	match id:
		"kitchen":
			kitchen = _use_point_on(holder, "Cozinhar")
			kitchen.interacted.connect(func(_w): stove_used.emit())
		"cupboard":
			var ch := _use_point_on(holder, "Abrir o armário")
			ch.interacted.connect(func(_w): chest_used.emit())
		"bed":
			_bed_use = _use_point_on(holder, "Dormir")
			_bed_use.interacted.connect(func(_w): bed_used.emit())
	entities.add_child(holder)
	furniture[id] = holder
	_set_furniture(holder, cell, view)


func _use_point_on(holder: Node2D, label: String) -> Interactable:
	var it := Interactable.new()
	it.label = label
	it.reach = 30.0
	holder.add_child(it)
	return it


static func view_of(piece: String, view: int) -> Array:
	var vs: Array = PIECES[piece]
	return vs[posmod(view, vs.size())]


func furniture_cells(holder: Node2D) -> Array:
	var v := view_of(holder.get_meta("piece"), holder.get_meta("view"))
	var c: Vector2i = holder.get_meta("cell")
	var size: Vector2i = v[1]
	var out := []
	for y in range(c.y, c.y + size.y):
		for x in range(c.x, c.x + size.x):
			out.append(Vector2i(x, y))
	return out


## Põe o móvel numa célula (canto de cima à esquerda) com uma vista.
func _set_furniture(holder: Node2D, cell: Vector2i, view: int) -> void:
	var piece: String = holder.get_meta("piece")
	view = posmod(view, (PIECES[piece] as Array).size())
	var v := view_of(piece, view)
	var size: Vector2i = v[1]
	holder.set_meta("cell", cell)
	holder.set_meta("view", view)
	var spr: Sprite2D = holder.get_node("Sprite")
	spr.texture = load(DIR + str(v[0]) + ".png")
	spr.flip_h = bool(v[2])
	var foot := Vector2(cell * TILE) + Vector2(size.x * TILE / 2.0, size.y * TILE)
	holder.position = foot
	spr.position = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height() + 2)
	if piece in FLOOR_PIECES:
		spr.position = Vector2(-spr.texture.get_width() / 2.0, -size.y * TILE / 2.0 - spr.texture.get_height() / 2.0)
	var body = holder.get_node_or_null("Body")
	if body:
		for ch in body.get_children():
			ch.free()
		_add_rect_collision(body, Vector2(size.x * TILE - 4, size.y * TILE - 10), Vector2(0, -size.y * TILE / 2.0 + 1))
	for it in holder.get_children():
		if it is Interactable:
			it.position = Vector2(0, -size.y * TILE / 2.0 + 4)
	if holder.get_meta("id") == "bed":
		bed_spot = holder.position
	queue_redraw()
	Game.house["layout"] = Game.house.get("layout", {})
	Game.house["layout"][holder.get_meta("id")] = [cell.x, cell.y, view]


## Células ocupadas: fora do cômodo e os móveis (o tapete não conta).
func _rebuild_blocked() -> void:
	blocked.clear()
	for y in H:
		for x in W:
			if not ROOM.has_point(Vector2i(x, y)):
				blocked[Vector2i(x, y)] = true
	for h in furniture.values():
		if h.get_meta("piece") in FLOOR_PIECES:
			continue
		for c in furniture_cells(h):
			blocked[c] = true


## Dá para pôr o móvel ali? (dentro do cômodo, sem cobrir outro móvel, a porta ou um aquário)
func can_put(holder: Node2D, cell: Vector2i, view: int) -> bool:
	var piece: String = holder.get_meta("piece")
	var size: Vector2i = view_of(piece, view)[1]
	var floor_piece: bool = piece in FLOOR_PIECES
	var others := {}
	if not floor_piece:
		for h in furniture.values():
			if h != holder and not (h.get_meta("piece") in FLOOR_PIECES):
				for c in furniture_cells(h):
					others[c] = true
	for y in range(cell.y, cell.y + size.y):
		for x in range(cell.x, cell.x + size.x):
			var c := Vector2i(x, y)
			if not ROOM.has_point(c) or others.has(c):
				return false
			if not floor_piece and (occupied.has(c) or c == DOOR_CELL or c == DOOR_CELL + Vector2i(0, 1)):
				return false
	return true


# ------------------------------------------------------------------ modo decorar
func set_decorating(on: bool) -> void:
	decorating = on
	select(null)


func select(h: Node2D) -> void:
	if selected and is_instance_valid(selected):
		selected.modulate = Color.WHITE
	selected = h
	if selected:
		selected.modulate = Color(1.25, 1.25, 0.85)
	queue_redraw()


## Toque no modo decorar: num móvel escolhe; no chão leva o escolhido para lá. Devolve um aviso ("" se nada).
func decor_tap(wp: Vector2) -> String:
	var c := cell_of(wp)
	var hit: Node2D = null
	for h in furniture.values():
		if c in furniture_cells(h) and (hit == null or not (h.get_meta("piece") in FLOOR_PIECES)):
			hit = h
	if hit and hit != selected and (selected == null or not (hit.get_meta("piece") in FLOOR_PIECES)):
		select(hit)
		return ""
	if selected == null:
		return "Toque num móvel para escolher."
	# o toque marca o meio de baixo do móvel
	var size: Vector2i = view_of(selected.get_meta("piece"), selected.get_meta("view"))[1]
	var cell := Vector2i(c.x - (size.x - 1) / 2, c.y - size.y + 1)
	if not can_put(selected, cell, selected.get_meta("view")):
		return "Não cabe aí."
	_set_furniture(selected, cell, selected.get_meta("view"))
	_rebuild_blocked()
	Sound.play("build", -4.0)
	return ""


## Gira o móvel escolhido (frente / lado / outro lado). Devolve um aviso.
func rotate_selected() -> String:
	if selected == null:
		return "Toque num móvel para escolher."
	var piece: String = selected.get_meta("piece")
	var n := (PIECES[piece] as Array).size()
	if n < 2:
		return "Este móvel só tem a vista de frente."
	var cell: Vector2i = selected.get_meta("cell")
	for k in range(1, n):
		var v: int = (int(selected.get_meta("view")) + k) % n
		if can_put(selected, cell, v):
			_set_furniture(selected, cell, v)
			_rebuild_blocked()
			Sound.play("ui_click")
			return ""
	return "Não dá para girar aqui: falta espaço."


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


# ------------------------------------------------------------------ cores
func _recolor_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = RECOLOR
	return m


static func _set_color(m: ShaderMaterial, kind: String, i: int) -> void:
	var c: Array = COLORS[kind][posmod(i, (COLORS[kind] as Array).size())]
	m.set_shader_parameter("hue_shift", c[1])
	m.set_shader_parameter("sat_mult", c[2])
	m.set_shader_parameter("val_mult", c[3])


func _colors() -> Dictionary:
	if not (Game.house.get("colors") is Dictionary):
		Game.house["colors"] = {}
	var c: Dictionary = Game.house["colors"]
	if not (c.get("furniture") is Dictionary):
		c["furniture"] = {}
	return c


## Aplica as cores salvas (piso, paredes e cada móvel).
func apply_colors() -> void:
	var c := _colors()
	if _floor_node:
		_set_color(_floor_node.material, "floor", int(c.get("floor", 0)))
		_set_color(_wall_node.material, "wall", int(c.get("wall", 0)))
		_wall_node.material.set_shader_parameter("light_only", true)
	for id in furniture:
		var spr: Sprite2D = furniture[id].get_node("Sprite")
		if spr.material == null:
			spr.material = _recolor_mat()
		_set_color(spr.material, "furniture", int(c["furniture"].get(id, 0)))


## Troca para a próxima cor do piso ("floor"), das paredes ("wall") ou do móvel escolhido ("furniture").
## Devolve o nome da cor (ou um aviso).
func next_color(kind: String) -> String:
	var c := _colors()
	var n: int = (COLORS[kind] as Array).size()
	var i: int
	if kind == "furniture":
		if selected == null:
			return "Toque num móvel para escolher."
		var id: String = selected.get_meta("id")
		i = (int(c["furniture"].get(id, 0)) + 1) % n
		c["furniture"][id] = i
	else:
		i = (int(c.get(kind, 0)) + 1) % n
		c[kind] = i
	apply_colors()
	Sound.play("ui_click")
	var what: String = {"floor": "Piso", "wall": "Paredes", "furniture": "Móvel"}[kind]
	return "%s: %s" % [what, COLORS[kind][i][0]]


func _draw() -> void:
	# modo decorar: contorno do móvel escolhido
	if decorating and selected and is_instance_valid(selected):
		for c in furniture_cells(selected):
			draw_rect(Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), Color(1, 0.95, 0.4, 0.25))
			draw_rect(Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), Color(1, 0.9, 0.3, 0.8), false, 1.0)


func _draw_ground() -> void:
	var g := _ground_layer
	g.draw_rect(Rect2(0, 0, W * TILE, H * TILE), DARK)
	var r := Rect2(Vector2(ROOM.position * TILE), Vector2(ROOM.size * TILE))



func _draw_floor() -> void:
	var g := _floor_node
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



func _draw_walls() -> void:
	var g := _wall_node
	var r := Rect2(Vector2(ROOM.position * TILE), Vector2(ROOM.size * TILE))
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
