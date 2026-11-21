class_name FX
extends Sprite2D
## Efeito visual animado de uso único (poeira, respingo, brilho...).
## As folhas de efeito têm quadros de 64x64 e 9 linhas de cores:
## 0 vermelho, 1 roxo, 2 azul, 3 verde, 4 marrom, 5 branco, 6 lilás, 7 rosa, 8 índigo.

const SHEETS := {
	"dust": preload("res://assets/fx/fx_dust.png"),
	"splash": preload("res://assets/fx/fx_splash.png"),
	"puff": preload("res://assets/fx/fx_puff.png"),
	"cloud": preload("res://assets/fx/fx_cloud.png"),
	"sparkle": preload("res://assets/fx/fx_sparkle.png"),
	"pop": preload("res://assets/fx/fx_pop.png"),
	# pacote "Effect and FX Pixel" (só os usados): fogo, vapor, anel, impacto, estrela, explosão, bolha
	"fire": preload("res://assets/fx/fx_fire.png"),
	"steam": preload("res://assets/fx/fx_steam.png"),
	"ring": preload("res://assets/fx/fx_ring.png"),
	"impact": preload("res://assets/fx/fx_impact.png"),
	"star": preload("res://assets/fx/fx_star.png"),
	"burst": preload("res://assets/fx/fx_burst.png"),
	"bubble": preload("res://assets/fx/fx_bubble.png"),
}
## Som de cada efeito (o golpe "hit" toca o som certo em quem chama: madeira ou pedra).
const SOUNDS := {"till": "till", "water": "water", "break_wood": "break_wood", "break_stone": "break_stone",
	"harvest": "harvest", "plant": "plant", "weed": "weed"}
const ROWS := 9
const FPS := 22.0

enum Color9 { RED, PURPLE, BLUE, GREEN, BROWN, WHITE, LILAC, PINK, INDIGO }

## Qual efeito usar em cada ação do jogo.
const PRESETS := {
	"till": ["dust", Color9.BROWN, 0.7],
	"water": ["splash", Color9.BLUE, 0.6],
	"hit": ["puff", Color9.WHITE, 0.45],
	"break_wood": ["cloud", Color9.BROWN, 0.7],
	"break_stone": ["cloud", Color9.WHITE, 0.7],
	"harvest": ["sparkle", Color9.GREEN, 0.8],
	"plant": ["pop", Color9.GREEN, 0.6],
	"weed": ["dust", Color9.GREEN, 0.6],
	"hit_stone": ["impact", Color9.WHITE, 0.45],     # picareta na pedra
	"ripple": ["ring", Color9.BLUE, 0.55],           # boia na água (lançar e fisgada)
	"catch": ["star", Color9.BROWN, 0.75],           # peixe pego, nível novo
	"gem": ["burst", Color9.LILAC, 0.7],             # gema e cristal na mina
	"fill": ["bubble", Color9.BLUE, 0.5],            # encher o regador
	"steam": ["steam", Color9.WHITE, 0.55],          # prato pronto
	"fire": ["fire", Color9.WHITE, 0.32, Color(1.6, 0.95, 0.35)],  # fogo do fogão (embaixo da panela), tingido de laranja
	"fire_small": ["fire", Color9.WHITE, 0.24, Color(1.6, 0.85, 0.3)],  # boca da fornalha
	"smoke": ["steam", Color9.WHITE, 0.45, Color(0.85, 0.85, 0.85, 0.95)],  # fumaça da chaminé              # fogo do fogão (em loop)
}

var _frames := 1
var loop := false
var _row := 0
var _t := 0.0


## Efeito que fica repetindo (o fogo do fogão). Tire com queue_free().
static func spawn_loop(parent: Node, preset: String, pos: Vector2) -> FX:
	var fx := _make(preset, pos)
	fx.loop = true
	parent.add_child(fx)
	return fx


static func _make(preset: String, pos: Vector2) -> FX:
	var p: Array = PRESETS[preset]
	var fx := FX.new()
	fx.texture = SHEETS[p[0]]
	fx._frames = fx.texture.get_width() / 64
	fx._row = p[1]
	fx.hframes = fx._frames
	fx.vframes = ROWS
	fx.frame = fx._row * fx._frames
	fx.scale = Vector2.ONE * float(p[2])
	fx.position = pos
	fx.z_index = 40
	if p.size() > 3:
		fx.modulate = p[3]
	return fx


static func spawn(parent: Node, preset: String, pos: Vector2) -> void:
	if not PRESETS.has(preset):
		return
	if SOUNDS.has(preset):
		Sound.play(SOUNDS[preset], -2.0)
	parent.add_child(_make(preset, pos))


func _process(delta: float) -> void:
	_t += delta * FPS
	var i := int(_t)
	if i >= _frames:
		if loop:
			_t = 0.0
			i = 0
		else:
			queue_free()
			return
	frame = _row * _frames + i
