extends Node2D
## Scène racine de l'arène : câble les systèmes entre eux et démarre la run.
##
## Aucun système n'est référencé par un autre en dur : tout passe par ici ou par
## `GameEvents` / `RunState`, ce qui permet d'ajouter ou de retirer un système
## sans toucher aux autres.

@onready var player: Player = %Player
@onready var waves: WaveManager = %WaveManager
@onready var enemies: Node2D = %Enemies
@onready var hud: HUD = %HUD
@onready var curse_select: CanvasLayer = %CurseSelect
@onready var forge: CanvasLayer = %Forge
@onready var game_over: CanvasLayer = %GameOver
@onready var pause_menu: CanvasLayer = %PauseMenu
@onready var pause_options: CanvasLayer = %PauseOptions


func _ready() -> void:
	# L'état de run est un autoload : il survit au rechargement de scène, donc il
	# doit être remis à zéro explicitement à chaque nouvelle partie.
	RunState.reset_run()
	Audio.play_music(&"arene")

	waves.target = player
	waves.container = enemies
	hud.bind_wave_manager(waves)
	game_over.set(&"forge_screen", forge)

	# La run ne démarre qu'une fois l'écran de malédictions validé. Cet écran est
	# purement facultatif : son bouton par défaut lance une run sans malédiction.
	pause_menu.call(&"bind_options", pause_options)

	curse_select.connect(&"confirmed", waves.start)
	curse_select.call(&"open")

	# L'histoire autour des boss : entrées, sceaux, portail, Hélel.
	var director := StoryDirector.new()
	director.name = "StoryDirector"
	director.setup(player, waves, %Shop, game_over)
	add_child(director)

	_monter_panneau_dev()


## Monte le panneau de développement, et UNIQUEMENT dans un build qui le porte.
##
## Il n'est plus un nœud de `main.tscn` : une référence statique aurait obligé
## le script à rester dans le `.pck` de tout le monde, sans quoi la scène de
## l'arène ne se chargerait plus du tout. En le montant ici, le préréglage
## d'export destiné aux joueurs peut l'exclure pour de bon — script, empreinte
## du mot de passe et tout le reste partent du paquet.
##
## Les deux conditions sont volontairement redondantes. `dev_panel` est un
## indicateur d'export personnalisé, porté par le seul préréglage de test ;
## `ResourceLoader.exists` vérifie que le fichier est bien là. Si l'un des deux
## se trompe un jour — un indicateur oublié, un filtre mal écrit — l'autre
## empêche le plantage ou la fuite.
##
## `editor` couvre le jeu lancé depuis les sources : on n'exporte pas un build
## rien que pour vérifier une vague, et un panneau qui ne marche qu'une fois
## empaqueté ne serait utilisé par personne.
func _monter_panneau_dev() -> void:
	const CHEMIN := "res://scripts/ui/dev_screen.gd"
	var autorise := OS.has_feature("dev_panel") or OS.has_feature("editor")
	if not autorise or not ResourceLoader.exists(CHEMIN):
		return
	var panneau := CanvasLayer.new()
	panneau.name = "DevScreen"
	panneau.set_script(load(CHEMIN))
	add_child(panneau)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		# Relancer est un abandon : clés versées, vague enregistrée.
		RunState.end_run()
		get_tree().paused = false
		get_tree().reload_current_scene()
