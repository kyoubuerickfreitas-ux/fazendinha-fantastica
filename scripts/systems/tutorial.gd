class_name Tutorial
extends Node2D
## Tutorial dos primeiros dias: uma lista de passos com objetivo, verificação e recompensa.
## Mostra o objetivo num painel da HUD e uma setinha no mapa apontando para onde ir.
## Estado em Game.tutorial {"step", "base", "done"}.
##
## Cada passo: text (objetivo), metric (o que medir), goal (quanto precisa subir desde o começo
## do passo; com "abs": true conta o total), target (para onde a seta aponta), reward.

const STEPS := [
	{"text": "Bem-vindo à Fazendinha! Arraste o joystick (canto esquerdo) para andar.",
		"metric": "moved", "goal": 1},
	{"text": "Selecione a Enxada na barra de baixo e toque no botão grande, na grama, para arar 3 quadrados.",
		"metric": "soil", "goal": 3, "target": "field"},
	{"text": "Selecione as Sementes de Couve-Musgo e plante nos quadrados arados.",
		"metric": "planted", "goal": 3, "target": "soil"},
	{"text": "Selecione o Regador: encha na água e regue as sementes plantadas.",
		"metric": "watered", "goal": 3, "target": "water", "reward": {"money": 50}},
	{"text": "Corte uma árvore com o Machado para juntar madeira.",
		"metric": "item:wood", "goal": 3, "target": "tree", "reward": {"wood": 10, "stone": 15},
		"done": "O Fungo deixou umas pedras e madeiras para você construir coisas!"},
	{"text": "Visite o Fungo na barraca dele: ele vende sementes e compra tudo.",
		"metric": "counter:shop", "goal": 1, "target": "shop", "reward": {"money": 50}},
	{"text": "Faça carinho num animal do pasto: chegue perto e toque no botão da mão.",
		"metric": "counter:pets", "goal": 1, "target": "animal"},
	{"text": "Pegue a Vara de Pesca e use na água. Quando aparecer o \"!\", toque rápido e depois várias vezes para puxar.",
		"metric": "fish", "goal": 1, "abs": true, "target": "water", "reward": {"bait_worm": 5}},
	{"text": "Converse com um morador. A Pipoca costuma brincar perto da barraca do Fungo.",
		"metric": "counter:talks", "goal": 1, "target": "villager"},
	{"text": "Na bancada ao lado de casa, fabrique um Fogão.",
		"metric": "stove", "goal": 1, "abs": true, "target": "workbench"},
	{"text": "Coloque o Fogão no chão (selecione e toque) e cozinhe um prato, como o Peixe na Brasa.",
		"metric": "cooked", "goal": 1, "abs": true, "target": "stove", "reward": {"money": 80}},
	{"text": "Segure o prato e toque no botão de usar para comer: recupera energia!",
		"metric": "counter:eaten", "goal": 1, "abs": true},
	{"text": "Venda algo: chegue perto da caixa de vendas ao lado de casa e toque nela.",
		"metric": "counter:sold", "goal": 1, "target": "bin"},
	{"text": "Quando escurecer, durma na porta de casa. O dia passa e o jogo é salvo.",
		"metric": "day", "goal": 1, "target": "door"},
	{"text": "Regue as plantas todo dia. Colha a Couve-Musgo quando o canteiro tiver uma estrelinha.",
		"metric": "counter:harvests", "goal": 1, "abs": true, "target": "soil", "reward": {"money": 100}},
	{"text": "Abra o Livro de Pesca (botão do livro) para ver os peixes, tesouros e pedidos.",
		"metric": "counter:book", "goal": 1},
]
const FINAL_REWARD := 300

var world: FarmWorld
var player: Node2D
var hud: HUD
var _check := 0.0
var _t := 0.0
var _arrow_to := Vector2.INF


func _ready() -> void:
	z_index = 60
	_refresh_panel()


func active() -> bool:
	return not Game.tutorial.get("done", false)


func step() -> Dictionary:
	return STEPS[clampi(int(Game.tutorial["step"]), 0, STEPS.size() - 1)]


func skip() -> void:
	Game.tutorial["done"] = true
	_refresh_panel()
	queue_redraw()


# ------------------------------------------------------------------ medir
func metric(name: String) -> int:
	if name.begins_with("item:"):
		return Game.count_item(name.trim_prefix("item:"))
	if name.begins_with("counter:"):
		return Game.counter(name.trim_prefix("counter:"))
	match name:
		"moved":
			return 1 if player.position.distance_to(world.player_start) > 80.0 else 0
		"soil":
			return world.soil.size()
		"planted":
			return world.soil.values().filter(func(c): return Agri.has_crop(c)).size()
		"watered":
			return world.soil.values().filter(func(c): return Agri.has_crop(c) and float(c["moist"]) >= 0.5).size()
		"day":
			return Game.day
		"fish":
			var n := 0
			for id in Game.fish_log:
				n += int(Game.fish_log[id]["n"])
			return n
		"cooked":
			return Game.dishes_cooked
		"stove":
			return Game.count_item("stove") + world.placeables.filter(func(p): return is_instance_valid(p) and p.kind == "stove").size()
	return 0


func _process(delta: float) -> void:
	_t += delta
	if not active():
		if _arrow_to != Vector2.INF:
			_arrow_to = Vector2.INF
			queue_redraw()
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.25
		_update_step()
		_arrow_to = _target_pos(step().get("target", ""))
	queue_redraw()


func _update_step() -> void:
	var s := step()
	var value := metric(s["metric"])
	if int(Game.tutorial.get("base", -1)) < 0:
		Game.tutorial["base"] = 0 if s.get("abs", false) else value
	if value - int(Game.tutorial["base"]) >= int(s["goal"]):
		_complete(s)


func _complete(s: Dictionary) -> void:
	var text: String = s.get("done", "Muito bem!")
	var reward: Dictionary = s.get("reward", {})
	var parts := []
	for k in reward:
		if k == "money":
			Game.add_money(int(reward[k]))
			parts.append("%d moedas" % int(reward[k]))
		else:
			Game.add_item(k, int(reward[k]))
			parts.append("%d %s" % [int(reward[k]), ItemDB.item_name(k)])
	if not parts.is_empty():
		text += " +" + ", ".join(parts)
	Game.tutorial["step"] = int(Game.tutorial["step"]) + 1
	Game.tutorial["base"] = -1
	if int(Game.tutorial["step"]) >= STEPS.size():
		Game.tutorial["done"] = true
		Game.add_money(FINAL_REWARD)
		text = "Tutorial concluído! +%d moedas. Agora a fazenda é toda sua." % FINAL_REWARD
	_refresh_panel()
	Game.toast.emit(text)


func _refresh_panel() -> void:
	if hud == null:
		return
	if not active():
		hud.set_tutorial("", "")
		return
	hud.set_tutorial(step()["text"], "Tutorial %d/%d" % [int(Game.tutorial["step"]) + 1, STEPS.size()])


# ------------------------------------------------------------------ seta
func _nearest(points: Array) -> Vector2:
	var best := Vector2.INF
	for p in points:
		if best == Vector2.INF or player.position.distance_to(p) < player.position.distance_to(best):
			best = p
	return best


func _target_pos(target: String) -> Vector2:
	var pts := []
	match target:
		"shop":
			return world.fungo.position + Vector2(0, -60) if world.fungo else Vector2.INF
		"door":
			return world.house_door.position + Vector2(0, -30) if world.house_door else Vector2.INF
		"bin":
			return world.sell_bin.position + Vector2(0, -34) if world.sell_bin else Vector2.INF
		"workbench", "stove":
			for p in world.placeables:
				if is_instance_valid(p) and p.kind == target:
					pts.append(p.position + Vector2(0, -44))
			if pts.is_empty() and target == "stove":
				return _target_pos("workbench") if Game.count_item("stove") == 0 else Vector2.INF
		"animal":
			for a in world.animals:
				if is_instance_valid(a) and a.visible:
					pts.append(a.position + Vector2(0, -40))
		"villager":
			for v in world.villagers:
				if v.visible:
					pts.append(v.position + Vector2(0, -64))
		"tree":
			for c in world.props:
				if world.props[c].kind in ["tree", "pine", "old_tree"]:
					pts.append(world.cell_center(c) + Vector2(0, -60))
		"water":
			var pc := Vector2i(player.position / FarmWorld.TILE)
			for dy in range(-14, 15):
				for dx in range(-14, 15):
					var c := pc + Vector2i(dx, dy)
					if world.ground_at(c) == FarmWorld.Ground.WATER and world.is_inside(c):
						pts.append(world.cell_center(c) + Vector2(0, -24))
		"soil":
			for c in world.soil:
				pts.append(world.cell_center(c) + Vector2(0, -26))
		"field":
			return world.cell_center(Vector2i(8, 12)) + Vector2(0, -24)
	return _nearest(pts)


func _draw() -> void:
	if _arrow_to == Vector2.INF or player == null or player.position.distance_to(_arrow_to) < 48.0:
		return
	var ink := Color("2b2118")
	var fill := Color("f2c14e")
	# área visível do mundo (pela câmera)
	var vp := get_viewport()
	var inv := get_global_transform_with_canvas().affine_inverse()
	var view := Rect2(inv * Vector2.ZERO, inv.basis_xform(vp.get_visible_rect().size))
	var inner := view.grow(-36)
	if not inner.has_point(_arrow_to):
		# alvo fora da tela: seta na borda apontando para ele
		var c := inner.get_center()
		var dir := (_arrow_to - c).normalized()
		var tx := INF if is_zero_approx(dir.x) else (inner.size.x / 2.0) / absf(dir.x)
		var ty := INF if is_zero_approx(dir.y) else (inner.size.y / 2.0) / absf(dir.y)
		var e := c + dir * minf(tx, ty) + dir * sin(_t * 5.0) * 3.0
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([e + dir * 12, e - dir * 6 + side * 10, e - dir * 6 - side * 10]), ink)
		draw_colored_polygon(PackedVector2Array([e + dir * 8, e - dir * 4 + side * 6, e - dir * 4 - side * 6]), fill)
		return
	var p := _arrow_to + Vector2(0, sin(_t * 5.0) * 4.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -14), p + Vector2(9, -14), p]), ink)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -12), p + Vector2(6, -12), p + Vector2(0, -3)]), fill)
	draw_rect(Rect2(p + Vector2(-4, -24), Vector2(8, 11)), ink)
	draw_rect(Rect2(p + Vector2(-2, -23), Vector2(4, 10)), fill)
