class_name HUD
extends CanvasLayer
## Interface do jogo: status no topo, barra rápida e botões embaixo,
## joystick à esquerda e os painéis (mochila, loja, confirmação).

signal use_pressed
signal interact_pressed
signal sleep_confirmed
signal quit_confirmed

const PLAYER_SHEET := preload("res://assets/sprites/player.png")

var player: Player
var world: FarmWorld

var _root: Control
var _health_bar: ProgressBar
var _energy_bar: ProgressBar
var _money_label: Label
var _time_label: Label
var _time_icon: TextureRect
var _weather_icon: TextureRect
var _hotbar: Array[ItemSlot] = []
var _use_btn: TouchButton
var _hand_btn: TouchButton
var _context_label: Label
var _toast: Label
var _toast_tween: Tween
var _fade: ColorRect

var _open_panel: Control = null
## Áreas da HUD em que um toque não deve atingir o mundo.
var _blockers: Array[Control] = []
var _backpack: Control
var _bp_slots: Array[ItemSlot] = []
var _bp_marked := -1
var _bp_desc: Label
var _shop: Control
var _shop_buy: VBoxContainer
var _shop_sell: VBoxContainer
var _shop_money: Label
var _bag_btn: TouchButton
var _book_btn: TouchButton
var _book: Control
var _book_body: VBoxContainer
var _book_filter := "all"
var _cook: Control
var _cook_body: VBoxContainer
var _buff_label: Label
var _tut_panel: PanelContainer
var _tut_title: Label
var _tut_label: Label
signal tutorial_skip_pressed
var _npc_win: Control
var _npc_body: VBoxContainer
var _top_right: Control
var _calendar: Control
var _cal_body: VBoxContainer
var _craft: Control
var _craft_list: VBoxContainer
var _shop_animals: VBoxContainer
var _animal_card: Control
var _card_body: VBoxContainer
var _card_record: AnimalRecord
var _name_dialog: Control
var _name_edit: LineEdit
var _name_record: AnimalRecord
var _confirm: Control
var _confirm_label: Label
var _confirm_action := Callable()


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.make_theme()
	add_child(_root)

	_build_joystick()
	_build_top_left()
	_build_top_right()
	_build_hotbar()
	_build_buttons()
	_build_toast()
	_build_backpack()
	_build_shop()
	_build_crafting()
	_build_calendar()
	_build_fish_book()
	_build_cooking()
	_build_npc_dialog()
	_build_animal_card()
	_build_name_dialog()
	_build_confirm()
	_build_fade()

	Game.money_changed.connect(func(_v): _refresh_stats())
	Game.stats_changed.connect(_refresh_stats)
	Game.time_changed.connect(func(_d, _m):
		_refresh_time()
		_refresh_buffs())
	Game.weather_changed.connect(func(_w): _refresh_time())
	Game.inventory_changed.connect(_on_inventory_changed)
	Game.selected_slot_changed.connect(func(_i): _refresh_hotbar())
	Game.toast.connect(show_toast)
	_refresh_stats()
	_refresh_time()
	_refresh_hotbar()


# ================================================================= construção
func _build_joystick() -> void:
	var joy := VirtualJoystick.new()
	joy.anchor_top = 0.0
	joy.anchor_bottom = 1.0
	joy.anchor_left = 0.0
	joy.anchor_right = 0.32
	joy.offset_top = 70
	_root.add_child(joy)


func _build_top_left() -> void:
	var box := HBoxContainer.new()
	box.position = Vector2(8, 8)
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_blockers.append(box)

	var portrait := PanelContainer.new()
	portrait.add_theme_stylebox_override("panel", UIStyle.wood_panel())
	var inner := PanelContainer.new()
	var inner_style := UIStyle.panel(Color("526a23"), UIStyle.WOOD_DARK, 1, 4)
	inner_style.set_content_margin_all(0)
	inner_style.shadow_size = 0
	inner.add_theme_stylebox_override("panel", inner_style)
	var face := TextureRect.new()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # nunca distorcer o ícone
	var at := AtlasTexture.new()
	at.atlas = PLAYER_SHEET
	at.region = Rect2(18, 9, 28, 28)
	face.texture = at
	face.custom_minimum_size = Vector2(36, 36)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inner.add_child(face)
	portrait.add_child(inner)
	box.add_child(portrait)

	var bars := PanelContainer.new()
	bars.add_theme_stylebox_override("panel", UIStyle.wood_panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_child(v)
	_health_bar = _make_bar(v, "heart", Color("c8503c"))
	_energy_bar = _make_bar(v, "bolt", Color("78945b"))
	box.add_child(bars)
	# bônus de comida ativos (some quando não há nenhum)
	_buff_label = UIStyle.label("", 9, UIStyle.CREAM)
	_buff_label.position = Vector2(10, 60)
	_buff_label.add_theme_color_override("font_outline_color", UIStyle.WOOD_DARK)
	_buff_label.add_theme_constant_override("outline_size", 4)
	_root.add_child(_buff_label)
	_build_tutorial_panel()


func _make_bar(parent: Control, icon_name: String, color: Color) -> ProgressBar:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # nunca distorcer o ícone
	ic.texture = ItemDB.ui_icon(icon_name)
	ic.custom_minimum_size = Vector2(16, 16)
	h.add_child(ic)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(84, 11)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(color))
	h.add_child(bar)
	parent.add_child(h)
	return bar


func _build_top_right() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.wood_panel())
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_right = -8
	panel.offset_top = 8
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	_blockers.append(panel)
	_top_right = panel
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	panel.add_child(h)

	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # nunca distorcer o ícone
	coin.texture = ItemDB.ui_icon("coin")
	coin.custom_minimum_size = Vector2(16, 16)
	h.add_child(coin)
	_money_label = UIStyle.outlined_label("0", 13)
	_money_label.custom_minimum_size.x = 44
	h.add_child(_money_label)
	h.add_child(_vsep())
	_time_icon = TextureRect.new()
	_time_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_time_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # nunca distorcer o ícone
	_time_icon.custom_minimum_size = Vector2(16, 16)
	h.add_child(_time_icon)
	_time_label = UIStyle.outlined_label("", 13)
	h.add_child(_time_label)
	h.add_child(_vsep())
	_weather_icon = TextureRect.new()
	_weather_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weather_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # nunca distorcer o ícone
	_weather_icon.custom_minimum_size = Vector2(16, 16)
	h.add_child(_weather_icon)


func _vsep() -> Control:
	var c := ColorRect.new()
	c.color = UIStyle.WOOD_DARK
	c.custom_minimum_size = Vector2(2, 14)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _build_hotbar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.wood_panel())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_bottom = -6
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	_blockers.append(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	panel.add_child(h)
	for i in Game.HOTBAR_SIZE:
		var s := ItemSlot.new(i, 40)
		s.show_number = true
		s.tapped.connect(func(idx): Game.select_slot(idx))
		h.add_child(s)
		_hotbar.append(s)


func _build_buttons() -> void:
	var area := Control.new()
	area.anchor_left = 1.0
	area.anchor_right = 1.0
	area.anchor_top = 1.0
	area.anchor_bottom = 1.0
	area.offset_left = -170
	area.offset_top = -150
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(area)

	_use_btn = TouchButton.new()
	_use_btn.radius = 30
	_use_btn.position = Vector2(170 - 72, 150 - 70)
	_use_btn.pressed.connect(func(): use_pressed.emit())
	area.add_child(_use_btn)

	_hand_btn = TouchButton.new()
	_hand_btn.radius = 22
	_hand_btn.icon = ItemDB.ui_icon("hand")
	_hand_btn.position = Vector2(170 - 128, 150 - 52)
	_hand_btn.pressed.connect(func(): interact_pressed.emit())
	area.add_child(_hand_btn)

	var bag := TouchButton.new()
	bag.radius = 19
	bag.icon = ItemDB.ui_icon("backpack")
	bag.position = Vector2(170 - 62, 150 - 120)
	bag.pressed.connect(toggle_backpack)
	area.add_child(bag)
	_bag_btn = bag

	_book_btn = TouchButton.new()
	_book_btn.radius = 16
	_book_btn.icon = ItemDB.ui_icon("book")
	_book_btn.icon_scale = 1.6
	_book_btn.position = Vector2(170 - 108, 150 - 112)
	_book_btn.pressed.connect(open_fish_book)
	area.add_child(_book_btn)

	_context_label = UIStyle.outlined_label("", 11)
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.size = Vector2(130, 14)
	_context_label.position = Vector2(170 - 170, 150 - 70)
	area.add_child(_context_label)


func _build_toast() -> void:
	_toast = UIStyle.outlined_label("", 13)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -230
	_toast.offset_right = 230
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.offset_top = 62
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.04, 0.08, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_root.add_child(_fade)


func _make_window(title: String, min_size: Vector2) -> Array:
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.02, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	_root.add_child(shade)

	var outer := PanelContainer.new()
	outer.add_theme_stylebox_override("panel", UIStyle.wood_panel())
	outer.custom_minimum_size = min_size
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	outer.grow_vertical = Control.GROW_DIRECTION_BOTH
	shade.add_child(outer)
	var panel := PanelContainer.new()
	outer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)

	var header := HBoxContainer.new()
	var t := UIStyle.label(title, 15, UIStyle.WOOD_DARK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(28, 24)
	close.pressed.connect(close_panel)
	header.add_child(close)
	v.add_child(header)
	return [shade, v]


func _build_backpack() -> void:
	var w := _make_window("Mochila", Vector2(300, 0))
	_backpack = w[0]
	var v: VBoxContainer = w[1]
	var hint := UIStyle.label("Toque em dois espaços para trocar. A 1ª linha é a barra rápida.", 10, UIStyle.EARTH)
	v.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)
	for i in Game.INV_SIZE:
		var s := ItemSlot.new(i, 40)
		s.works_in_panel = true
		s.tapped.connect(_on_backpack_slot)
		grid.add_child(s)
		_bp_slots.append(s)
	_bp_desc = UIStyle.label("", 11, UIStyle.WOOD_DARK)
	_bp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bp_desc.custom_minimum_size = Vector2(280, 28)
	v.add_child(_bp_desc)


func _build_shop() -> void:
	var w := _make_window("Barraca do Fungo", Vector2(440, 0))
	_shop = w[0]
	var v: VBoxContainer = w[1]
	_shop_money = UIStyle.label("", 12, UIStyle.WOOD_DARK)
	v.add_child(_shop_money)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	v.add_child(cols)
	for which in ["buy", "sell"]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIStyle.label("Comprar" if which == "buy" else "Vender", 13, UIStyle.WOOD))
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 190)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		col.add_child(scroll)
		cols.add_child(col)
		if which == "buy":
			_shop_buy = list
			var animals_title := UIStyle.label("Animais", 13, UIStyle.WOOD)
			list.add_child(animals_title)
			_shop_animals = VBoxContainer.new()
			list.add_child(_shop_animals)
			list.add_child(UIStyle.label("Itens", 13, UIStyle.WOOD))
		else:
			_shop_sell = list


func _build_crafting() -> void:
	var w := _make_window("Bancada de Trabalho", Vector2(420, 0))
	_craft = w[0]
	var v: VBoxContainer = w[1]
	v.add_child(UIStyle.label("Junte madeira, pedra e fibra e fabrique. Objetos vão para a mochila: selecione e toque no chão para construir.", 10, UIStyle.EARTH))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_craft_list = VBoxContainer.new()
	_craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_craft_list)
	v.add_child(scroll)


# ================================================================= animais
func _build_animal_card() -> void:
	var w := _make_window("Animal", Vector2(360, 0))
	_animal_card = w[0]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_body = VBoxContainer.new()
	_card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_card_body)
	w[1].add_child(scroll)


## Abre o cartão de um animal (ou a lista, se `records` tiver mais de um).
func open_animal_card(r: AnimalRecord) -> void:
	_card_record = r
	_open(_animal_card)
	for c in _card_body.get_children():
		c.queue_free()
	var s := r.data()
	var top := HBoxContainer.new()
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # nunca distorcer o ícone
	var at := AtlasTexture.new()
	at.atlas = load(s.sprite_path())
	at.region = Rect2(0, 0, 64, 64)
	ic.texture = at
	ic.custom_minimum_size = Vector2(56, 56)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.add_child(ic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIStyle.label(r.name, 16, UIStyle.WOOD_DARK))
	var stage_name: String = {"baby": "Filhote", "young": "Jovem", "adult": "Adulto"}[r.stage()]
	info.add_child(UIStyle.label("%s · %s · %d dia(s) · %s" % [s.name, stage_name, r.age, r.personality], 10, UIStyle.EARTH))
	var hearts := ""
	for i in 5:
		hearts += "♥" if i < r.hearts() else "♡"
	info.add_child(UIStyle.label("%s   %s" % [hearts, AnimalSystem.mood_text(r)], 13, Color("c8503c")))
	top.add_child(info)
	var ren := Button.new()
	ren.text = "Nome"
	ren.pressed.connect(func(): ask_animal_name(r))
	top.add_child(ren)
	_card_body.add_child(top)
	var happy := ProgressBar.new()
	happy.custom_minimum_size = Vector2(0, 10)
	happy.show_percentage = false
	happy.value = r.happiness
	happy.add_theme_stylebox_override("fill", UIStyle.bar_fill(Color("78945b")))
	_card_body.add_child(UIStyle.label("Felicidade", 10, UIStyle.WOOD))
	_card_body.add_child(happy)
	var status: String = {"ok": "Saudável", "indisposto": "Indisposto", "resfriado": "Resfriado"}.get(r.health, r.health)
	if r.hygiene < 30:
		status += " · sujo"
	var fed := "comeu ontem" if r.fed_today else "ficou com fome"
	var where := "dorme no %s" % ("celeiro" if s.housing == "barn" else "galinheiro") if r.home != "" else "dorme no pasto"
	_card_body.add_child(UIStyle.label("%s · %s · %s" % [status, fed, where], 10, UIStyle.WOOD_DARK))
	if r.produced_total > 0:
		_card_body.add_child(UIStyle.label("Já deu %d produto(s). Melhor qualidade: %s." % [r.produced_total,
			AnimalSystem.QUALITY_NAMES[r.best_quality]], 10, UIStyle.EARTH))
	var tip := UIStyle.label(AnimalSystem.need_text(r), 12, UIStyle.WOOD)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(330, 0)
	_card_body.add_child(tip)


## Lista dos animais de uma construção (ou de todos).
func open_animal_list(records: Array, title: String, building: Placeable = null) -> void:
	_open(_animal_card)
	for c in _card_body.get_children():
		c.queue_free()
	_card_body.add_child(UIStyle.label(title, 15, UIStyle.WOOD_DARK))
	if building:
		var bar := HBoxContainer.new()
		var stored := 0
		for it in building.storage:
			stored += int(it["qty"])
		if stored > 0:
			var cb := Button.new()
			cb.text = "Coletar tudo (%d)" % stored
			cb.pressed.connect(func():
				var n: int = world.collect_storage(building)
				show_toast("Pegou %d produto(s) do coletor." % n)
				close_panel())
			bar.add_child(cb)
		var babies := CheckButton.new()
		babies.text = "Permitir filhotes"
		babies.button_pressed = building.allow_babies
		babies.add_theme_color_override("font_color", UIStyle.WOOD_DARK)
		babies.toggled.connect(func(on): building.allow_babies = on)
		_card_body.add_child(babies)
		var levels: Array = ItemDB.BUILDING_LEVELS[building.kind]
		if building.level < levels.size():
			var nxt: Dictionary = levels[building.level]
			var ub := Button.new()
			ub.text = "Melhorar p/ nível %d" % (building.level + 1)
			ub.disabled = not ItemDB.can_afford(nxt["cost"])
			ub.pressed.connect(func():
				show_toast(world.upgrade_building(building))
				close_panel())
			bar.add_child(ub)
			var perk := "comedouro automático do silo" if building.level == 1 else "aquecedor + coletor automático"
			_card_body.add_child(UIStyle.label("Próximo nível: %d vagas, %s.\nCusto: %s" % [nxt["capacity"], perk,
				ItemDB.cost_text(nxt["cost"])], 10, UIStyle.EARTH))
		_card_body.add_child(bar)
	if records.is_empty():
		_card_body.add_child(UIStyle.label("Ninguém mora aqui ainda. Compre animais na barraca do Fungo.", 11, UIStyle.EARTH))
	for r: AnimalRecord in records:
		var row := HBoxContainer.new()
		var hearts := ""
		for i in 5:
			hearts += "♥" if i < r.hearts() else "♡"
		var l := UIStyle.label("%s (%s) %s\n%s" % [r.name, r.data().name, hearts, AnimalSystem.need_text(r)], 10, UIStyle.WOOD_DARK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(250, 0)
		row.add_child(l)
		var b := Button.new()
		b.text = "Ver"
		b.pressed.connect(func(): open_animal_card(r))
		row.add_child(b)
		_card_body.add_child(row)


func _build_name_dialog() -> void:
	var w := _make_window("Nome do animal", Vector2(300, 0))
	_name_dialog = w[0]
	_name_edit = LineEdit.new()
	_name_edit.max_length = 14
	_name_edit.custom_minimum_size = Vector2(0, 32)
	w[1].add_child(_name_edit)
	var ok := Button.new()
	ok.text = "Pronto"
	ok.custom_minimum_size = Vector2(0, 30)
	ok.pressed.connect(_confirm_name)
	_name_edit.text_submitted.connect(func(_t): _confirm_name())
	w[1].add_child(ok)


func ask_animal_name(r: AnimalRecord) -> void:
	_name_record = r
	_name_edit.text = r.name
	_open(_name_dialog)
	_name_edit.grab_focus()
	_name_edit.select_all()


func _confirm_name() -> void:
	var t := _name_edit.text.strip_edges()
	if _name_record and t != "":
		_name_record.name = t
		if world:
			world.refresh_animals()
	close_panel()


# ================================================================= Moradores
func _build_npc_dialog() -> void:
	var w := _make_window("", Vector2(430, 0))
	_npc_win = w[0]
	_npc_body = VBoxContainer.new()
	w[1].add_child(_npc_body)


func _npc_portrait(n: NPCData, size: float) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = load(n.sheet)
	at.region = Rect2(0, 0, 64, 64)
	var ic := TextureRect.new()
	ic.texture = at
	ic.custom_minimum_size = Vector2(size, size)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return ic


## 10 coraçõezinhos: cheios até a amizade atual.
func _hearts_row(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var h := Villagers.hearts(id)
	for i in Villagers.MAX_HEARTS:
		var ic := TextureRect.new()
		ic.texture = ItemDB.ui_icon("heart")
		ic.custom_minimum_size = Vector2(12, 12)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if i >= h:
			ic.modulate = Color(0.2, 0.15, 0.1, 0.35)
		row.add_child(ic)
	return row


func open_npc_dialog(id: String, text: String) -> void:
	var n := Villagers.get_npc(id)
	for c in _npc_body.get_children():
		c.queue_free()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_npc_portrait(n, 72))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIStyle.label(n.name, 16, UIStyle.WOOD_DARK))
	info.add_child(UIStyle.label("%s · aniversário: %s" % [n.role, Villagers.birthday_text(id)], 10, UIStyle.EARTH))
	info.add_child(_hearts_row(id))
	var says := UIStyle.label(text, 12, UIStyle.WOOD_DARK)
	says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	says.custom_minimum_size = Vector2(300, 0)
	info.add_child(says)
	top.add_child(info)
	_npc_body.add_child(top)
	var tip := UIStyle.label("Segure um item e toque no morador para dar de presente (1 por dia).", 9, UIStyle.EARTH)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_npc_body.add_child(tip)
	_open(_npc_win)


# ================================================================= Cozinha
func _build_cooking() -> void:
	var w := _make_window("Fogão", Vector2(470, 0))
	_cook = w[0]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cook_body = VBoxContainer.new()
	_cook_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cook_body)
	w[1].add_child(scroll)


func open_cooking() -> void:
	var u := Cooking.check_unlocks()
	if u != "":
		show_toast(u)
	_open(_cook)
	_refresh_cooking()


func _refresh_cooking() -> void:
	for c in _cook_body.get_children():
		c.queue_free()
	var ids := Cooking.all_ids()
	var known := ids.filter(func(id): return Cooking.is_known(id)).size()
	_cook_body.add_child(UIStyle.label("Receitas: %d de %d · pratos feitos: %d" % [known, ids.size(), Game.dishes_cooked],
		11, UIStyle.EARTH))
	for id in ids:
		var r := Cooking.get_recipe(id)
		if not Cooking.is_known(id):
			var lock := _shop_row(r.dish_id(), "??? — %s" % Cooking.unlock_hint(r))
			lock.modulate = Color(1, 1, 1, 0.55)
			_cook_body.add_child(lock)
			continue
		var parts := []
		for key in r.ingredients:
			parts.append("%d/%d %s" % [mini(Cooking.have(key), int(r.ingredients[key])), int(r.ingredients[key]),
				Cooking.ingredient_name(key)])
		var eff := "+%d energia" % r.energy
		if r.health > 0:
			eff += ", +%d vida" % r.health
		if r.buff != "":
			eff += ", %s %s" % [RecipeData.BUFF_NAMES[r.buff], Cooking.duration_text(r.buff_minutes)]
		var row := _shop_row(r.dish_id(), "%s · %s\n%s" % [r.name, eff, ", ".join(parts)])
		var b := Button.new()
		b.text = "Cozinhar"
		b.disabled = not Cooking.can_cook(id)
		var rid: String = id
		b.pressed.connect(func():
			show_toast(Cooking.cook(rid))
			_refresh_cooking())
		row.add_child(b)
		_cook_body.add_child(row)


# ================================================================= Livro de Pesca
func _build_fish_book() -> void:
	var w := _make_window("Livro de Pesca", Vector2(460, 0))
	_book = w[0]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_book_body = VBoxContainer.new()
	_book_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_book_body)
	w[1].add_child(scroll)


func open_fish_book(filter: String = "") -> void:
	Game.bump("book")
	if filter != "":
		_book_filter = filter
	_open(_book)
	for c in _book_body.get_children():
		c.queue_free()
	var ids := FishDB.all_ids()
	var lvl := FishDB.level()
	var nxt := FishDB.xp_for_level(lvl + 1)
	var title := FishDB.current_title()
	_book_body.add_child(UIStyle.label("Descobertos %d de %d · Nível de pesca %d%s%s" % [FishDB.discovered_count(),
		ids.size(), lvl, "" if lvl >= FishDB.MAX_LEVEL else " (%d/%d XP)" % [Game.fishing_xp, nxt],
		" · " + title if title != "" else ""], 12, UIStyle.WOOD_DARK))
	# filtros
	var tabs := HBoxContainer.new()
	for f in [["all", "Todos"], ["season", "Esta estação"], ["lake", "Lago"], ["river", "Rio"], ["pond", "Laguinho"], ["legend", "Lendários"], ["treasure", "Tesouros"], ["quests", "Pedidos"]]:
		var b := Button.new()
		b.text = f[1]
		b.add_theme_font_size_override("font_size", 10)
		b.toggle_mode = true
		b.button_pressed = _book_filter == f[0]
		var key: String = f[0]
		b.pressed.connect(func(): open_fish_book(key))
		tabs.add_child(b)
	_book_body.add_child(tabs)
	if _book_filter == "treasure":
		_fill_treasures()
		return
	if _book_filter == "quests":
		_fill_quests()
		return
	var shown := ids.filter(func(id):
		var fd: FishData = FishDB.get_fish(id)
		match _book_filter:
			"season":
				return fd.seasons.is_empty() or fd.seasons.has(Game.season_id())
			"legend":
				return fd.rarity >= 5
			"lake", "river", "pond":
				return fd.waters.has(_book_filter)
		return fd.rarity < 6 or FishDB.is_discovered(id))   # secretos só aparecem depois de achados
	var found := shown.filter(func(id): return FishDB.is_discovered(id)).size()
	_book_body.add_child(UIStyle.label("Nesta lista: %d/%d" % [found, shown.size()], 10, UIStyle.EARTH))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for id in shown:
		var known := FishDB.is_discovered(id)
		var b := Button.new()
		b.icon = ItemDB.icon(id)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(46, 46)
		if not known:
			b.self_modulate = Color(1, 1, 1)
			b.icon = _silhouette(id)
		var fid: String = id
		b.pressed.connect(func(): _open_fish_card(fid))
		grid.add_child(b)
	_book_body.add_child(grid)


func _fill_treasures() -> void:
	var ids := TreasureDB.all_ids()
	var found := ids.filter(func(id): return TreasureDB.found_count(id) > 0).size()
	_book_body.add_child(UIStyle.label("Tesouros encontrados: %d/%d · Mapa: %d/%d%s · Mensagens: %d/%d" % [found, ids.size(),
		TreasureDB.map_pieces(), TreasureDB.MAP_PIECES, " (completo!)" if Game.fish_flags.get("map_complete", false) else "",
		TreasureDB.messages_read(), TreasureDB.MESSAGES.size()], 10, UIStyle.EARTH))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for id in ids:
		var b := Button.new()
		var tex: Texture2D = load(TreasureDB.icon_path(id))
		b.icon = tex if TreasureDB.found_count(id) > 0 else _silhouette(id, tex)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(46, 46)
		var tid: String = id
		b.pressed.connect(func(): _open_treasure_card(tid))
		grid.add_child(b)
	_book_body.add_child(grid)
	if TreasureDB.messages_read() > 0:
		_book_body.add_child(UIStyle.label("Mensagens das garrafas", 13, UIStyle.WOOD_DARK))
		for i in TreasureDB.messages_read():
			var lab := UIStyle.label("%d. %s" % [i + 1, TreasureDB.MESSAGES[i]], 10, UIStyle.WOOD_DARK)
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lab.custom_minimum_size = Vector2(420, 0)
			_book_body.add_child(lab)


func _fill_quests() -> void:
	var lines := []
	var r := FishQuests.request()
	lines.append(["Pedido do Fungo", 13])
	if r.is_empty():
		lines.append(["Nenhum pedido agora. Fale com o Fungo na barraca para ver se ele precisa de algo.", 11])
	else:
		lines.append([r["text"], 11])
		lines.append(["Progresso: %s · prazo: %d dia(s)" % [FishQuests.progress_text(), maxi(FishQuests.days_left(), 0)], 11])
		lines.append(["Recompensa: " + FishQuests.reward_text(r), 11])
	lines.append(["Pedidos entregues: %d" % FishQuests.requests_done(), 10])
	lines.append(["Torneio do Lago", 13])
	var dos := Calendar.day_of_season(Game.day)
	if FishQuests.tournament_active():
		var t = Game.fish_flags.get("tour", {})
		var best := int(t.get("best", 0)) if t is Dictionary and int(t.get("day", -1)) == Game.day else 0
		lines.append(["ACONTECENDO AGORA (até as 16h)! Seu melhor: %d pts%s." % [best,
			" (%dº lugar)" % FishQuests.rank_of(best) if best > 0 else ""], 11])
		var rv := FishQuests.rival_scores()
		lines.append(["Rivais: %s %d · %s %d · %s %d" % [FishQuests.RIVALS[0], rv[0], FishQuests.RIVALS[1], rv[1], FishQuests.RIVALS[2], rv[2]], 11])
	elif dos == FishQuests.TOURNAMENT_DAY and Game.minutes < FishQuests.TOUR_START:
		lines.append(["É hoje! Começa às 8h e vai até as 16h.", 11])
	else:
		var wait := FishQuests.TOURNAMENT_DAY - dos
		if wait <= 0:
			wait += Calendar.SEASON_LENGTH
		lines.append(["Todo dia %d de cada estação, das 8h às 16h. Próximo: em %d dia(s)." % [FishQuests.TOURNAMENT_DAY, wait], 11])
	lines.append(["Pontos = tamanho do peixe (cm) × bônus da raridade. Vale o seu melhor peixe do dia.", 10])
	lines.append(["Vitórias: %d de %d torneios" % [int(Game.fish_flags.get("tour_wins", 0)), int(Game.fish_flags.get("tour_played", 0))], 10])
	lines.append(["Títulos (%d/%d)" % [FishDB.titles().size(), FishDB.TITLES.size()], 13])
	for d in FishDB.TITLES:
		var done: bool = FishDB.titles().has(d["id"])
		lines.append(["%s — %s%s" % [d["name"], d["goal"], " (conquistado!)" if done else ""], 10])
	for l in lines:
		var lab := UIStyle.label(l[0], l[1], UIStyle.WOOD if l[1] == 13 else UIStyle.WOOD_DARK)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(420, 0)
		_book_body.add_child(lab)


func _open_treasure_card(id: String) -> void:
	for c in _book_body.get_children():
		c.queue_free()
	var t := TreasureDB.get_treasure(id)
	var n := TreasureDB.found_count(id)
	var back := Button.new()
	back.text = "← Voltar"
	back.pressed.connect(func(): open_fish_book("treasure"))
	_book_body.add_child(back)
	var top := HBoxContainer.new()
	var ic := TextureRect.new()
	var tex: Texture2D = load(TreasureDB.icon_path(id))
	ic.texture = tex if n > 0 else _silhouette(id, tex)
	ic.custom_minimum_size = Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(ic)
	var info := VBoxContainer.new()
	info.add_child(UIStyle.label(t.name if n > 0 else "???", 16, UIStyle.WOOD_DARK))
	var sub := t.rarity_name()
	if n > 0 and t.sell > 0:
		sub += " · vende %d" % t.sell
	info.add_child(UIStyle.label(sub, 11, UIStyle.EARTH))
	top.add_child(info)
	_book_body.add_child(top)
	var lines := []
	if n > 0:
		lines.append(t.description)
		lines.append("Encontrado %d vez(es)." % n)
	else:
		lines.append("Ainda não encontrado. Às vezes a linha fisga outra coisa além de peixe...")
	var w := []
	for x in t.waters:
		w.append(FishData.WATER_NAMES.get(x, x))
	lines.append("Onde: " + ", ".join(w) + (" (fundo)" if t.depth == "deep" else "") + ("" if t.min_level <= 1 else " · nível %d+" % t.min_level))
	for l in lines:
		var lab := UIStyle.label(l, 11, UIStyle.WOOD_DARK)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(420, 0)
		_book_body.add_child(lab)


static var _sil_cache := {}


## Silhueta escura (peixe ou tesouro ainda não descoberto).
func _silhouette(id: String, from: Texture2D = null) -> Texture2D:
	if _sil_cache.has(id):
		return _sil_cache[id]
	var tex := from if from != null else ItemDB.icon(id)
	var img: Image
	if tex is AtlasTexture:
		var full: Image = tex.atlas.get_image()
		if full.is_compressed():
			full.decompress()
		img = full.get_region(Rect2i(tex.region))
	else:
		img = tex.get_image()
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.1:
				img.set_pixel(x, y, Color(0.17, 0.13, 0.09, 0.85))
	var t := ImageTexture.create_from_image(img)
	_sil_cache[id] = t
	return t


func _open_fish_card(id: String) -> void:
	for c in _book_body.get_children():
		c.queue_free()
	var f := FishDB.get_fish(id)
	var known := FishDB.is_discovered(id)
	var e := FishDB.entry(id)
	var back := Button.new()
	back.text = "← Voltar"
	back.pressed.connect(func(): open_fish_book())
	_book_body.add_child(back)
	var top := HBoxContainer.new()
	var ic := TextureRect.new()
	ic.texture = ItemDB.icon(id) if known else _silhouette(id)
	ic.custom_minimum_size = Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(ic)
	var info := VBoxContainer.new()
	info.add_child(UIStyle.label(f.name if known else "???", 16, UIStyle.WOOD_DARK))
	info.add_child(UIStyle.label("%s · vende %d" % [f.rarity_name(), ItemDB.sell_price(id)] if known else f.rarity_name(), 11, UIStyle.EARTH))
	top.add_child(info)
	_book_body.add_child(top)
	var lines := []
	if known:
		lines.append(f.description)
		if f.lore != "":
			lines.append("Lenda: " + f.lore)
		lines.append("Onde: " + FishDB.where_text(f))
		lines.append("Quando: " + FishDB.when_text(f))
		lines.append("Clima: " + FishDB.weather_text(f))
		if not f.baits.is_empty():
			lines.append("Iscas preferidas: " + ", ".join(Array(f.baits).map(func(b): return ItemDB.item_name(b))))
		lines.append("Tamanho: %.0f–%.0f cm · peso %.2f–%.1f kg" % [f.size_min, f.size_max, f.weight_min, f.weight_max])
		lines.append("Seu recorde: %.1f cm · %.2f kg · pescado %d vez(es) · primeira vez no %s" % [e["max_size"],
			e["max_weight"], e["n"], Calendar.short_text(int(e["first"]))])
		lines.append("Usos: " + ", ".join(f.uses))
	else:
		lines.append("Ainda não descoberto.")
		lines.append("Pista: " + (f.hint if f.hint != "" else "procure em %s." % FishDB.where_text(f).to_lower()))
		if FishDB.level() >= 5:
			lines.append("(Nível 5+) Quando: " + FishDB.when_text(f))
	for l in lines:
		var lab := UIStyle.label(l, 11, UIStyle.WOOD_DARK)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(420, 0)
		_book_body.add_child(lab)


# ================================================================= calendário
func _build_calendar() -> void:
	var w := _make_window("Calendário", Vector2(420, 0))
	_calendar = w[0]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cal_body = VBoxContainer.new()
	_cal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cal_body)
	w[1].add_child(scroll)


func open_calendar() -> void:
	_open(_calendar)
	for c in _cal_body.get_children():
		c.queue_free()
	var d := Game.day
	var left := Calendar.days_left(d)
	_cal_body.add_child(UIStyle.label("%s · dia %d de %d · ano %d" % [Calendar.season_name(d),
		Calendar.day_of_season(d), Calendar.SEASON_LENGTH, Calendar.year(d)], 14, UIStyle.WOOD_DARK))
	var next_name := Calendar.season_name(d + left + 1)
	_cal_body.add_child(UIStyle.label("Faltam %d dia(s) para o %s." % [left, next_name] if left > 0
		else "Hoje é o último dia! Amanhã começa o %s." % next_name, 11, UIStyle.EARTH))
	# previsão
	_cal_body.add_child(UIStyle.label("Previsão", 13, UIStyle.WOOD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var days := [{"weather": Game.weather, "temp": Game.temperature}] + Game.forecast.slice(0, 3)
	for i in days.size():
		var f: Dictionary = days[i]
		var box := HBoxContainer.new()
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # nunca distorcer o ícone
		ic.texture = ItemDB.ui_icon(CropDB.weather(f["weather"]).icon)
		ic.custom_minimum_size = Vector2(16, 16)
		box.add_child(ic)
		box.add_child(UIStyle.label("%s\n%s\n%d°C" % ["Hoje" if i == 0 else Calendar.weekday(d + i),
			CropDB.weather(f["weather"]).name, int(f["temp"])], 10, UIStyle.WOOD_DARK))
		row.add_child(box)
	_cal_body.add_child(row)
	# eventos
	var dos := Calendar.day_of_season(d)
	var ev := "Torneio do Lago: dia %d (%s)" % [FishQuests.TOURNAMENT_DAY,
		"HOJE, 8h às 16h!" if dos == FishQuests.TOURNAMENT_DAY else ("já passou nesta estação" if dos > FishQuests.TOURNAMENT_DAY
		else "daqui a %d dia(s)" % (FishQuests.TOURNAMENT_DAY - dos))]
	_cal_body.add_child(UIStyle.label("Eventos", 13, UIStyle.WOOD))
	_cal_body.add_child(UIStyle.label(ev, 11, UIStyle.WOOD_DARK))
	for vid in Villagers.all_ids():
		if Villagers.is_birthday(vid):
			_cal_body.add_child(UIStyle.label("Hoje: aniversário de %s!" % Villagers.get_npc(vid).name, 11, UIStyle.WOOD_DARK))
	# moradores
	_cal_body.add_child(UIStyle.label("Moradores", 13, UIStyle.WOOD))
	for vid in Villagers.all_ids():
		var n := Villagers.get_npc(vid)
		var vrow := HBoxContainer.new()
		vrow.add_theme_constant_override("separation", 6)
		vrow.add_child(_npc_portrait(n, 32))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIStyle.label("%s (%s) · aniversário %s" % [n.name, n.role, Villagers.birthday_text(vid)], 10, UIStyle.WOOD_DARK))
		col.add_child(_hearts_row(vid))
		var known := UIStyle.label(Villagers.known_text(vid), 9, UIStyle.EARTH)
		known.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		known.custom_minimum_size = Vector2(320, 0)
		col.add_child(known)
		vrow.add_child(col)
		_cal_body.add_child(vrow)
	# o que plantar agora
	_cal_body.add_child(UIStyle.label("Plante agora", 13, UIStyle.WOOD))
	for seed_id in CropDB.seeds_for(Calendar.season_id(d)):
		var c := CropDB.crop_for_seed(seed_id)
		var ok := Calendar.fits_in_season(c, d)
		var extra := ", depois a cada %d" % c.regrow_days if c.harvest_type == "regrow" else ""
		var line := _shop_row(c.produce_id(), "%s — %d dias%s%s" % [c.name, c.total_days(), extra,
			"" if ok else " · não dá tempo nesta estação"])
		_cal_body.add_child(line)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and _open_panel == null and _top_right \
			and _top_right.get_global_rect().has_point(event.position):
		open_calendar()
		get_viewport().set_input_as_handled()


func open_crafting() -> void:
	_open(_craft)
	_refresh_crafting()


func _refresh_crafting() -> void:
	for c in _craft_list.get_children():
		c.queue_free()
	for r in ItemDB.RECIPES:
		var id: String = r["result"]
		var cost: Dictionary = r["cost"]
		var name := ItemDB.item_name(id) + (" x%d" % int(r["qty"]) if int(r["qty"]) > 1 else "")
		var row := _shop_row(id, "%s\n%s" % [name, ItemDB.cost_text(cost)])
		var b := Button.new()
		b.text = "Fazer"
		b.disabled = not ItemDB.can_afford(cost)
		b.pressed.connect(func():
			if not ItemDB.can_afford(cost):
				return
			if Game.add_item(id, int(r["qty"])) > 0:
				return
			ItemDB.pay(cost)
			show_toast("Fabricou %s!" % name)
			_refresh_crafting())
		row.add_child(b)
		_craft_list.add_child(row)
	# melhorias de ferramenta
	_craft_list.add_child(UIStyle.label("Melhorar ferramentas", 13, UIStyle.WOOD))
	for tool in ItemDB.TOOL_UPGRADES:
		var lvl := Game.tool_level(tool)
		var ups: Array = ItemDB.TOOL_UPGRADES[tool]
		if lvl > ups.size():
			_craft_list.add_child(_shop_row(tool, "%s — nível máximo" % ItemDB.item_name(tool)))
			continue
		var cost: Dictionary = ups[lvl - 1]
		var effect := "3 canteiros em linha" if lvl == 1 else "área 3×3"
		if tool == "fishing_rod":
			effect = "fisgada mais longa, puxa com mais força"
		if tool == "watering_can":
			effect += ", %d de água" % (Game.WATER_CAPACITY * (lvl + 1))
		var row := _shop_row(tool, "%s → nível %d (%s)\n%s" % [ItemDB.item_name(tool), lvl + 1, effect, ItemDB.cost_text(cost)])
		var ub := Button.new()
		ub.text = "Melhorar"
		ub.disabled = not ItemDB.can_afford(cost)
		ub.pressed.connect(func():
			if not ItemDB.can_afford(cost):
				return
			ItemDB.pay(cost)
			Game.tool_levels[tool] = lvl + 1
			Game.inventory_changed.emit()
			show_toast("%s agora é nível %d!" % [ItemDB.item_name(tool), lvl + 1])
			_refresh_crafting())
		row.add_child(ub)
		_craft_list.add_child(row)


func _build_confirm() -> void:
	var w := _make_window("", Vector2(260, 0))
	_confirm = w[0]
	var v: VBoxContainer = w[1]
	_confirm_label = UIStyle.label("", 13, UIStyle.WOOD_DARK)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_confirm_label)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	var yes := Button.new()
	yes.text = "Sim"
	yes.custom_minimum_size = Vector2(80, 30)
	yes.pressed.connect(func():
		var cb := _confirm_action
		close_panel()
		if cb.is_valid():
			cb.call())
	var no := Button.new()
	no.text = "Não"
	no.custom_minimum_size = Vector2(80, 30)
	no.pressed.connect(close_panel)
	h.add_child(yes)
	h.add_child(no)
	v.add_child(h)


# ================================================================= painéis
## O ponto da tela está sobre algum elemento da HUD?
func blocks_point(p: Vector2) -> bool:
	for c in _blockers:
		if c.get_global_rect().grow(4).has_point(p):
			return true
	for b in [_use_btn, _hand_btn, _bag_btn, _book_btn]:
		if (p - b.global_position - b.size / 2.0).length() <= b.radius + 8:
			return true
	if _tut_panel and _tut_panel.visible and _tut_panel.get_global_rect().grow(4).has_point(p):
		return true
	return false


func is_panel_open() -> bool:
	return _open_panel != null


func _open(p: Control) -> void:
	if _open_panel:
		_open_panel.visible = false
	_open_panel = p
	p.visible = true
	Game.ui_lock = 1


func close_panel() -> void:
	if _open_panel:
		_open_panel.visible = false
	_open_panel = null
	_bp_marked = -1
	Game.ui_lock = 0
	_refresh_hotbar()


func toggle_backpack() -> void:
	if _open_panel == _backpack:
		close_panel()
		return
	_bp_marked = -1
	_bp_desc.text = ""
	_open(_backpack)
	_refresh_backpack()


func open_shop() -> void:
	_open(_shop)
	_refresh_shop()


func ask(text: String, action: Callable) -> void:
	_confirm_label.text = text
	_confirm_action = action
	_open(_confirm)


func _on_backpack_slot(i: int) -> void:
	var s = Game.inventory[i]
	if _bp_marked == -1:
		if s == null:
			return
		_bp_marked = i
		var item := ItemDB.get_item(s["id"])
		_bp_desc.text = "%s — %s" % [item.get("name", ""), item.get("desc", "")]
	elif _bp_marked == i:
		_bp_marked = -1
		_bp_desc.text = ""
	else:
		Game.swap_slots(_bp_marked, i)
		_bp_marked = -1
		_bp_desc.text = ""
	_refresh_backpack()


func _refresh_backpack() -> void:
	for s in _bp_slots:
		s.marked = s.index == _bp_marked
		s.selected = s.index < Game.HOTBAR_SIZE and s.index == Game.selected_slot
		s.queue_redraw()


func _refresh_shop() -> void:
	_shop_money.text = "Moedas: %d" % Game.money
	for c in _shop_buy.get_children():
		if c is HBoxContainer:
			c.queue_free()
	for c in _shop_animals.get_children():
		c.queue_free()
	for sp in AnimalSystem.all_species():
		var price: int = AnimalSystem.species(sp).price
		var group := AnimalSystem.species(sp).group
		var has_room: bool = world != null and world.count_animals(group) < world.capacity(group)
		var row := HBoxContainer.new()
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # nunca distorcer o ícone
		var at := AtlasTexture.new()
		at.atlas = load("res://assets/sprites/animals/%s.png" % sp)
		at.region = Rect2(0, 0, 64, 64)
		ic.texture = at
		ic.custom_minimum_size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(ic)
		var info := "%s (filhote)\n%d moedas" % [AnimalSystem.species(sp).name, price]
		if world and not has_room:
			info += " · precisa de %s" % ("galinheiro" if group == "bird" else "celeiro")
		var l := UIStyle.label(info, 10, UIStyle.WOOD_DARK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Button.new()
		b.text = "Comprar"
		b.disabled = Game.money < price or not has_room
		b.pressed.connect(func():
			if Game.money < price or world.count_animals(group) >= world.capacity(group):
				return
			Game.add_money(-price)
			var newborn: Animal = world.add_animal(sp, false)
			show_toast("Um filhote de %s chegou ao pasto!" % AnimalSystem.species(sp).name)
			ask_animal_name(newborn.record))
		row.add_child(b)
		_shop_animals.add_child(row)
	for c in _shop_sell.get_children():
		c.queue_free()

	var buy_list: Array = CropDB.seeds_for(Calendar.season_id(Game.day))
	for id in ItemDB.SHOP_ITEMS:
		if ItemDB.get_item(id).get("type", "") != "seed":
			buy_list.append(id)
	buy_list += Cooking.shop_scrolls(Calendar.season_id(Game.day))
	for id in buy_list:
		if ItemDB.get_item(id).get("type", "") == "tool" and Game.count_item(id) > 0:
			continue   # não vende de novo uma ferramenta que você já tem
		var price: int = ItemDB.get_item(id)["buy"]
		var row := _shop_row(id, "%s\n%d moedas" % [ItemDB.item_name(id).replace("Sementes de ", ""), price])
		var b := Button.new()
		b.text = "Comprar"
		b.disabled = Game.money < price
		b.pressed.connect(func():
			if Game.money >= price and Game.add_item(id, 1) == 0:
				Game.add_money(-price)
			_refresh_shop())
		row.add_child(b)
		_shop_buy.add_child(row)

	var seen := {}
	for s in Game.inventory:
		if s == null or ItemDB.sell_price(s["id"]) <= 0:
			continue
		var id: String = s["id"]
		var q: int = int(s.get("q", 0))
		var key := "%s/%d" % [id, q]
		if seen.has(key):
			continue
		seen[key] = true
		var price := ItemDB.sell_price(id, q)
		var qty := Game.count_item(id, q)
		var qname := "" if q == 0 else " (%s)" % AnimalSystem.QUALITY_NAMES[q]
		var row := _shop_row(id, "%s%s x%d\n%d cada" % [ItemDB.item_name(id), qname, qty, price])
		var b1 := Button.new()
		b1.text = "1"
		b1.pressed.connect(func():
			if Game.remove_item(id, 1, q):
				Game.add_money(price)
			_refresh_shop())
		var b2 := Button.new()
		b2.text = "Tudo"
		b2.pressed.connect(func():
			var n := Game.count_item(id, q)
			if Game.remove_item(id, n, q):
				Game.add_money(price * n)
			_refresh_shop())
		row.add_child(b1)
		row.add_child(b2)
		_shop_sell.add_child(row)
	if seen.is_empty():
		_shop_sell.add_child(UIStyle.label("Nada para vender ainda.", 11, UIStyle.EARTH))


func _shop_row(id: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # nunca distorcer o ícone
	ic.texture = ItemDB.icon(id)
	ic.custom_minimum_size = Vector2(24, 24)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := UIStyle.label(text, 10, UIStyle.WOOD_DARK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


# ================================================================= atualização
func _process(_d: float) -> void:
	var text := ""
	if player and Game.ui_lock == 0:
		var it := player.find_interactable()
		if it:
			text = it.label
		elif player.world and player.world.can_interact_cell(player.pick_target("")):
			text = "Colher"
		elif Game.selected_item_id() == "fishing_rod":
			var wc := player.target_cell()
			var wk: String = player.world.water_kind(wc)
			if wk != "":
				var dep: String = player.world.water_depth(wc)
				var ctx := FishDB.context(wk, dep, Game.equipped_bait)
				var here := FishDB.possible_here(ctx)
				var known := here.filter(func(i): return FishDB.is_discovered(i)).size()
				text = "%s%s · %d/%d" % [FishData.WATER_NAMES.get(wk, wk), " fundo" if dep == "deep" else "", known, here.size()]
	if _context_label.text != text:
		_context_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("backpack"):
		toggle_backpack()
	for i in Game.HOTBAR_SIZE:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			Game.select_slot(i)


func _on_inventory_changed() -> void:
	_refresh_hotbar()
	if _open_panel == _backpack:
		_refresh_backpack()


func _refresh_hotbar() -> void:
	for s in _hotbar:
		s.selected = s.index == Game.selected_slot
		s.queue_redraw()
	var id := Game.selected_item_id()
	_use_btn.icon = ItemDB.icon(id) if id != "" else ItemDB.ui_icon("hand")
	_use_btn.queue_redraw()


# ================================================================= tutorial
func _build_tutorial_panel() -> void:
	_tut_panel = PanelContainer.new()
	_tut_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_tut_panel.position = Vector2(176, 50)
	_tut_panel.custom_minimum_size = Vector2(290, 0)
	_tut_panel.size = Vector2(290, 0)
	_tut_panel.visible = false
	_root.add_child(_tut_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_tut_panel.add_child(v)
	var top := HBoxContainer.new()
	_tut_title = UIStyle.label("", 9, UIStyle.WOOD)
	_tut_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_tut_title)
	var skip := Button.new()
	skip.text = "Pular"
	skip.add_theme_font_size_override("font_size", 8)
	skip.pressed.connect(func(): tutorial_skip_pressed.emit())
	top.add_child(skip)
	v.add_child(top)
	_tut_label = UIStyle.label("", 10, UIStyle.WOOD_DARK)
	_tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_label.custom_minimum_size = Vector2(280, 0)
	v.add_child(_tut_label)


## Objetivo do tutorial ("" esconde o painel).
func set_tutorial(text: String, title: String) -> void:
	if _tut_panel == null:
		return
	_tut_panel.visible = text != ""
	_tut_label.text = text
	_tut_title.text = title
	_tut_panel.reset_size()


func _refresh_buffs() -> void:
	if _buff_label:
		var t := Cooking.buffs_text()
		_buff_label.text = t
		_buff_label.visible = t != ""


func _refresh_stats() -> void:
	_refresh_buffs()
	_health_bar.max_value = Game.max_health
	_health_bar.value = Game.health
	_energy_bar.max_value = Game.max_energy
	_energy_bar.value = Game.energy
	_money_label.text = _format_money(Game.money)
	if _open_panel == _shop:
		_refresh_shop()


func _refresh_time() -> void:
	_time_label.text = "%s  %s  %d°" % [Calendar.short_text(Game.day), Game.clock_text(), int(Game.temperature)]
	_time_icon.texture = ItemDB.ui_icon("moon" if Game.is_night() else "sun")
	_weather_icon.texture = ItemDB.ui_icon(Game.weather_data().icon)
	_weather_icon.visible = true


static func _format_money(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func show_toast(text: String) -> void:
	_toast.text = text
	# com o painel do tutorial aberto, o aviso aparece logo abaixo dele
	_toast.offset_top = 122.0 if _tut_panel and _tut_panel.visible else 62.0
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6 + text.length() / 45.0)   # texto longo fica mais tempo
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


## Escurece a tela, executa `mid` e clareia de novo.
func fade_through(mid: Callable, after: Callable = Callable()) -> void:
	Game.ui_lock = 1
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.6)
	tw.tween_callback(mid)
	tw.tween_interval(0.4)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		Game.ui_lock = 0
		if after.is_valid():
			after.call())
