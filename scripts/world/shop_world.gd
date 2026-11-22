class_name ShopWorld
extends FarmWorld
## Interior de uma loja da cidade (como a casa: um mundo à parte, com a porta na parede do fundo).
## O morador fica atrás do balcão: tocar nele abre a conversa e, dali, a loja.
## Arte: o mesmo piso/parede da casa (assets/sprites/house_in/) e enfeites de cada ramo.

signal exit_used
signal keeper_used(npc_id: String)

const IN := "res://assets/sprites/"
const ROOM := Rect2i(18, 14, 9, 6)
const DOOR_CELL := Vector2i(19, 14)
const KEEPER_X := 22.5                 # o morador e o balcão ficam no meio do fundo
## Quem atende cada loja (data/npcs: o campo "shop" de cada um)
const KEEPERS := {"fish": "bigode", "smith": "cometa", "bakery": "brioche", "market": "girassol",
	"restaurant": "shiitake", "tailor": "folha"}
## Enfeites de cada loja: [arte, centro x (quadrados), linha da base, com colisão]
const DECOR := {
	"fish": [["house_in/bookshelf", 25.0, 14, true], ["craft/aquarium_large", 25.5, 18, true],
		["house_in/plant_pot", 26.5, 14, true], ["city/barrel", 18.6, 19, true], ["city/barrel", 19.3, 19, true],
		["city/crate", 21.0, 14, true]],
	"smith": [["craft/furnace", 25.3, 14, true], ["house_in/bookshelf", 21.0, 14, true],
		["city/barrel", 26.5, 14, true], ["house_in/crate", 25.6, 19, true], ["city/barrel", 18.6, 19, true]],
	"bakery": [["house_in/kitchen", 25.4, 14, true], ["house_in/cupboard", 21.0, 14, true],
		["house_in/plant_pot", 18.5, 19, true], ["city/crate", 26.4, 19, true], ["craft/preserves_jar", 25.6, 19, true]],
	"market": [["house_in/flower_box", 25.0, 14, true], ["house_in/crate", 21.0, 14, true],
		["house_in/plant_pot", 26.5, 14, true], ["craft/preserves_jar", 18.6, 19, true],
		["city/barrel", 26.5, 19, true], ["city/crate", 25.6, 19, true]],
	"restaurant": [["house_in/kitchen", 25.4, 14, true], ["house_in/coffee_table", 20.0, 18, true],
		["house_in/coffee_table", 25.0, 18, true], ["house_in/plant_pot", 18.5, 19, true],
		["house_in/plant_pot", 26.5, 19, true], ["city/barrel", 21.0, 14, true]],
	"tailor": [["house_in/bookshelf", 21.0, 14, true], ["house_in/cupboard", 25.3, 14, true],
		["house_in/armchair", 25.5, 18, true], ["house_in/plant_pot", 18.5, 19, true],
		["house_in/flower_box", 26.2, 14, true], ["city/crate", 19.3, 19, true]],
}

var kind := ""
var npc_id := ""
var keeper: NPC
var spawn_pos := Vector2.ZERO
var _floor: Texture2D
var _wall: Texture2D
var _side: Texture2D
var _win: Texture2D
var _door: Texture2D
var _rug: Texture2D
var _deco := Node2D.new()


func region_id() -> String:
	return "shop"


func is_indoor() -> bool:
	return true


func water_kind(_c: Vector2i) -> String:
	return ""


func _is_free_grass(_c: Vector2i) -> bool:
	return false


func can_place(_kind: String, _target: Vector2i) -> bool:
	return false


func would_act(item_id: String, c: Vector2i) -> bool:
	return item_id == "" and can_interact_cell(c)


func use_item(item_id: String, c: Vector2i) -> String:
	if item_id == "":
		return interact_cell(c)
	return ""


func generate(saved: Dictionary) -> void:
	kind = str(saved.get("kind", "fish"))
	npc_id = KEEPERS.get(kind, "")
	_floor = load(IN + "house_in/floor_big.png")
	_wall = load(IN + "house_in/wall_plain.png")
	_side = load(IN + "house_in/wall_side.png")
	_win = load(IN + "house_in/wall_window.png")
	_door = load(IN + "house_in/door.png")
	_rug = load(IN + "house_in/rug.png")
	ground.resize(W * H)
	variant.resize(W * H)
	for i in W * H:
		ground[i] = Ground.PATH
	for y in H:
		for x in W:
			if not ROOM.has_point(Vector2i(x, y)):
				blocked[Vector2i(x, y)] = true
	var body := StaticBody2D.new()
	add_child(body)
	var rp := Vector2(ROOM.position * TILE)
	var rs := Vector2(ROOM.size * TILE)
	_add_rect_collision(body, Vector2(rs.x + 64, 32), rp + Vector2(rs.x / 2.0, -16))
	_add_rect_collision(body, Vector2(rs.x + 64, 32), rp + Vector2(rs.x / 2.0, rs.y + 16))
	_add_rect_collision(body, Vector2(32, rs.y), rp + Vector2(-16, rs.y / 2.0))
	_add_rect_collision(body, Vector2(32, rs.y), rp + Vector2(rs.x + 16, rs.y / 2.0))

	var door := Interactable.new()
	door.label = "Sair da loja"
	door.reach = 30.0
	door.position = cell_center(DOOR_CELL)
	door.interacted.connect(func(_w): exit_used.emit())
	entities.add_child(door)
	spawn_pos = cell_center(DOOR_CELL + Vector2i(0, 1))

	# balcão e o morador atrás dele
	_piece("house_in/side_table", KEEPER_X, ROOM.position.y + 1, true)
	if npc_id != "":
		keeper = NPC.new()
		keeper.setup(Villagers.get_npc(npc_id), self)
		keeper.stationary = true
		keeper.position = Vector2(KEEPER_X * TILE, ROOM.position.y * TILE + 26)
		keeper.interacted.connect(func(_w): keeper_used.emit(npc_id))
		entities.add_child(keeper)
		keeper.reach = 62.0          # dá para falar por cima do balcão
		blocked[Vector2i(int(KEEPER_X), ROOM.position.y)] = true
	for d in DECOR.get(kind, []):
		_piece(d[0], d[1], d[2], d[3])

	_deco.z_index = -9
	_deco.draw.connect(_draw_room)
	add_child(_deco)
	var wall_top := ROOM.position.y * TILE - _wall.get_height() + 4
	add_glow(self, Vector2((ROOM.position.x + ROOM.size.x / 2.0) * TILE, wall_top + 20), 70.0, true)
	_ground_layer.queue_redraw()


func _piece(art: String, cx: float, base_row: int, solid: bool) -> void:
	var holder := StaticBody2D.new()
	holder.position = Vector2(cx * TILE, (base_row + 1) * TILE - 2)
	var s := Sprite2D.new()
	s.texture = load(IN + art + ".png")
	s.position = Vector2(0, -s.texture.get_height() / 2.0)
	holder.add_child(s)
	entities.add_child(holder)
	var w := float(s.texture.get_width())
	if solid:
		_add_rect_collision(holder, Vector2(maxf(10.0, w - 8.0), 22), Vector2(0, -11))
		for x in range(int(floor(cx - w / 2.0 / TILE)), int(ceil(cx + w / 2.0 / TILE))):
			blocked[Vector2i(x, base_row)] = true


func _draw_ground() -> void:
	# fora do cômodo: escuro (o piso e as paredes são desenhados em _draw_room)
	_ground_layer.draw_rect(Rect2(0, 0, W * TILE, H * TILE), Color("1c130d"))


func _draw_room() -> void:
	var g := _deco
	var r := Rect2(Vector2(ROOM.position * TILE), Vector2(ROOM.size * TILE))
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
	g.draw_texture(_rug, Vector2(KEEPER_X * TILE - _rug.get_width() / 2.0, (ROOM.position.y + 3) * TILE))
	var wall_top := r.position.y - _wall.get_height() + 4
	var x0 := r.position.x
	while x0 < r.end.x:
		var w := minf(_wall.get_width(), r.end.x - x0)
		g.draw_texture_rect_region(_wall, Rect2(x0, wall_top, w, _wall.get_height()), Rect2(0, 0, w, _wall.get_height()))
		x0 += _wall.get_width() - 6
	g.draw_texture(_win, Vector2(KEEPER_X * TILE - _win.get_width() / 2.0, wall_top))
	g.draw_texture(_door, Vector2((DOOR_CELL.x + 0.5) * TILE - _door.get_width() / 2.0, r.position.y - _door.get_height() + 6))
	for yy in range(ROOM.position.y - 2, ROOM.end.y + 1):
		g.draw_texture_rect(_side, Rect2(ROOM.position.x * TILE - 16, yy * TILE, 16, 32), false)
		g.draw_texture_rect(_side, Rect2(ROOM.end.x * TILE, yy * TILE, 16, 32), false)
	for xx in range(ROOM.position.x, ROOM.end.x):
		g.draw_texture_rect(_side, Rect2(xx * TILE, ROOM.end.y * TILE, 32, 14), true)
