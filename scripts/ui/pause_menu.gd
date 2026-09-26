extends CanvasLayer
## Menu de pause de l'arène : Échap / B.
##
## QUI POSSÈDE LA PAUSE. Boutique, malédictions et fin de run mettent déjà l'arbre
## en pause pendant qu'ils sont ouverts. Ce menu ne doit donc pas s'ouvrir
## par-dessus eux — sinon le fermer relancerait la partie alors que la boutique
## est encore affichée. Le test est `get_tree().paused` : si l'arbre est en pause
## et que ce menu n'est pas visible, c'est qu'un autre écran la détient, et Échap
## lui appartient. Aucune référence croisée n'est nécessaire.

@onready var wave_label: Label = %WaveLabel
@onready var resume_button: Button = %ResumeButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton

## Écran d'options réutilisé tel quel, câblé par `main.gd`. Sans lui le bouton
## est simplement masqué : le menu reste utilisable.
var options_screen: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(close)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func bind_options(screen: CanvasLayer) -> void:
	options_screen = screen
	options_button.visible = screen != null
	if screen != null:
		screen.visibility_changed.connect(_on_options_visibility_changed)


## Fermer les options rendait un menu sans focus : visible, mais plus rien à
## quoi la manette puisse s'accrocher. On le récupère.
func _on_options_visibility_changed() -> void:
	if visible and options_screen != null and not options_screen.visible:
		resume_button.grab_focus()


func open() -> void:
	if visible:
		return
	wave_label.text = tr("Vague %d  ·  %d âmes") % [RunState.wave, RunState.souls]
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	# Les options s'ouvrent PAR-DESSUS ce menu : c'est à elles de se refermer
	# d'abord, sinon un seul appui fermerait les deux.
	if options_screen != null and options_screen.visible:
		return
	if visible:
		get_viewport().set_input_as_handled()
		close()
	elif not get_tree().paused:
		get_viewport().set_input_as_handled()
		open()


func _on_options_pressed() -> void:
	if options_screen != null:
		options_screen.call(&"open")


## Abandonner met FIN à la run avant de quitter la scène. Les clés ramassées ne
## sont versées à la sauvegarde qu'à la fin de la run (`RunState.end_run`) : sans
## cet appel, quitter perdait les clés et n'enregistrait pas la vague atteinte —
## une run à la vague 20 abandonnée ne comptait pas.
func _on_quit_pressed() -> void:
	RunState.end_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
