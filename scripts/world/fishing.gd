class_name Fishing
extends Node2D
## Pesca: lançar a linha na água, esperar a fisgada, fisgar no tempo certo
## e puxar o peixe tocando no botão de usar.
##
## Fluxo: IDLE -> WAITING (boia na água) -> BITE (!) -> REELING (barra de puxar) -> IDLE
## A isca equipada (Game.equipped_bait) é gasta a cada lançamento e muda
## a rapidez da fisgada e a chance de cada raridade (ItemDB.BAITS).

enum State { IDLE, WAITING, BITE, REELING }

signal caught(fish_id: String, measures: Dictionary)

const ENERGY_COST := 2.0
## por raridade (comum, incomum, raro, muito raro, épico, lendário, secreto)
const BITE_WINDOW := [1.3, 1.1, 0.9, 0.85, 0.8, 0.75, 0.75]   # tempo para fisgar
const PULL := [10.0, 15.0, 22.0, 26.0, 30.0, 36.0, 36.0]      # força do peixe (barra/segundo)
const TAP := 9.0                                # quanto cada toque puxa
const REEL_TIME := 12.0

var state := State.IDLE
var player: Player
var world: FarmWorld

var _bobber_pos := Vector2.ZERO
var _timer := 0.0
var _bait := ""
var _fish := ""
var _water := "lake"
var _depth := "shallow"
## último resultado (para testes e a interface): {"id", "size", "weight", "q", "new", "record"}
var last_catch := {}
var _progress := 0.0
var _t := 0.0

var _layer: CanvasLayer
var _panel: PanelContainer
var _bar: ProgressBar
var _label: Label


func _ready() -> void:
	z_index = 30
	_build_ui()


func is_active() -> bool:
	return state != State.IDLE


func blocks_movement() -> bool:
	return state == State.REELING


# ------------------------------------------------------------------ ações
## Botão de usar com a vara na mão.
func on_use(cell: Vector2i) -> String:
	match state:
		State.IDLE:
			return _cast(cell)
		State.WAITING:
			cancel("Cedo demais... o peixe fugiu.")
		State.BITE:
			_hook()
		State.REELING:
			_progress += TAP
			_bar.value = _progress
			if _progress >= 100.0:
				_catch()
	return ""


func cancel(msg: String = "") -> void:
	if state == State.IDLE:
		return
	state = State.IDLE
	_panel.visible = false
	queue_redraw()
	if msg != "":
		Game.toast.emit(msg)


func _cast(cell: Vector2i) -> String:
	if world.ground_at(cell) != FarmWorld.Ground.WATER:
		return "Lance a linha na água."
	if not Game.use_energy(ENERGY_COST):
		return ""
	_bait = Game.consume_bait()
	_water = world.water_kind(cell)
	_depth = world.water_depth(cell)
	_bobber_pos = world.target_anchor(cell) + Vector2(randf_range(-6, 6), randf_range(-4, 4))
	var speed: float = ItemDB.BAITS[_bait]["speed"]
	var wait := randf_range(2.5, 8.0) / speed
	if Game.is_wet():
		wait *= 0.8
	_timer = wait
	state = State.WAITING
	FX.spawn(world, "water", _bobber_pos)
	queue_redraw()
	return "Linha lançada%s." % ("" if _bait == "" else " com " + ItemDB.item_name(_bait))


func _hook() -> void:
	state = State.REELING
	_progress = 35.0
	_timer = REEL_TIME
	_bar.value = _progress
	_label.text = "Puxe! Toque no botão rápido"
	_panel.visible = true


func _catch() -> void:
	state = State.IDLE
	_panel.visible = false
	queue_redraw()
	var f := FishDB.get_fish(_fish)
	var m := FishDB.measure(f)
	if Game.add_item(_fish, 1, m["q"]) > 0:
		return
	var reg := FishDB.register_catch(_fish, m)
	last_catch = {"id": _fish, "size": m["size"], "weight": m["weight"], "q": m["q"], "new": reg["new"], "record": reg["record"]}
	FX.spawn(world, "harvest", _bobber_pos)
	var text := "Pescou %s! %.1f cm · %s" % [f.name, m["size"], f.rarity_name()]
	if reg["new"]:
		text = "NOVA ESPÉCIE! " + text + " (registrada no Livro de Pesca)"
	elif reg["record"]:
		text += " · novo recorde!"
	if reg["level_up"] > 0:
		text += "\nNível de pesca %d!" % reg["level_up"]
	Game.toast.emit(text)
	caught.emit(_fish, m)


## Contexto do lance atual (lugar + momento).
func context() -> Dictionary:
	return FishDB.context(_water, _depth, _bait)


# ------------------------------------------------------------------ atualização
func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	_t += delta
	match state:
		State.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_fish = FishDB.roll(context())
				state = State.BITE
				var lvl := FishDB.level()
				_timer = BITE_WINDOW[FishDB.get_fish(_fish).rarity] * (1.0 + 0.04 * (lvl - 1))
				FX.spawn(world, "water", _bobber_pos)
		State.BITE:
			_timer -= delta
			if _timer <= 0.0:
				cancel("O peixe levou a isca...")
		State.REELING:
			var fd := FishDB.get_fish(_fish)
			var pull: float = PULL[fd.rarity] if fd.difficulty <= 0.0 else lerpf(10.0, 40.0, fd.difficulty)
			pull *= 1.0 - 0.035 * (FishDB.level() - 1)     # o nível deixa mais fácil puxar
			_progress -= pull * delta
			_timer -= delta
			_bar.value = _progress
			if _progress <= 0.0 or _timer <= 0.0:
				cancel("O peixe escapou!")
	queue_redraw()


func _draw() -> void:
	if state == State.IDLE or player == null:
		return
	var tip := player.position + player.facing_vector() * 12 + Vector2(0, -30)
	if player._holding_rod and player.facing_vector() == Vector2.DOWN:
		tip = player.position + Vector2(18, -10)   # ponta da vara na pose de segurar (de frente)
	var bob := _bobber_pos
	var dip := 0.0
	if state == State.WAITING:
		dip = sin(_t * 3.0) * 1.0
	elif state == State.BITE:
		dip = 3.0 + sin(_t * 30.0) * 1.5
	elif state == State.REELING:
		dip = 2.0 + sin(_t * 18.0) * 2.0
		bob = bob.lerp(player.position, clampf(_progress / 100.0, 0.0, 1.0) * 0.5)
	bob.y += dip
	# linha com uma barriguinha
	var mid := (tip + bob) / 2.0 + Vector2(0, 8)
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(tip.lerp(mid, t).lerp(mid.lerp(bob, t), t))
	draw_polyline(pts, Color(0.95, 0.92, 0.82, 0.85), 1.0)
	# boia
	draw_circle(bob, 3.5, Color("2b2118"))
	draw_circle(bob, 2.6, Color("e9ddbb"))
	draw_rect(Rect2(bob.x - 2.6, bob.y - 2.6, 5.2, 2.6), Color("c8382e"))
	if state == State.BITE:
		var font := ThemeDB.fallback_font
		draw_string_outline(font, bob + Vector2(-3, -10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("2b2118"))
		draw_string(font, bob + Vector2(-3, -10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2d16b"))


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -110
	_panel.offset_right = 110
	_panel.offset_top = -110
	_panel.offset_bottom = -64
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_layer.add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	_label = UIStyle.label("", 12, UIStyle.WOOD_DARK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(200, 12)
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(Color("4c88a3")))
	var bg := UIStyle.panel(Color("3a2a1d"), UIStyle.WOOD_DARK, 1, 3)
	bg.set_content_margin_all(0)
	bg.shadow_size = 0
	_bar.add_theme_stylebox_override("background", bg)
	v.add_child(_bar)
