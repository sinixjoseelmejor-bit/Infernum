class_name ParryGauge
extends Node2D
## Jauge de la parade de Job : elle montre les TROIS états, pas seulement la
## recharge.
##
## POURQUOI TROIS. La parade se joue sur une fenêtre de 0,25 s ouverte 0,15 s
## après l'appui. Un joueur qui ne voit pas QUAND elle est ouverte ne peut pas
## apprendre à la placer : il croit que le jeu répond mal, alors que c'est lui
## qui appuie trop tôt. La ruée pouvait se contenter d'une recharge, parce
## qu'elle part à l'instant où on la demande. Pas celle-ci.
##
##   AMORCE    un anneau se resserre vers le corps — « ça arrive »
##   FENÊTRE   un anneau plein et vif — « maintenant »
##   RECHARGE  un arc se remplit, comme pour la ruée — « pas encore »
##
## Le bleu est celui de Job. Il ressemble au bleu de la ruée, et ça ne pose pas
## de problème : les deux appartiennent à des personnages différents et ne
## peuvent pas être à l'écran en même temps.
##
## SANS EFFET DE JEU. Elle lit un état, elle n'en produit aucun.

enum Etat { PRET, AMORCE, FENETRE, RECHARGE }

var decalage_pieds: float = 34.0
var rayon: float = 26.0
var teinte: Color = Color(0.62, 0.80, 0.95)

## Rendus par le joueur.
var etat: int = Etat.PRET
## 0 à 1 : avancement de l'amorce, de la fenêtre ou de la recharge selon l'état.
var progression: float = 0.0
## Éclat de réussite, déclenché par le joueur quand un coup est paré.
var _succes: float = 0.0


func _ready() -> void:
	z_index = -1
	position.y = decalage_pieds


func reussite() -> void:
	_succes = 0.3


func _process(delta: float) -> void:
	_succes = maxf(0.0, _succes - delta)
	# L'état par défaut du jeu n'affiche rien : une jauge pleine en permanence
	# serait un élément d'interface collé au personnage, à regarder sans cesse
	# pour n'y rien lire.
	visible = etat != Etat.PRET or _succes > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	if _succes > 0.0:
		var q := _succes / 0.3
		draw_arc(Vector2.ZERO, rayon * (1.0 + 1.4 * (1.0 - q)), 0.0, TAU, 32,
			Color(1.0, 1.0, 1.0, 0.8 * q), 3.0, true)
	match etat:
		Etat.AMORCE:
			# L'anneau se resserre : le geste est parti, il n'est pas encore là.
			var r := rayon * (2.2 - 1.2 * clampf(progression, 0.0, 1.0))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32,
				Color(teinte.r, teinte.g, teinte.b, 0.45), 2.0, true)
		Etat.FENETRE:
			draw_arc(Vector2.ZERO, rayon, 0.0, TAU, 32,
				Color(teinte.r, teinte.g, teinte.b, 0.95), 3.5, true)
			draw_arc(Vector2.ZERO, rayon * 0.62, 0.0, TAU, 24,
				Color(1.0, 1.0, 1.0, 0.35), 1.5, true)
		Etat.RECHARGE:
			draw_arc(Vector2.ZERO, rayon, 0.0, TAU, 32,
				Color(teinte.r, teinte.g, teinte.b, 0.16), 1.5, true)
			var depart := -PI * 0.5
			draw_arc(Vector2.ZERO, rayon, depart,
				depart + TAU * clampf(progression, 0.0, 1.0), 32,
				Color(teinte.r, teinte.g, teinte.b, 0.7), 2.5, true)
