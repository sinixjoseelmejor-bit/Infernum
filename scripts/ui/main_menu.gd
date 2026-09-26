extends Control
## Écran titre : un hub, rien de plus.
##
## Chaque bouton ouvre un écran dédié (surcouche `CanvasLayer`) plutôt que de
## charger une scène : le menu reste monté, le retour est instantané.

const ARENA_SCENE := "res://scenes/main/main.tscn"

## BRAISES : ce qui fait vivre l'illustration. Des carrés de quelques pixels,
## sans lissage, qui montent du gouffre et s'éteignent en route. Peu nombreuses
## et lentes : elles doivent se remarquer au second regard, pas disputer la
## lecture des boutons.
const EMBER_COUNT := 70
const EMBER_LIFETIME := 7.0

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
	Audio.stop_ambiance()
	_add_embers()
	for screen in [character_select, profiles_screen, options_screen, forge_screen]:
		screen.visibility_changed.connect(_update_hub)
	_refresh_meta()
	play_button.grab_focus()


## Le hub s'efface derrière un sous-écran. Le voile de 80 % laisse respirer
## l'illustration, mais il laissait aussi transparaître le titre et les boutons
## autour des panneaux les plus courts — des blocs rouges au-dessus de Profils.
## L'illustration et les braises, elles, restent.
func _update_hub() -> void:
	var covered := false
	for screen in [character_select, profiles_screen, options_screen, forge_screen]:
		covered = covered or screen.visible
	$Margin.visible = not covered
	if not covered:
		play_button.grab_focus()


func _add_embers() -> void:
	var embers := CPUParticles2D.new()
	embers.name = "Braises"
	embers.amount = EMBER_COUNT
	embers.lifetime = EMBER_LIFETIME
	embers.preprocess = EMBER_LIFETIME
	embers.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.direction = Vector2.UP
	embers.spread = 18.0
	embers.gravity = Vector2(0, -6)
	embers.initial_velocity_min = 30.0
	embers.initial_velocity_max = 70.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.72, 0.3, 0.0))
	ramp.add_point(0.12, Color(1.0, 0.6, 0.2, 0.9))
	ramp.add_point(0.7, Color(0.95, 0.3, 0.1, 0.55))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.1, 0.05, 0.0))
	embers.color_ramp = ramp
	# Entre le voile et les boutons : devant l'illustration, derrière le texte.
	add_child(embers)
	move_child(embers, $Margin.get_index())
	var place := func() -> void:
		embers.position = Vector2(size.x * 0.5, size.y + 10.0)
		embers.emission_rect_extents = Vector2(size.x * 0.4, 4.0)
	resized.connect(place)
	place.call()


func _refresh_meta() -> void:
	var progress := Forge.get_progress()
	meta_label.text = "%s   ·   Clés : %d   ·   Forge %d/%d   ·   Meilleure vague : %d   ·   Runs : %d" % [
		SaveGame.profile_name, SaveGame.banked_keys, progress.x, progress.y,
		SaveGame.best_wave, SaveGame.total_runs]


## L'histoire se raconte ici, entre le choix du damné et l'arène : le Pari la
## toute première fois, puis le prologue de chaque personnage la première fois
## qu'on le joue. Rien du tout ensuite — et tout se passe à tout moment.
func _on_start_requested() -> void:
	var file := StoryDB.pending_for(Characters.selected_id)
	if file.is_empty():
		get_tree().change_scene_to_file(ARENA_SCENE)
		return
	Cinematic.play(file, func() -> void: get_tree().change_scene_to_file(ARENA_SCENE))


func _on_quit_pressed() -> void:
	# Sortie propre : on force l'écriture avant de rendre la main au bureau.
	SaveGame.save_game()
	Settings.save_settings()
	get_tree().quit()
