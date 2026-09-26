class_name LaserBeam
extends Node2D
## Rayon annoncé : une ligne de visée suit le joueur, se VERROUILLE, puis frappe.
##
## Même contrat que [Telegraph], transposé d'un disque à un segment : rien ne
## touche le joueur sans préavis, et la difficulté tient à la lecture, pas à la
## surprise. Le rayon ajoute une chose que les zones de boss ne faisaient pas —
## il sanctionne l'IMMOBILITÉ plutôt que le placement. Une zone se quitte en
## marchant n'importe où ; un rayon ne se quitte qu'en travers.
##
## TROIS TEMPS, et c'est le verrouillage qui porte tout le sens :
##
##   VISÉE        la ligne suit le joueur, fine et sombre. Elle ne dit pas encore
##                où le coup partira, seulement qu'il se prépare.
##   VERROUILLAGE la direction se fige et la ligne s'allume. C'est LE signal, et
##                c'est la seule fenêtre où esquiver veut dire quelque chose.
##   TIR          le trait s'épaissit et frappe une fois, puis s'éteint.
##
## Entièrement dessiné par code — aucun asset, aucune collision. Au moment du
## tir on mesure la distance du joueur au SEGMENT : c'est un test exact, là où
## une zone de collision allongée demanderait un corps et une couche.

## Longueur du trait. Il traverse l'arène : on ne se met pas hors de portée d'un
## rayon, on se met en travers.
@export var length: float = 1100.0
## Demi-largeur de la zone touchée, en pixels. La ligne dessinée est un peu plus
## fine que ça : mieux vaut une image qui promet moins que le coup.
@export var half_width: float = 13.0
## Durée pendant laquelle la visée suit le joueur.
@export var aim_time: float = 0.70
## Durée du verrouillage, direction figée. C'est la fenêtre d'esquive, et elle
## doit rester lisible : en dessous de 0,3 s le rayon devient un coup gratuit.
@export var lock_time: float = 0.38
## Durée d'affichage du trait après le tir.
@export var fire_time: float = 0.16
@export var damage: float = 16.0
@export var knockback: float = 260.0
@export var color: Color = Color(1.0, 0.35, 0.45)
@export var shake: float = 4.0

## Émetteur. Le trait part de lui tant qu'il vit : un œil qu'on repousse
## pendant sa charge emmène son rayon avec lui — et un œil qu'on TUE emporte son
## rayon dans sa chute, voir `_process`.
var source: Node2D

var _direction: Vector2 = Vector2.RIGHT
## Longueur réelle du trait : `length`, ou moins si un obstacle de la carte
## l'arrête. Recalculée à chaque image, puisque l'œil bouge.
var _portee: float = 1100.0
var _elapsed: float = 0.0
var _fired: bool = false
## Vrai si un émetteur a été posé à la création. Sans ce drapeau, un rayon tiré
## sans source s'annulerait immédiatement.
var _a_un_emetteur: bool = false


func _ready() -> void:
	# Au-dessus du décor et du sol, sous les créatures : un rayon ne doit pas
	# masquer ce qu'il menace.
	z_index = -1
	# `source` est posé par l'émetteur AVANT l'entrée dans l'arbre, donc la
	# question a déjà une réponse ici.
	_a_un_emetteur = source != null
	var player := get_tree().get_first_node_in_group(Groups.PLAYER)
	if player != null and is_instance_valid(player):
		_direction = (player.global_position - global_position).normalized()


## TUER L'ÉMETTEUR ANNULE LE RAYON, entièrement.
##
## Le rayon vit dans le conteneur des projectiles, pas sous l'œil : il lui
## survivait donc, et frappait au nom d'un mort. C'était faux deux fois. Faux
## pour le jeu d'abord — toute la faiblesse de l'œil est son immobilité pendant
## la charge, et le README la formule ainsi : « un œil qu'on charge meurt sans
## avoir fini de viser ». Si le trait part quand même, la récompense de l'avoir
## vu venir n'existe plus.
##
## Faux pour le code ensuite : `_tirer` passait `source` à `apply_damage` sans
## vérifier sa validité. Une fois l'œil libéré, l'appel entier échouait sur une
## erreur de type, et le rayon ne blessait donc personne — le bon résultat,
## obtenu par accident, avec une erreur en console et sans que rien ne disparaisse
## à l'écran. Le joueur voyait le trait le traverser sans effet.
##
## `is_queued_for_deletion` compte autant que `is_instance_valid` : `queue_free`
## ne libère qu'en fin d'image, donc sans ce test le rayon tirerait encore une
## fois au nom d'un œil déjà mort.
func _process(delta: float) -> void:
	if _a_un_emetteur and (not is_instance_valid(source) or source.is_queued_for_deletion()):
		queue_free()
		return

	_elapsed += delta
	if is_instance_valid(source):
		global_position = source.global_position
	if _elapsed < aim_time:
		var player := get_tree().get_first_node_in_group(Groups.PLAYER)
		if player != null and is_instance_valid(player):
			var vers: Vector2 = player.global_position - global_position
			if vers.length_squared() > 1.0:
				_direction = vers.normalized()
	elif not _fired and _elapsed >= aim_time + lock_time:
		_fired = true
		_tirer()
	elif _fired and _elapsed >= aim_time + lock_time + fire_time:
		queue_free()
	# UN OBSTACLE ARRÊTE LE RAYON, comme il arrête les projectiles : se mettre à
	# couvert derrière une statue est une esquive, et la ligne dessinée s'arrête
	# là où le coup s'arrêtera.
	_portee = length
	if Carte.courante != null:
		_portee = Carte.courante.portee_libre(global_position, _direction, length)
	queue_redraw()


func _tirer() -> void:
	GameEvents.request_shake(shake)
	var player := get_tree().get_first_node_in_group(Groups.PLAYER)
	if player == null or not is_instance_valid(player):
		return
	if _distance_au_segment(player.global_position) > half_width:
		return
	if player.has_method(&"apply_damage"):
		player.call(&"apply_damage", damage, source, _direction * knockback)


## Distance d'un point au segment [origine, origine + direction * longueur].
## Le rayon n'est pas une demi-droite infinie : se placer DERRIÈRE l'œil est
## une esquive valable, et ce serait faux de la refuser.
func _distance_au_segment(point: Vector2) -> float:
	var vers := point - global_position
	var le_long := vers.dot(_direction)
	if le_long > _portee:
		return INF
	le_long = clampf(le_long, 0.0, _portee)
	return vers.distance_to(_direction * le_long)


func _draw() -> void:
	var fin := _direction * _portee
	if _fired:
		# Le coup : un trait large, un cœur blanc, et une lueur au point de
		# départ pour qu'on voie d'où il vient même en le prenant de plein fouet.
		draw_line(Vector2.ZERO, fin, Color(color.r, color.g, color.b, 0.75),
			half_width * 2.0, true)
		draw_line(Vector2.ZERO, fin, Color(1.0, 0.97, 0.92, 0.95), half_width * 0.7, true)
		draw_circle(Vector2.ZERO, half_width * 1.6, Color(1.0, 0.95, 0.9, 0.7))
		return

	if _elapsed < aim_time:
		# Visée : un fil, presque rien. Il annonce sans encore menacer.
		var charge := clampf(_elapsed / maxf(0.01, aim_time), 0.0, 1.0)
		draw_line(Vector2.ZERO, fin, Color(color.r, color.g, color.b, 0.22), 2.0, true)
		draw_circle(Vector2.ZERO, 3.0 + 7.0 * charge, Color(color.r, color.g, color.b, 0.55))
		return

	# Verrouillage : la ligne s'allume et s'épaissit à mesure. C'est ce
	# changement, et non la ligne elle-même, qui dit qu'il faut bouger.
	var t := clampf((_elapsed - aim_time) / maxf(0.01, lock_time), 0.0, 1.0)
	draw_line(Vector2.ZERO, fin, Color(color.r, color.g, color.b, 0.35 + 0.45 * t),
		2.0 + half_width * 0.9 * t, true)
	draw_circle(Vector2.ZERO, 10.0 + 6.0 * t, Color(1.0, 0.9, 0.9, 0.5 + 0.4 * t))
