class_name ChainLash
extends Node2D
## LA CHAÎNE DE SALOMON : le lien qu'Asmodée jette sur le joueur pour le ramener.
##
## Elle n'existait pas. Le boss tirait le joueur, lui infligeait des dégâts et
## faisait trembler la caméra, mais RIEN N'ÉTAIT DESSINÉ entre les deux : le
## joueur se voyait aspiré vers un ennemi sans qu'aucune image n'explique
## pourquoi. C'est le seul effet du jeu à modifier la position du joueur, et
## c'était le seul à ne rien montrer.
##
## Elle est dessinée par code, et c'est le bon choix ici plutôt qu'une planche
## d'images : ses deux extrémités bougent toutes les deux pendant l'animation,
## sa longueur varie du simple au triple selon la distance, et le nombre de
## maillons doit suivre. Un sprite étiré donnerait des maillons ovales, un
## sprite répété demanderait la même logique qu'ici pour un résultat identique.
##
## SANS EFFET DE JEU. Elle ne blesse pas, ne bloque pas, ne retient rien : la
## traction et les dégâts restent chez le boss. On peut la supprimer à tout
## moment sans rien changer au combat.

## Extrémités suivies image par image. Les deux bougent : le boss dérive, le
## joueur est tiré. Figer la chaîne à sa pose la ferait glisser à côté d'eux.
var ancre: Node2D
var proie: Node2D

## Position de repli quand un nœud disparaît en cours de route — un boss qui
## meurt pendant sa propre traction ne doit pas emporter le dessin dans un
## accès de nœud invalide.
var depuis: Vector2 = Vector2.ZERO
var vers: Vector2 = Vector2.ZERO

@export var duree: float = 0.55
## Temps de sortie du fouet. Avant, la chaîne se déploie ; après, elle est tendue
## puis s'efface. Le déploiement doit être BREF : la traction commence tout de
## suite, une chaîne encore en vol pendant que le joueur bouge déjà mentirait.
@export var jet: float = 0.12
@export var pas_maillon: float = 17.0
@export var epaisseur: float = 8.0
@export var teinte: Color = Color(0.86, 0.78, 0.62)
## Le maillon vu de profil. Il doit rester CLAIR : essayé en brun sombre
## (0.30, 0.24, 0.20), il se confondait avec le sol de l'arène et la chaîne se
## lisait comme un pointillé — un maillon sur deux disparaissait.
@export var teinte_profil: Color = Color(0.55, 0.48, 0.38)
## Silhouette posée sous la chaîne. Sans elle, la chaîne se perd dès qu'elle
## passe sur un rocher clair, et elle en traverse forcément.
@export var teinte_cerne: Color = Color(0.08, 0.05, 0.05, 0.6)
## Retrait à l'ancre : la chaîne sort du CORPS du boss et non de son centre
## géométrique, sinon elle semble le transpercer.
@export var retrait_ancre: float = 38.0
## Fouetté : la chaîne part en arc et se tend. Dessinée parfaitement droite,
## elle lisait comme une BARRE — c'est la courbure qui dit qu'un objet souple
## vient d'être lancé. L'arc s'efface à mesure que la traction la tend.
@export var fouette: float = 46.0

var _temps: float = 0.0
## Côté vers lequel la chaîne se cambre. Tiré UNE FOIS : recalculé à chaque
## image, le ventre de la chaîne sauterait d'un côté à l'autre.
var _sens: float = 1.0


func _ready() -> void:
	# Au-dessus du sol et du décor, sous les projectiles : la chaîne est un
	# décor de l'action, pas un élément à lire en priorité.
	z_index = 20
	_sens = 1.0 if randi() % 2 == 0 else -1.0
	_rafraichir()


func _process(delta: float) -> void:
	_temps += delta
	if _temps >= duree:
		queue_free()
		return
	_rafraichir()
	queue_redraw()


func _rafraichir() -> void:
	if ancre != null and is_instance_valid(ancre):
		depuis = ancre.global_position
	if proie != null and is_instance_valid(proie):
		vers = proie.global_position
	global_position = depuis


func _draw() -> void:
	var axe := vers - depuis
	var portee := axe.length()
	if portee < 1.0:
		return
	var direction := axe / portee
	var origine := direction * minf(retrait_ancre, portee * 0.35)
	var utile := portee - origine.length()
	if utile <= 1.0:
		return

	# Déploiement, puis effacement. L'opacité ne tombe qu'en fin de course :
	# une chaîne qui pâlit pendant qu'elle tire aurait l'air de lâcher prise.
	var sortie := clampf(_temps / maxf(0.01, jet), 0.0, 1.0)
	var reste := clampf((duree - _temps) / 0.2, 0.0, 1.0)
	var longueur := utile * sortie
	var pointe := origine + direction * longueur

	# L'arc se résorbe une fois la chaîne sortie : elle se tend.
	var courbure := fouette * (1.0 - sortie) 		+ fouette * 0.22 * clampf((duree - _temps) / duree, 0.0, 1.0)
	var normale := direction.orthogonal() * _sens

	var points := PackedVector2Array()
	var pas := maxi(2, int(ceil(longueur / pas_maillon)))
	for i in pas + 1:
		var u := float(i) / float(pas)
		# Arc en cloche : nul aux deux bouts, maximal au milieu. La chaîne reste
		# attachée au boss et au joueur, seul son ventre s'écarte.
		points.append(origine + direction * (longueur * u) + normale * courbure * sin(u * PI))

	# 1. La silhouette, d'un seul trait continu.
	draw_polyline(points,
		Color(teinte_cerne.r, teinte_cerne.g, teinte_cerne.b, teinte_cerne.a * reste),
		epaisseur + 4.0, true)

	# 2. Les maillons, CONTIGUS. Ils étaient espacés de 5 px, ce qui donnait un
	#    pointillé : l'entrelacement d'une chaîne se lit au contraste entre un
	#    maillon de face et un maillon de profil, pas à des trous.
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if a.distance_to(b) < 0.5:
			continue
		var de_face := i % 2 == 0
		var c := teinte if de_face else teinte_profil
		draw_line(a, b, Color(c.r, c.g, c.b, reste),
			epaisseur if de_face else epaisseur * 0.5, true)
	var pointe_reelle := points[points.size() - 1]

	# 3. Le crochet. Deux barbes en V vers l'arrière : sans elles la chaîne se
	#    termine en rien et on ne sait pas ce qui a mordu.
	if sortie >= 1.0:
		pointe = pointe_reelle
		var arriere := -direction
		for signe in [-1.0, 1.0]:
			var barbe := arriere.rotated(signe * 0.6) * 18.0
			draw_line(pointe, pointe + barbe,
				Color(teinte_cerne.r, teinte_cerne.g, teinte_cerne.b, 0.55 * reste),
				epaisseur * 0.8 + 3.0, true)
			draw_line(pointe, pointe + barbe, Color(teinte.r, teinte.g, teinte.b, reste),
				epaisseur * 0.8, true)
