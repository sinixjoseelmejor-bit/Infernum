class_name Ecran
extends RefCounted
## LES ÉCRANS PLEIN CADRE (0.10.1) — ce qu'ils partagent.
##
## Avant, chaque sous-écran était un panneau posé au centre sur un voile : sept
## écrans, sept tailles, et autant de titres de couleurs différentes. Ils
## prennent maintenant tout l'écran, avec le même en-tête — « Retour » à
## gauche, le titre au centre, une action ou une information à droite — et un
## filet de braise dessous. Le style vit dans le thème (`TitreEcran`,
## `SecondaryButton`, le cadre du `PanelContainer`) ; ici, seulement
## l'apparition.
##
## Convention des scènes : un voile `Dim` et un cadre `Center` à la racine du
## CanvasLayer. Un écran qui n'a pas l'un des deux apparaît sans l'animer.

const CASE := preload("res://assets/sprites/ui/enfer/case.png")
const CASE_ACTIVE := preload("res://assets/sprites/ui/enfer/case_active.png")

const DUREE := 0.18
## Le cadre monte de ces quelques pixels en apparaissant.
const MONTEE := 18.0


static func apparaitre(ecran: CanvasLayer) -> void:
	var voile := ecran.get_node_or_null(^"Dim") as CanvasItem
	var cadre := ecran.get_node_or_null(^"Center") as Control
	var tween := ecran.create_tween().set_parallel()
	if voile != null:
		voile.modulate.a = 0.0
		tween.tween_property(voile, ^"modulate:a", 1.0, DUREE)
	if cadre != null:
		cadre.modulate.a = 0.0
		tween.tween_property(cadre, ^"modulate:a", 1.0, DUREE)
	# La montée passe par le décalage du CanvasLayer, JAMAIS par la position du
	# cadre : il est ancré plein écran, et lui donner une position fige ses
	# marges à la taille qu'il a à cet instant. À l'ouverture, avant la
	# première mise en page, un texte à la ligne réclamait 5 600 px de haut —
	# le cadre est resté à cette taille, son contenu sous le bord de l'écran.
	ecran.offset.y = MONTEE
	tween.tween_property(ecran, ^"offset:y", 0.0, DUREE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Le cadre d'une case du kit, pour un panneau construit par le code : éteint,
## ou allumé en braise (l'élément actif, le choix en cours).
static func case(allumee: bool, marge: float = 16.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = CASE_ACTIVE if allumee else CASE
	style.set_texture_margin_all(8.0)
	style.set_content_margin_all(marge)
	return style
