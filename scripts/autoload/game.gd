extends Node
## Estado global do jogo (autoload "Game"): dinheiro, energia, tempo, clima,
## inventário e salvamento.

signal money_changed(value: int)
signal stats_changed
signal time_changed(day: int, minutes: int)
signal weather_changed(weather: String)
signal inventory_changed
signal selected_slot_changed(index: int)
signal toast(text: String)
signal pass_out
signal season_changed(season_id: String)
signal look_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

const INV_SIZE := 24
const HOTBAR_SIZE := 6

const DAY_START := 6 * 60          # 06:00
const DAY_END := 26 * 60           # 02:00 do dia seguinte: desmaia de sono
const SECONDS_PER_GAME_MINUTE := 0.7
const WATER_CAPACITY := 20

var money := 500
var energy := 100.0
var max_energy := 100.0
var health := 100.0
var max_health := 100.0
var day := 1
var minutes := DAY_START
var weather := "sunny"
## temperatura de hoje (°C) e de ontem (o crescimento da noite usa a de ontem)
var temperature := 16.0
var temperature_yesterday := 16.0
## previsão dos próximos dias: [{"weather", "temp"}]
var forecast: Array = []
var water := WATER_CAPACITY
var tool_levels := {"watering_can": 1, "hoe": 1, "fishing_rod": 1, "pickaxe": 1}
## Pesca: registro do Livro ({id: {n, first, max_size, max_weight}}), XP, tesouros e marcadores
var fish_log := {}
var fishing_xp := 0
var treasure_log := {}
var fish_flags := {}
## Cozinha: receitas que já sabe, bônus ativos ({tipo: minuto absoluto do fim}) e pratos feitos
var known_recipes: Array = []
var buffs := {}
var dishes_cooked := 0
## Amizade com os moradores (ver Villagers)
var friends := {}
## Contadores de ações (tutorial e metas): {"talks": 3, "harvests": 10, ...}
var counters := {}
## Mina: andar mais fundo já alcançado (o elevador para a cada 5)
var mine_deepest := 0
## Tutorial: {"step": índice, "base": valor no começo do passo, "done": bool}
var tutorial := {"step": 0, "base": 0, "done": false}
## Correr: fôlego próprio (não gasta energia). Enche sozinho quando você para de correr.
const MAX_STAMINA := 100.0
var stamina := MAX_STAMINA
var exhausted := false      # zerou: só volta a correr depois de recuperar um pouco
var run_held := false       # botão de correr (ou Shift) apertado
## Trator: comprado no Fungo; fica estacionado onde você desceu (x, y na fazenda).
var tractor := {"owned": false, "x": 0.0, "y": 0.0}
## Caçamba: engatada atrás do trator; items = carga (lista de espaços como a mochila).
var trailer := {"owned": false, "items": []}
## TESTES: trator e caçamba já vêm no jogo novo (e saves antigos ganham). Depois eles serão vendidos
## numa loja da cidade (HUD.buy_tractor / buy_trailer já existem); aí é só pôr false.
const START_WITH_VEHICLES := true
## Casa: baú (24 espaços) e objetos colocados dentro (aquários...).
var house := {"chest": [], "placeables": [], "layout": {}}
## Jogador: nome, nome da fazenda e aparência (criação de personagem). created = já passou pela tela.
var profile := {"name": "", "farm": "", "look": {}, "created": false}
## Isca colocada na vara de pesca ("" = sem isca)
var equipped_bait := ""

## Cada posição: null ou {"id": String, "qty": int}
var inventory: Array = []
var selected_slot := 0

## Vetor do joystick virtual (-1..1). Usado pelo jogador.
var joystick_vector := Vector2.ZERO
## Quantos painéis estão abertos. Quando > 0, o jogador não se move e o tempo para.
var ui_lock := 0

var _time_acc := 0.0
var _passed_out := false


func _ready() -> void:
	_setup_input_map()
	reset_new_game()


func reset_new_game() -> void:
	money = 500
	energy = max_energy
	health = max_health
	day = 1
	minutes = DAY_START
	weather = "sunny"
	temperature = 16.0
	temperature_yesterday = 16.0
	forecast.clear()
	_fill_forecast()
	water = WATER_CAPACITY
	inventory.clear()
	inventory.resize(INV_SIZE)
	selected_slot = 0
	equipped_bait = ""
	tool_levels = {"watering_can": 1, "hoe": 1, "fishing_rod": 1, "pickaxe": 1}
	fish_log = {}
	fishing_xp = 0
	treasure_log = {}
	fish_flags = {}
	known_recipes = Cooking.starting_recipes()
	buffs = {}
	dishes_cooked = 0
	friends = {}
	counters = {}
	mine_deepest = 0
	tutorial = {"step": 0, "base": -1, "done": false}
	profile = {"name": "", "farm": "", "look": PlayerLook.default_look(), "created": false}
	tractor = {"owned": false, "x": 0.0, "y": 0.0}
	trailer = {"owned": false, "items": []}
	house = {"chest": [], "placeables": [], "layout": {}}
	if START_WITH_VEHICLES:
		tractor["owned"] = true
		trailer["owned"] = true
	for pair in [["watering_can", 1], ["hoe", 1], ["axe", 1], ["pickaxe", 1], ["scythe", 1],
			["seed_kale", 10], ["fishing_rod", 1], ["bait_worm", 10], ["seed_carrot", 6], ["shears", 1], ["brush", 1]]:
		add_item(pair[0], pair[1])


# ------------------------------------------------------------------ tempo
func _process(delta: float) -> void:
	if ui_lock > 0 or _passed_out:
		return
	_time_acc += delta
	while _time_acc >= SECONDS_PER_GAME_MINUTE:
		_time_acc -= SECONDS_PER_GAME_MINUTE
		minutes += 1
		if minutes % 10 == 0:
			time_changed.emit(day, minutes)
		if minutes >= DAY_END:
			_passed_out = true
			pass_out.emit()
			return


func player_name() -> String:
	var n: String = str(profile.get("name", "")).strip_edges()
	return n if n != "" else "Fazendeiro"


func farm_name() -> String:
	var n: String = str(profile.get("farm", "")).strip_edges()
	return n if n != "" else "Fazendinha"


func look() -> Dictionary:
	var l = profile.get("look", {})
	return l if l is Dictionary and not l.is_empty() else PlayerLook.default_look()


func is_night() -> bool:
	return minutes >= 19 * 60 or minutes < DAY_START


func clock_text() -> String:
	var m := minutes % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## Começa um novo dia (chamado ao dormir). Retorna true se choveu.
func start_new_day(rested: bool) -> void:
	day += 1
	minutes = DAY_START
	_time_acc = 0.0
	_passed_out = false
	energy = max_energy if rested else max_energy * 0.5
	buffs = {}                              # bônus de comida duram só até dormir
	health = max_health
	temperature_yesterday = temperature
	_fill_forecast()
	var today: Dictionary = forecast.pop_front()
	weather = today["weather"]
	temperature = today["temp"]
	_fill_forecast()
	if Calendar.day_of_season(day) == 1:
		season_changed.emit(Calendar.season_id(day))
	weather_changed.emit(weather)
	time_changed.emit(day, minutes)
	stats_changed.emit()


# ------------------------------------------------------------------ clima e previsão
## Mantém a previsão com 3 dias à frente. O clima de cada dia depende da estação
## daquele dia e um pouco do dia anterior (chuva tende a durar).
func _fill_forecast() -> void:
	while forecast.size() < 4:
		var d := day + 1 + forecast.size()
		var s := CropDB.season(Calendar.season_id(d))
		var prev: String = forecast.back()["weather"] if not forecast.is_empty() else weather
		var w := ""
		# o clima tende a continuar (se for permitido nesta estação)
		if s.weather_weights.has(prev) and prev != "sunny" and randf() < 0.3:
			w = prev
		else:
			var total := 0.0
			for k in s.weather_weights:
				total += float(s.weather_weights[k])
			var x := randf() * total
			for k in s.weather_weights:
				x -= float(s.weather_weights[k])
				if x <= 0.0:
					w = k
					break
		if w == "" or CropDB.weather(w) == null:
			w = "sunny"
		var t := randf_range(s.temp_min, s.temp_max) + CropDB.weather(w).temp_offset
		forecast.append({"weather": w, "temp": snappedf(t, 1.0)})


func weather_data() -> WeatherData:
	return CropDB.weather(weather)


## Chuva de qualquer tipo (rega, peixes de chuva...)
func is_wet() -> bool:
	return weather_data().wet


func tool_level(id: String) -> int:
	return int(tool_levels.get(id, 1))


func water_capacity() -> int:
	return WATER_CAPACITY * tool_level("watering_can")


func season_id() -> String:
	return Calendar.season_id(day)


# ------------------------------------------------------------------ status
func bump(key: String, n: int = 1) -> void:
	counters[key] = int(counters.get(key, 0)) + n


func counter(key: String) -> int:
	return int(counters.get(key, 0))


func add_money(amount: int) -> void:
	money = max(0, money + amount)
	money_changed.emit(money)
	if amount != 0:
		Sound.play("coin" if amount > 0 else "buy", -3.0, 1.0, 0.0)


func use_energy(amount: float) -> bool:
	amount *= Cooking.energy_mult()        # bônus de comida (Fôlego)
	if energy < amount:
		toast.emit("Você está exausto... vá dormir.")
		return false
	energy -= amount
	stats_changed.emit()
	return true


# ------------------------------------------------------------------ inventário
func select_slot(i: int) -> void:
	selected_slot = clampi(i, 0, HOTBAR_SIZE - 1)
	selected_slot_changed.emit(selected_slot)


func selected_item_id() -> String:
	var s = inventory[selected_slot]
	return s["id"] if s != null else ""


## Adiciona itens. Retorna quantos NÃO couberam.
## q = qualidade (0 comum, 1 prata, 2 ouro, 3 lendário); só empilha com a mesma qualidade.
func add_item(id: String, qty: int = 1, q: int = 0) -> int:
	if ItemDB.is_stackable(id):
		for s in inventory:
			if s != null and s["id"] == id and int(s.get("q", 0)) == q and s["qty"] < ItemDB.MAX_STACK:
				var add: int = min(qty, ItemDB.MAX_STACK - s["qty"])
				s["qty"] += add
				qty -= add
				if qty <= 0:
					break
	while qty > 0:
		var idx := inventory.find(null)
		if idx == -1:
			break
		var add: int = min(qty, ItemDB.MAX_STACK) if ItemDB.is_stackable(id) else 1
		inventory[idx] = {"id": id, "qty": add} if q == 0 else {"id": id, "qty": add, "q": q}
		qty -= add
	inventory_changed.emit()
	if qty > 0:
		toast.emit("Mochila cheia!")
	return qty


## q = -1: qualquer qualidade
func count_item(id: String, q: int = -1) -> int:
	var total := 0
	for s in inventory:
		if s != null and s["id"] == id and (q < 0 or int(s.get("q", 0)) == q):
			total += s["qty"]
	return total


func remove_from_slot(i: int, qty: int = 1) -> void:
	var s = inventory[i]
	if s == null:
		return
	s["qty"] -= qty
	if s["qty"] <= 0:
		inventory[i] = null
	inventory_changed.emit()


func remove_item(id: String, qty: int = 1, q: int = -1) -> bool:
	if count_item(id, q) < qty:
		return false
	for i in range(INV_SIZE - 1, -1, -1):
		var s = inventory[i]
		if s != null and s["id"] == id and (q < 0 or int(s.get("q", 0)) == q):
			var take: int = min(qty, s["qty"])
			s["qty"] -= take
			qty -= take
			if s["qty"] <= 0:
				inventory[i] = null
			if qty <= 0:
				break
	inventory_changed.emit()
	return true


func swap_slots(a: int, b: int) -> void:
	var tmp = inventory[a]
	inventory[a] = inventory[b]
	inventory[b] = tmp
	inventory_changed.emit()


# ------------------------------------------------------------------ iscas
func equip_bait(id: String) -> void:
	equipped_bait = id
	inventory_changed.emit()


## Gasta 1 da isca equipada. Retorna a isca usada ("" se não havia).
func consume_bait() -> String:
	var b := equipped_bait
	if b == "":
		return ""
	if not remove_item(b, 1):
		equipped_bait = ""
		return ""
	if count_item(b) == 0:
		equipped_bait = ""
		toast.emit("Acabaram as iscas: %s." % ItemDB.item_name(b))
	return b


# ------------------------------------------------------------------ salvar / carregar
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(world_data: Dictionary) -> void:
	var data := {
		"version": SAVE_VERSION,
		"money": money, "energy": energy, "health": health,
		"day": day, "minutes": minutes, "weather": weather, "water": water,
		"temperature": temperature, "temperature_yesterday": temperature_yesterday, "forecast": forecast,
		"bait": equipped_bait, "tools": tool_levels,
		"fish_log": fish_log, "fishing_xp": fishing_xp, "treasure_log": treasure_log, "fish_flags": fish_flags,
		"recipes": known_recipes, "buffs": buffs, "dishes_cooked": dishes_cooked,
		"friends": friends, "counters": counters, "tutorial": tutorial, "mine_deepest": mine_deepest,
		"profile": profile, "tractor": tractor, "trailer": trailer, "house": house,
		"inventory": inventory, "selected_slot": selected_slot,
		"world": world_data,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## Carrega o estado global e devolve os dados do mundo (ou {} se não houver save).
func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	money = int(data.get("money", money))
	energy = float(data.get("energy", energy))
	health = float(data.get("health", health))
	day = int(data.get("day", day))
	minutes = int(data.get("minutes", DAY_START))
	weather = str(data.get("weather", "sunny"))
	temperature = float(data.get("temperature", 16.0))
	temperature_yesterday = float(data.get("temperature_yesterday", temperature))
	var fc = data.get("forecast", [])
	forecast = fc if fc is Array else []
	_fill_forecast()
	water = int(data.get("water", WATER_CAPACITY))
	equipped_bait = str(data.get("bait", ""))
	var fl = data.get("fish_log", {})
	fish_log = fl if fl is Dictionary else {}
	fishing_xp = int(data.get("fishing_xp", 0))
	var tlog = data.get("treasure_log", {})
	treasure_log = tlog if tlog is Dictionary else {}
	var ff = data.get("fish_flags", {})
	fish_flags = ff if ff is Dictionary else {}
	var kr = data.get("recipes", null)
	known_recipes = kr if kr is Array else Cooking.starting_recipes()
	var bf = data.get("buffs", {})
	buffs = bf if bf is Dictionary else {}
	dishes_cooked = int(data.get("dishes_cooked", 0))
	var fr = data.get("friends", {})
	friends = fr if fr is Dictionary else {}
	mine_deepest = int(data.get("mine_deepest", 0))
	var ct = data.get("counters", {})
	counters = ct if ct is Dictionary else {}
	var tu = data.get("tutorial", null)
	# saves de antes do tutorial: quem já joga não precisa dele
	tutorial = tu if tu is Dictionary else {"step": 0, "base": -1, "done": true}
	var pr = data.get("profile", null)
	# saves de antes da criação de personagem: nome e visual padrão (dá para mudar nas Opções)
	if pr is Dictionary:
		profile = {"name": str(pr.get("name", "")), "farm": str(pr.get("farm", "")),
			"look": PlayerLook.sanitize(pr.get("look", {})), "created": bool(pr.get("created", true))}
	else:
		profile = {"name": "", "farm": "", "look": PlayerLook.default_look(), "created": true}
	var tr = data.get("tractor", {})
	tractor = {"owned": bool(tr.get("owned", false)), "x": float(tr.get("x", 0.0)), "y": float(tr.get("y", 0.0))} \
		if tr is Dictionary else {"owned": false, "x": 0.0, "y": 0.0}
	var tl_ = data.get("trailer", {})
	trailer = {"owned": false, "items": []}
	if tl_ is Dictionary:
		trailer["owned"] = bool(tl_.get("owned", false))
		var its: Array = []
		for s in tl_.get("items", []):
			its.append({"id": str(s["id"]), "qty": int(s.get("qty", 1)), "q": int(s.get("q", 0))} \
				if s is Dictionary and ItemDB.has(str(s.get("id", ""))) else null)
		for s in its:
			if s != null and int(s["q"]) == 0:
				s.erase("q")
		trailer["items"] = its
	if START_WITH_VEHICLES:
		tractor["owned"] = true
		trailer["owned"] = true
	var hs = data.get("house", {})
	house = {"chest": [], "placeables": [], "layout": {}}
	if hs is Dictionary:
		var lay = hs.get("layout", {})
		house["layout"] = lay if lay is Dictionary else {}
		for s in hs.get("chest", []):
			if s is Dictionary and ItemDB.has(str(s.get("id", ""))):
				var it := {"id": str(s["id"]), "qty": int(s.get("qty", 1))}
				if int(s.get("q", 0)) > 0:
					it["q"] = int(s["q"])
				house["chest"].append(it)
			else:
				house["chest"].append(null)
		var pls = hs.get("placeables", [])
		house["placeables"] = pls if pls is Array else []
	var tl = data.get("tools", {})
	tool_levels = {"watering_can": 1, "hoe": 1, "fishing_rod": 1, "pickaxe": 1}
	if tl is Dictionary:
		for k in tool_levels:
			tool_levels[k] = int(tl.get(k, 1))
	selected_slot = int(data.get("selected_slot", 0))
	var inv: Array = data.get("inventory", [])
	inventory.clear()
	inventory.resize(INV_SIZE)
	for i in min(inv.size(), INV_SIZE):
		var s = inv[i]
		if s is Dictionary and ItemDB.has(str(s.get("id", ""))):
			inventory[i] = {"id": str(s["id"]), "qty": int(s.get("qty", 1))}
			if int(s.get("q", 0)) > 0:
				inventory[i]["q"] = int(s["q"])
	# saves de antes dos animais F1 ganham a tesoura de tosquia
	if count_item("shears") == 0:
		add_item("shears", 1)
	if count_item("brush") == 0:
		add_item("brush", 1)
	# saves de antes da pesca ganham a vara e algumas minhocas
	if count_item("fishing_rod") == 0:
		add_item("fishing_rod", 1)
		add_item("bait_worm", 10)
	return data.get("world", {})


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ------------------------------------------------------------------ controles de teclado (para testar no PC)
func _setup_input_map() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"use_tool": [KEY_SPACE, KEY_J], "interact": [KEY_E, KEY_K],
		"backpack": [KEY_I, KEY_TAB], "run": [KEY_SHIFT],
		"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3],
		"slot_4": [KEY_4], "slot_5": [KEY_5], "slot_6": [KEY_6],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
