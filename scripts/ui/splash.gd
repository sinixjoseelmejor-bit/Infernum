extends Control
## LOGO DU STUDIO, au lancement — apparition, tenue, fondu, puis le menu.
##
## C'est la PREMIÈRE scène du jeu : `run/main_scene` pointe ici et non sur le
## menu principal, qui est chargé ensuite. Le lancement est le seul moment où
## l'on peut montrer quelque chose sans interrompre personne, et un fondu dit
## « ça démarre » là où un logo posé une seconde dit « ça a planté ».
##
## POURQUOI PAS L'ÉCRAN DE DÉMARRAGE DE GODOT (`boot_splash`). Il affiche une
## image fixe pendant le chargement du moteur, sans fondu, sans durée réglable
## et sans possibilité de la passer. Une scène coûte trois nœuds et donne les
## trois.
##
## ELLE SE PASSE. N'importe quelle touche, n'importe quel bouton de manette,
## n'importe quel clic l'abrège — et au deuxième lancement de la journée c'est
## la seule chose qu'on demande à un logo. Sans ça, ce qui accueille le joueur
## devient ce qui le retarde.
##
## RIEN DE CE QUI SUIT N'EST PRÉCHARGÉ ICI : le menu est chargé au changement de
## scène, pas pendant le fondu. Le jeu pèse 0,3 Mo de contenu, il s'ouvre
## instantanément ; un préchargement n'achèterait rien et masquerait le vrai
## coût si un jour il augmentait.

const MENU := "res://scenes/ui/main_menu.tscn"

## Trois temps. La tenue est ce qui donne au logo le temps d'être LU : à 0,6 s
## il passe pour un défaut d'affichage, au-delà de 2 s il se fait attendre.
@export var apparition: float = 0.45
@export var tenue: float = 1.10
@export var fondu: float = 0.70

@onready var logo: TextureRect = %Logo

var _fini: bool = false


func _ready() -> void:
	logo.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(logo, ^"modulate:a", 1.0, apparition)
	tween.tween_interval(tenue)
	tween.tween_property(logo, ^"modulate:a", 0.0, fondu)
	tween.tween_callback(_suite)


func _unhandled_input(event: InputEvent) -> void:
	# Les relâchements ne comptent pas : sans ce test, la touche qui a lancé le
	# jeu depuis un terminal passerait le logo avant qu'il ne s'affiche.
	if not event.is_pressed():
		return
	if event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventMouseButton or event is InputEventScreenTouch:
		_suite()


func _suite() -> void:
	if _fini:
		return
	_fini = true
	get_tree().change_scene_to_file(MENU)
