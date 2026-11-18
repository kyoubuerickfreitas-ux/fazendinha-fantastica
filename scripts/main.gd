extends Node2D
## Cena principal: monta o mundo, o jogador, a câmera e a interface,
## e cuida do ciclo de dia/noite, chuva, sono e salvamento.

var world: FarmWorld
var player: Player
var hud: HUD
var camera: Camera2D
var daylight: CanvasModulate
var rain: CPUParticles2D


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

	hud = HUD.new()
	hud.player = player
	add_child(hud)

	hud.use_pressed.connect(player.use_tool)
	hud.interact_pressed.connect(player.interact)
	world.house_door_used.connect(func(): hud.ask("Dormir até amanhã?\n(o jogo é salvo)", _sleep.bind(true)))
	world.shop_requested.connect(_on_shop)
	world.bin_used.connect(_sell_all)
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
	if event.is_action_pressed("use_tool"):
		player.use_tool()
	elif event.is_action_pressed("interact"):
		player.interact()


# ------------------------------------------------------------------ ações do mundo
func _on_shop() -> void:
	Game.toast.emit("Fungo: Sementes fresquinhas! Vendo e compro de tudo.")
	hud.open_shop()


func _sell_all() -> void:
	var total := 0
	var count := 0
	for i in Game.INV_SIZE:
		var s = Game.inventory[i]
		if s != null and ItemDB.get_item(s["id"]).get("type", "") in ["crop", "product"]:
			total += ItemDB.sell_price(s["id"]) * int(s["qty"])
			count += int(s["qty"])
			Game.inventory[i] = null
	if count == 0:
		Game.toast.emit("Coloque colheitas e produtos aqui para vender.")
		return
	Game.inventory_changed.emit()
	Game.add_money(total)
	Game.toast.emit("Vendeu %d itens por %d moedas!" % [count, total])


func _sleep(rested: bool) -> void:
	hud.fade_through(func():
		Game.start_new_day(rested)
		world.on_new_day()
		player.position = world.player_start
		camera.reset_smoothing()
		save_now()
		Game.toast.emit("Dia %d — %s" % [Game.day, "Está chovendo!" if Game.weather == "rain" else "Bom dia!"]))


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
	if Game.weather == "rain":
		c = c * Color(0.82, 0.86, 0.92)
	var tw := create_tween()
	tw.tween_property(daylight, "color", c, 1.0)


func _build_rain() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	rain = CPUParticles2D.new()
	rain.amount = 160
	rain.lifetime = 0.9
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(420, 10)
	rain.position = Vector2(340, -20)
	rain.direction = Vector2(-0.25, 1)
	rain.spread = 2
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 380
	rain.initial_velocity_max = 460
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 2.0
	rain.color = Color(0.75, 0.85, 0.95, 0.55)
	rain.preprocess = 1.0
	layer.add_child(rain)


func _update_weather() -> void:
	rain.emitting = Game.weather == "rain"
	rain.visible = rain.emitting
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
