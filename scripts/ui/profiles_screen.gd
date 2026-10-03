extends CanvasLayer
## Gestion des profils : sélection, renommage, effacement.
##
## C'est ici qu'on « recommence une partie » : activer un emplacement vide, ou
## effacer celui en cours, remet toute la méta-progression à zéro sans toucher
## aux autres profils.

@onready var list: HBoxContainer = %ProfileList
@onready var close_button: Button = %ProfilesCloseButton

const CARTE := Vector2(470, 440)
const JERSEY := preload("res://assets/fonts/Jersey10-Regular.ttf")

## Emplacement en attente de confirmation d'effacement (-1 = aucun).
var _pending_delete: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	SaveGame.profile_changed.connect(func(_slot: int) -> void: refresh())


func open() -> void:
	_pending_delete = -1
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
	UIUtils.clear_children(list)
	for summary in SaveGame.get_all_summaries():
		list.add_child(_build_row(summary))
	UIUtils.chain_focus(self)


## UNE CARTE PAR EMPLACEMENT (0.10.1), côte à côte comme des emplacements de
## sauvegarde : le nom en grand, la progression ligne à ligne, les deux actions
## en bas. L'emplacement actif est allumé en braise.
func _build_row(summary: Dictionary) -> Control:
	var slot: int = summary["slot"]
	var is_active: bool = slot == SaveGame.active_slot
	var exists: bool = summary["exists"]

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", Ecran.case(is_active, 22.0))
	panel.custom_minimum_size = CARTE

	var infos := VBoxContainer.new()
	infos.add_theme_constant_override(&"separation", 10)
	panel.add_child(infos)

	# Le nom est éditable directement : pas d'écran de renommage séparé.
	var name_edit := LineEdit.new()
	name_edit.text = summary["name"]
	name_edit.placeholder_text = SaveGame.get_default_name(slot)
	name_edit.add_theme_font_override(&"font", JERSEY)
	name_edit.add_theme_font_size_override(&"font_size", 44)
	name_edit.add_theme_color_override(&"font_color",
		Color(1, 0.7, 0.36) if is_active else Color(0.9, 0.84, 0.78))
	name_edit.editable = is_active
	name_edit.flat = true
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.text_submitted.connect(func(t: String) -> void: SaveGame.rename_profile(t))
	name_edit.focus_exited.connect(func() -> void:
		if is_active and name_edit.text != summary["name"]:
			SaveGame.rename_profile(name_edit.text))
	infos.add_child(name_edit)
	infos.add_child(HSeparator.new())

	var detail := Label.new()
	if exists:
		# Le gabarit d'une ligne, coupé en lignes : sa traduction ne change pas.
		detail.text = (tr("%d clés  ·  Forge %d/%d  ·  meilleure vague %d  ·  %d runs") % [
			summary["keys"], summary["forge_nodes"], Forge.count_all_nodes(),
			summary["best_wave"], summary["total_runs"]]).replace("  ·  ", "\n")
	else:
		detail.text = tr("Emplacement vide — nouvelle partie")
	detail.add_theme_font_size_override(&"font_size", 24)
	detail.add_theme_color_override(&"font_color", Color(0.88, 0.82, 0.78) if exists
		else Color(0.62, 0.56, 0.54))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	infos.add_child(detail)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 12)
	infos.add_child(actions)

	var select := Button.new()
	select.custom_minimum_size = Vector2(0, 54)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.text = tr("Actif") if is_active else (tr("Charger") if exists else tr("Commencer ici"))
	select.disabled = is_active
	select.pressed.connect(func() -> void: SaveGame.load_profile(slot))
	actions.add_child(select)

	var erase := Button.new()
	# Style DANGER : l'action la plus destructrice de l'interface ne doit jamais
	# être la plus visible. En doré plein, elle attirait l'œil sur le profil actif.
	erase.theme_type_variation = &"DangerButton"
	erase.custom_minimum_size = Vector2(0, 54)
	erase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erase.disabled = not exists
	if _pending_delete == slot:
		erase.text = "Confirmer ?"
		erase.add_theme_color_override(&"font_color", Color(1, 0.93, 0.86))
		erase.pressed.connect(func() -> void:
			SaveGame.delete_profile(slot)
			_pending_delete = -1
			refresh())
	else:
		erase.text = "Effacer"
		# Double clic requis : l'effacement est définitif.
		erase.pressed.connect(func() -> void:
			_pending_delete = slot
			refresh())
	actions.add_child(erase)
	return panel
