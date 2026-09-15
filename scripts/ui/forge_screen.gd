extends CanvasLayer
## Écran de la Forge Éternelle : arbre de méta-progression + déblocage d'objets.
##
## Ouvert depuis l'écran de fin de run. Les lignes sont construites par code à
## partir de `Forge.NODES` : ajouter un nœud ne demande aucune retouche d'UI.

@onready var keys_label: Label = %ForgeKeysLabel
@onready var progress_label: Label = %ForgeProgressLabel
@onready var branches_row: HBoxContainer = %BranchesRow
@onready var items_list: VBoxContainer = %ForgeItemsList
@onready var close_button: Button = %ForgeCloseButton

var _refresh_queued: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	SaveGame.keys_changed.connect(func(_t: int) -> void: refresh())
	Forge.node_unlocked.connect(func(_id: StringName) -> void: refresh())


func open() -> void:
	visible = true
	_rebuild()
	# Premier nœud ouvrable plutôt que « Retour » : à la manette, on arrive là
	# où il y a quelque chose à faire.
	var reachable := UIUtils.focusable_controls(self)
	if reachable.is_empty():
		close_button.grab_focus()
	else:
		reachable[0].grab_focus()


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


## Débloquer un nœud émet `keys_changed` PUIS `node_unlocked` : reconstruire à
## chaque signal, c'est reconstruire trois fois par clic, et détruire le bouton
## pressé pendant l'exécution de son propre signal. On diffère à la fin de la
## frame et on ne reconstruit qu'une fois.
func refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_refresh_queued = false
	var keep := UIUtils.capture_focus(self)
	var progress := Forge.get_progress()
	keys_label.text = "Clés : %d" % SaveGame.banked_keys
	progress_label.text = "Forge %d / %d nœuds  ·  %d clés pour tout ouvrir" % [
		progress.x, progress.y, Forge.get_total_cost()]

	UIUtils.clear_children(branches_row)
	for branch in Forge.BRANCHES:
		branches_row.add_child(_build_branch(branch))

	UIUtils.clear_children(items_list)
	var locked := ItemDB.get_locked()
	if locked.is_empty():
		var done := Label.new()
		done.text = "Tous les objets sont débloqués."
		items_list.add_child(done)
	else:
		for item in locked:
			items_list.add_child(_build_item_row(item))

	UIUtils.restore_focus(self, keep, close_button)


func _build_branch(branch: String) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 6)

	var title := Label.new()
	title.text = branch.to_upper()
	title.add_theme_font_size_override(&"font_size", 20)
	title.add_theme_color_override(&"font_color", Color(1, 0.55, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	for node in Forge.get_branch(branch):
		column.add_child(_build_node_row(node))
	return column


func _build_node_row(node: Dictionary) -> Control:
	var id: StringName = node["id"]
	var unlocked := Forge.is_unlocked(id)
	var available := Forge.requirements_met(id)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.165, 0.141, 0.204, 0.96)
	style.border_color = Color(0.91, 0.722, 0.282) if unlocked else Color(0.404, 0.294, 0.204)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override(&"panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	panel.add_child(box)

	var name_label := Label.new()
	name_label.text = node["name"]
	name_label.add_theme_font_size_override(&"font_size", 15)
	if not available and not unlocked:
		name_label.add_theme_color_override(&"font_color", Color(0.5, 0.45, 0.45))
	box.add_child(name_label)

	var effect := Label.new()
	effect.text = ItemCard.format_mods(node.get("mods", {}))
	if effect.text == "":
		effect.text = node.get("desc", "")
	effect.add_theme_font_size_override(&"font_size", 12)
	effect.add_theme_color_override(&"font_color", Color(0.8, 0.8, 0.8))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(effect)

	var button := Button.new()
	# Nom stable : c'est par lui que le focus se retrouve après reconstruction.
	button.name = "noeud_%s" % id
	if unlocked:
		button.text = "Acquis"
		button.disabled = true
	elif not available:
		button.text = "Verrouillé (%d clés)" % int(node["cost"])
		button.disabled = true
		button.tooltip_text = "Nécessite : %s" % _requirement_names(node)
	else:
		button.text = "%d clés" % int(node["cost"])
		button.disabled = not Forge.can_unlock(id)
		button.pressed.connect(func() -> void: Forge.unlock(id))
	if button.disabled:
		button.focus_mode = Control.FOCUS_NONE
	box.add_child(button)
	return panel


func _requirement_names(node: Dictionary) -> String:
	var names: Array[String] = []
	for req in node.get("requires", []):
		names.append(String(Forge.get_node_data(req).get("name", req)))
	return ", ".join(names)


func _build_item_row(item: ItemData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)

	var label := Label.new()
	label.text = "%s — %s" % [item.display_name, item.description]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", item.get_rarity_color())
	label.add_theme_font_size_override(&"font_size", 14)
	row.add_child(label)

	var button := Button.new()
	button.name = "objet_%s" % item.id
	button.text = "%d clés" % item.key_cost
	button.disabled = SaveGame.banked_keys < item.key_cost
	if button.disabled:
		button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: SaveGame.unlock_item(item))
	row.add_child(button)
	return row
