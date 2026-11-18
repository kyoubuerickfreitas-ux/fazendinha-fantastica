class_name Interactable
extends Node2D
## Qualquer coisa com a qual o jogador pode interagir pelo botão da mão
## (personagens, caixa de vendas, porta de casa...).
## O jogo procura o Interactable mais próximo do ponto à frente do jogador.

signal interacted(who: Node)

@export var label := ""
@export var reach := 30.0


func _enter_tree() -> void:
	add_to_group("interactable")


func interact(who: Node) -> void:
	interacted.emit(who)
