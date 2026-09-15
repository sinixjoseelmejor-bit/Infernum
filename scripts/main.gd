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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
