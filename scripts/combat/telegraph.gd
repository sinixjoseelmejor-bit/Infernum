class_name Telegraph
extends Node2D
## Zone d'impact annoncée : un cercle se remplit, puis frappe.
##
## Toute la lisibilité des combats de boss repose dessus. Un boss ne touche
## jamais le joueur sans préavis : la difficulté vient du nombre de zones et de
## leur placement, pas d'un coup impossible à lire.
##
## Entièrement dessinée par code — aucun asset, aucune collision : au moment de
## la détonation on teste simplement la distance au joueur.

@export var radius: float = 90.0
## Délai avant détonation. C'est la fenêtre d'esquive.
@export var delay: float = 0.9
@export var damage: float = 18.0
@export var knockback: float = 220.0
@export var color: Color = Color(1.0, 0.35, 0.2)
@export var shake: float = 3.0
## Durée d'affichage du flash après l'impact.
@export var flash_time: float = 0.22
## Effet joué à la détonation, mis à l'échelle du rayon. Facultatif : le flash
## dessiné suffit pour les zones de boss, qui partent par grappes de huit et
## n'ont pas besoin qu'on en rajoute. Une détonation ISOLÉE, elle, se remarque
## mal — c'est le cas des chairs volatiles.
@export var impact_scene: PackedScene
## Largeur utile du dessin dans l'effet, en pixels, pour que la mise à l'échelle
## corresponde vraiment au rayon annoncé.
@export var impact_content_width: float = 111.0

var _elapsed: float = 0.0
var _fired: bool = false


func _ready() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if not _fired and _elapsed >= delay:
		_fired = true
		_detonate()
	elif _fired and _elapsed >= delay + flash_time:
		queue_free()


func _detonate() -> void:
	GameEvents.request_shake(shake)
	_spawn_impact()
	var player := get_tree().get_first_node_in_group(Groups.PLAYER)
	if player == null or not is_instance_valid(player):
		return
	var offset: Vector2 = player.global_position - global_position
	if offset.length() > radius:
		return
	if player.has_method(&"apply_damage"):
		player.call(&"apply_damage", damage, null, offset.normalized() * knockback)


## L'effet est monté sur le PARENT et non sur la zone : la zone se libère
## `flash_time` après la détonation, ce qui couperait l'animation en plein vol.
func _spawn_impact() -> void:
	if impact_scene == null:
		return
	var effet := impact_scene.instantiate() as Node2D
	if effet == null:
		return
	var hote := get_parent()
	if hote == null:
		return
	hote.add_child(effet)
	effet.global_position = global_position
	effet.scale = Vector2.ONE * (radius * 2.0 / maxf(1.0, impact_content_width))


func _draw() -> void:
	var progress := clampf(_elapsed / maxf(0.01, delay), 0.0, 1.0)
	if _fired:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.95, 0.85, 0.55))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color.WHITE, 4.0, true)
		return
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.14))
	# Le disque intérieur se remplit : le joueur lit le temps qu'il lui reste.
	draw_circle(Vector2.ZERO, radius * progress, Color(color.r, color.g, color.b, 0.30))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, color, 3.0, true)
