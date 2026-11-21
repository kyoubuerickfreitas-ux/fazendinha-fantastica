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
	main.set_zoom(1.0)      # o zoom fica salvo no aparelho: o teste sempre começa no normal
	# ---- criação de personagem (jogo novo)
	var ccr = main.hud._root.get_node_or_null("CharacterCreator")
	assert(ccr != null and game.ui_lock == 1, "jogo novo abre a criação de personagem")
	ccr._step_hair(1)
	await _wait(0.4)
	await _shot("39_criacao")
	ccr.set_choices("Lia", "Sítio Girassol", {"skin": 3, "hair": 5, "hair_color": 2, "shirt": 2, "pants": 1})
	ccr.confirm()
	await _wait(0.3)
	assert(game.profile["created"] and game.player_name() == "Lia" and game.farm_name() == "Sítio Girassol")
	assert(int(game.look()["hair"]) == 5 and game.ui_lock == 0)
	assert(main.player._hair.texture != null, "o cabelo escolhido aparece no personagem")
	await _shot("01_inicio")
	assert(main.tutorial.active() and main.hud._tut_panel.visible, "jogo novo começa com o tutorial")
	game.tutorial["done"] = true    # as recompensas mexeriam nas contas dos testes abaixo; testado no fim

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
	assert(game.player_name() == "Lia" and int(game.look()["skin"]) == 3, "nome e visual voltam do save")
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
	if fishing._treasure != "":   # este teste quer um peixe; tesouros são testados mais abaixo
		fishing._treasure = ""
		fishing._fish = "fish_silver"
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

	# ---- tesouros: chance, sorteio por isca, cada tipo
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null
	for bait in ["", "bait_treasure"]:
		var tc := {"water": "lake", "depth": "deep", "season": "summer", "time": "afternoon", "weather": "sunny",
			"level": 5, "bait": bait, "region": "farm"}
		var hits := 0
		var kinds := {}
		for i in 3000:
			var tid := TreasureDB.maybe_roll(tc)
			if tid != "":
				hits += 1
				kinds[tid] = int(kinds.get(tid, 0)) + 1
		print("tesouros com isca '%s': %.1f%% das fisgadas · %s" % [bait, hits * 100.0 / 3000.0, kinds])
	assert(TreasureDB.chance({"bait": "bait_treasure", "level": 1}) > TreasureDB.chance({"bait": "", "level": 1}) * 3.0)
	var money_t: int = game.money
	for tid in ["chest_small", "old_coin", "message_bottle", "message_bottle", "driftwood", "old_boot", "fungo_glasses", "chest_gold"]:
		print("  pescou ", tid, ": ", TreasureDB.collect(tid).replace("\n", " / "))
	assert(game.money > money_t, "o baú deveria dar moedas")
	assert(game.count_item("old_coin") >= 1 and game.count_item("fungo_glasses") == 1)
	assert(TreasureDB.messages_read() == 2)
	assert(not TreasureDB.available(TreasureDB.get_treasure("fungo_glasses"), {"water": "lake", "depth": "deep", "level": 9}),
		"os óculos só aparecem uma vez")
	# o tesouro também vem pela vara (mesma mecânica de fisgar e puxar)
	var shells0: int = game.count_item("relic_shell")
	fishing.state = Fishing.State.REELING
	fishing._treasure = "relic_shell"
	fishing._fish = ""
	fishing._progress = 99.0
	fishing.on_use(Vector2i.ZERO)
	assert(game.count_item("relic_shell") == shells0 + 1 and fishing.last_catch.get("treasure", false), "a concha deveria vir na linha")
	# mapa: 4 pedaços liberam o Guardião
	var gctx := {"water": "lake", "depth": "deep", "season": "summer", "time": "night", "weather": "sunny",
		"level": 8, "bait": "", "region": "farm"}
	assert(not FishDB.available(FishDB.get_fish("fish_guardian"), gctx))
	game.fish_flags["map_pieces"] = 3
	print("  mapa: ", TreasureDB.collect("map_piece").replace("\n", " / "))
	assert(game.fish_flags.get("map_complete", false))
	assert(FishDB.available(FishDB.get_fish("fish_guardian"), gctx), "com o mapa completo o Guardião aparece")
	var legend_hits := 0
	for i in 1000:
		if FishDB.roll(gctx) == "fish_guardian":
			legend_hits += 1
	print("  Guardião: %d em 1000 fisgadas com tudo certo" % legend_hits)
	assert(legend_hits > 60 and legend_hits < 200)
	# devolver os óculos ao Fungo
	var money_f: int = game.money
	main._on_shop()
	main.hud.close_panel()
	assert(game.count_item("fungo_glasses") == 0 and game.money == money_f + 500, "o Fungo deveria recompensar")
	# ---- lendário: pescar dá o troféu, que vira decoração
	fishing.state = Fishing.State.REELING
	fishing._treasure = ""
	fishing._fish = "fish_moss_king"
	fishing._progress = 99.0
	fishing.on_use(Vector2i.ZERO)
	print("  lendário: ", fishing.last_catch)
	assert(game.count_item("fish_moss_king", 3) == 1, "lendário vem com qualidade lendária")
	assert(game.count_item("trophy_moss_king") == 1, "deveria ganhar o troféu")
	assert(ItemDB.sell_price("fish_moss_king", 3) == 3000)
	var trophy_pl: Placeable = w.place("trophy_moss_king", Vector2i(30, 12), true)
	assert(trophy_pl != null, "o troféu deveria poder ser colocado")
	main.hud.open_fish_book("treasure")
	await _wait(0.3)
	await _shot("22_tesouros")
	main.hud._open_fish_card("fish_moss_king")
	await _wait(0.2)
	await _shot("23_ficha_lendario")
	main.hud.close_panel()
	p.position = Vector2(30 * 32 + 16, 13 * 32 + 20)
	main.camera.reset_smoothing()
	await _wait(0.2)
	await _shot("24_trofeu")
	# ---- pedidos do Fungo
	var kinds_seen := {}
	for i in 40:
		game.fish_flags["request"] = {}
		FishQuests.ensure_request()
		kinds_seen[FishQuests.request()["type"]] = FishQuests.request()["text"]
	print("tipos de pedido: ", kinds_seen.keys())
	assert(kinds_seen.size() >= 4, "deveria haver vários tipos de pedido")
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null
	game.fish_flags["request"] = {"type": "deliver", "fish": "fish_silver", "qty": 2, "money": 100, "xp": 20,
		"deadline": game.day + 5, "progress": 0, "text": "Traga 2 Prateadinho."}
	game.add_item("fish_silver", 2)
	assert(FishQuests.is_ready())
	var money_q: int = game.money
	main._on_shop()
	main.hud.close_panel()
	assert(game.money == money_q + 100 and game.count_item("fish_silver") == 0 and FishQuests.requests_done() == 1,
		"entregar o pedido deveria pagar e levar os peixes")
	game.fish_flags["request"] = {"type": "big", "fish": "fish_perch", "qty": 1, "size": 20.0, "money": 90, "xp": 20,
		"deadline": game.day + 5, "progress": 0, "text": "Pesque uma Perca-Musgo de 20 cm."}
	print("  pedido de tamanho (pequeno): '", FishQuests.on_catch("fish_perch", {"size": 15.0}), "'")
	assert(not FishQuests.is_ready())
	print("  pedido de tamanho (grande): ", FishQuests.on_catch("fish_perch", {"size": 24.0}))
	assert(FishQuests.is_ready())
	assert(FishQuests.try_deliver() != "" and FishQuests.requests_done() == 2)
	game.fish_flags["request"] = {"type": "rare", "rarity": 2, "qty": 1, "money": 1, "xp": 1, "deadline": game.day - 1, "progress": 0, "text": "x"}
	print("  novo dia: ", FishQuests.on_new_day().replace("\n", " / "))
	assert(FishQuests.request().is_empty() or int(FishQuests.request()["deadline"]) >= game.day, "pedido vencido deveria sumir")
	# ---- Torneio do Lago
	var day_t: int = game.day
	var min_t: int = game.minutes
	game.day = FishQuests.TOURNAMENT_DAY
	game.minutes = 9 * 60
	assert(FishQuests.tournament_active())
	print("  rivais: ", FishQuests.rival_scores())
	print("  ", FishQuests.on_catch("fish_perch", {"size": 20.0}))
	print("  ", FishQuests.on_catch("fish_shark", {"size": 100.0}))
	assert(FishQuests.rank_of(200) == 1)
	main.hud.open_fish_book("quests")
	await _wait(0.3)
	await _shot("25_pedidos_torneio")
	main.hud.close_panel()
	var money_tour: int = game.money
	game.minutes = FishQuests.TOUR_END
	game.time_changed.emit(game.day, game.minutes)
	assert(game.money >= money_tour + 800 and game.count_item("trophy_tournament") == 1, "1º lugar: prêmio e taça")
	assert(not FishQuests.tournament_active() and FishQuests.finish_tournament() == "", "o torneio só fecha uma vez")
	print("  torneio: ", game.fish_flags["tour_last"])
	game.day = day_t
	game.minutes = min_t
	game.time_changed.emit(game.day, game.minutes)
	# ---- defumador, adubo de peixe, aquário, vara melhorada e títulos
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null
	var smoker: Placeable = w.place("smoker", Vector2i(32, 12), true)
	game.inventory[0] = {"id": "fish_perch", "qty": 2, "q": 1}
	game.select_slot(0)
	w._on_placeable_used(smoker)
	assert(not smoker.job.is_empty() and smoker.job["output"] == "smoked_fish_perch", "o defumador deveria aceitar peixe")
	smoker.job["ready"] = game.day
	w._on_placeable_used(smoker)
	print("  defumado: ", game.count_item("smoked_fish_perch"), " · vende ", ItemDB.sell_price("smoked_fish_perch", 1),
		" (peixe cru ", ItemDB.sell_price("fish_perch", 1), ")")
	assert(game.count_item("smoked_fish_perch", 1) == 1, "o peixe defumado mantém a qualidade")
	game.add_item("fish_silver", 1)
	var fert_cost: Dictionary = {"any_fish": 1, "fiber": 2}
	game.add_item("fiber", 2)
	assert(ItemDB.can_afford(fert_cost))
	ItemDB.pay(fert_cost)
	assert(game.count_item("fish_silver") == 0 and game.count_item("fish_perch") == 1, "o adubo gasta o peixe mais barato")
	var aq: Placeable = w.place("aquarium_large", Vector2i(34, 12), true)
	assert(aq != null)
	for fid in ["fish_orange", "fish_yellow", "fish_clown"]:
		game.inventory[0] = {"id": fid, "qty": 1, "q": 0}
		game.select_slot(0)
		w._on_placeable_used(aq)
	assert(aq.fish.size() == 3)
	game.inventory[0] = {"id": "fish_perch", "qty": 1, "q": 0}
	w._on_placeable_used(aq)
	assert(aq.fish.size() == 3 and game.count_item("fish_perch") >= 1, "aquário cheio não aceita mais")
	assert(not aq.can_pick_up(), "não se desmonta aquário com peixe")
	var pond: Placeable = w.place("fish_pond", Vector2i(37, 13), true)
	for fid in ["fish_goldfish", "fish_betta", "fish_axolotl"]:
		game.inventory[0] = {"id": fid, "qty": 1, "q": 0}
		w._on_placeable_used(pond)
	print("  espécies nos aquários: ", w.aquarium_species(), " · títulos: ", FishDB.titles())
	assert(FishDB.titles().has("aquarist") and FishDB.titles().has("legend_hunter") and FishDB.titles().has("champion"))
	var saved_aq: Dictionary = aq.serialize()
	assert(saved_aq["fish"].size() == 3)
	game.inventory[0] = null
	game.select_slot(0)
	w._on_placeable_used(aq)
	assert(aq.fish.size() == 2, "mão vazia tira o peixe")
	p.position = Vector2(35 * 32, 14 * 32 + 10)
	main.camera.reset_smoothing()
	await _wait(0.4)
	await _shot("26_aquarios")
	game.tool_levels["fishing_rod"] = 3
	assert(fishing.rod_level() == 3)
	game.tool_levels["fishing_rod"] = 1
	main.hud.open_fish_book("quests")
	await _wait(0.3)
	await _shot("27_titulos")
	main.hud.close_panel()
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null

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
	print("clima na hora de sair: ", game.weather)
	game.weather = "sunny"     # com tempestade/neve eles ficam em casa de propósito
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

	# ---- cozinha: receitas, fogão, comer e bônus
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null
	print("receitas iniciais: ", game.known_recipes)
	assert(game.known_recipes.size() == 4 and Cooking.is_known("grilled_fish"))
	var stove: Placeable = w.place("stove", Vector2i(32, 14), true)
	assert(stove != null and stove.is_interactive())
	game.add_item("kale", 2)
	game.add_item("egg", 2)
	game.add_item("fish_silver", 1)
	game.add_item("fish_perch", 1)
	game.add_item("apple", 2)
	assert(Cooking.can_cook("salad_kale") and Cooking.can_cook("omelette") and Cooking.can_cook("fruit_juice"))
	assert(not Cooking.can_cook("carrot_soup"), "receita não aprendida")
	w._on_placeable_used(stove)
	await _wait(0.3)
	assert(main.hud._cook.visible, "o fogão deveria abrir a cozinha")
	await _shot("29_cozinha")
	print("  ", Cooking.cook("grilled_fish").replace("\n", " / "))
	assert(game.count_item("fish_silver") == 0 and game.count_item("fish_perch") == 1, "gasta o peixe mais barato")
	assert(game.count_item("dish_grilled_fish") == 1)
	print("  ", Cooking.cook("fruit_juice"))
	main.hud.close_panel()
	game.energy = 20.0
	game.inventory[0] = {"id": "dish_grilled_fish", "qty": 1}
	game.select_slot(0)
	p._busy = 0
	p._action = {}
	var dishes0: int = game.count_item("dish_grilled_fish")
	p.use_at(p.target_cell())
	print("  energia depois de comer: ", game.energy)
	assert(game.energy == 65.0 and game.count_item("dish_grilled_fish") == dishes0 - 1)
	game.inventory[0] = {"id": "dish_fruit_juice", "qty": 1}
	p.use_at(p.target_cell())
	assert(Cooking.has_buff("speed") and Cooking.speed_mult() > 1.0, "o suco dá Passo Leve")
	print("  bônus: ", Cooking.buffs_text())
	game.buffs["stamina"] = Cooking.now_abs() + 60
	var e0: float = game.energy
	game.use_energy(10.0)
	assert(is_equal_approx(e0 - game.energy, 6.0), "Fôlego: gasta 40% menos energia")
	game.inventory[0] = {"id": "recipe_carrot_soup", "qty": 1}
	p.use_at(p.target_cell())
	assert(Cooking.is_known("carrot_soup") and game.count_item("recipe_carrot_soup") == 0, "a receita ensina")
	print("  desbloqueios: ", Cooking.check_unlocks().replace("\n", " / "))
	assert(Cooking.is_known("lake_stew") and Cooking.is_known("legend_feast"), "nível de pesca e título liberam receitas")
	assert(Cooking.shop_scrolls("spring").has("recipe_strawberry_cake") and not Cooking.shop_scrolls("spring").has("recipe_carrot_soup"))
	main.hud._refresh_stats()
	await _wait(0.2)
	await _shot("30_bonus")
	game.buffs = {}
	game.inventory[0] = null

	# ---- moradores: conversar, presentear, corações, recompensas e aniversário
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null
	game.minutes = 10 * 60
	await _wait(0.2)
	print("moradores: ", w.villagers.map(func(n): return "%s em %s" % [n.npc_name, Vector2i(n.position / 32)]))
	assert(w.villagers.size() == 4 and w.villagers.all(func(n): return n.visible))
	assert(Villagers.reaction("estrelo", "moonstone") == "love" and Villagers.reaction("estrelo", "ruby") == "like")
	var reach: Dictionary = w.walkable_from(Vector2i(w.player_start / 32))
	for n in w.villagers:
		assert(reach.has(w.nearest_passable(n.data.home)), "%s deveria ser alcançável a pé" % n.npc_name)
	game.inventory[0] = {"id": "axe", "qty": 1}
	game.select_slot(0)
	main._on_villager("carpa")
	assert(Villagers.points("carpa") == Villagers.TALK_PTS and main.hud._npc_win.visible)
	var carpa: NPC = w.villagers.filter(func(n): return n.data.id == "carpa")[0]
	p.position = carpa.position + Vector2(-40, 0)
	main.camera.reset_smoothing()
	await _wait(0.3)
	await _shot("31_conversa")
	main.hud.close_panel()
	main._on_villager("carpa")
	assert(Villagers.points("carpa") == Villagers.TALK_PTS, "conversa só conta 1x por dia")
	game.inventory[0] = {"id": "fish_perch", "qty": 2, "q": 0}
	main._on_villager("carpa")
	print("  presente: ", Villagers.reaction("carpa", "fish_perch"), " -> ", Villagers.points("carpa"))
	assert(Villagers.points("carpa") == Villagers.TALK_PTS + 45 and game.count_item("fish_perch") == 1)
	main._on_villager("carpa")
	assert(game.count_item("fish_perch") == 1, "só 1 presente por dia")
	assert(Villagers.reaction("carpa", "pearl") == "love" and Villagers.reaction("carpa", "old_boot") == "dislike")
	assert(Villagers.reaction("pipoca", "apple") == "like" and Villagers.reaction("pipoca", "fish_silver") == "dislike")
	assert(Villagers.reaction("raiz", "dish_starflower_tea") == "love" and Villagers.reaction("raiz", "potato") == "like")
	# 2 corações: recompensa ao conversar
	game.friends["carpa"]["pts"] = 200
	var flies0: int = game.count_item("bait_fly")
	print("  ", Villagers.talk("carpa").replace("\n", " / "))
	assert(game.count_item("bait_fly") == flies0 + 5 and game.friends["carpa"]["rewards"].has(2))
	# aniversário: presente vale o triplo
	var day_b: int = game.day
	game.day = Calendar.SEASON_LENGTH + 8      # 8 de verão
	assert(Villagers.is_birthday("carpa"))
	print("  avisos: ", Villagers.on_new_day())
	var pts_b := Villagers.points("carpa")
	game.inventory[0] = {"id": "fish_silver", "qty": 1, "q": 0}
	main._on_villager("carpa")
	assert(Villagers.points("carpa") == pts_b + 45 * Villagers.BIRTHDAY_MULT, "aniversário: o triplo")
	main.hud.close_panel()
	game.day = day_b
	game.inventory[0] = null
	main.hud.open_calendar()
	await _wait(0.3)
	main.hud._cal_body.get_parent().scroll_vertical = 260
	await _wait(0.1)
	await _shot("32_moradores")
	main.hud.close_panel()
	game.minutes = 21 * 60
	await _wait(0.2)
	assert(w.villagers.all(func(n): return not n.visible), "de noite os moradores ficam em casa")
	game.minutes = 10 * 60
	await _wait(0.1)

	# vitrine: todas as plantas da folha nova em todos os estágios (2 por linha)
	var crop_ids := ["apple", "orange", "pear", "lemon", "grape", "raspberry", "strawberry", "plum", "blueberry", "peach",
		"cherry", "pomegranate", "watermelon", "carrot", "melon", "radish", "pineapple", "beet", "coconut", "tomato",
		"banana", "mushroom"]
	var gx := 14
	var gy := 22
	for k in crop_ids.size():
		var cd: CropData = CropDB.get_crop(crop_ids[k])
		assert(cd != null, "planta %s deveria existir" % crop_ids[k])
		for st in cd.frames():
			var c := Vector2i(gx + (k % 2) * 6 + st, gy + k / 2)
			if w.props.has(c):
				w.props[c].queue_free()
				w.props.erase(c)
			if w.occupied.has(c) or w.ground_at(c) == FarmWorld.Ground.WATER:
				continue
			var sc := Agri.new_cell(false)
			Agri.plant(sc, cd.seed_id())
			sc["crop"]["stage"] = st
			if st == cd.frames() - 1:
				sc["crop"]["state"] = "ready"
			w.soil[c] = sc
	w._soil_layer.queue_redraw()
	p.position = Vector2((gx + 6) * 32, (gy + 5) * 32 + 16)
	main.camera.reset_smoothing()
	await _wait(0.4)
	await _shot("28_plantas")

	# ---- tutorial: cada passo conclui quando o objetivo é cumprido
	game.tutorial = {"step": 0, "base": -1, "done": false}
	var tut: Tutorial = main.tutorial
	p.position = w.player_start
	for i in Tutorial.STEPS.size():
		var st: Dictionary = Tutorial.STEPS[i]
		tut._update_step()                  # marca a base do passo
		if st.get("abs", false) and int(game.tutorial["step"]) > i:
			continue                        # já tinha feito antes (pescou, cozinhou...): conclui na hora
		assert(int(game.tutorial["step"]) == i)
		var m: String = st["metric"]
		if i == 5:
			p.position = w.fungo.position + Vector2(0, 160)
			main.camera.reset_smoothing()
			tut._process(0.3)
			await _wait(0.3)
			await _shot("33_tutorial")
		var goal: int = st["goal"]
		if m.begins_with("counter:"):
			game.bump(m.trim_prefix("counter:"), goal)
		elif m.begins_with("item:"):
			game.add_item(m.trim_prefix("item:"), goal)
		else:
			match m:
				"moved":
					p.position = w.player_start + Vector2(120, 0)
				"soil", "planted", "watered":
					for k in goal:
						var sc := Agri.new_cell(false)
						Agri.plant(sc, "seed_kale")
						sc["moist"] = 1.0
						w.soil[Vector2i(14 + k + i * 4, 37)] = sc
				"day":
					game.day += 1
				"fish":
					game.fish_log["fish_silver"] = {"n": 3, "first": 1, "max_size": 9.0, "max_weight": 0.1}
				"cooked":
					game.dishes_cooked += 1
				"stove":
					game.add_item("stove", 1)
		tut._update_step()
		assert(int(game.tutorial["step"]) == i + 1 or game.tutorial["done"], "o passo %d deveria concluir" % i)
	assert(game.tutorial["done"] and not main.hud._tut_panel.visible)
	print("tutorial: %d passos concluídos" % Tutorial.STEPS.size())

	# ---- mina
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null
	game.minutes = 10 * 60
	assert(w.mine_entrance_pos != Vector2.ZERO)
	game.mine_deepest = 0
	w.mine_entrance_used.emit()
	await _wait(0.3)
	var mn: MineWorld = main.mine
	assert(mn != null and p.world == mn and mn.entities.is_ancestor_of(p) and not w.visible, "deveria estar na mina")
	var kinds_m := {}
	for c in mn.props:
		kinds_m[mn.props[c].kind] = int(kinds_m.get(mn.props[c].kind, 0)) + 1
	print("mina andar 1: ", mn.props.size(), " rochas ", kinds_m)
	assert(mn.props.size() > 20 and kinds_m.has("ore_copper") and not kinds_m.has("ore_crystal"))
	await _shot("35_mina")
	# quebra rochas até achar a escada
	game.inventory[0] = {"id": "pickaxe", "qty": 1}
	game.select_slot(0)
	var copper0: int = game.count_item("copper_ore")
	var broken := 0
	for c in mn.props.keys():
		if mn.ladder_visible():
			break
		while mn.props.has(c):
			game.energy = 100.0
			mn.use_item("pickaxe", c)
		broken += 1
	print("  quebrou %d rochas, escada=%s, cobre +%d" % [broken, mn.ladder_visible(), game.count_item("copper_ore") - copper0])
	assert(mn.ladder_visible(), "uma das rochas esconde a escada")
	mn.ladder_down_used.emit()
	await _wait(0.2)
	assert(main.mine.level == 2 and p.world == main.mine)
	# andar fundo com laguinho: peixes de caverna
	main.enter_mine(12)
	await _wait(0.3)
	mn = main.mine
	var water_cells := []
	for y in FarmWorld.H:
		for x in FarmWorld.W:
			if mn.ground_at(Vector2i(x, y)) == FarmWorld.Ground.WATER:
				water_cells.append(Vector2i(x, y))
	kinds_m = {}
	for c in mn.props:
		kinds_m[mn.props[c].kind] = int(kinds_m.get(mn.props[c].kind, 0)) + 1
	print("mina andar 12: rochas ", kinds_m, " · água: ", water_cells.size())
	assert(water_cells.size() > 4 and mn.water_kind(water_cells[0]) == "cave" and mn.region_id() == "mine_deep")
	assert(kinds_m.has("ore_iron") and kinds_m.has("ore_crystal"))
	var cave_seen := {}
	for i in 400:
		var cctx := FishDB.context("cave", "deep", "bait_mushroom", mn.region_id())
		cctx["level"] = 10
		cave_seen[FishDB.roll(cctx)] = true
	print("  peixes da caverna: ", cave_seen.keys())
	assert(cave_seen.has("fish_cave_blind") and cave_seen.has("fish_cave_crystal") and not cave_seen.has("fish_silver"))
	p.position = mn.cell_center(water_cells[0]) + Vector2(0, 40)
	main.camera.reset_smoothing()
	await _wait(0.3)
	await _shot("36_mina_lago")
	for c in mn.props.keys():
		if mn.props[c].kind in ["gem_ruby", "gem_emerald", "gem_moon"]:
			var gems0 := 0
			for g in ["ruby", "emerald", "moonstone"]:
				gems0 += game.count_item(g)
			while mn.props.has(c):
				game.energy = 100.0
				mn.use_item("pickaxe", c)
			var gems1 := 0
			for g in ["ruby", "emerald", "moonstone"]:
				gems1 += game.count_item(g)
			assert(gems1 == gems0 + 1, "rocha de gemas funda dá rubi, esmeralda ou pedra-lua")
			break
	var money_ch: int = game.money
	print("  ", mn._open_chest())
	assert(game.money > money_ch)
	# picareta melhorada: menos golpes
	game.tool_levels["pickaxe"] = 3
	for c in mn.props.keys():
		if mn.props[c].kind == "ore_iron":
			game.energy = 100.0
			mn.use_item("pickaxe", c)
			mn.use_item("pickaxe", c)
			assert(not mn.props.has(c), "picareta nível 3 quebra ferro (4) em 2 golpes")
			break
	game.tool_levels["pickaxe"] = 1
	# salvar dentro da mina volta pela entrada
	main.save_now()
	var sd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	assert(Vector2(sd["world"]["player"][0], sd["world"]["player"][1]) == w.mine_entrance_pos, "salvo na mina: volta pela entrada")
	main.exit_mine()
	await _wait(0.3)
	assert(main.mine == null and p.world == w and w.visible and p.position == w.mine_entrance_pos)
	await _shot("37_entrada_mina")
	assert(game.mine_deepest == 12)
	main._on_mine_entrance()
	await _wait(0.2)
	assert(main.hud._floors.visible and main.hud._floors_body.get_child_count() == 4, "elevador: andares 1, 5 e 10")
	await _shot("38_elevador")
	main.hud.close_panel()
	# fornalha: 5 minérios -> 1 barra, vários de uma vez
	var furnace: Placeable = w.place("furnace", Vector2i(34, 9), true)
	assert(furnace != null)
	for i in range(12, game.INV_SIZE):
		game.inventory[i] = null
	game.inventory[0] = {"id": "copper_ore", "qty": 12}
	game.select_slot(0)
	w._on_placeable_used(furnace)
	assert(int(furnace.job.get("qty", 0)) == 2 and game.count_item("copper_ore") == 2, "12 minérios -> 2 barras, sobram 2")
	furnace.job["ready"] = game.day
	var bars0: int = game.count_item("copper_bar")
	w._on_placeable_used(furnace)
	assert(game.count_item("copper_bar") == bars0 + 2)
	assert(Villagers.reaction("pipoca", "ruby") == "like" and Villagers.reaction("raiz", "emerald") == "love")
	game.inventory[0] = null

	# ---- correr (fôlego próprio) e bancada mostrando quanto você tem
	game.weather = "sunny"
	game.stamina = game.MAX_STAMINA
	game.exhausted = false
	var start_pos: Vector2 = p.position
	game.joystick_vector = Vector2(1, 0)
	await _wait(0.5)
	var walk_d: float = p.position.distance_to(start_pos)
	game.joystick_vector = Vector2(-1, 0)
	main.hud._run_btn._down = true
	start_pos = p.position
	await _wait(0.5)
	var run_d: float = p.position.distance_to(start_pos)
	assert(p.running, "segurando o botão, o personagem corre")
	await _shot("42_correndo")
	assert(run_d > walk_d * 1.4, "correr é mais rápido (andou %.0f, correu %.0f)" % [walk_d, run_d])
	assert(game.stamina < game.MAX_STAMINA, "correr gasta fôlego")
	var energy_before: float = game.energy
	game.stamina = 1.0
	await _wait(0.2)
	assert(game.exhausted and not p.running, "sem fôlego, para de correr")
	assert(is_equal_approx(game.energy, energy_before), "correr não gasta energia")
	main.hud._run_btn._down = false
	game.joystick_vector = Vector2.ZERO
	await _wait(1.0)
	assert(game.stamina > 1.0, "parado, o fôlego volta")
	game.stamina = game.MAX_STAMINA
	game.exhausted = false
	game.inventory[0] = {"id": "wood", "qty": 4}
	main.hud.open_crafting()
	await _wait(0.2)
	var chip = main.hud._craft_list.find_child("Chip_wood", true, false)
	assert(chip != null, "a bancada mostra os materiais com o que você tem")
	await _shot("43_bancada_materiais")
	main.hud.close_panel()
	game.inventory[0] = null
	assert(ItemDB.missing_text({"wood": 10}).contains("tem 0 de 10"))

	# ---- trator (por enquanto já vem no jogo novo; depois será vendido na cidade)
	assert(game.tractor["owned"] and game.trailer["owned"] and w.tractor != null and w.trailer != null,
		"jogo novo começa com o trator e a caçamba")
	main.hud.open_shop()
	await _wait(0.2)
	assert(main.hud._shop_buy.find_child("BuyTractor", true, false) == null, "o Fungo não vende o trator")
	main.hud.close_panel()
	p.position = w.tractor.position + Vector2(0, 12)
	await _wait(0.2)
	assert(p.find_interactable() != null and p.find_interactable().label == "Subir no trator")
	p.interact()
	await _wait(0.2)
	assert(p.riding and w.tractor == null, "subiu no trator")
	for dvec in [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]:
		game.joystick_vector = dvec
		await _wait(0.25)
		game.joystick_vector = Vector2.ZERO
		await _wait(0.1)
		await _shot("45_trator_%d_%d" % [int(dvec.x), int(dvec.y)])
	game.joystick_vector = Vector2(1, 1).normalized()       # diagonal: vista em 3/4
	await _wait(0.25)
	assert(p.tractor.dir == 5, "na diagonal o trator usa a vista diagonal (dir %d)" % p.tractor.dir)
	game.joystick_vector = Vector2.ZERO
	await _wait(0.1)
	var tp: Vector2 = p.position
	game.joystick_vector = Vector2(1, 0)
	await _wait(0.4)
	game.joystick_vector = Vector2.ZERO
	var ride_d: float = p.position.distance_to(tp)
	assert(p.tractor._wheel > 0.0, "as rodas giram andando")
	assert(ride_d > 60.0, "de trator anda bem mais rápido (andou %.0f)" % ride_d)
	p.use_tool()
	assert(p.riding, "ferramentas não funcionam em cima do trator")
	p.interact()
	await _wait(0.2)
	assert(not p.riding and w.tractor != null, "desceu: o trator fica estacionado")
	assert(is_equal_approx(float(game.tractor["x"]), w.tractor.position.x))
	# caçamba: segue o trator, guarda itens, vende perto da caixa
	p.position = w.tractor.position + Vector2(0, 12)
	await _wait(0.1)
	p.interact()
	for dvec in [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]:
		game.joystick_vector = dvec
		await _wait(0.3)
		game.joystick_vector = Vector2.ZERO
		await _wait(0.15)
		await _shot("46_cacamba_%d_%d" % [int(dvec.x), int(dvec.y)])
		var behind: Vector2 = p.global_position + Trailer.BEHIND[p.tractor.dir]
		assert(w.trailer.global_position.distance_to(behind) < 12.0, "a caçamba segue atrás do trator")
	assert(w.trailer._wheel > 0.0, "as rodas da caçamba giram quando ela é puxada")
	# leva até a caixa de vendas e desce
	p.position = w.sell_bin.position + Vector2(20, 40)
	await _wait(0.4)
	p.interact()
	await _wait(0.2)
	game.inventory[10] = {"id": "kale", "qty": 30}
	main.hud.open_cargo()
	main.hud._on_cargo_slot(10, false)
	assert(game.inventory[10] == null and Trailer.items()[0]["id"] == "kale", "o item foi para a carga")
	var tool_i := 11
	var old11 = game.inventory[11]
	game.inventory[11] = {"id": "hoe", "qty": 1}
	main.hud._on_cargo_slot(tool_i, false)   # ferramenta fica na mochila
	assert(game.inventory[tool_i] != null and game.inventory[tool_i]["id"] == "hoe")
	game.inventory[11] = old11
	await _wait(0.2)
	await _shot("47_carga")
	var m0: int = game.money
	main.hud.sell_cargo()
	assert(game.money > m0 and Trailer.items()[0] == null, "vendeu a carga perto da caixa")
	main.hud.close_panel()
	main.save_now()
	game.load_game()
	assert(game.tractor["owned"], "o trator fica salvo")
	assert(game.trailer["owned"], "a caçamba fica salva")

	# ---- não dá para andar sobre a água (a pé)
	var wcell := Vector2i(-1, -1)
	for yy in range(2, w.H - 2):
		for xx in range(2, w.W - 2):
			if w.ground_at(Vector2i(xx, yy)) == FarmWorld.Ground.WATER and w.ground_at(Vector2i(xx, yy - 1)) != FarmWorld.Ground.WATER \
					and w.ground_at(Vector2i(xx, yy + 2)) == FarmWorld.Ground.WATER and not w.props.has(Vector2i(xx, yy - 1)) \
					and not w.blocked.has(Vector2i(xx, yy - 1)):
				wcell = Vector2i(xx, yy)
				break
		if wcell.x >= 0:
			break
	assert(wcell.x >= 0)
	p.position = w.cell_center(wcell + Vector2i(0, -1))
	game.joystick_vector = Vector2(0, 1)
	await _wait(0.8)
	game.joystick_vector = Vector2.ZERO
	assert(w.ground_at(w.cell_of(p.position)) != FarmWorld.Ground.WATER or p.position.y < wcell.y * 32 + 10,
		"não dá para entrar na água")

	# ---- opções
	main.hud.open_options()
	await _wait(0.3)
	assert(main.hud._options.visible)
	await _shot("34_opcoes")
	# ---- som: volume nas Opções, música e ambiente por lugar/hora/clima, efeitos existem
	var snd = root.get_node("Sound")
	var slider: HSlider = main.hud._options.find_child("VolumeMúsica", true, false)
	assert(slider != null, "Opções deveriam ter o volume da música")
	var mv0: float = snd.music_volume
	slider.value = 0.4
	assert(is_equal_approx(snd.music_volume, 0.4), "o controle muda o volume da música")
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.4))
	slider.value = mv0
	# zoom da câmera: pelo controle das Opções e por pinça com dois dedos
	var zs: HSlider = main.hud._options.find_child("Zoom", true, false)
	zs.value = 1.5
	assert(is_equal_approx(main.camera.zoom.x, 1.5), "o controle muda o zoom")
	main.hud.close_panel()
	await _wait(0.2)
	await _shot("48_zoom")
	main.set_zoom(1.0)
	var t1 := InputEventScreenTouch.new()
	t1.index = 5
	t1.position = Vector2(300, 150)
	t1.pressed = true
	var t2 := InputEventScreenTouch.new()
	t2.index = 6
	t2.position = Vector2(340, 150)
	t2.pressed = true
	main._unhandled_input(t1)
	main._unhandled_input(t2)
	var dr := InputEventScreenDrag.new()
	dr.index = 6
	dr.position = Vector2(380, 150)
	main._unhandled_input(dr)
	assert(is_equal_approx(main.camera.zoom.x, 2.0), "a pinça aproxima (zoom %.2f)" % main.camera.zoom.x)
	t1.pressed = false
	t2.pressed = false
	main._unhandled_input(t1)
	main._unhandled_input(t2)
	main.set_zoom(1.0)
	snd.update_scene(false, false, "sunny")
	assert(snd.current_music == "farm_day" and snd.current_ambience == "amb_birds")
	snd.update_scene(false, true, "sunny")
	assert(snd.current_music == "farm_night" and snd.current_ambience == "amb_night")
	snd.update_scene(false, false, "storm")
	assert(snd.current_music == "farm_rain" and snd.current_ambience == "amb_rain")
	snd.update_scene(true, false, "rain")
	assert(snd.current_music == "mine" and snd.current_ambience == "amb_cave")
	for t in ["farm_day", "farm_night", "farm_rain", "mine", "amb_birds", "amb_night", "amb_rain", "amb_cave"]:
		var st = load("res://assets/music/%s.ogg" % t)
		assert(st is AudioStreamOggVorbis and st.get_length() > 20.0, "faixa %s" % t)
	for sfx in ["ui_click", "till", "water", "fill", "chop", "pick", "harvest", "cast", "bite", "reel", "catch", "escape",
			"treasure", "coin", "buy", "cook", "eat", "door", "sleep", "levelup", "success", "chest", "ladder", "talk",
			"gift", "gem", "build", "step_grass", "step_path", "step_stone", "deny", "ui_open", "ui_close", "weed"]:
		assert(load("res://assets/sounds/%s.wav" % sfx) is AudioStreamWAV, "efeito %s" % sfx)
		snd.play(sfx)
	main._update_daylight()
	# mudar a aparência pelas Opções
	var cc2 = main.hud.open_character_creator(false)
	await _wait(0.2)
	assert(cc2._name.text == "Lia", "editar mostra o nome atual")
	cc2.set_choices("Lia", "Sítio Girassol", {"skin": 6, "hair": 3, "hair_color": 5, "shirt": 6, "pants": 4})
	await _wait(0.3)
	await _shot("40_aparencia")
	cc2.confirm()
	await _wait(0.2)
	assert(int(game.look()["hair"]) == 3 and game.ui_lock == 0)
	await _shot("41_novo_visual")
	main.hud.tutorial_restart_requested.emit()
	assert(main.tutorial.active() and int(game.tutorial["step"]) == 0 and main.hud._tut_panel.visible)
	game.tutorial["done"] = true
	main.tutorial._refresh_panel()

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
