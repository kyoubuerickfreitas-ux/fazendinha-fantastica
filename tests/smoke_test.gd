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
		game.select_slot(1); p._busy = 0; p.use_tool()
		game.select_slot(5); p._busy = 0; p.use_tool()
		game.select_slot(0); p._busy = 0; p.use_tool()
		if i == 1:
			await _wait(0.15)
			await _shot("02b_efeito")
		game.joystick_vector = Vector2(1, 0)
		await _wait(0.38)
		game.joystick_vector = Vector2(0, 1)
		await _wait(0.05)
		game.joystick_vector = Vector2.ZERO
		await _wait(0.1)
	await _shot("02_plantando")
	# avança dias regando tudo
	for d in 3:
		for c in w.soil: w.soil[c]["wet"] = true
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
	# animais: carinho, novo dia, coleta
	var cow = w.animals[0]
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
	p._busy = 0
	p.use_tool()
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
	print("toque na árvore: hp ", hp1, " -> ", tree.hp)
	assert(tree.hp == hp1 - 1, "tocar na árvore deveria usar o machado nela")
	await _wait(0.1)
	await _shot("08_mira")

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
