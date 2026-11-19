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
	game.weather = "sunny"   # tempo bom: sem resfriados no teste de produção
	# animais: carinho, novo dia, coleta (com qualidade)
	var cow = null
	for an in w.animals:
		if an.record.species == "moombor":
			cow = an
	cow.record.product_ready = false
	cow.record.petted_today = false
	for an in w.animals:
		an.record.health = "ok"
	cow._on_interact(p)
	assert(cow.record.petted_today, "carinho deveria marcar o dia")
	var f0: int = cow.record.friendship
	w.on_new_day()
	print("amizade do Moombor: %d -> %d, felicidade %d" % [f0, cow.record.friendship, cow.record.happiness])
	assert(cow.record.product_ready, "o Moombor deveria ter leite no dia seguinte")
	cow._on_interact(p)
	print("leite coletado: ", game.count_item("milk"))
	assert(game.count_item("milk") == 1)
	# tosquia: lã cresce em 3 dias e precisa da tesoura
	var sheep = null
	for an in w.animals:
		if an.record.species == "fofranca":
			sheep = an
	sheep.record.product_ready = false
	sheep.record.prod_days = 0
	sheep.record.health = "ok"
	for i in 3:
		for pl in w.placeables:
			if pl.kind == "feeder":
				pl.hay = 20
		w.on_new_day()
	print("lã pronta após 3 dias: ", sheep.record.product_ready, " (tesouras: ", game.count_item("shears"), ")")
	assert(sheep.record.product_ready)
	sheep._on_interact(p)
	print("lã coletada: ", game.count_item("wool"))
	assert(game.count_item("wool") >= 1)
	# fome: sem feno não produz; 3 dias seguidos = indisposto
	for pl in w.placeables:
		if pl.kind == "feeder":
			pl.hay = 0
	cow.record.product_ready = false
	for i in 3:
		for an in w.animals:
			an.record.ate_grass = false
			an.record.hand_fed = false
		w.on_new_day()
	print("Moombor com fome: produto=%s saúde=%s fome=%d dias" % [cow.record.product_ready, cow.record.health, cow.record.hunger_days])
	assert(not cow.record.product_ready and cow.record.health == "indisposto")
	# pasto: capim existe, o animal come e conta como alimentado
	var grass_n := 0
	for c in w.props:
		if w.props[c].kind == "grass":
			grass_n += 1
	print("tufos de capim no pasto: ", grass_n)
	assert(grass_n > 10)
	var gcell: Vector2i = Vector2i(-1, -1)
	for c in w.props:
		if w.props[c].kind == "grass":
			gcell = c
			break
	cow.position = Vector2(gcell.x * 32 + 16, gcell.y * 32 + 20)
	cow.record.ate_grass = false
	cow.mode = Animal.Mode.WANDER
	assert(cow._try_graze() and cow.record.ate_grass and not w.props.has(gcell))
	cow.record.hunger_days = 3
	cow.record.health = "indisposto"
	for pl in w.placeables:
		if pl.kind == "feeder":
			pl.hay = 0
	w.on_new_day()
	print("depois de pastar: fome=%d saúde=%s" % [cow.record.hunger_days, cow.record.health])
	assert(cow.record.hunger_days == 0 and cow.record.health == "ok")
	# comida favorita na mão
	game.add_item("kale", 1)
	var ks: int = game.inventory.find(game.inventory.filter(func(x): return x != null and x["id"] == "kale")[0])
	game.swap_slots(ks, 0)
	game.select_slot(0)
	cow.record.petted_today = false
	cow.record.product_ready = false
	var fr0: int = cow.record.friendship
	cow._on_interact(p)
	print("couve na mão (favorita): amizade %d -> %d" % [fr0, cow.record.friendship])
	assert(cow.record.hand_fed and cow.record.friendship == fr0 + 40)
	# silo: capim cortado vira feno guardado
	var silo_pl: Placeable = w.place("silo", Vector2i(26, 14), true)
	var gcell2: Vector2i = Vector2i(-1, -1)
	for c in w.props:
		if w.props[c].kind == "grass":
			gcell2 = c
			break
	w._destroy_prop(w.props[gcell2])
	print("silo depois da foice: ", silo_pl.hay)
	assert(silo_pl.hay == 1)
	# saúde: resfriado ao dormir na chuva sem abrigo; cura abrigado; escova
	var cold := AnimalRecord.create("moombor", true)
	var nights := 0
	while cold.health != "resfriado" and nights < 50:
		AnimalSystem.process_day([cold], func(_r): return true, func(_r): return false, "storm", 12.0, "spring")
		nights += 1
	print("resfriou depois de %d noite(s) na chuva sem abrigo" % nights)
	assert(cold.health == "resfriado")
	AnimalSystem.process_day([cold], func(_r): return true, func(_r): return true, "rain", 12.0, "spring")
	print("depois de uma noite abrigado: ", cold.health)
	assert(cold.health == "ok")
	cow.record.hygiene = 10
	cow.record.brushed_today = false
	game.add_item("brush", 1)
	var bs: int = game.inventory.find(game.inventory.filter(func(x): return x != null and x["id"] == "brush")[0])
	game.swap_slots(bs, 0)
	game.select_slot(0)
	cow.record.product_ready = false
	cow._on_interact(p)
	print("escovado: higiene ", cow.record.hygiene)
	assert(cow.record.hygiene == 100)
	# filhote cresce até adulto
	var baby = w.add_animal("piuplum", false)
	assert(baby.record.stage() == "baby")
	baby.record.age = baby.record.data().baby_days + baby.record.data().young_days
	print("filhote virou: ", baby.record.stage())
	assert(baby.record.is_adult())
	# farejar: estatística sem rodar o mundo
	var pig := AnimalRecord.create("catarrapio", true)
	pig.friendship = 600
	pig.happiness = 80
	var found := 0
	for i in 200:
		pig.product_ready = false
		var rr := AnimalSystem.process_day([pig], func(_r): return true, func(_r): return true, false, 18.0, "spring")
		found += rr["forage"].size()
	print("Catarrápio farejou em %d de 200 dias" % found)
	assert(found > 40 and found < 200)
	# save antigo (formato de antes) vira registro adulto
	var old := AnimalRecord.restore({"species": "fofranca", "x": 10, "y": 20, "friendship": 4, "petted": true, "product": false})
	print("migração: ", old.name, " amizade ", old.friendship, " adulto ", old.is_adult())
	assert(old.friendship == 400 and old.is_adult())
	for pl in w.placeables:
		if pl.kind == "feeder":
			pl.hay = 20
	for an in w.animals:
		an.record.product_ready = an != cow
		an.record.hunger_days = 0
		an.refresh()
	p.position = Vector2(38 * 32, 16 * 32)
	main.camera.reset_smoothing()
	await _wait(2.5)
	await _shot("07_pasto")
	main.hud.open_animal_card(cow.record)
	await _wait(0.2)
	await _shot("16_cartao_animal")
	main.hud.close_panel()
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
	for id in FishDB.all_ids():
		caught += game.count_item(id)
	print("peixes pescados: ", caught, " | último: ", fishing.last_catch)
	assert(caught == 1, "deveria ter pescado 1 peixe")
	assert(FishDB.is_discovered(fishing.last_catch["id"]), "a captura deveria ir para o Livro de Pesca")
	# sorteio por ambiente, isca e momento
	print("ambientes: rio=%s laguinho=%s lago fundo=%s" % [w.water_kind(Vector2i(46, 8)) + w.water_kind(Vector2i(47, 8)),
		w.water_kind(Vector2i(9, 34)), w.water_depth(Vector2i(40, 24))])
	assert(w.water_kind(Vector2i(9, 34)) == "pond" and w.water_depth(Vector2i(40, 24)) == "deep")
	for water in ["lake", "river", "pond"]:
		var seen := {}
		for i in 600:
			var ctx := {"water": water, "depth": "deep" if water == "lake" else "shallow", "season": "summer",
				"time": "afternoon", "weather": "sunny", "level": 10, "bait": "bait_fly", "region": "farm"}
			seen[FishDB.roll(ctx)] = true
		print("%s no verão à tarde: %s" % [water, ", ".join(seen.keys().map(func(x): return FishDB.get_fish(x).name))])
	for bait in ["", "bait_worm", "bait_fly"]:
		var rar := [0, 0, 0, 0, 0, 0, 0]
		for i in 2000:
			var ctx2 := {"water": "lake", "depth": "deep", "season": "winter", "time": "night", "weather": "fog",
				"level": 10, "bait": bait, "region": "farm"}
			rar[FishDB.get_fish(FishDB.roll(ctx2)).rarity] += 1
		print("isca '%s' (lago fundo, noite de inverno) -> por raridade: %s" % [bait, rar])
	# nível sobe com XP
	var lv0 := FishDB.level()
	FishDB.add_xp(400)
	print("nível de pesca: %d -> %d (xp %d)" % [lv0, FishDB.level(), game.fishing_xp])
	assert(FishDB.level() > lv0)
	main.hud.open_fish_book()
	await _wait(0.3)
	await _shot("19_livro_pesca")
	main.hud._open_fish_card(fishing.last_catch["id"])
	await _wait(0.2)
	await _shot("20_ficha_peixe")
	main.hud._open_fish_card("fish_ghost")
	await _wait(0.2)
	await _shot("21_ficha_desconhecido")
	main.hud.close_panel()

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
	# níveis: melhorar celeiro, comedouro automático do silo e coletor
	var barn_pl: Placeable = null
	for pl in w.placeables:
		if pl.kind == "barn":
			barn_pl = pl
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null
	game.add_item("wood", 400)
	game.add_item("stone", 300)
	game.add_money(8000)
	print("antes de melhorar: madeira %d pedra %d moedas %d" % [game.count_item("wood"), game.count_item("stone"), game.money])
	print(w.upgrade_building(barn_pl))
	print(w.upgrade_building(barn_pl))
	print("capacidade com celeiro nível 3: ", w.capacity("big"))
	assert(barn_pl.level == 3 and w.capacity("big") == 3 + 12)
	var silo2: Placeable = null
	for pl in w.placeables:
		if pl.kind == "silo":
			silo2 = pl
	silo2.hay = 50
	for pl in w.placeables:
		if pl.kind == "feeder":
			pl.hay = 0
	var housed_rec: AnimalRecord = null
	for an in w.animals:
		an.record.ate_grass = false
		an.record.hand_fed = false
		an.record.product_ready = false
		if an.record.home == w._key(barn_pl) and an.record.species == "moombor":
			housed_rec = an.record
	w.on_new_day()
	print("silo depois do comedouro automático: ", silo2.hay, " | guardado no celeiro: ", barn_pl.storage)
	assert(silo2.hay < 50)
	if housed_rec:
		assert(housed_rec.fed_today and not housed_rec.product_ready)
		assert(barn_pl.storage.size() > 0)
	var got: int = w.collect_storage(barn_pl)
	print("coletado do celeiro: ", got)
	# reprodução: gestação no celeiro e nascimento
	var mom: AnimalRecord = null
	for an in w.animals:
		if an.record.home == w._key(barn_pl) and an.record.is_adult():
			mom = an.record
			break
	var before_n: int = w.animals.size()
	mom.pregnant_days = 1
	var born: int = w._process_breeding()
	var baby_rec: AnimalRecord = w.animals.back().record
	print("nasceu: %d | filhote %s (%s) de %s, casa=%s, estágio=%s" % [born, baby_rec.name, baby_rec.species, mom.name, baby_rec.home, baby_rec.stage()])
	assert(born == 1 and w.animals.size() == before_n + 1 and baby_rec.stage() == "baby" and baby_rec.home == mom.home)
	var preg := 0
	for i in 300:
		mom.pregnant_days = 0
		mom.happiness = 90
		for x in w.records():
			x.pregnant_days = 0
		w._process_breeding()
		if w.records().any(func(x): return x.pregnant_days > 0):
			preg += 1
	print("gestações em 300 noites: ", preg)
	for x in w.records():
		x.pregnant_days = 0
	# ovo fértil + incubadora
	var hen := AnimalRecord.create("piuplum", true)
	var fertile := 0
	for i in 400:
		hen.product_ready = false
		AnimalSystem.process_day([hen], func(_r): return true, func(_r): return true, "sunny", 18.0, "spring")
		if hen.product_item == "fertile_egg":
			fertile += 1
	print("ovos férteis em 400: ", fertile)
	assert(fertile > 20 and fertile < 120)
	var inc: Placeable = w.place("incubator", Vector2i(27, 17), true)
	game.add_item("fertile_egg", 1)
	var fs: int = game.inventory.find(game.inventory.filter(func(x): return x != null and x["id"] == "fertile_egg")[0])
	game.swap_slots(fs, 0)
	game.select_slot(0)
	w._on_placeable_used(inc)
	assert(not inc.job.is_empty())
	game.day += 4
	var coop: Placeable = w.place("coop", Vector2i(20, 24), true)
	w.assign_homes()
	var chicks0: int = w.count_animals("bird")
	w._on_placeable_used(inc)
	print("pintinhos: %d -> %d" % [chicks0, w.count_animals("bird")])
	assert(w.count_animals("bird") == chicks0 + 1)
	game.day -= 4
	main.hud.close_panel()
	main.hud.open_animal_list(w.records().filter(func(r): return r.home == w._key(barn_pl)), "Celeiro", barn_pl)
	await _wait(0.2)
	await _shot("18_celeiro_painel")
	main.hud.close_panel()
	# rotina da noite: quem tem casa vai para o celeiro e some; sem casa dorme no pasto
	var housed_n := 0
	for an in w.animals:
		if an.record.home != "":
			housed_n += 1
	game.minutes = 20 * 60
	await _wait(1.0)
	for an in w.animals:
		an.position = an.home_door if an.home_door != Vector2.INF else an.position
	await _wait(0.3)
	var inside_n := 0
	var sleeping_n := 0
	for an in w.animals:
		if an.mode == Animal.Mode.INSIDE:
			inside_n += 1
		elif an.mode == Animal.Mode.SLEEP:
			sleeping_n += 1
	print("noite: %d com casa, %d dentro de casa, %d dormindo no pasto" % [housed_n, inside_n, sleeping_n])
	assert(inside_n == housed_n and housed_n > 0)
	game.minutes = 8 * 60
	await _wait(0.2)
	for an in w.animals:
		assert(an.visible, "de manhã todos saem")
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

	# ---------- clima
	var wc := Agri.new_cell(false)
	wc["moist"] = 1.0
	var wl := {Vector2i(0, 0): wc}
	Agri.process_day(wl, 2, 3, 16.0, 16.0, "sunny")
	var after_sun: float = wc["moist"]
	wc["moist"] = 1.0
	Agri.process_day(wl, 2, 3, 16.0, 16.0, "heatwave")
	var after_heat: float = wc["moist"]
	wc["moist"] = 0.0
	Agri.process_day(wl, 62, 63, -2.0, -4.0, "snow")
	print("umidade de manhã: sol %.2f | calor %.2f | neve %.2f" % [after_sun, after_heat, wc["moist"]])
	assert(after_heat < after_sun and absf(wc["moist"] - 0.45) < 0.01)
	var counts := {}
	for i in 400:
		game.forecast.clear()
		game.day = 1 + (i % 4) * Calendar.SEASON_LENGTH
		game._fill_forecast()
		var wid: String = game.forecast[0]["weather"]
		counts[wid] = counts.get(wid, 0) + 1
	print("climas sorteados em 400 dias: ", counts)
	assert(counts.size() >= 7)
	game.day = 5
	game.forecast.clear()
	game._fill_forecast()
	for wid in ["storm", "snow", "fog"]:
		game.weather = wid
		main._update_weather()
		await _wait(1.2)
		await _shot("17_clima_" + wid)
	game.weather = "sunny"
	main._update_weather()

	# ---------- solo, adubo, qualidade, aspersor, ferramentas, máquinas
	var clay := Agri.new_cell(false, "clay")
	var sand := Agri.new_cell(false, "sandy")
	clay["moist"] = 1.0
	sand["moist"] = 1.0
	Agri.process_day({Vector2i(0, 0): clay, Vector2i(1, 0): sand}, 2, 3, 18.0, 18.0, "sunny")
	print("de manhã: argiloso %.2f | arenoso %.2f" % [clay["moist"], sand["moist"]])
	assert(clay["moist"] > sand["moist"])
	var qual := [[0, 0, 0, 0], [0, 0, 0, 0]]
	for k in 2:
		for i in 300:
			var qc := Agri.new_cell(false, "common")
			if k == 1:
				Agri.apply_fertilizer(qc, "fert_quality")
			Agri.plant(qc, "seed_kale")
			qc["crop"]["care"] = 3
			qc["crop"]["days"] = 3
			qc["crop"]["state"] = "ready"
			qual[k][Agri.harvest(qc)["q"]] += 1
	print("qualidade couve (comum/prata/ouro/lendária): sem adubo %s | com adubo de qualidade %s" % [qual[0], qual[1]])
	assert(qual[1][2] + qual[1][3] > qual[0][2] + qual[0][3])
	# aspersor de cobre rega os 8 em volta de manhã
	var sp_origin := Vector2i(8, 26)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cc: Vector2i = sp_origin + Vector2i(dx, dy)
			w.props.erase(cc)
			w.soil.erase(cc)
	w.place("sprinkler_q", sp_origin, true)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dy != 0:
				w.soil[sp_origin + Vector2i(dx, dy)] = Agri.new_cell(false)
	var watered: int = w._run_sprinklers()
	print("aspersor de cobre regou: ", watered)
	assert(watered == 8)
	# regador nível 3: área 3x3
	game.tool_levels["watering_can"] = 3
	print("área do regador nível 3: ", w.tool_area("watering_can", Vector2i(10, 20)).size(), " | capacidade ", game.water_capacity())
	assert(w.tool_area("watering_can", Vector2i(10, 20)).size() == 9 and game.water_capacity() == 60)
	game.tool_levels["watering_can"] = 1
	# máquinas: regras por categoria e qualidade herdada
	print("pote: tomate -> %s | couve -> %s" % [ItemDB.machine_output("preserves_jar", "tomato"), ItemDB.machine_output("preserves_jar", "kale")])
	assert(ItemDB.machine_output("preserves_jar", "tomato") == "jam" and ItemDB.machine_output("preserves_jar", "kale") == "pickles")
	var churn: Placeable = w.place("butter_churn", Vector2i(28, 17), true)
	game.inventory[0] = {"id": "milk", "qty": 1, "q": 2}
	game.select_slot(0)
	w._on_placeable_used(churn)
	game.day += 1
	w._on_placeable_used(churn)
	game.day -= 1
	print("manteiga ouro: ", game.count_item("butter", 2))
	assert(game.count_item("butter", 2) == 1)
	var info_cell := Agri.new_cell(false, "fertile", "forest_edge")
	Agri.plant(info_cell, "seed_kale")
	print("info do canteiro: ", Agri.describe(info_cell))
	print("ficha da semente: ", ItemDB.get_item("seed_grape")["desc"])

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
