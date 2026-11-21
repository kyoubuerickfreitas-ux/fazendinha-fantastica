extends Node2D
## Cena principal: monta o mundo, o jogador, a câmera e a interface,
## e cuida do ciclo de dia/noite, chuva, sono e salvamento.

var world: FarmWorld
var player: Player
var hud: HUD
var tutorial: Tutorial
var _resetting := false
## andar da mina em que o jogador está (null = na fazenda)
var mine: MineWorld = null
var house: HouseWorld = null
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

	tutorial = Tutorial.new()
	tutorial.world = world
	tutorial.player = player
	tutorial.hud = hud
	world.add_child(tutorial)
	hud.tutorial_skip_pressed.connect(func():
		hud.ask("Pular o tutorial?\n(as dicas param de aparecer)", tutorial.skip))

	hud.save_requested.connect(save_now)
	hud.zoom_requested.connect(func(z): set_zoom(z))
	_load_zoom()
	hud.zoom_changed(zoom_level)
	hud.new_game_requested.connect(_new_game)
	hud.tutorial_restart_requested.connect(func():
		Game.tutorial = {"step": 0, "base": -1, "done": false}
		tutorial._refresh_panel())

	hud.use_pressed.connect(player.use_tool)
	hud.interact_pressed.connect(player.interact)
	world.house_door_used.connect(enter_house)
	world.shop_requested.connect(_on_shop)
	world.stove_used.connect(func(): hud.open_cooking())
	world.villager_used.connect(_on_villager)
	world.mine_entrance_used.connect(_on_mine_entrance)
	world.untill_requested.connect(func(c: Vector2i):
		hud.ask("Desfazer este canteiro?\n(volta a ser grama)", func(): world.untill(c)))
	world.trailer_open_requested.connect(func(): hud.open_cargo())
	hud.floor_chosen.connect(enter_mine)
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
		exit_mine(true)
		_sleep(false))
	Game.time_changed.connect(func(_d, _m): _update_daylight())
	Game.weather_changed.connect(func(_w): _update_weather())
	_update_daylight()
	_update_weather()

	hud.character_created.connect(func(first: bool):
		save_now()
		if first:
			Game.toast.emit("Bem-vindo(a), %s! Esta é a sua fazenda: %s." % [Game.player_name(), Game.farm_name()])
		else:
			Game.toast.emit("Visual atualizado!"))
	if not Game.profile.get("created", true):
		hud.open_character_creator(true)
	elif saved.is_empty():
		Game.toast.emit("Bem-vindo à sua fazendinha!")
	else:
		Game.toast.emit("Dia %d" % Game.day)


func _unhandled_input(event: InputEvent) -> void:
	# zoom: pinça com dois dedos no mapa, ou a rodinha do mouse
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 2:
				_pinch_start = _pinch_dist()
				_pinch_zoom = zoom_level
				return
		else:
			_touches.erase(event.index)
	if event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() == 2 and _pinch_start > 10.0:
			set_zoom(_pinch_zoom * _pinch_dist() / _pinch_start, false)
		return
	if event is InputEventMouseButton and event.pressed and Game.ui_lock == 0:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom_level + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom_level - 0.1)
	if event is InputEventScreenTouch and event.pressed:
		if _touches.size() == 1:
			_on_world_tap(event.position)
		return
	if event.is_action_pressed("use_tool"):
		player.use_tool()
	elif event.is_action_pressed("interact"):
		player.interact()


# ------------------------------------------------------------------ zoom da câmera
const ZOOM_MIN := 0.75
const ZOOM_MAX := 2.0
const SETTINGS := "user://settings.cfg"
var zoom_level := 1.0
var _touches := {}
var _pinch_start := 0.0
var _pinch_zoom := 1.0


func _pinch_dist() -> float:
	var p: Array = _touches.values()
	return (p[0] as Vector2).distance_to(p[1])


## Muda o zoom (1 = normal; maior = mais perto). Fica salvo no aparelho.
func set_zoom(z: float, save := true) -> void:
	zoom_level = clampf(z, ZOOM_MIN, ZOOM_MAX)
	if camera:
		camera.zoom = Vector2(zoom_level, zoom_level)
	hud.zoom_changed(zoom_level)
	if save:
		save_zoom()


func save_zoom() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("view", "zoom", zoom_level)
	cfg.save(SETTINGS)


func _load_zoom() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		zoom_level = clampf(float(cfg.get_value("view", "zoom", 1.0)), ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(zoom_level, zoom_level)


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
		if not it.is_visible_in_tree() or not player.world.is_ancestor_of(it):
			continue
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
	var here: FarmWorld = player.world      # fazenda ou andar da mina
	var prop := here.prop_at_point(wp)
	var c: Vector2i = prop.cell if prop else here.cell_of(wp)
	if not player.can_reach(here.target_anchor(c)):
		Game.toast.emit("Chegue mais perto.")
		return
	player.use_at(c)


# ------------------------------------------------------------------ ações do mundo
## Conversar com um morador; com um item na mão (que não seja ferramenta), dá de presente.
func _on_villager(id: String) -> void:
	var held := Game.selected_item_id()
	var text := ""
	if Villagers.can_gift(held):
		text = Villagers.gift(id, held)
	if text == "":
		text = Villagers.talk(id)
	hud.open_npc_dialog(id, text)


func _on_shop() -> void:
	Villagers.voice("fungo")
	Game.bump("shop")
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
	Game.bump("sold", count)
	Game.toast.emit("Vendeu %d itens por %d moedas!" % [count, total])


func _sleep(rested: bool) -> void:
	player.fishing.cancel()
	player.dismount()
	Sound.play("sleep" if rested else "escape")
	var tour_result := FishQuests.finish_tournament()   # dormiu antes das 16h no dia do torneio
	hud.fade_through(func():
		Game.start_new_day(rested)
		var notes := world.on_new_day()
		for extra in [FishQuests.on_new_day(), tour_result, Cooking.check_unlocks(), Villagers.on_new_day()]:
			if extra != "":
				notes = extra if notes == "" else notes + "\n" + extra
		player.position = house.bed_spot + Vector2(0, 24) if house else world.player_start
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


# ------------------------------------------------------------------ mina
func _on_mine_entrance() -> void:
	if Game.mine_deepest >= 5:
		hud.open_floor_chooser(Game.mine_deepest)     # elevador: a cada 5 andares
	else:
		enter_mine(1)


# ------------------------------------------------------------------ casa
## Entra em casa: o interior é um mundo à parte (como a mina).
func enter_house() -> void:
	if house:
		return
	player.dismount()
	Sound.play("door")
	hud.fade_through(func():
		house = HouseWorld.new()
		house.name = "House"
		add_child(house)
		house.generate({})
		house.exit_used.connect(exit_house)
		house.bed_used.connect(func(): hud.ask("Dormir até amanhã?\n(o jogo é salvo)", _sleep.bind(true)))
		house.chest_used.connect(func(): hud.open_cargo("chest"))
		house.stove_used.connect(func(): hud.open_cooking())
		_move_player(house, house.spawn_pos)
		world.visible = false
		world.process_mode = Node.PROCESS_MODE_DISABLED
		tutorial.visible = false
		_set_camera_free(true)
		Game.bump("house_visits")
		_update_weather())


## Sai de casa pela porta (de volta à fazenda, na frente da porta).
func exit_house() -> void:
	if house == null:
		return
	Sound.play("door")
	hud.fade_through(func():
		Game.house["placeables"] = house.serialize_house()
		world.visible = true
		world.process_mode = Node.PROCESS_MODE_INHERIT
		tutorial.visible = true
		_move_player(world, world.house_door.position + Vector2(0, 18))
		house.queue_free()
		house = null
		_set_camera_free(false)
		_update_weather())


## Dentro de casa a câmera não fica presa às bordas do mapa (o cômodo é menor que a tela).
func _set_camera_free(free: bool) -> void:
	camera.limit_left = -100000 if free else 0
	camera.limit_top = -100000 if free else 0
	camera.limit_right = 100000 if free else int(world.world_size().x)
	camera.limit_bottom = 100000 if free else int(world.world_size().y)
	camera.reset_smoothing()


## Vai para um andar da mina (da fazenda ou de outro andar).
func enter_mine(level: int) -> void:
	player.dismount()            # o trator fica estacionado na entrada
	Sound.play("ladder")
	var old := mine
	mine = MineWorld.new()
	mine.name = "Mine"
	add_child(mine)
	mine.generate({"level": level})
	mine.ladder_down_used.connect(func(): enter_mine(mine.level + 1))
	mine.exit_used.connect(func(): exit_mine())
	_move_player(mine, mine.spawn_pos)
	if old:
		old.queue_free()
	world.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	tutorial.visible = false
	Game.mine_deepest = maxi(Game.mine_deepest, level)
	_update_weather()
	var extra := ""
	if level % 5 == 0 and level == Game.mine_deepest:
		extra = "\nO elevador agora para aqui!"
	if level % 3 == 0:
		extra += "\nTem um laguinho subterrâneo neste andar."
	Game.toast.emit("Mina · andar %d%s" % [level, extra])


## Volta para a fazenda, na entrada da mina.
func exit_mine(silent: bool = false) -> void:
	if mine == null:
		return
	if not silent:
		Sound.play("ladder")
	world.visible = true
	world.process_mode = Node.PROCESS_MODE_INHERIT
	tutorial.visible = true
	_move_player(world, world.mine_entrance_pos)
	mine.queue_free()
	mine = null
	_update_weather()
	if not silent:
		Game.toast.emit("De volta à fazenda.")


func _move_player(to: FarmWorld, pos: Vector2) -> void:
	player.fishing.cancel()
	player.get_parent().remove_child(player)
	to.entities.add_child(player)
	player.world = to
	player.position = pos
	to.player = player
	var f := player.fishing
	f.get_parent().remove_child(f)
	to.add_child(f)
	f.world = to
	camera.reset_smoothing()


## Apaga o save e recomeça do zero (botão Opções > Novo jogo).
func _new_game() -> void:
	_resetting = true
	Game.delete_save()
	Game.reset_new_game()
	Game.ui_lock = 0
	get_tree().reload_current_scene()


func save_now() -> void:
	if _resetting:
		return     # não salvar o jogo antigo por cima enquanto recomeça
	var data := world.serialize()
	var pos := world.mine_entrance_pos if mine else player.position   # salvo na mina: volta pela entrada
	if house:
		Game.house["placeables"] = house.serialize_house()
		pos = world.house_door.position + Vector2(0, 18)           # salvo em casa: volta na porta
	data["player"] = [pos.x, pos.y]
	if player.riding:            # dirigindo: o trator fica onde você está
		Game.tractor["x"] = player.position.x
		Game.tractor["y"] = player.position.y
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
	if mine:
		c = Color(0.66, 0.6, 0.72)       # caverna: sempre na penumbra
	if house:
		c = Color(1.0, 0.95, 0.88) if not Game.is_night() else Color(0.86, 0.76, 0.66)   # luz da lareira
	Sound.update_scene(mine != null, Game.is_night(), Game.weather, house != null)
	var tw := create_tween()
	tw.tween_property(daylight, "color", c, 1.0)


func _build_rain() -> void:
	weather_fx = WeatherFX.new()
	add_child(weather_fx)


func _update_weather() -> void:
	weather_fx.set_weather(Game.weather)
	weather_fx.visible = mine == null and house == null      # não chove dentro da mina nem de casa
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
