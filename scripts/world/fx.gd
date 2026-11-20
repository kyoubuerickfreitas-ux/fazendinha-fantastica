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
}

var _frames := 1
var _row := 0
var _t := 0.0


static func spawn(parent: Node, preset: String, pos: Vector2) -> void:
	if not PRESETS.has(preset):
		return
	if SOUNDS.has(preset):
		Sound.play(SOUNDS[preset], -2.0)
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
	parent.add_child(fx)


func _process(delta: float) -> void:
	_t += delta * FPS
	var i := int(_t)
	if i >= _frames:
		queue_free()
		return
	frame = _row * _frames + i
