extends SceneTree
## Teste rápido: abre o jogo, executa ações e salva capturas de tela.
## Uso: godot --path . -s tests/smoke_test.gd -- <pasta_de_saida>

var out := "user://"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("captura: ", name)


## Usa a ferramenta e espera a animação terminar.
func _use(p) -> void:
	p._busy = 0
	p.use_tool()
	while not p._action.is_empty():
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _run() -> void:
	var game = root.get_node("Game")
	game.delete_save()
	game.reset_new_game()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	await _shot("01_inicio")

	var p = main.player
	var w = main.world
	# anda até a área de plantio
	game.joystick_vector = Vector2(0.2, 1)
	await _wait(2.2)
	game.joystick_vector = Vector2.ZERO
	await _wait(0.2)
	# ara, planta, rega numa fileira
	for i in 4:
		var c: Vector2i = p.target_cell()
		var prop = w.props.get(c)
		if prop:
			prop.queue_free(); w.props.erase(c)
		game.select_slot(1); await _use(p)
		game.select_slot(5); await _use(p)
		game.select_slot(0); await _use(p)
		if i == 1:
			await _wait(0.15)
			await _shot("02b_efeito")
		game.joystick_vector = Vector2(1, 0)
		await _wait(0.38)
		game.joystick_vector = Vector2(0, 1)
		await _wait(0.05)
		game.joystick_vector = Vector2.ZERO
		await _wait(0.1)
	# animação de ferramenta (de frente): captura no meio do golpe
	var back: Vector2 = p.position
	p.position = w.player_start + Vector2(64, 40)
	main.camera.reset_smoothing()
	await _wait(0.1)
	p.facing = Vector2.DOWN
	p._dir = Player.Dir.DOWN
	game.select_slot(2)
	p._busy = 0
	p.use_tool()
	await _wait(0.33)
	await _shot("02c_golpe")
	while not p._action.is_empty():
		await process_frame
	p.position = back
	main.camera.reset_smoothing()
	await _shot("02_plantando")
	# avança dias regando tudo
	for d in 3:
		for c in w.soil: w.soil[c]["moist"] = 1.0
		game.start_new_day(true)
		w.on_new_day()
	w._soil_layer.queue_redraw()
	await _shot("03_crescido")
	# colhe tudo e vende na caixa
	var cells: Array = w.soil.keys()
	for c in cells:
		w.interact_cell(c)
	print("couves colhidas: ", game.count_item("kale"))
	main._sell_all()
	print("dinheiro depois da venda: ", game.money)
	assert(game.money > 500, "a venda deveria aumentar o dinheiro")
	main.save_now()
	var reloaded: Dictionary = game.load_game()
	print("save ok, canteiros salvos: ", reloaded.get("soil", []).size())
	# comedouro cheio antes do teste dos animais
	for pl in w.placeables:
		if pl.kind == "feeder":
			pl.hay = 20
	# animais: carinho, novo dia, coleta
	var cow = w.animals[0]
	cow.has_product = false
	cow.petted_today = false
	cow._on_interact(p)
	assert(cow.petted_today, "carinho deveria marcar o dia")
	w.on_new_day()
	assert(cow.has_product, "o Moombor deveria ter leite no dia seguinte")
	cow._on_interact(p)
	print("leite coletado: ", game.count_item("milk"))
	assert(game.count_item("milk") == 1)
	for an in w.animals:
		an.has_product = an != cow
		an._refresh()
	p.position = Vector2(38 * 32, 16 * 32)
	main.camera.reset_smoothing()
	await _wait(2.5)
	await _shot("07_pasto")
	# mira: pedra ao lado, personagem de costas para ela -> a mira automática acerta
	var rock_cell := Vector2i(-1, -1)
	for c in w.props:
		if w.props[c].kind == "rock":
			rock_cell = c
			break
	var rock = w.props[rock_cell]
	p.position = Vector2(rock_cell.x * 32 + 16 + 30, rock_cell.y * 32 + 28)
	p.facing = Vector2.RIGHT
	game.select_slot(3)   # picareta
	var hp0: int = rock.hp
	await _use(p)
	print("mira automática na pedra: hp ", hp0, " -> ", rock.hp)
	assert(rock.hp == hp0 - 1, "a mira automática deveria acertar a pedra")

	# toque na copa de uma árvore próxima
	var tree = null
	for c in w.props:
		if w.props[c].kind == "tree":
			tree = w.props[c]
			break
	p.position = tree.position + Vector2(40, 10)
	main.camera.reset_smoothing()
	await _wait(0.3)
	game.select_slot(2)   # machado
	p._busy = 0
	var hp1: int = tree.hp
	var screen: Vector2 = main.get_viewport().get_canvas_transform() * (tree.position + Vector2(0, -40))
	main._on_world_tap(screen)
	while not p._action.is_empty():
		await process_frame
	print("toque na árvore: hp ", hp1, " -> ", tree.hp)
	assert(tree.hp == hp1 - 1, "tocar na árvore deveria usar o machado nela")
	await _wait(0.1)
	await _shot("08_mira")

	# pesca: isca, lançar, fisgar, puxar
	var fishing = main.player.fishing
	var water_cell := Vector2i(-1, -1)
	for y in range(w.H):
		for x in range(w.W):
			if w.ground_at(Vector2i(x, y)) == FarmWorld.Ground.WATER and w.ground_at(Vector2i(x, y - 1)) != FarmWorld.Ground.WATER:
				water_cell = Vector2i(x, y)
				break
		if water_cell.x >= 0:
			break
	p.position = Vector2(water_cell.x * 32 + 16, (water_cell.y - 1) * 32 + 20)
	main.camera.reset_smoothing()
	game.inventory[0] = {"id": "bait_cricket", "qty": 3}
	game.inventory[1] = {"id": "fishing_rod", "qty": 1}
	game.select_slot(0); await _use(p)
	assert(game.equipped_bait == "bait_cricket", "a isca deveria ir para a vara")
	game.select_slot(1); p._busy = 0
	print("alvo da vara: ", p.target_cell(), " água: ", water_cell)
	p.use_tool()
	await _wait(0.2)
	await _shot("09a_lancando")
	while not p._action.is_empty():
		await process_frame
	assert(fishing.state == Fishing.State.WAITING, "deveria estar esperando o peixe")
	assert(game.count_item("bait_cricket") == 2, "o lançamento gasta 1 isca")
	fishing._timer = 0.01
	await _wait(0.1)
	assert(fishing.state == Fishing.State.BITE, "deveria ter fisgada")
	await _shot("09_fisgada")
	p.use_tool()
	assert(fishing.state == Fishing.State.REELING)
	await _wait(0.2)
	await _shot("10_puxando")
	for i in 30:
		if fishing.state != Fishing.State.REELING:
			break
		p.use_tool()
		await _wait(0.05)
	var caught := 0
	for id in ItemDB.FISH:
		caught += game.count_item(id)
	print("peixes pescados: ", caught)
	assert(caught == 1, "deveria ter pescado 1 peixe")
	# estatística do sorteio por isca
	for bait in ["", "bait_worm", "bait_fly"]:
		var rar := [0, 0, 0, 0]
		for i in 2000:
			rar[ItemDB.FISH[Fishing.roll_fish(bait, false, false)]["rarity"]] += 1
		print("isca '%s' -> comum/incomum/raro/lendário: %s" % [bait, rar])

	# bancada: fabricar, construir, máquina, feno, celeiro e compra de animal
	game.add_item("wood", 200)
	game.add_item("stone", 100)
	game.add_item("fiber", 20)
	game.add_money(2000)
	main.hud.open_crafting()
	await _wait(0.2)
	await _shot("11_bancada")
	main.hud.close_panel()
	assert(ItemDB.can_afford({"wood": 20, "stone": 10}))
	game.add_item("cheese_press", 1)
	game.add_item("barn", 1)
	var spot := Vector2i(20, 6)
	p.position = Vector2(spot.x * 32 + 16, (spot.y + 1) * 32 + 20)
	main.camera.reset_smoothing()
	await _wait(0.1)
	var press_slot: int = game.inventory.find(game.inventory.filter(func(x): return x != null and x["id"] == "cheese_press")[0])
	game.swap_slots(press_slot, 0)
	game.select_slot(0)
	print("prensa pode construir em ", spot, ": ", w.can_place("cheese_press", spot))
	p.use_at(spot)
	var press = w.occupied.get(spot)
	assert(press != null and press.kind == "cheese_press", "a prensa deveria ser construída")
	game.add_item("milk", 1)
	var milk_slot: int = game.inventory.find(game.inventory.filter(func(x): return x != null and x["id"] == "milk")[0])
	game.swap_slots(milk_slot, 0)
	game.select_slot(0)
	w._on_placeable_used(press)
	assert(not press.job.is_empty(), "o leite deveria entrar na prensa")
	game.start_new_day(true)
	w.on_new_day()
	w._on_placeable_used(press)
	print("queijos: ", game.count_item("cheese"))
	assert(game.count_item("cheese") == 1)
	# celeiro e compra de animal
	var cap0: int = w.capacity("big")
	var barn_target := Vector2i(-1, -1)
	for y in range(5, 30):
		for x in range(4, 46):
			if barn_target.x < 0 and w.can_place("barn", Vector2i(x, y)):
				barn_target = Vector2i(x, y)
	p.position = Vector2(barn_target.x * 32 + 16, (barn_target.y + 2) * 32)
	print("celeiro pode construir: ", w.can_place("barn", barn_target))
	assert(w.place("barn", Placeable.footprint("barn", barn_target).position) != null)
	print("capacidade grandes: ", cap0, " -> ", w.capacity("big"))
	var n0: int = w.animals.size()
	w.add_animal("moombor")
	assert(w.animals.size() == n0 + 1)
	main.camera.reset_smoothing()
	await _wait(0.3)
	await _shot("12_construcoes")
	main.save_now()
	var saved: Dictionary = game.load_game()
	print("objetos salvos: ", saved.get("placeables", []).size(), " animais: ", saved.get("animals", []).size())
	main.hud.open_shop()
	await _wait(0.2)
	await _shot("13_loja_animais")
	main.hud.close_panel()

	# ---------- agricultura: seca, recorrente, dormência, estação
	var cell := Agri.new_cell(false)
	Agri.plant(cell, "seed_strawberry")
	var sb := CropDB.get_crop("strawberry")
	var sl := {Vector2i(0, 0): cell}
	var dd := 1
	for i in sb.total_days():
		cell["moist"] = 1.0
		Agri.process_day(sl, dd, dd + 1, 16.0, 16.0, false)
		dd += 1
	print("morango pronto após %d dias: %s" % [sb.total_days(), Agri.is_ready(cell)])
	assert(Agri.is_ready(cell))
	var hv := Agri.harvest(cell)
	print("colheita: ", hv, " estado depois: ", cell["crop"].get("state"))
	assert(cell["crop"]["state"] == "growing", "morango deveria ficar no canteiro (recorrente)")
	for i in sb.regrow_days:
		cell["moist"] = 1.0
		Agri.process_day(sl, dd, dd + 1, 16.0, 16.0, false)
		dd += 1
	assert(Agri.is_ready(cell), "deveria dar de novo após a regeneração")
	# seca: sem água o crescimento pausa e, depois da tolerância, morre
	var dry := Agri.new_cell(false)
	Agri.plant(dry, "seed_radish")
	var dl := {Vector2i(1, 0): dry}
	Agri.process_day(dl, 2, 3, 16.0, 16.0, false)
	print("rabanete sem água: progresso ", dry["crop"]["prog"], " estresse ", dry["crop"]["stress"])
	assert(dry["crop"]["prog"] == 0.0 and dry["crop"]["stress"] == 1)
	for i in 6:
		Agri.process_day(dl, 3 + i, 4 + i, 16.0, 16.0, false)
	assert(Agri.is_dead(dry), "depois de muitos dias sem água o rabanete morre")
	# fim da estação: morango dorme, rabanete morre, cogumelo sobrevive
	var e1 := Agri.new_cell(false); Agri.plant(e1, "seed_strawberry")
	var e2 := Agri.new_cell(false); Agri.plant(e2, "seed_radish")
	var el := {Vector2i(0, 0): e1, Vector2i(1, 0): e2}
	var last_spring := Calendar.SEASON_LENGTH
	Agri.process_day(el, last_spring, last_spring + 1, 16.0, 26.0, false)
	print("virada para o verão: morango=", e1["crop"]["state"], " rabanete=", e2["crop"]["state"])
	assert(e1["crop"]["state"] == "dormant" and e2["crop"]["state"] == "dead")
	Agri.process_day(el, Calendar.SEASON_LENGTH * 4, Calendar.SEASON_LENGTH * 4 + 1, 2.0, 14.0, false)
	print("primavera do ano 2: morango=", e1["crop"]["state"])
	assert(e1["crop"]["state"] == "growing")
	print("calendário dia 21: ", Calendar.short_text(21), " | evaporação verão: ", snappedf(Agri.evaporation(28.0, CropDB.season("summer")), 0.01))
	main.hud.open_calendar()
	await _wait(0.2)
	await _shot("14_calendario")
	main.hud.close_panel()

	# sinais nos canteiros + cor do outono
	var base_c: Vector2i = w.cell_of(w.player_start) + Vector2i(3, 2)
	var demo := [["seed_tomato", "ready"], ["seed_melon", "dry"], ["seed_strawberry", "dormant"], ["seed_radish", "dead"], ["seed_watermelon", "ready"], ["seed_mushroom", "ready"]]
	for i in demo.size():
		var cc: Vector2i = base_c + Vector2i(i, 0)
		w.props.erase(cc)
		w.soil[cc] = Agri.new_cell(false)
		Agri.plant(w.soil[cc], demo[i][0])
		var cr: Dictionary = w.soil[cc]["crop"]
		var cdat: CropData = CropDB.get_crop(cr["id"])
		match demo[i][1]:
			"ready":
				cr["stage"] = cdat.frames() - 1
				cr["state"] = "ready"
				w.soil[cc]["moist"] = 0.8
			"dry":
				cr["stage"] = 2
				cr["stress"] = 1
			"dormant":
				cr["stage"] = 2
				cr["state"] = "dormant"
			"dead":
				cr["stage"] = 2
				cr["state"] = "dead"
	w._soil_layer.queue_redraw()
	w._ground_layer.modulate = CropDB.season("autumn").tint
	p.position = Vector2((base_c.x + 2) * 32, (base_c.y - 1) * 32)
	main.camera.reset_smoothing()
	await _wait(0.3)
	await _shot("15_canteiros")

	main.hud.toggle_backpack()
	await _shot("04_mochila")
	main.hud.close_panel()
	main.hud.open_shop()
	await _shot("05_loja")
	main.hud.close_panel()
	game.minutes = 21 * 60
	game.weather = "rain"
	main._update_weather()
	await _wait(1.3)
	await _shot("06_noite_chuva")
	quit()
