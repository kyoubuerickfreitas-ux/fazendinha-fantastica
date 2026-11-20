extends Node2D
## Cena principal: monta o mundo, o jogador, a câmera e a interface,
## e cuida do ciclo de dia/noite, chuva, sono e salvamento.

var world: FarmWorld
var player: Player
var hud: HUD
var camera: Camera2D
var daylight: CanvasModulate
var weather_fx: WeatherFX
var _new_babies: Array = []


func _ready() -> void:
	var saved := Game.load_game()

	world = FarmWorld.new()
	world.name = "World"
	add_child(world)
	world.generate(saved)

	player = Player.new()
	player.name = "Player"
	player.world = world
	var pos = saved.get("player", null)
	player.position = Vector2(pos[0], pos[1]) if pos is Array else world.player_start
	world.entities.add_child(player)
	world.player = player

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.world_size().x)
	camera.limit_bottom = int(world.world_size().y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)

	daylight = CanvasModulate.new()
	add_child(daylight)
	_build_rain()

	var fishing := Fishing.new()
	fishing.name = "Fishing"
	fishing.player = player
	fishing.world = world
	world.add_child(fishing)
	player.fishing = fishing

	hud = HUD.new()
	hud.player = player
	add_child(hud)

	hud.use_pressed.connect(player.use_tool)
	hud.interact_pressed.connect(player.interact)
	world.house_door_used.connect(func(): hud.ask("Dormir até amanhã?\n(o jogo é salvo)", _sleep.bind(true)))
	world.shop_requested.connect(_on_shop)
	world.stove_used.connect(func(): hud.open_cooking())
	Game.time_changed.connect(func(_d: int, m: int):
		if m >= FishQuests.TOUR_END and FishQuests.is_tournament_day():
			var res := FishQuests.finish_tournament()
			if res != "":
				var tt := FishDB.check_titles()
				Game.toast.emit(res + ("\n" + tt if tt != "" else "")))
	world.bin_used.connect(_sell_all)
	world.workbench_used.connect(func(): hud.open_crafting())
	world.baby_born.connect(func(r):
		if Game.ui_lock == 0:
			hud.ask_animal_name(r)   # chocou agora (incubadora)
		else:
			_new_babies.append(r))   # nasceu de noite: pergunta ao acordar
	world.animal_card_requested.connect(func(r): hud.open_animal_card(r))
	world.animal_list_requested.connect(func(list, title, b): hud.open_animal_list(list, title, b))
	hud.world = world
	Game.pass_out.connect(func():
		Game.toast.emit("Você desmaiou de sono...")
		_sleep(false))
	Game.time_changed.connect(func(_d, _m): _update_daylight())
	Game.weather_changed.connect(func(_w): _update_weather())
	_update_daylight()
	_update_weather()

	if saved.is_empty():
		Game.toast.emit("Bem-vindo à sua fazendinha!")
	else:
		Game.toast.emit("Dia %d" % Game.day)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_world_tap(event.position)
		return
	if event.is_action_pressed("use_tool"):
		player.use_tool()
	elif event.is_action_pressed("interact"):
		player.interact()


# ------------------------------------------------------------------ toque no mundo
## Tocar na tela (fora dos botões) usa o item exatamente onde você tocou.
func _on_world_tap(screen_pos: Vector2) -> void:
	if Game.ui_lock > 0 or hud.blocks_point(screen_pos):
		return
	var wp := get_viewport().get_canvas_transform().affine_inverse() * screen_pos

	# personagens, animais, caixa, porta
	var best: Interactable = null
	var best_d := 22.0
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		var d := (it.global_position + Vector2(0, -14)).distance_to(wp)
		if d < best_d:
			best = it
			best_d = d
	if best:
		if player.can_reach(best.global_position):
			best.interact(player)
		else:
			Game.toast.emit("Chegue mais perto.")
		return

	# objetos grandes (árvore, pedra...) pela imagem; senão, a célula tocada
	var prop := world.prop_at_point(wp)
	var c: Vector2i = prop.cell if prop else world.cell_of(wp)
	if not player.can_reach(world.target_anchor(c)):
		Game.toast.emit("Chegue mais perto.")
		return
	player.use_at(c)


# ------------------------------------------------------------------ ações do mundo
func _on_shop() -> void:
	var delivered := FishQuests.try_deliver()
	if delivered != "":
		var tt := FishDB.check_titles()
		Game.toast.emit(delivered + ("\n" + tt if tt != "" else ""))
		hud.open_shop()
		return
	if Game.count_item("fungo_glasses") > 0:
		Game.remove_item("fungo_glasses", 1)
		Game.money += 500
		Game.add_item("bait_treasure", 5)
		Game.fish_flags["fungo_glasses_returned"] = true
		Game.toast.emit("Fungo: MEUS ÓCULOS! Agora enxergo as sementes de novo! Tome 500 moedas e 5 Iscas Reluzentes.")
		hud.open_shop()
		return
	var asked := FishQuests.ensure_request()
	if asked != "":
		Game.toast.emit("Fungo: Sementes fresquinhas! E tenho um pedido de pesca: " + FishQuests.request()["text"])
	else:
		Game.toast.emit("Fungo: Sementes fresquinhas! Vendo e compro de tudo.")
	hud.open_shop()


func _sell_all() -> void:
	var total := 0
	var count := 0
	for i in Game.INV_SIZE:
		var s = Game.inventory[i]
		if s != null and ItemDB.get_item(s["id"]).get("type", "") in ["crop", "product", "fish"]:
			total += ItemDB.sell_price(s["id"], int(s.get("q", 0))) * int(s["qty"])
			count += int(s["qty"])
			Game.inventory[i] = null
	if count == 0:
		Game.toast.emit("Coloque colheitas e produtos aqui para vender.")
		return
	Game.inventory_changed.emit()
	Game.add_money(total)
	Game.toast.emit("Vendeu %d itens por %d moedas!" % [count, total])


func _sleep(rested: bool) -> void:
	player.fishing.cancel()
	var tour_result := FishQuests.finish_tournament()   # dormiu antes das 16h no dia do torneio
	hud.fade_through(func():
		Game.start_new_day(rested)
		var notes := world.on_new_day()
		for extra in [FishQuests.on_new_day(), tour_result, Cooking.check_unlocks()]:
			if extra != "":
				notes = extra if notes == "" else notes + "\n" + extra
		player.position = world.player_start
		camera.reset_smoothing()
		save_now()
		var head := "%s · %d°C%s" % [Calendar.short_text(Game.day), int(Game.temperature),
			" · " + Game.weather_data().name.to_lower() if Game.weather != "sunny" else ""]
		Game.toast.emit(head + ("\n" + notes if notes != "" else "")),
		func():
			# filhotes que nasceram de noite: pede o nome do último
			if not _new_babies.is_empty():
				hud.ask_animal_name(_new_babies.back())
				_new_babies.clear())


func save_now() -> void:
	var data := world.serialize()
	data["player"] = [player.position.x, player.position.y]
	Game.save_game(data)


# ------------------------------------------------------------------ dia/noite e clima
func _update_daylight() -> void:
	var m := float(Game.minutes)
	var day_c := Color(1, 1, 1)
	var dusk_c := Color(1.0, 0.86, 0.74)
	var night_c := Color(0.52, 0.56, 0.8)
	var c: Color
	if m < 17 * 60:
		c = day_c
	elif m < 19 * 60:
		c = day_c.lerp(dusk_c, (m - 17 * 60) / 120.0)
	elif m < 21 * 60:
		c = dusk_c.lerp(night_c, (m - 19 * 60) / 120.0)
	else:
		c = night_c
	c = c * Game.weather_data().light
	var tw := create_tween()
	tw.tween_property(daylight, "color", c, 1.0)


func _build_rain() -> void:
	weather_fx = WeatherFX.new()
	add_child(weather_fx)


func _update_weather() -> void:
	weather_fx.set_weather(Game.weather)
	_update_daylight()


# ------------------------------------------------------------------ ciclo de vida do app
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			if world:
				save_now()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if hud.is_panel_open():
				hud.close_panel()
			else:
				hud.ask("Salvar e sair do jogo?", func():
					save_now()
					get_tree().quit())
