class_name Prop
extends StaticBody2D
## Objeto do mundo (árvore, pedra, mato, cogumelo gigante, decoração...).
## Ocupa uma célula da grade. A origem do nó fica na base do objeto,
## para ordenar a profundidade com o jogador (Y-sort).

const FOREST := "res://assets/sprites/forest/"

## tex: lista de variantes (caminhos). tool "" = não pode ser removido.
## shape: tamanho da colisão na base (Vector2.ZERO = sem colisão).
## pad: quantos pixels a base fica acima do fim da imagem.
const DEFS := {
	"tree": {"tex": ["tree_a", "tree_b", "tree_c", "tree_d", "tree_e"], "tool": "axe", "hp": 5,
		"drop": ["wood", 6], "shape": Vector2(18, 10), "pad": 8},
	"sapling": {"tex": ["sapling_a", "sapling_b"], "tool": "axe", "hp": 2,
		"drop": ["wood", 2], "shape": Vector2(10, 6), "pad": 6},
	"stump": {"tex": ["res://assets/sprites/stump.png"], "tool": "axe", "hp": 2,
		"drop": ["wood", 2], "shape": Vector2(18, 10), "pad": 4},
	"rock": {"tex": ["rock_small"], "tool": "pickaxe", "hp": 3,
		"drop": ["stone", 3], "shape": Vector2(30, 12), "pad": 4},
	"weed": {"tex": ["weed_a", "weed_b", "weed_c", "weed_d", "weed_e"], "tool": "scythe", "hp": 1,
		"drop": ["fiber", 1], "shape": Vector2.ZERO, "pad": 3},
	"bush": {"tex": ["bush_a", "bush_b", "bush_c", "bush_d", "bush_e", "bush_f"], "tool": "scythe", "hp": 2,
		"drop": ["fiber", 3], "shape": Vector2(28, 10), "pad": 5},
	"old_tree": {"tex": ["old_tree_a", "old_tree_b", "old_tree_c", "old_tree_d", "old_tree_e"], "tool": "", "hp": 0,
		"drop": [], "shape": Vector2(28, 12), "pad": 14},
	"pine": {"tex": ["pine_a", "pine_b"], "tool": "", "hp": 0,
		"drop": [], "shape": Vector2(20, 10), "pad": 10},
	"boulder": {"tex": ["boulder_a", "boulder_b", "boulder_c", "boulder_d"], "tool": "", "hp": 0,
		"drop": [], "shape": Vector2(80, 22), "pad": 8},
	"mushroom": {"tex": ["mushroom_a", "mushroom_b", "mushroom_c", "mushroom_d"], "tool": "", "hp": 0,
		"drop": [], "shape": Vector2(22, 10), "pad": 6},
	"campfire": {"tex": ["campfire"], "tool": "", "hp": 0, "drop": [], "shape": Vector2(60, 20), "pad": 6},
	"tent": {"tex": ["tent"], "tool": "", "hp": 0, "drop": [], "shape": Vector2(130, 26), "pad": 8},
	"barrel": {"tex": ["barrel"], "tool": "", "hp": 0, "drop": [], "shape": Vector2(20, 10), "pad": 3},
	"crate": {"tex": ["crate"], "tool": "", "hp": 0, "drop": [], "shape": Vector2(24, 10), "pad": 3},
	"fence": {"tex": ["fence"], "tool": "", "hp": 0, "drop": [], "shape": Vector2(40, 8), "pad": 4},
}

static var _tex_cache := {}

var kind := ""
var variant := 0
var cell := Vector2i.ZERO
var hp := 1
var _sprite: Sprite2D


static func texture_for(path: String) -> Texture2D:
	if not path.begins_with("res://"):
		path = FOREST + path + ".png"
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


static func variant_count(p_kind: String) -> int:
	return DEFS[p_kind]["tex"].size()


func setup(p_kind: String, p_cell: Vector2i, tile_size: int, p_hp: int = -1, p_variant: int = 0) -> void:
	kind = p_kind
	cell = p_cell
	var def: Dictionary = DEFS[kind]
	var texs: Array = def["tex"]
	variant = clampi(p_variant, 0, texs.size() - 1)
	hp = p_hp if p_hp > 0 else int(def["hp"])
	position = Vector2(cell.x * tile_size + tile_size / 2, cell.y * tile_size + tile_size - 4)

	var tex := texture_for(texs[variant])
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = false
	_sprite.offset = Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height() + int(def["pad"]))
	add_child(_sprite)

	var size: Vector2 = def["shape"]
	if size != Vector2.ZERO:
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(min(size.x, tex.get_width() * 0.8), size.y)
		col.shape = rect
		col.position = Vector2(0, -size.y / 2 + 2)
		add_child(col)
	else:
		collision_layer = 0


func required_tool() -> String:
	return DEFS[kind]["tool"]


func is_removable() -> bool:
	return required_tool() != ""


## Aplica um golpe. Retorna true se o objeto foi destruído.
func hit() -> bool:
	if not is_removable():
		return false
	hp -= 1
	var tw := create_tween()
	tw.tween_property(_sprite, "position:x", 2.0, 0.04)
	tw.tween_property(_sprite, "position:x", -2.0, 0.06)
	tw.tween_property(_sprite, "position:x", 0.0, 0.04)
	return hp <= 0


func drops() -> Array:
	return DEFS[kind]["drop"]
