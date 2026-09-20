class_name MarkGauge
extends Node2D
## Jauge de la Marque de Caïn : un arc aux pieds, qui se remplit en tuant.
##
## POURQUOI ELLE EXISTE. Le Prix du sang dépense une ressource que RIEN
## n'affichait : la Marque montait et retombait sans qu'on la voie jamais. Un
## pouvoir dont on ignore la charge n'est pas un choix, c'est une loterie — et
## le choix est tout ce que ce pouvoir apporte.
##
## ELLE NE SE CONFOND AVEC AUCUNE DES DEUX AUTRES, et il fallait y veiller : il y
## a déjà deux arcs aux pieds du joueur.
##
##   | | Seconde chance | Ruée | Marque |
##   | sens   | se vide | se remplit | se remplit |
##   | rayon  | 56 px   | 26 px      | 26 px      |
##   | teinte | doré    | bleu froid | rouge sang |
##
## Le rayon est celui de la ruée, et c'est volontaire : les deux appartiennent à
## des personnages différents, ils ne peuvent pas être à l'écran en même temps.
## La teinte, elle, est celle de Caïn.
##
## ELLE RESTE VISIBLE tant qu'il y a de la Marque, contrairement à la jauge de
## ruée qui disparaît une fois pleine. Les deux règles disent la même chose :
## on n'affiche que ce qui se décide. Une recharge finie ne se décide plus, une
## Marque chargée si.
##
## SANS EFFET DE JEU. Elle lit un état, elle n'en produit aucun.

## Aux pieds : les planches sont des images de 100 px où le dessin flotte au
## milieu, donc l'origine du nœud tombe à mi-corps.
var decalage_pieds: float = 34.0
var rayon: float = 26.0
var teinte: Color = Color(0.85, 0.22, 0.18)

## Rendu par le joueur : 0 (Marque vide) à 1 (plafond atteint).
var remplissage: float = 0.0
## En dessous, le coup ne part pas : l'arc le dit en restant terne.
var minimum: float = 0.25

var _eclair: float = 0.0
var _precedent: float = 0.0


func _ready() -> void:
	z_index = -1
	position.y = decalage_pieds


func _process(delta: float) -> void:
	# L'ÉCLAIR DE DISPONIBILITÉ, au franchissement du minimum et non au plafond :
	# c'est l'instant où le pouvoir devient utilisable, et c'est le seul que le
	# joueur a besoin de ne pas manquer. Le plafond, lui, se voit à l'arc plein.
	if remplissage >= minimum and _precedent < minimum:
		_eclair = 0.22
	_precedent = remplissage
	_eclair = maxf(0.0, _eclair - delta)
	visible = remplissage > 0.001
	if visible:
		queue_redraw()


func _draw() -> void:
	if _eclair > 0.0:
		var p := _eclair / 0.22
		draw_arc(Vector2.ZERO, rayon * (1.0 + 0.9 * (1.0 - p)), 0.0, TAU, 32,
			Color(teinte.r, teinte.g, teinte.b, 0.7 * p), 2.5, true)
	# La piste d'abord : un arc seul dit qu'il grandit, pas jusqu'où il va.
	draw_arc(Vector2.ZERO, rayon, 0.0, TAU, 32,
		Color(teinte.r, teinte.g, teinte.b, 0.16), 1.5, true)
	var pret := remplissage >= minimum
	var depart := -PI * 0.5
	draw_arc(Vector2.ZERO, rayon, depart, depart + TAU * clampf(remplissage, 0.0, 1.0), 32,
		Color(teinte.r, teinte.g, teinte.b, 0.75 if pret else 0.30), 2.5, true)
