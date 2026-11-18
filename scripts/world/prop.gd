class_name Prop
extends StaticBody2D
## Obstáculo do mundo (árvore, toco, pedra, mato...). Ocupa uma célula da grade.
## A origem do nó fica na base do objeto, para ordenar a profundidade (Y-sort).

const DEFS := {
	"tree": {"tex": preload("res://assets/sprites/tree.png"), "tool": "axe", "hp": 4,
		"drop": ["wood", 5], "shape": Vector2(16, 8), "y": -44},
	"tree_big": {"tex": preload("res://assets/sprites/tree_big.png"), "tool": "", "hp": 0,
		"drop": [], "shape": Vector2(18, 10), "y": -44},
	"stump": {"tex": preload("res://assets/sprites/stump.png"), "tool": "axe", "hp": 2,
		"drop": ["wood", 2], "shape": Vector2(18, 10), "y": -12},
	"rock": {"tex": preload("res://assets/sprites/rock.png"), "tool": "pickaxe", "hp": 2,
		"drop": ["stone", 2], "shape": Vector2(22, 10), "y": -12},
	"weed": {"tex": preload("res://assets/sprites/weed.png"), "tool": "scythe", "hp": 1,
		"drop": ["fiber", 1], "shape": Vector2.ZERO, "y": -12},
}

var kind := ""
var cell := Vector2i.ZERO
var hp := 1
var _sprite: Sprite2D


func setup(p_kind: String, p_cell: Vector2i, tile_size: int, p_hp: int = -1) -> void:
	kind = p_kind
	cell = p_cell
	var def: Dictionary = DEFS[kind]
	hp = p_hp if p_hp > 0 else int(def["hp"])
	position = Vector2(cell.x * tile_size + tile_size / 2, cell.y * tile_size + tile_size - 4)
	_sprite = Sprite2D.new()
	_sprite.texture = def["tex"]
	_sprite.position = Vector2(0, def["y"])
	add_child(_sprite)
	var size: Vector2 = def["shape"]
	if size != Vector2.ZERO:
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		col.shape = rect
		col.position = Vector2(0, -size.y / 2 + 2)
		add_child(col)
	else:
		collision_layer = 0


func required_tool() -> String:
	return DEFS[kind]["tool"]


## Aplica um golpe. Retorna true se o objeto foi destruído.
func hit() -> bool:
	if required_tool() == "":
		return false
	hp -= 1
	var tw := create_tween()
	tw.tween_property(_sprite, "position:x", 2.0, 0.04)
	tw.tween_property(_sprite, "position:x", -2.0, 0.06)
	tw.tween_property(_sprite, "position:x", 0.0, 0.04)
	return hp <= 0


func drops() -> Array:
	return DEFS[kind]["drop"]
