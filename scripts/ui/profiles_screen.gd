extends CanvasLayer
## Gestion des profils : sélection, renommage, effacement.
##
## C'est ici qu'on « recommence une partie » : activer un emplacement vide, ou
## effacer celui en cours, remet toute la méta-progression à zéro sans toucher
## aux autres profils.

@onready var list: VBoxContainer = %ProfileList
@onready var close_button: Button = %ProfilesCloseButton

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


func _build_row(summary: Dictionary) -> Control:
	var slot: int = summary["slot"]
	var is_active: bool = slot == SaveGame.active_slot
	var exists: bool = summary["exists"]

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.07, 0.95)
	style.border_color = Color(1, 0.62, 0.16) if is_active else Color(0.34, 0.2, 0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override(&"panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	panel.add_child(row)

	var infos := VBoxContainer.new()
	infos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infos.add_theme_constant_override(&"separation", 2)
	row.add_child(infos)

	# Le nom est éditable directement : pas d'écran de renommage séparé.
	var name_edit := LineEdit.new()
	name_edit.text = summary["name"]
	name_edit.placeholder_text = SaveGame.get_default_name(slot)
	name_edit.add_theme_font_size_override(&"font_size", 20)
	name_edit.editable = is_active
	name_edit.flat = true
	name_edit.text_submitted.connect(func(t: String) -> void: SaveGame.rename_profile(t))
	name_edit.focus_exited.connect(func() -> void:
		if is_active and name_edit.text != summary["name"]:
			SaveGame.rename_profile(name_edit.text))
	infos.add_child(name_edit)

	var detail := Label.new()
	if exists:
		detail.text = tr("%d clés  ·  Forge %d/%d  ·  meilleure vague %d  ·  %d runs") % [
			summary["keys"], summary["forge_nodes"], Forge.count_all_nodes(),
			summary["best_wave"], summary["total_runs"]]
	else:
		detail.text = "Emplacement vide — nouvelle partie"
	detail.add_theme_font_size_override(&"font_size", 14)
	detail.add_theme_color_override(&"font_color", Color(0.7, 0.67, 0.66))
	infos.add_child(detail)

	var select := Button.new()
	select.custom_minimum_size = Vector2(160, 40)
	select.text = tr("Actif") if is_active else (tr("Charger") if exists else tr("Commencer ici"))
	select.disabled = is_active
	select.pressed.connect(func() -> void: SaveGame.load_profile(slot))
	row.add_child(select)

	var erase := Button.new()
	# Style DANGER : l'action la plus destructrice de l'interface ne doit jamais
	# être la plus visible. En doré plein, elle attirait l'œil sur le profil actif.
	erase.theme_type_variation = &"DangerButton"
	erase.custom_minimum_size = Vector2(160, 40)
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
	row.add_child(erase)
	return panel
