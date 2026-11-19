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
var water := WATER_CAPACITY
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
	water = WATER_CAPACITY
	inventory.clear()
	inventory.resize(INV_SIZE)
	selected_slot = 0
	equipped_bait = ""
	for pair in [["watering_can", 1], ["hoe", 1], ["axe", 1], ["pickaxe", 1], ["scythe", 1],
			["seed_kale", 10], ["fishing_rod", 1], ["bait_worm", 10], ["seed_carrot", 6]]:
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
	health = max_health
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	weather = "rain" if rng.randf() < 0.25 else "sunny"
	weather_changed.emit(weather)
	time_changed.emit(day, minutes)
	stats_changed.emit()


# ------------------------------------------------------------------ status
func add_money(amount: int) -> void:
	money = max(0, money + amount)
	money_changed.emit(money)


func use_energy(amount: float) -> bool:
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
func add_item(id: String, qty: int = 1) -> int:
	if ItemDB.is_stackable(id):
		for s in inventory:
			if s != null and s["id"] == id and s["qty"] < ItemDB.MAX_STACK:
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
		inventory[idx] = {"id": id, "qty": add}
		qty -= add
	inventory_changed.emit()
	if qty > 0:
		toast.emit("Mochila cheia!")
	return qty


func count_item(id: String) -> int:
	var total := 0
	for s in inventory:
		if s != null and s["id"] == id:
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


func remove_item(id: String, qty: int = 1) -> bool:
	if count_item(id) < qty:
		return false
	for i in range(INV_SIZE - 1, -1, -1):
		var s = inventory[i]
		if s != null and s["id"] == id:
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
		"bait": equipped_bait,
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
	water = int(data.get("water", WATER_CAPACITY))
	equipped_bait = str(data.get("bait", ""))
	selected_slot = int(data.get("selected_slot", 0))
	var inv: Array = data.get("inventory", [])
	inventory.clear()
	inventory.resize(INV_SIZE)
	for i in min(inv.size(), INV_SIZE):
		var s = inv[i]
		if s is Dictionary and ItemDB.has(str(s.get("id", ""))):
			inventory[i] = {"id": str(s["id"]), "qty": int(s.get("qty", 1))}
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
		"backpack": [KEY_I, KEY_TAB],
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
