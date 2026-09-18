class_name DashGauge
extends Node2D
## Jauge de recharge de la ruée : un arc aux pieds, qui se REMPLIT.
##
## POURQUOI ELLE EXISTE. Une ruée sur recharge sans rien afficher donne un
## bouton qui répond une fois sur trois, et le joueur ne peut pas savoir si
## c'est le jeu ou lui. Ce n'est pas de la difficulté, c'est du bruit — la même
## raison qui a fait dessiner la chaîne d'Asmodée et l'anneau de la seconde
## chance.
##
## POURQUOI ELLE NE RESSEMBLE PAS À L'ANNEAU DE LA SECONDE CHANCE, alors que les
## deux sont des arcs aux pieds du joueur. Trois différences délibérées, parce
## que deux jauges qui se ressemblent au même endroit se confondent :
##
##   | | Seconde chance | Ruée |
##   | sens   | se VIDE         | se REMPLIT |
##   | rayon  | 56 px           | 26 px      |
##   | teinte | doré            | bleu froid |
##
## Elle ne se montre QUE pendant la recharge, et disparaît dès que la ruée est
## disponible : l'état par défaut du jeu ne doit rien afficher. Une jauge pleine
## en permanence serait un élément d'interface collé au personnage, à regarder
## sans cesse pour n'y rien lire.
##
## SANS EFFET DE JEU. Elle lit un état, elle n'en produit aucun.

## Aux pieds, comme tout ce qui se pose au sol : les planches sont des images de
## 100 px où le dessin flotte au milieu, donc l'origine du nœud tombe à mi-corps.
var decalage_pieds: float = 34.0
var rayon: float = 26.0
var teinte: Color = Color(0.72, 0.88, 1.0)

## Rendu par le joueur : de 0 (vient de foncer) à 1 (prêt).
var remplissage: float = 1.0

var _eclair: float = 0.0
var _precedent: float = 1.0


func _ready() -> void:
	z_index = -1
	position.y = decalage_pieds


func _process(delta: float) -> void:
	# L'ÉCLAIR DE DISPONIBILITÉ. La jauge disparaît à l'instant où elle se
	# remplit, donc son dernier état est aussi celui qu'on voit le moins. Sans un
	# bref éclat au franchissement, le seul moment qui intéresse le joueur —
	# « c'est bon, je peux repartir » — serait le seul qu'il ne verrait pas.
	if remplissage >= 1.0 and _precedent < 1.0:
		_eclair = 0.22
	_precedent = remplissage
	_eclair = maxf(0.0, _eclair - delta)
	visible = remplissage < 1.0 or _eclair > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	if _eclair > 0.0:
		var p := _eclair / 0.22
		draw_arc(Vector2.ZERO, rayon * (1.0 + 0.9 * (1.0 - p)), 0.0, TAU, 32,
			Color(teinte.r, teinte.g, teinte.b, 0.7 * p), 2.5, true)
	if remplissage >= 1.0:
		return
	# La piste d'abord : un arc seul dit qu'il grandit, pas jusqu'où il va.
	draw_arc(Vector2.ZERO, rayon, 0.0, TAU, 32,
		Color(teinte.r, teinte.g, teinte.b, 0.16), 1.5, true)
	var depart := -PI * 0.5
	draw_arc(Vector2.ZERO, rayon, depart, depart + TAU * remplissage, 32,
		Color(teinte.r, teinte.g, teinte.b, 0.75), 2.5, true)
