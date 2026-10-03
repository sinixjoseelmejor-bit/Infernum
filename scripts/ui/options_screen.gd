extends CanvasLayer
## Écran d'options. Chaque réglage agit réellement sur le jeu et se sauvegarde
## immédiatement — il n'y a pas de bouton « Appliquer » à oublier.

@onready var rows: VBoxContainer = %OptionRows
@onready var reset_button: Button = %OptionsResetButton
@onready var close_button: Button = %OptionsCloseButton

const JERSEY := preload("res://assets/fonts/Jersey10-Regular.ttf")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	reset_button.pressed.connect(func() -> void:
		Settings.reset()
		refresh())


func open() -> void:
	visible = true
	refresh()
	close_button.grab_focus()
	Ecran.apparaitre(self)


func close() -> void:
	visible = false


## Bouton B de la manette / Échap : retour. Sans ça, un écran ouvert à la manette
## est un cul-de-sac — il n'y a aucun moyen d'en sortir sans souris.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func refresh() -> void:
	UIUtils.clear_children(rows)

	# EN TÊTE, et chaque langue écrite dans la sienne : un joueur qui ne lit pas
	# la langue affichée doit trouver la sienne sans rien comprendre d'autre.
	var langue := OptionButton.new()
	langue.name = "Langue"
	langue.add_item("%s (%s)" % [tr("Automatique"), Settings.LANGUES[Settings.get_langue_systeme()]], 0)
	var codes: Array = Settings.LANGUES.keys()
	for i in codes.size():
		langue.add_item(Settings.LANGUES[codes[i]], i + 1)
	langue.select(codes.find(Settings.langue) + 1)
	langue.item_selected.connect(func(index: int) -> void:
		var id := langue.get_item_id(index)
		Settings.set_langue("" if id == 0 else String(codes[id - 1]))
		# L'écran se reconstruit dans la nouvelle langue ; pas dans le signal du
		# bouton, qu'il détruit.
		_relangue.call_deferred())
	rows.add_child(_row("Langue · Language", tr("La langue des menus, de l'interface et de l'histoire."),
		langue))

	var fullscreen := CheckButton.new()
	fullscreen.text = "Plein écran"
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	rows.add_child(_row(tr("Affichage"), tr("Bascule entre fenêtré et plein écran."), fullscreen))

	rows.add_child(_percent_row(tr("Musique"),
		tr("Volume des musiques du menu et de l'arène."),
		Settings.music_volume, 1.0, Settings.set_music_volume))

	rows.add_child(_percent_row(tr("Effets", "son"),
		tr("Volume des tirs, des rugissements et de l'interface."),
		Settings.sfx_volume, 1.0, Settings.set_sfx_volume))

	var joystick := OptionButton.new()
	for mode in [Settings.JoystickMode.AUTO, Settings.JoystickMode.ALWAYS,
			Settings.JoystickMode.NEVER]:
		joystick.add_item(tr(Settings.JOYSTICK_LABELS[mode]), mode)
	joystick.select(joystick.get_item_index(Settings.joystick_mode))
	joystick.item_selected.connect(func(index: int) -> void:
		Settings.set_joystick_mode(joystick.get_item_id(index) as Settings.JoystickMode))
	rows.add_child(_row(tr("Joystick virtuel"),
		tr("« Automatique » ne l'affiche que sur écran tactile. « Toujours » permet de le tester à la souris."),
		joystick))

	rows.add_child(_percent_row(tr("Tremblement de caméra"),
		tr("Réduire ou couper les secousses d'écran (confort visuel)."),
		Settings.shake_scale, 1.5, Settings.set_shake_scale))

	var eight_way := CheckButton.new()
	eight_way.text = "8 directions"
	eight_way.button_pressed = Settings.eight_way
	eight_way.toggled.connect(func(on: bool) -> void: Settings.set_eight_way(on))
	rows.add_child(_row(tr("Déplacement"),
		tr("Quantifie le stick et le joystick tactile sur 8 axes. Désactivé, le déplacement est libre."),
		eight_way))

	# Les cinématiques ne se jouent qu'une fois par profil : il faut pouvoir
	# les revoir sans effacer sa progression.
	var replay := Button.new()
	replay.name = "RevoirHistoire"
	replay.text = "Revoir"
	replay.theme_type_variation = &"SecondaryButton"
	replay.custom_minimum_size = Vector2(240, 52)
	replay.pressed.connect(func() -> void:
		Cinematic.play(StoryDB.all_for(Characters.selected_id), func() -> void:
			if is_instance_valid(replay) and replay.is_visible_in_tree():
				replay.grab_focus()))
	rows.add_child(_row(tr("Histoire"),
		tr("Rejoue le Pari, le prologue de %s et les scènes déjà vues.") % Characters.get_selected().display_name,
		replay))

	UIUtils.chain_focus(self)


func _relangue() -> void:
	refresh()
	var langue := rows.find_child("Langue", true, false) as Control
	if langue != null:
		langue.grab_focus()


## Curseur exprimé en pourcentage, avec la valeur lue à droite. Le réglage part
## dans `Settings` au fil du glissement : on entend le volume qu'on règle.
func _percent_row(title: String, help: String, value: float, maximum: float,
		setter: Callable) -> Control:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(380, 28)

	var readout := Label.new()
	readout.custom_minimum_size = Vector2(80, 0)
	readout.add_theme_font_size_override(&"font_size", 22)
	readout.text = tr("%d %%") % roundi(value * 100.0)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		readout.text = tr("%d %%") % roundi(v * 100.0))

	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.add_child(slider)
	box.add_child(readout)
	return _row(title, help, box)


## Une ligne = intitulé + explication à gauche, contrôle à droite. La ligne
## s'allume en braise quand son contrôle a le focus (0.10.1) : à la manette, on
## voit de loin quel réglage on touche.
func _row(title: String, help: String, control: Control) -> Control:
	var panel := PanelContainer.new()
	var eteinte := Ecran.case(false, 18.0)
	var allumee := Ecran.case(true, 18.0)
	panel.add_theme_stylebox_override(&"panel", eteinte)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	panel.add_child(row)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", 2)
	row.add_child(texts)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override(&"font", JERSEY)
	title_label.add_theme_font_size_override(&"font_size", 32)
	title_label.add_theme_color_override(&"font_color", Color(0.94, 0.88, 0.8))
	texts.add_child(title_label)

	var help_label := Label.new()
	help_label.text = help
	help_label.add_theme_font_size_override(&"font_size", 18)
	help_label.add_theme_color_override(&"font_color", Color(0.74, 0.68, 0.64))
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(help_label)

	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	var focal: Control = control
	if control is HBoxContainer and control.get_child_count() > 0:
		focal = control.get_child(0)
	focal.focus_entered.connect(func() -> void:
		panel.add_theme_stylebox_override(&"panel", allumee)
		title_label.add_theme_color_override(&"font_color", Color(1, 0.72, 0.36)))
	focal.focus_exited.connect(func() -> void:
		panel.add_theme_stylebox_override(&"panel", eteinte)
		title_label.add_theme_color_override(&"font_color", Color(0.94, 0.88, 0.8)))
	return panel
