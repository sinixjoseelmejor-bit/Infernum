class_name ReviveBurst
extends Node2D
## LA SECONDE CHANCE SE VOIT — et surtout, on voit COMBIEN DE TEMPS elle dure.
##
## Le nœud de Forge « Seconde chance » relève le joueur à mi-vie sur le coup
## fatal et le rend intouchable un instant. Rien ne le montrait : le joueur
## prenait le même éclair rouge et la même secousse que pour n'importe quel
## coup encaissé, en un peu plus fort. Il ne savait donc ni qu'il venait d'être
## sauvé, ni — et c'est la partie qui coûte des runs — qu'il disposait d'une
## fenêtre pour s'extraire de ce qui l'avait tué.
##
## L'EFFET EST EN DEUX TEMPS, et le second porte l'information :
##
##   ÉCLAT   une onde part du corps et des rais s'échappent. C'est le « il s'est
##           passé quelque chose », et il est doré : le rouge dirait « touché ».
##   COMPTE  un anneau se vide comme un cadran pendant TOUTE l'invulnérabilité,
##           et disparaît exactement quand elle s'arrête. Ce n'est pas une
##           décoration qui dure à peu près aussi longtemps : c'est la mesure de
##           la protection restante, et c'est pour ça que `duree` est posée par
##           le joueur à partir de la même valeur qu'il donne à `Health.revive`.
##
## Dessiné par code plutôt qu'en planche d'images, pour la même raison que la
## chaîne d'Asmodée : l'anneau de compte à rebours dépend d'une valeur connue à
## l'exécution seulement, et aucune animation pré-rendue ne peut se vider au bon
## rythme si la durée d'invulnérabilité change un jour.
##
## SANS EFFET DE JEU. Il ne blesse rien, ne bloque rien, ne protège rien — la
## protection vit dans `Health`. On peut le supprimer à tout moment.

## Durée totale : celle de l'invulnérabilité accordée par la seconde chance.
var duree: float = 1.5
## Durée de l'onde de départ.
var eclat: float = 0.45
## Rayon de l'anneau de compte à rebours. Essayé à 34 px : à l'écran il tombait
## SUR le personnage et l'arc restant se lisait comme une rayure au-dessus de sa
## tête. À 56 il entoure ses pieds et se lit d'un coup d'œil, sans pour autant
## atteindre la taille d'une zone de boss (78 à 135 px), qu'il ne doit jamais
## imiter : celles-là annoncent un dégât.
var rayon_anneau: float = 56.0
## L'effet est posé aux PIEDS et non à l'origine du nœud. Les planches sont des
## images de 100 px où le dessin flotte au milieu : l'origine tombe à mi-corps et
## les pieds 37,5 px plus bas (valeur mesurée, voir le tri du décor). Un cercle
## au sol centré à mi-corps donne un personnage coupé en deux.
var decalage_pieds: float = 34.0
## Doré et non rouge : le rouge est la couleur du coup encaissé dans tout le
## jeu, et un sauvetage peint en rouge se lirait comme un dégât de plus.
var teinte: Color = Color(1.0, 0.84, 0.42)
var rais: int = 10

var _temps: float = 0.0


func _ready() -> void:
	# Derrière le personnage : l'anneau l'entoure, il ne doit pas le masquer au
	# moment précis où le joueur cherche où aller.
	z_index = -1
	position.y = decalage_pieds


func _process(delta: float) -> void:
	_temps += delta
	if _temps >= duree:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var restant := clampf(1.0 - _temps / maxf(0.01, duree), 0.0, 1.0)

	# La piste, puis l'arc qui s'y vide. SANS LA PISTE il n'y a pas de jauge :
	# un arc seul ne dit pas sur quelle course il se vide, donc il ne dit pas
	# combien il reste — il dit seulement qu'il rétrécit.
	draw_arc(Vector2.ZERO, rayon_anneau, 0.0, TAU, 56,
		Color(teinte.r, teinte.g, teinte.b, 0.20), 2.0, true)
	# Il part du haut et se vide dans le sens des aiguilles : c'est la lecture
	# d'un cadran, elle n'a pas à être apprise.
	var depart := -PI * 0.5
	if restant > 0.0:
		draw_arc(Vector2.ZERO, rayon_anneau, depart, depart + TAU * restant, 56,
			Color(teinte.r, teinte.g, teinte.b, 0.95), 5.0, true)
	# Un voile qui bat sous l'anneau. Sans lui, l'anneau seul se perd sur un sol
	# clair ; avec, le personnage est posé sur une tache qui ne ressemble à rien
	# d'autre dans le jeu. Il ne s'efface que sur le DERNIER QUART : fondu sur
	# toute la durée, il avait déjà disparu à mi-protection et laissait croire
	# qu'elle était finie.
	var fin := clampf(restant / 0.25, 0.0, 1.0)
	var battement := 0.13 + 0.06 * sin(_temps * 13.0)
	draw_circle(Vector2.ZERO, rayon_anneau * 0.95,
		Color(teinte.r, teinte.g, teinte.b, battement * fin))

	if _temps >= eclat:
		return

	# L'onde de départ : elle s'ouvre vite puis ralentit, et s'amincit en
	# s'élargissant — une onde qui garde son épaisseur lit comme un disque qui
	# grossit, pas comme une détonation.
	var p := clampf(_temps / maxf(0.01, eclat), 0.0, 1.0)
	var ouverture := 1.0 - pow(1.0 - p, 3.0)
	var rayon := lerpf(14.0, 132.0, ouverture)
	var reste := 1.0 - p
	draw_arc(Vector2.ZERO, rayon, 0.0, TAU, 64,
		Color(teinte.r, teinte.g, teinte.b, 0.75 * reste), lerpf(9.0, 1.5, p), true)
	draw_arc(Vector2.ZERO, rayon, 0.0, TAU, 64,
		Color(1.0, 0.98, 0.92, 0.55 * reste), lerpf(3.5, 0.8, p), true)

	# Les rais. Ils partent du corps et se détachent de l'onde en la suivant :
	# c'est ce décrochage qui donne une direction à l'effet, là où un anneau seul
	# se contente de grandir.
	var interne := lerpf(8.0, rayon * 0.62, ouverture)
	for i in rais:
		var angle := TAU * float(i) / float(maxi(1, rais))
		var axe := Vector2.RIGHT.rotated(angle)
		draw_line(axe * interne, axe * rayon,
			Color(1.0, 0.95, 0.85, 0.5 * reste * reste), 2.0, true)
