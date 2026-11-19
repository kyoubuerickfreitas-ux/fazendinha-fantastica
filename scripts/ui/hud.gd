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
	_build_confirm()
	_build_fade()

	Game.money_changed.connect(func(_v): _refresh_stats())
	Game.stats_changed.connect(_refresh_stats)
	Game.time_changed.connect(func(_d, _m): _refresh_time())
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


func _make_bar(parent: Control, icon_name: String, color: Color) -> ProgressBar:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	var ic := TextureRect.new()
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
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	panel.add_child(h)

	var coin := TextureRect.new()
	coin.texture = ItemDB.ui_icon("coin")
	coin.custom_minimum_size = Vector2(16, 16)
	h.add_child(coin)
	_money_label = UIStyle.outlined_label("0", 13)
	_money_label.custom_minimum_size.x = 44
	h.add_child(_money_label)
	h.add_child(_vsep())
	_time_icon = TextureRect.new()
	_time_icon.custom_minimum_size = Vector2(16, 16)
	h.add_child(_time_icon)
	_time_label = UIStyle.outlined_label("", 13)
	h.add_child(_time_label)
	h.add_child(_vsep())
	_weather_icon = TextureRect.new()
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

	_context_label = UIStyle.outlined_label("", 11)
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.size = Vector2(80, 14)
	_context_label.position = Vector2(170 - 145, 150 - 70)
	area.add_child(_context_label)


func _build_toast() -> void:
	_toast = UIStyle.outlined_label("", 13)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -200
	_toast.offset_right = 200
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
		else:
			_shop_sell = list


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
	for b in [_use_btn, _hand_btn]:
		if (p - b.global_position - b.size / 2.0).length() <= b.radius + 8:
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
		c.queue_free()
	for c in _shop_sell.get_children():
		c.queue_free()

	for id in ItemDB.SHOP_ITEMS:
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
		if s == null or seen.has(s["id"]) or ItemDB.sell_price(s["id"]) <= 0:
			continue
		var id: String = s["id"]
		seen[id] = true
		var price := ItemDB.sell_price(id)
		var qty := Game.count_item(id)
		var row := _shop_row(id, "%s x%d\n%d cada" % [ItemDB.item_name(id), qty, price])
		var b1 := Button.new()
		b1.text = "1"
		b1.pressed.connect(func():
			if Game.remove_item(id, 1):
				Game.add_money(price)
			_refresh_shop())
		var b2 := Button.new()
		b2.text = "Tudo"
		b2.pressed.connect(func():
			var n := Game.count_item(id)
			if Game.remove_item(id, n):
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


func _refresh_stats() -> void:
	_health_bar.max_value = Game.max_health
	_health_bar.value = Game.health
	_energy_bar.max_value = Game.max_energy
	_energy_bar.value = Game.energy
	_money_label.text = _format_money(Game.money)
	if _open_panel == _shop:
		_refresh_shop()


func _refresh_time() -> void:
	_time_label.text = "Dia %d  %s" % [Game.day, Game.clock_text()]
	_time_icon.texture = ItemDB.ui_icon("moon" if Game.is_night() else "sun")
	_weather_icon.texture = ItemDB.ui_icon("rain" if Game.weather == "rain" else "cloud")
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
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


## Escurece a tela, executa `mid` e clareia de novo.
func fade_through(mid: Callable) -> void:
	Game.ui_lock = 1
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.6)
	tw.tween_callback(mid)
	tw.tween_interval(0.4)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): Game.ui_lock = 0)
