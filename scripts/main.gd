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
var city: CityWorld = null       # criada na 1ª visita e guardada (o trator pode ficar estacionado lá)
var in_city := false
var shop: ShopWorld = null      # dentro de uma loja da cidade
var _traveling := false
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
	hud.decorate_toggled.connect(func(on: bool):
		if house:
			house.set_decorating(on)
			if on:
				Game.toast.emit("Decorar: toque num móvel e depois no chão para mudar de lugar. \"Girar\" vira, \"Cor\" pinta o móvel; \"Piso\" e \"Parede\" trocam as cores da casa."))
	hud.color_pressed.connect(func(kind: String):
		if house:
			Game.toast.emit(house.next_color(kind)))
	hud.rotate_pressed.connect(func():
		if house:
			var m := house.rotate_selected()
			if m != "":
				Game.toast.emit(m))
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
	world.stove_used.connect(_use_stove)
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
		exit_shop(true)
		exit_city(true)
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
	if house and house.decorating:
		var msg := house.decor_tap(wp)
		if msg != "":
			Game.toast.emit(msg)
		return

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
func _on_villager(id: String, shop_kind := "") -> void:
	var held := Game.selected_item_id()
	var text := ""
	if Villagers.can_gift(held):
		text = Villagers.gift(id, held)
	if text == "":
		text = Villagers.talk(id)
	hud.open_npc_dialog(id, text, shop_kind)


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


## Fogão: se tem prato pronto, pega; senão abre a cozinha (receitas e fila).
func _use_stove() -> void:
	var m := Cooking.collect()
	if m != "":
		Game.toast.emit(m)
		if house and house.kitchen:
			FX.spawn(house, "steam", house.kitchen.global_position + Vector2(10, -26))
		return
	hud.open_cooking()


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
		house.stove_used.connect(_use_stove)
		_move_player(house, house.spawn_pos)
		world.visible = false
		world.process_mode = Node.PROCESS_MODE_DISABLED
		tutorial.visible = false
		_set_camera_free(true)
		hud.set_house_mode(true)
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
		hud.set_house_mode(false)
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


# ------------------------------------------------------------------ cidade
## Andar até a borda do mapa pela estrada troca de mapa (fazenda <-> cidade).
func _physics_process(_delta: float) -> void:
	if _traveling or Game.ui_lock > 0 or player == null or player.world == null:
		return
	match player.world.exit_at(player.position):
		"city":
			enter_city()
		"farm":
			exit_city()


## Vai para a cidade pela estrada leste. Dirigindo, o trator (e a caçamba engatada) vão junto.
func enter_city() -> void:
	if in_city or mine or house:
		return
	_traveling = true
	hud.fade_through(func():
		if city == null:
			city = CityWorld.new()
			city.name = "City"
			add_child(city)
			city.generate({})
			city.building_used.connect(_on_city_building)
			city.trailer_open_requested.connect(func(): hud.open_cargo())
		city.visible = true
		city.process_mode = Node.PROCESS_MODE_INHERIT
		in_city = true
		_move_player(city, city.spawn_pos)
		world.visible = false
		world.process_mode = Node.PROCESS_MODE_DISABLED
		tutorial.visible = false
		Game.bump("city_visits")
		_update_weather()
		Game.toast.emit("Cidade"),
		func(): _traveling = false)


## Volta para a fazenda, no fim da estrada (a cidade fica guardada, com o trator se ele ficou lá).
func exit_city(silent := false) -> void:
	if not in_city:
		return
	_traveling = true
	var back := func():
		world.visible = true
		world.process_mode = Node.PROCESS_MODE_INHERIT
		tutorial.visible = true
		in_city = false
		_move_player(world, FarmWorld.CITY_RETURN)
		city.visible = false
		city.process_mode = Node.PROCESS_MODE_DISABLED
		_update_weather()
	if silent:
		if player.riding:
			player.dismount()
		back.call()
		_traveling = false
		return
	hud.fade_through(func():
		back.call()
		Game.toast.emit("De volta à fazenda."),
		func(): _traveling = false)


## Portas da cidade: cada loja abre a sua janela.
func _on_city_building(kind: String) -> void:
	match kind:
		"bakery", "smith", "market", "fish":
			enter_shop(kind)
		"restaurant":
			Sound.play("door", -6.0)
			hud.open_shop(kind)
		"tailor":
			hud.open_character_creator(false)
		"inn":
			if Game.energy >= Game.max_energy - 0.5:
				Game.toast.emit("Pousada: Volte quando estiver cansado(a)! Um cochilo custa %d moedas." % INN_PRICE)
				return
			hud.ask("Tirar um cochilo na pousada?\nCusta %d moedas e recupera toda a energia." % INN_PRICE, func():
				if Game.money < INN_PRICE:
					Game.toast.emit("Moedas insuficientes.")
					return
				Game.add_money(-INN_PRICE)
				Sound.play("sleep")
				hud.fade_through(func():
					Game.energy = Game.max_energy
					Game.stats_changed.emit()
					Game.toast.emit("Energia renovada!")))
		"well":
			if Game.count_item("watering_can") > 0 and Game.water < Game.water_capacity():
				Game.water = Game.water_capacity()
				Game.stats_changed.emit()
				Sound.play("fill")
				FX.spawn(city, "fill", player.position + Vector2(0, -10))
				Game.toast.emit("Regador cheio com a água do poço.")
			else:
				Game.toast.emit("Um poço antigo de água fresquinha. Dá para encher o regador aqui.")
		"board":
			var lines := ["Quadro de avisos · %s" % Calendar.short_text(Game.day)]
			if FishQuests.is_tournament_day():
				lines.append("Hoje tem torneio de pesca!")
			var req: Dictionary = FishQuests.request()
			if not req.is_empty():
				lines.append("Pedido do Fungo: " + str(req.get("text", "")))
			if lines.size() == 1:
				lines.append("Nenhum aviso novo hoje.")
			Game.toast.emit("\n".join(lines))
		"sign":
			Game.toast.emit("← Fazenda %s" % Game.farm_name())
		"windmill":
			Game.toast.emit("O moinho gira devagar. Dizem que logo vai moer farinha.")
		_:
			Game.toast.emit("Casa de um morador. A porta está fechada.")


const INN_PRICE := 40


## Entra numa loja da cidade (o morador atende das 6h às 20h).
func enter_shop(kind: String) -> void:
	if shop or not in_city:
		return
	if Game.minutes < NPC.DAY_START or Game.minutes >= NPC.DAY_END:
		var who := Villagers.get_npc(ShopWorld.KEEPERS[kind]).name
		Game.toast.emit("Fechado. %s atende das 6h às 20h." % who)
		return
	player.dismount()            # o trator fica estacionado na frente da loja
	Sound.play("door")
	_traveling = true
	hud.fade_through(func():
		shop = ShopWorld.new()
		shop.name = "Shop"
		add_child(shop)
		shop.generate({"kind": kind})
		shop.exit_used.connect(func(): exit_shop())
		shop.keeper_used.connect(func(id: String): _on_villager(id, kind))
		_move_player(shop, shop.spawn_pos)
		city.visible = false
		city.process_mode = Node.PROCESS_MODE_DISABLED
		_set_camera_free(true)
		_update_weather(),
		func(): _traveling = false)


## Sai da loja para a frente dela, na cidade.
func exit_shop(silent := false) -> void:
	if shop == null:
		return
	var back := func():
		city.visible = true
		city.process_mode = Node.PROCESS_MODE_INHERIT
		_move_player(city, city.doors.get(shop.kind, city.spawn_pos) + Vector2(0, 18))
		shop.queue_free()
		shop = null
		_set_camera_free(false)
		_update_weather()
	if silent:
		back.call()
		return
	Sound.play("door")
	_traveling = true
	hud.fade_through(back, func(): _traveling = false)


func _move_player(to: FarmWorld, pos: Vector2) -> void:
	player.fishing.cancel()
	var from := player.world
	player.get_parent().remove_child(player)
	to.entities.add_child(player)
	player.world = to
	player.position = pos
	to.player = player
	# dirigindo: a caçamba engatada vai junto para o outro mapa
	if player.riding and player.tractor.trailer and from != to:
		var tr: Trailer = player.tractor.trailer
		tr.get_parent().remove_child(tr)
		to.entities.add_child(tr)
		to.trailer = tr
		if from:
			from.trailer = null
		tr.follow(player.global_position, player.tractor.dir, 1.0)
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
	if in_city:
		pos = FarmWorld.CITY_RETURN                                    # salvo na cidade: volta pela estrada
	if house:
		Game.house["placeables"] = house.serialize_house()
		pos = world.house_door.position + Vector2(0, 18)           # salvo em casa: volta na porta
	data["player"] = [pos.x, pos.y]
	if player.riding:            # dirigindo: o trator fica onde você está (na cidade: no fim da estrada da fazenda)
		var tp := player.position if not in_city else FarmWorld.CITY_RETURN + Vector2(-40, 0)
		Game.tractor["x"] = tp.x
		Game.tractor["y"] = tp.y
		Game.tractor["where"] = "farm"
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
	if house or shop:
		c = Color(1.0, 0.95, 0.88) if not Game.is_night() else Color(0.86, 0.76, 0.66)   # luz da lareira
	Sound.update_scene(mine != null, Game.is_night(), Game.weather, house != null or shop != null)
	# luzes: acendem das 17h30 às 20h; dentro de casa e na mina ficam sempre um pouco acesas
	var nf := clampf((m - 17.5 * 60) / 150.0, 0.0, 1.0) if m >= 12 * 60 else (1.0 if m < Game.DAY_START + 30 else 0.0)
	if Game.weather_data().light.v < 0.85:      # chuva forte, tempestade, neblina
		nf = maxf(nf, 0.4)
	FarmWorld.set_night(get_tree(), nf)
	var tw := create_tween()
	tw.tween_property(daylight, "color", c, 1.0)


func _build_rain() -> void:
	weather_fx = WeatherFX.new()
	add_child(weather_fx)


func _update_weather() -> void:
	weather_fx.set_weather(Game.weather)
	weather_fx.visible = mine == null and house == null and shop == null    # não chove dentro da mina, de casa nem das lojas
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
