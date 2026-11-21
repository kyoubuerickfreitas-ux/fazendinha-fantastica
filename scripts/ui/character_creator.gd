class_name CharacterCreator
extends ColorRect
## Tela de criação de personagem: nome, nome da fazenda e aparência (pele, penteado, cor do cabelo,
## camisa e calção), com prévia andando. Aparece no jogo novo e pelas Opções ("Aparência e nomes").

signal finished

var first_time := true

var _look := {}
var _preview: PlayerPortrait
var _name: LineEdit
var _farm: LineEdit
var _hair_label: Label
var _swatches := {}      # chave -> [botões]


func _ready() -> void:
	color = Color(0.05, 0.03, 0.02, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_look = Game.look().duplicate()
	if first_time:
		_look = PlayerLook.random_look()

	var outer := PanelContainer.new()
	outer.add_theme_stylebox_override("panel", UIStyle.window_frame())
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	outer.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(outer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	outer.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	panel.add_child(root)
	var title := UIStyle.label("Crie seu personagem" if first_time else "Aparência e nomes", 14, UIStyle.WOOD_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_stylebox_override("normal", UIStyle.title_plate())    # plaquinha em cima da viga
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	root.add_child(cols)

	# ---- prévia
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	var stage := PanelContainer.new()
	var st := UIStyle.panel(Color("8fae5e"), UIStyle.WOOD_DARK, 2, 8)
	st.set_content_margin_all(0)
	stage.add_theme_stylebox_override("panel", st)
	left.add_child(stage)
	_preview = PlayerPortrait.new()
	_preview.look = _look
	_preview.walking = true
	_preview.region = Rect2(8, 4, 48, 58)
	_preview.custom_minimum_size = Vector2(120, 145)
	stage.add_child(_preview)
	var turn := HBoxContainer.new()
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	turn.add_child(_small_button("<", func(): _turn(1)))
	turn.add_child(UIStyle.label("girar", 9, UIStyle.EARTH))
	turn.add_child(_small_button(">", func(): _turn(-1)))
	left.add_child(turn)
	var rnd := Button.new()
	rnd.text = "Sortear tudo"
	rnd.add_theme_font_size_override("font_size", 10)
	rnd.pressed.connect(_randomize)
	left.add_child(rnd)

	# ---- escolhas
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	cols.add_child(grid)
	_name = _text_row(grid, "Nome", 14, Game.player_name() if not first_time else PlayerLook.random_name(), PlayerLook.random_name)
	_farm = _text_row(grid, "Fazenda", 22, Game.farm_name() if not first_time else PlayerLook.random_farm(), PlayerLook.random_farm)
	_swatch_row(grid, "Pele", "skin", PlayerLook.SKINS)
	# penteado: setas
	grid.add_child(_row_label("Cabelo"))
	var hs := HBoxContainer.new()
	hs.add_child(_small_button("<", func(): _step_hair(-1)))
	_hair_label = UIStyle.label("", 10, UIStyle.INK)
	_hair_label.custom_minimum_size = Vector2(110, 0)
	_hair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hs.add_child(_hair_label)
	hs.add_child(_small_button(">", func(): _step_hair(1)))
	grid.add_child(hs)
	_swatch_row(grid, "Cor do cabelo", "hair_color", PlayerLook.HAIR_COLORS)
	_swatch_row(grid, "Camisa", "shirt", PlayerLook.SHIRTS)
	_swatch_row(grid, "Calção", "pants", PlayerLook.PANTS)

	var ok := Button.new()
	ok.name = "Confirmar"
	ok.text = "Começar!" if first_time else "Pronto"
	ok.custom_minimum_size = Vector2(160, 26)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(confirm)
	root.add_child(ok)
	_refresh()


func _row_label(t: String) -> Label:
	var l := UIStyle.label(t, 10, UIStyle.WOOD_DARK)
	l.custom_minimum_size = Vector2(78, 0)
	return l


func _small_button(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 9)
	b.custom_minimum_size = Vector2(24, 20)
	b.pressed.connect(f)
	return b


func _text_row(grid: GridContainer, label: String, max_len: int, value: String, rnd: Callable) -> LineEdit:
	grid.add_child(_row_label(label))
	var h := HBoxContainer.new()
	var e := LineEdit.new()
	e.max_length = max_len
	e.text = value
	e.custom_minimum_size = Vector2(150, 22)
	e.add_theme_font_size_override("font_size", 10)
	e.select_all_on_focus = true
	h.add_child(e)
	h.add_child(_small_button("Sortear", func(): e.text = rnd.call()))
	grid.add_child(h)
	return e


func _swatch_row(grid: GridContainer, label: String, key: String, list: Array) -> void:
	grid.add_child(_row_label(label))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	var btns := []
	for i in list.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(20, 18)
		b.tooltip_text = list[i][0]
		var idx: int = i
		b.pressed.connect(func():
			_look[key] = idx
			_refresh())
		h.add_child(b)
		btns.append(b)
	_swatches[key] = [btns, list]
	grid.add_child(h)


func _swatch_style(c: Color, selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(4)
	s.set_border_width_all(2 if selected else 1)
	s.border_color = Color("fdf6e3") if selected else UIStyle.WOOD_DARK
	if selected:
		s.shadow_color = UIStyle.INK
		s.shadow_size = 2
	return s


func _refresh() -> void:
	for key in _swatches:
		var btns: Array = _swatches[key][0]
		var list: Array = _swatches[key][1]
		for i in btns.size():
			var c := Color(list[i][1])
			var sel := int(_look.get(key, 0)) == i
			for state in ["normal", "hover", "pressed", "focus"]:
				btns[i].add_theme_stylebox_override(state, _swatch_style(c if state != "hover" else c.lightened(0.15), sel))
	_hair_label.text = PlayerLook.HAIR_STYLES[int(_look["hair"])][1]
	_preview.look = _look
	_preview.refresh()


func _turn(d: int) -> void:
	var order := [0, 2, 3, 1]      # baixo, direita, cima, esquerda
	var i := order.find(_preview.direction)
	_preview.direction = order[posmod(i + d, 4)]
	_preview.refresh()


func _step_hair(d: int) -> void:
	_look["hair"] = posmod(int(_look["hair"]) + d, PlayerLook.HAIR_STYLES.size())
	_refresh()


func _randomize() -> void:
	_look = PlayerLook.random_look()
	_name.text = PlayerLook.random_name()
	_farm.text = PlayerLook.random_farm()
	_refresh()


## Mesmo efeito do botão "Começar!"/"Pronto" (também usado pelos testes).
func set_choices(player_name: String, farm: String, look: Dictionary) -> void:
	_name.text = player_name
	_farm.text = farm
	_look = PlayerLook.sanitize(look)
	_refresh()


func confirm() -> void:
	var n := _name.text.strip_edges()
	var f := _farm.text.strip_edges()
	Game.profile["name"] = n if n != "" else PlayerLook.random_name()
	Game.profile["farm"] = f if f != "" else PlayerLook.random_farm()
	Game.profile["look"] = PlayerLook.sanitize(_look)
	Game.profile["created"] = true
	Game.look_changed.emit()
	finished.emit()
	queue_free()
