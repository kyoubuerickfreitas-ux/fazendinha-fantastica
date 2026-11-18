class_name NPC
extends Interactable
## Habitante do vilarejo. Por enquanto: Fungo, o vendedor de sementes.

const SHEET := preload("res://assets/sprites/npc_fungo.png")

var npc_name := "Fungo"
var _sprite: Sprite2D
var _bubble: Sprite2D
var _t := 0.0


func _ready() -> void:
	reach = 40.0
	label = "Conversar"
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = 2
	_sprite.position = Vector2(0, -26)
	add_child(_sprite)

	_bubble = Sprite2D.new()
	_bubble.texture = ItemDB.ui_icon("bubble")
	_bubble.position = Vector2(14, -54)
	add_child(_bubble)

	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 8)
	col.shape = shape
	col.position = Vector2(0, -4)
	body.add_child(col)
	add_child(body)


func _process(delta: float) -> void:
	_t += delta
	_sprite.frame = int(_t * 2.0) % 2
	_bubble.position.y = -54 + sin(_t * 3.0) * 1.5
