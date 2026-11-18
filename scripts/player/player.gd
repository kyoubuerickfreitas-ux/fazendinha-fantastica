class_name Player
extends CharacterBody2D
## Personagem do jogador: movimento livre em 8 direções, animação em 4 direções.
## Spritesheet 7x4 de 64x64. Linhas: baixo, esquerda, direita, cima.
## Coluna 0 = parado, colunas 1..6 = caminhada.

const SHEET := preload("res://assets/sprites/player.png")
const SPEED := 85.0
const REACH := 20.0
const ACTION_TIME := 0.28
const COLS := 7
const WALK_FRAMES := 6

enum Dir { DOWN, LEFT, RIGHT, UP }

var world: FarmWorld
var facing := Vector2.DOWN
var _dir := Dir.DOWN
var _anim_t := 0.0
var _busy := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = COLS
	_sprite.vframes = 4
	_sprite.position = Vector2(0, -26)
	add_child(_sprite)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 8)
	col.shape = shape
	col.position = Vector2(0, -4)
	add_child(col)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	var v := Game.joystick_vector
	var key := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if key != Vector2.ZERO:
		v = key
	if v.length() > 1.0:
		v = v.normalized()
	if Game.ui_lock > 0 or _busy > 0.0:
		v = Vector2.ZERO
	_busy = max(0.0, _busy - delta)

	velocity = v * SPEED
	move_and_slide()

	if v.length() > 0.15:
		facing = v.normalized()
		if abs(v.x) > abs(v.y) * 1.1:
			_dir = Dir.RIGHT if v.x > 0 else Dir.LEFT
		else:
			_dir = Dir.DOWN if v.y > 0 else Dir.UP
		_anim_t += delta * (7.0 + 5.0 * v.length())
		_sprite.frame = _dir * COLS + 1 + int(_anim_t) % WALK_FRAMES
	else:
		_anim_t = 0.0
		_sprite.frame = _dir * COLS

	if world:
		world.set_cursor(target_cell(), Game.ui_lock == 0)


## Direção (4 lados) para a qual o personagem está virado.
func facing_vector() -> Vector2:
	match _dir:
		Dir.LEFT: return Vector2.LEFT
		Dir.RIGHT: return Vector2.RIGHT
		Dir.UP: return Vector2.UP
	return Vector2.DOWN


func target_point() -> Vector2:
	return global_position + Vector2(0, -6) + facing_vector() * REACH


func target_cell() -> Vector2i:
	return world.cell_of(target_point())


func use_tool() -> void:
	if _busy > 0.0 or Game.ui_lock > 0 or world == null:
		return
	_busy = ACTION_TIME
	_play_action_anim()
	var msg := world.use_item(Game.selected_item_id(), target_cell())
	if msg != "":
		Game.toast.emit(msg)


func interact() -> void:
	if Game.ui_lock > 0 or world == null:
		return
	var it := find_interactable()
	if it:
		it.interact(self)
		return
	var msg := world.interact_cell(target_cell())
	if msg != "":
		Game.toast.emit(msg)


func find_interactable() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	var p := target_point()
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		var d := it.global_position.distance_to(p)
		if d < it.reach and d < best_d:
			best = it
			best_d = d
	return best


func _play_action_anim() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.12, 0.9), 0.07)
	tw.tween_property(_sprite, "scale", Vector2.ONE, 0.12)
