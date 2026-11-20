extends Node
## Som do jogo: efeitos (play), música de fundo com troca suave (music) e ambiente em loop (ambience).
## Volumes de música e efeitos ficam em user://settings.cfg (preferência do aparelho; não é apagada
## pelo "Novo jogo"). Trilha e efeitos são gerados por tools/generate_music.py e tools/generate_sfx.py.

const SFX_DIR := "res://assets/sounds/"
const MUSIC_DIR := "res://assets/music/"
const SETTINGS := "user://settings.cfg"
const VOICES := 10
const FADE := 1.6
## Volume base de cada faixa (dB) para não brigar com os efeitos.
const MUSIC_DB := -6.0
const AMB_DB := -10.0

var music_volume := 0.8     # 0..1
var sfx_volume := 0.9       # 0..1
var current_music := ""
var current_ambience := ""

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
var _music: Array[AudioStreamPlayer] = []   # dois tocadores para trocar com fade
var _music_i := 0
var _amb: Array[AudioStreamPlayer] = []
var _amb_i := 0
var _last_played := {}       # nome -> tempo (evita o mesmo som empilhado no mesmo instante)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus("Music")
	_make_bus("SFX")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
		var a := AudioStreamPlayer.new()
		a.bus = "Music"
		a.volume_db = -80.0
		add_child(a)
		_amb.append(a)
	_load_settings()
	# todo botão da interface faz "clique"
	get_tree().node_added.connect(_on_node_added)


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


# ------------------------------------------------------------------ efeitos
## Toca um efeito. pitch_var sorteia uma variação de tom para não soar repetitivo.
func play(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_var: float = 0.06) -> void:
	if sfx_volume <= 0.001:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sfx_name, -1000)) < 45:
		return
	var stream := _stream(SFX_DIR + sfx_name + ".wav")
	if stream == null:
		return
	_last_played[sfx_name] = now
	var p := _voices[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-pitch_var, pitch_var)))
	p.play()


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func _on_node_added(n: Node) -> void:
	# (os botões redondos de ação não fazem clique: a ferramenta já tem o próprio som)
	if n is BaseButton:
		(n as BaseButton).pressed.connect(func(): play("ui_click", -4.0))


# ------------------------------------------------------------------ música e ambiente
## Troca a música de fundo (com fade). "" para silêncio.
func music(track: String) -> void:
	if track == current_music:
		return
	current_music = track
	_music_i = _crossfade(_music, _music_i, track, MUSIC_DB)


## Troca o som ambiente (passarinhos, grilos, chuva, caverna). "" para nenhum.
func ambience(track: String) -> void:
	if track == current_ambience:
		return
	current_ambience = track
	_amb_i = _crossfade(_amb, _amb_i, track, AMB_DB)


func _crossfade(players: Array[AudioStreamPlayer], cur: int, track: String, db: float) -> int:
	var old := players[cur]
	var tw := create_tween()
	tw.tween_property(old, "volume_db", -80.0, FADE)
	tw.tween_callback(old.stop)
	if track == "":
		return cur
	var stream := _stream(MUSIC_DIR + track + ".ogg")
	if stream == null:
		return cur
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var nxt := (cur + 1) % 2
	var p := players[nxt]
	p.stream = stream
	p.volume_db = -40.0
	p.play()
	var tw2 := create_tween()
	tw2.tween_property(p, "volume_db", db, FADE)
	return nxt


## Escolhe a música e o ambiente pelo lugar, hora e clima.
func update_scene(in_mine: bool, night: bool, weather: String) -> void:
	var wet := weather in ["rain", "heavy_rain", "storm"]
	if in_mine:
		music("mine")
		ambience("amb_cave")
	elif wet:
		music("farm_rain")
		ambience("amb_rain")
	elif night:
		music("farm_night")
		ambience("amb_night")
	else:
		music("farm_day")
		ambience("amb_birds")


# ------------------------------------------------------------------ volume
func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save_settings()


func _apply_volume() -> void:
	for pair in [["Music", music_volume], ["SFX", sfx_volume]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i < 0:
			continue
		var v: float = pair[1]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	_apply_volume()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS)
