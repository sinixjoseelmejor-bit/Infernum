extends Control
## Écran titre : un hub, rien de plus.
##
## Chaque bouton ouvre un écran dédié (surcouche `CanvasLayer`) plutôt que de
## charger une scène : le menu reste monté, le retour est instantané.

const ARENA_SCENE := "res://scenes/main/main.tscn"

@onready var play_button: Button = %PlayButton
@onready var profiles_button: Button = %ProfilesButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var meta_label: Label = %MetaLabel

@onready var character_select: CanvasLayer = %CharacterSelect
@onready var profiles_screen: CanvasLayer = %Profiles
@onready var options_screen: CanvasLayer = %Options
@onready var forge_screen: CanvasLayer = %Forge


func _ready() -> void:
	play_button.pressed.connect(func() -> void: character_select.call(&"open"))
	profiles_button.pressed.connect(func() -> void: profiles_screen.call(&"open"))
	options_button.pressed.connect(func() -> void: options_screen.call(&"open"))
	quit_button.pressed.connect(_on_quit_pressed)

	character_select.connect(&"start_requested", _on_start_requested)
	character_select.connect(&"forge_requested", func() -> void: forge_screen.call(&"open"))

	SaveGame.keys_changed.connect(func(_t: int) -> void: _refresh_meta())
	SaveGame.profile_changed.connect(func(_s: int) -> void: _refresh_meta())

	# Une run précédente peut avoir laissé l'arbre en pause ou des malédictions.
	get_tree().paused = false
	Curses.clear_all()
	Audio.play_music(&"menu")
	_refresh_meta()
	play_button.grab_focus()


func _refresh_meta() -> void:
	var progress := Forge.get_progress()
	meta_label.text = "%s   ·   Clés : %d   ·   Forge %d/%d   ·   Meilleure vague : %d   ·   Runs : %d" % [
		SaveGame.profile_name, SaveGame.banked_keys, progress.x, progress.y,
		SaveGame.best_wave, SaveGame.total_runs]


func _on_start_requested() -> void:
	get_tree().change_scene_to_file(ARENA_SCENE)


func _on_quit_pressed() -> void:
	# Sortie propre : on force l'écriture avant de rendre la main au bureau.
	SaveGame.save_game()
	Settings.save_settings()
	get_tree().quit()
