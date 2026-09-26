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
@onready var abyss_panel: PanelContainer = %AbyssPanel
@onready var abyss_button: Button = %AbyssButton
@onready var abyss_label: Label = %AbyssLabel
@onready var detail_label: Label = %ForgeDetailLabel
@onready var tree_scroll: ScrollContainer = %TreeScroll
@onready var items_scroll: ScrollContainer = %ItemsScroll

## Une case de nœud. La largeur loge deux cases côte à côte par branche.
const TILE_SIZE := Vector2(176, 84)
const TILE_GAP := 12
const ROW_GAP := 12
## Au-delà, la liste des objets à débloquer défile plutôt que de pousser l'écran.
const ITEMS_MAX_HEIGHT := 180.0

var _refresh_queued: bool = false
## Cases de l'arbre par identifiant de nœud, pour tracer les liens.
var _tiles: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	abyss_button.toggled.connect(_on_dechainement)
	branches_row.draw.connect(_draw_links)
	SaveGame.keys_changed.connect(func(_t: int) -> void: refresh())
	Forge.node_unlocked.connect(func(_id: StringName) -> void: refresh())


func open() -> void:
	visible = true
	_rebuild()
	# Premier nœud ouvrable plutôt que « Retour » : à la manette, on arrive là
	# où il y a quelque chose à faire. À défaut, le premier nœud, pour lire.
	var first: Control = null
	for control in UIUtils.focusable_controls(branches_row):
		if control is Button and not (control as Button).disabled:
			first = control
			break
		if first == null:
			first = control
	(first if first != null else close_button).grab_focus()


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
	keys_label.text = tr("Clés : %d") % SaveGame.banked_keys
	# Le personnage est NOMMÉ, et c'est indispensable : chaque personnage a sa
	# propre Forge, et un joueur qui ouvre cet écran sans savoir lequel il
	# renforce dépenserait ses clés au mauvais endroit — une dépense
	# irréversible.
	progress_label.text = tr("%s  ·  Forge %d / %d nœuds  ·  %d clés pour tout ouvrir") % [
		Characters.get_selected().display_name.to_upper(),
		progress.x, progress.y, Forge.get_total_cost()]

	UIUtils.clear_children(branches_row)
	_tiles.clear()
	for branch in Forge.get_branches():
		branches_row.add_child(_build_branch(branch))
	detail_label.text = "Survolez un nœud pour le détail."

	_rebuild_abysses()

	UIUtils.clear_children(items_list)
	var locked := ItemDB.get_locked()
	if locked.is_empty():
		var done := Label.new()
		done.text = "Tous les objets sont débloqués."
		items_list.add_child(done)
	else:
		for item in locked:
			items_list.add_child(_build_item_row(item))

	UIUtils.chain_focus(self)
	UIUtils.restore_focus(self, keep, close_button)
	_fit_scrolls.call_deferred()


## LES ZONES SE MESURENT SUR LEUR CONTENU. Un `ScrollContainer` a une taille
## minimale nulle : réglé à la main, il coupait l'arbre dès qu'un nœud gagnait une
## ligne — le défaut est revenu à chaque retouche d'habillage (voir README, « Mise
## en page des écrans »). L'arbre prend donc exactement sa hauteur, et la liste
## des objets la sienne, bornée pour ne pas pousser l'écran hors du cadre.
func _fit_scrolls() -> void:
	tree_scroll.custom_minimum_size.y = branches_row.get_combined_minimum_size().y
	items_scroll.custom_minimum_size.y = minf(items_list.get_combined_minimum_size().y, ITEMS_MAX_HEIGHT)
	branches_row.queue_redraw.call_deferred()


## LE DÉCHAÎNEMENT, armé ici et pas ailleurs.
##
## Sa place est à la Forge : c'est l'écran où l'on décide ce que devient un
## personnage sur la durée, et c'est le seul qui soit déjà propre à chacun. Armé
## une fois, il vaut pour toutes les runs suivantes de CE personnage — Caïn peut
## être déchaîné pendant que Job reste bridé.
##
## Le panneau est CACHÉ tant que la Clé des Abysses n'a pas été ramassée. Pas
## grisé : un bouton désactivé qu'on ne peut pas expliquer sans divulgâcher la
## fin du jeu vaut mieux ne pas exister.
func _rebuild_abysses() -> void:
	abyss_panel.visible = SaveGame.abyss_key
	if not SaveGame.abyss_key:
		return
	var personnage := Characters.get_selected()
	var actif := SaveGame.is_unleashed(personnage.id)
	# `set_pressed_no_signal` : régler l'état ne doit pas rejouer le signal qui
	# écrit dans la sauvegarde, sinon reconstruire l'écran réécrit le profil.
	abyss_button.set_pressed_no_signal(actif)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.10, 0.22, 0.96)
	style.border_color = Color(0.72, 0.42, 1.0) if actif else Color(0.38, 0.28, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	abyss_panel.add_theme_stylebox_override(&"panel", style)

	if actif:
		abyss_button.text = tr("DÉCHAÎNEMENT  ·  ARMÉ POUR %s") % personnage.display_name.to_upper()
		abyss_label.text = tr("Plafonds, taxes et limites de piles levés. En échange,"
			+ " les ennemis doublent de PV toutes les cinq vagues — la course est"
			+ " perdue d'avance, la question est de savoir jusqu'où.")
		abyss_label.add_theme_color_override(&"font_color", Color(0.82, 0.58, 1.0))
	else:
		abyss_button.text = "DÉCHAÎNEMENT"
		abyss_label.text = tr("La Clé des Abysses lève toutes les limites de %s. L'enfer s'endurcit d'autant.") \
			% personnage.display_name
		abyss_label.add_theme_color_override(&"font_color", Color(0.70, 0.66, 0.72))


func _on_dechainement(actif: bool) -> void:
	SaveGame.set_unleashed(Characters.selected_id, actif)
	refresh()


func _build_branch(branch: String) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", ROW_GAP)

	# La branche du personnage est TEINTÉE DE SA COULEUR, et l'écran en compte
	# quatre : sans marque visuelle, rien ne distinguerait celle qui n'existe que
	# pour lui des trois que tout le monde possède.
	var propre: bool = branch == String(Forge.BRANCHES_PERSO.get(Characters.selected_id, ""))
	var title := Label.new()
	title.text = tr(branch).to_upper()
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override(&"font_size", 30)
	title.add_theme_color_override(&"font_color",
		Characters.get_selected().color if propre else Color(1, 0.55, 0.3))
	if propre:
		title.text += "  ·  %s" % Characters.get_selected().display_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	# UN ARBRE, PAS UNE LISTE. Chaque nœud est rangé à sa profondeur — un de plus
	# que le plus profond de ses prérequis — et les nœuds d'un même rang sont
	# côte à côte. Les traits de `_draw_links` font le reste : on voit enfin ce
	# qu'il faut ouvrir pour atteindre ce qu'on veut.
	var rows: Array[HBoxContainer] = []
	for node in Forge.get_branch(branch):
		var depth := _depth(node["id"])
		while rows.size() <= depth:
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override(&"separation", TILE_GAP)
			row.custom_minimum_size = Vector2(0, TILE_SIZE.y)
			rows.append(row)
			column.add_child(row)
		rows[depth].add_child(_build_node_tile(node))
	return column


## Profondeur d'un nœud dans sa branche : 0 sans prérequis, sinon un de plus que
## le plus profond d'entre eux. Lue sur `requires`, donc un nœud ajouté se place
## tout seul.
func _depth(id: StringName) -> int:
	var deepest := -1
	for req in Forge.get_node_data(id).get("requires", []):
		deepest = maxi(deepest, _depth(req))
	return deepest + 1


func _build_node_tile(node: Dictionary) -> Control:
	var id: StringName = node["id"]
	var unlocked := Forge.is_unlocked(id)
	var available := Forge.requirements_met(id)

	# Trois états qui se lisent de loin, sans lire un mot : acquis (plein, doré),
	# achetable (liseré vif), verrouillé (éteint).
	var panel := PanelContainer.new()
	panel.name = "case_%s" % id
	panel.custom_minimum_size = TILE_SIZE
	var style := StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.set_content_margin_all(6)
	if unlocked:
		style.bg_color = Color(0.29, 0.21, 0.1, 0.98)
		style.border_color = Color(0.91, 0.722, 0.282)
	elif available:
		style.bg_color = Color(0.19, 0.16, 0.23, 0.98)
		style.border_color = Color(0.98, 0.86, 0.5)
	else:
		style.bg_color = Color(0.11, 0.1, 0.13, 0.9)
		style.border_color = Color(0.3, 0.24, 0.2)
	panel.add_theme_stylebox_override(&"panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	panel.add_child(box)

	var name_label := Label.new()
	name_label.text = tr(node["name"])
	name_label.add_theme_font_size_override(&"font_size", 15)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not available and not unlocked:
		name_label.add_theme_color_override(&"font_color", Color(0.55, 0.5, 0.5))
	box.add_child(name_label)

	var effect := Label.new()
	effect.text = _effect_text(node)
	effect.add_theme_font_size_override(&"font_size", 12)
	effect.add_theme_color_override(&"font_color",
		Color(0.85, 0.82, 0.78) if available or unlocked else Color(0.5, 0.47, 0.46))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Une ligne, et des points de suspension au-delà : la description entière
	# est dans la barre de détail. Couper un texte au milieu d'une ligne, c'est
	# exactement le défaut que cet écran avait.
	effect.max_lines_visible = 1
	effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(effect)

	var button := Button.new()
	# Nom stable : c'est par lui que le focus se retrouve après reconstruction.
	button.name = "noeud_%s" % id
	button.add_theme_font_size_override(&"font_size", 20)
	button.custom_minimum_size = Vector2(0, 30)
	if unlocked:
		button.text = "Acquis"
		button.disabled = true
		button.theme_type_variation = &"SecondaryButton"
	elif not available:
		button.text = tr("Verrouillé · %d") % int(node["cost"])
		button.disabled = true
		button.theme_type_variation = &"SecondaryButton"
	else:
		button.text = (tr("%d clé") if int(node["cost"]) == 1 else tr("%d clés")) % int(node["cost"])
		button.disabled = not Forge.can_unlock(id)
		button.pressed.connect(func() -> void: Forge.unlock(id))
	# Désactivé mais focalisable : à la manette, c'est le seul moyen de lire le
	# détail d'un nœud qu'on ne peut pas encore ouvrir.
	button.set_meta(UIUtils.INSPECTABLE, true)
	box.add_child(button)

	var detailler := func() -> void: _show_detail(node)
	panel.mouse_entered.connect(detailler)
	button.focus_entered.connect(detailler)
	button.mouse_entered.connect(detailler)
	_tiles[id] = panel
	return panel


func _effect_text(node: Dictionary) -> String:
	var text := ItemCard.format_mods(node.get("mods", {}))
	return text if text != "" else tr(String(node.get("desc", "")))


## La barre de détail : tout ce que la case ne peut pas dire.
func _show_detail(node: Dictionary) -> void:
	var id: StringName = node["id"]
	var state := tr("Acquis") if Forge.is_unlocked(id) else (tr("%d clé") if int(node["cost"]) == 1 else tr("%d clés")) % int(node["cost"])
	var text := "%s  —  %s" % [tr(node["name"]), tr(String(node.get("desc", "")))]
	var mods := ItemCard.format_mods(node.get("mods", {}))
	if mods != "":
		text += "  (%s)" % mods
	text += "   ·   %s" % state
	if not Forge.requirements_met(id) and not Forge.is_unlocked(id):
		text += tr("   ·   Nécessite : %s") % _requirement_names(node)
	detail_label.text = text


## Les liens entre prérequis et nœuds, dessinés SOUS les cases : un trait doré
## quand le prérequis est acquis — le chemin est ouvert —, sombre sinon. Coude à
## angle droit, comme tout le reste de l'interface en pixels.
func _draw_links() -> void:
	var origin := branches_row.get_global_rect().position
	for id in _tiles:
		var child: Control = _tiles[id]
		if not is_instance_valid(child):
			continue
		var to := child.get_global_rect()
		for req in Forge.get_node_data(id).get("requires", []):
			if not _tiles.has(req):
				continue
			var from := (_tiles[req] as Control).get_global_rect()
			var a := Vector2(from.get_center().x, from.end.y) - origin
			var b := Vector2(to.get_center().x, to.position.y) - origin
			# Le coude dans l'intervalle JUSTE AU-DESSUS de la case d'arrivée : à
			# mi-chemin, il tombait dans la rangée intermédiaire, derrière ses cases.
			var mid := b.y - ROW_GAP * 0.5
			var color := Color(0.91, 0.722, 0.282) if Forge.is_unlocked(req) else Color(0.34, 0.27, 0.22)
			branches_row.draw_polyline(PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b]),
				color, 2.0)


func _requirement_names(node: Dictionary) -> String:
	var names: Array[String] = []
	for req in node.get("requires", []):
		names.append(tr(String(Forge.get_node_data(req).get("name", req))))
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
	button.text = (tr("%d clé") if item.key_cost == 1 else tr("%d clés")) % item.key_cost
	button.disabled = SaveGame.banked_keys < item.key_cost
	if button.disabled:
		button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: SaveGame.unlock_item(item))
	row.add_child(button)
	return row
