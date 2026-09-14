extends CanvasLayer
## Écran d'options. Chaque réglage agit réellement sur le jeu et se sauvegarde
## immédiatement — il n'y a pas de bouton « Appliquer » à oublier.

@onready var rows: VBoxContainer = %OptionRows
@onready var reset_button: Button = %OptionsResetButton
@onready var close_button: Button = %OptionsCloseButton


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

	var fullscreen := CheckButton.new()
	fullscreen.text = "Plein écran"
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	rows.add_child(_row("Affichage", "Bascule entre fenêtré et plein écran.", fullscreen))

	var joystick := OptionButton.new()
	for mode in [Settings.JoystickMode.AUTO, Settings.JoystickMode.ALWAYS,
			Settings.JoystickMode.NEVER]:
		joystick.add_item(Settings.JOYSTICK_LABELS[mode], mode)
	joystick.select(joystick.get_item_index(Settings.joystick_mode))
	joystick.item_selected.connect(func(index: int) -> void:
		Settings.set_joystick_mode(joystick.get_item_id(index) as Settings.JoystickMode))
	rows.add_child(_row("Joystick virtuel",
		"« Automatique » ne l'affiche que sur écran tactile. « Toujours » permet de le tester à la souris.",
		joystick))

	var shake := HSlider.new()
	shake.min_value = 0.0
	shake.max_value = 1.5
	shake.step = 0.05
	shake.value = Settings.shake_scale
	shake.custom_minimum_size = Vector2(240, 0)
	var shake_value := Label.new()
	shake_value.custom_minimum_size = Vector2(60, 0)
	shake_value.text = "%d %%" % roundi(Settings.shake_scale * 100.0)
	shake.value_changed.connect(func(v: float) -> void:
		Settings.set_shake_scale(v)
		shake_value.text = "%d %%" % roundi(v * 100.0))
	var shake_box := HBoxContainer.new()
	shake_box.add_theme_constant_override(&"separation", 10)
	shake_box.add_child(shake)
	shake_box.add_child(shake_value)
	rows.add_child(_row("Tremblement de caméra",
		"Réduire ou couper les secousses d'écran (confort visuel).", shake_box))

	var eight_way := CheckButton.new()
	eight_way.text = "8 directions"
	eight_way.button_pressed = Settings.eight_way
	eight_way.toggled.connect(func(on: bool) -> void: Settings.set_eight_way(on))
	rows.add_child(_row("Déplacement",
		"Quantifie le stick et le joystick tactile sur 8 axes. Désactivé, le déplacement est libre.",
		eight_way))


## Une ligne = intitulé + explication à gauche, contrôle à droite.
func _row(title: String, help: String, control: Control) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.07, 0.95)
	style.border_color = Color(0.34, 0.2, 0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override(&"panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	panel.add_child(row)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", 2)
	row.add_child(texts)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override(&"font_size", 19)
	texts.add_child(title_label)

	var help_label := Label.new()
	help_label.text = help
	help_label.add_theme_font_size_override(&"font_size", 13)
	help_label.add_theme_color_override(&"font_color", Color(0.7, 0.67, 0.66))
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(help_label)

	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return panel
