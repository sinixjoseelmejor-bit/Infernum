class_name Encensoir
extends Node2D
## L'ENCENSOIR (0.9.2) : deux flammes qui tournent autour du joueur et brûlent
## ce qu'elles touchent.
##
## LE SEUL OBJET QUI FRAPPE AU CONTACT. Tout le reste du catalogue sert l'arme,
## qui tire de loin et vise seule : celui-ci paie le joueur qui se tient PRÈS de
## la foule, c'est-à-dire l'inverse de ce que fait naturellement un jeu à tir
## automatique. C'est une façon de jouer, pas une statistique.
##
## PLUS LOIN QUE LES ICÔNES D'OBJETS. `ItemOrbit` les fait flotter entre 49 et
## 71 px ; à 110 px les flammes tournent hors de ce cercle, et leur rythme —
## régulier, rapide — les distingue d'icônes qui dérivent. Ce qui blesse ne
## doit pas ressembler à ce qui décore.
##
## Posé et nourri par `ItemEffects` : il ne connaît ni l'arme ni le joueur,
## seulement des dégâts et un auteur. Dessiné par code pour la raison qui vaut
## pour l'onde de parade : sa portée est connue à l'exécution.

## Part des dégâts d'un tir de l'arme, par touche.
const RATIO := 0.60
const RAYON := 110.0
## Radians par seconde : un tour en 2,6 s. Plus lent, une foule le contourne
## entre deux passages ; plus rapide, on ne voit plus deux flammes mais un
## anneau, et on ne lit plus où elles sont.
const VITESSE := 2.4
## Portée d'une flamme autour de son centre, mesurée du centre de l'ennemi.
const PORTEE := 34.0
## Une même flamme ne retouche pas le même corps avant ce délai.
const RECHARGE := 0.5
const FLAMMES := 2

var degats: float = 0.0
var auteur: Node = null

var _angle: float = 0.0
var _temps: float = 0.0
## Clé : identifiant du corps × nombre de flammes + flamme -> temps restant.
var _touches: Dictionary = {}


func _ready() -> void:
	# Au-dessus du sol et des corps, sous l'interface.
	z_index = 20
	top_level = true


func _physics_process(delta: float) -> void:
	_angle = wrapf(_angle + VITESSE * delta, 0.0, TAU)
	_temps += delta
	for cle in _touches.keys():
		_touches[cle] -= delta
		if _touches[cle] <= 0.0:
			_touches.erase(cle)
	if degats > 0.0:
		_frapper()
	queue_redraw()


func position_flamme(i: int) -> Vector2:
	return Vector2.from_angle(_angle + TAU * float(i) / float(FLAMMES)) * RAYON


func _frapper() -> void:
	var centres: Array[Vector2] = []
	for i in FLAMMES:
		centres.append(global_position + position_flamme(i))
	var origine: Node = auteur if is_instance_valid(auteur) else null
	for noeud in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var ennemi := noeud as Node2D
		if ennemi == null or ennemi.is_queued_for_deletion():
			continue
		# Tri grossier d'abord : la plupart des corps sont loin des deux flammes.
		if ennemi.global_position.distance_squared_to(global_position) \
				> (RAYON + PORTEE) * (RAYON + PORTEE):
			continue
		for i in FLAMMES:
			if ennemi.global_position.distance_to(centres[i]) > PORTEE:
				continue
			var cle := ennemi.get_instance_id() * FLAMMES + i
			if _touches.has(cle):
				continue
			_touches[cle] = RECHARGE
			var poussee := (ennemi.global_position - global_position).normalized() * 160.0
			ennemi.call(&"apply_damage", degats, origine, poussee)
			GameEvents.damage_dealt.emit(degats, centres[i], false)
			ItemEffects.sur_coup(ennemi, degats, false, origine)
			if ennemi.is_queued_for_deletion():
				break


## OR, ET NON ORANGE. La première version reprenait l'orange du feu : vue en
## capture, chaque flamme passait pour un tir de Caïn — mêmes ronds, même
## couleur, même traînée. L'or de l'encens (celui de Job et de la
## Consécration) dit « sacré » et non « projectile », et un cercle à peine
## visible trace la portée : on sait où les flammes passeront avant qu'elles
## y soient.
const OR_HALO := Color(1.0, 0.82, 0.38, 0.26)
const OR_CORPS := Color(1.0, 0.86, 0.48, 0.92)
const OR_COEUR := Color(1.0, 0.98, 0.88, 1.0)

func _draw() -> void:
	draw_arc(Vector2.ZERO, RAYON, 0.0, TAU, 64, Color(1.0, 0.86, 0.5, 0.10), 2.0, true)
	for i in FLAMMES:
		var p := position_flamme(i)
		# Une traînée courte dit le sens de rotation, donc d'où la flamme vient.
		for t in 5:
			var recul := float(t + 1) * 0.1
			var q := Vector2.from_angle(_angle - recul + TAU * float(i) / float(FLAMMES)) * RAYON
			draw_circle(q, 9.0 - float(t) * 1.5, Color(1.0, 0.84, 0.45, 0.30 - float(t) * 0.055))
		var battement := 1.0 + sin(_temps * 17.0 + float(i) * 2.1) * 0.12
		draw_circle(p, 19.0 * battement, OR_HALO)
		draw_circle(p, 11.0 * battement, OR_CORPS)
		draw_circle(p, 5.5, OR_COEUR)
