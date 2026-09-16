extends CanvasLayer
## Choix du personnage, ouvert depuis « Jouer ».
##
## Les cartes sont construites à partir de `Characters.get_all()` : ajouter un
## personnage au catalogue le fait apparaître ici sans retoucher l'interface.

signal start_requested()
signal forge_requested()

@onready var cards_row: HBoxContainer = %CharacterCards
@onready var stats_label: Label = %CharStatsLabel
@onready var passive_label: Label = %CharPassiveLabel
@onready var start_button: Button = %StartButton
@onready var forge_button: Button = %CharForgeButton
@onready var back_button: Button = %CharBackButton

var _cards: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	start_button.pressed.connect(func() -> void: start_requested.emit())
	forge_button.pressed.connect(func() -> void: forge_requested.emit())
	back_button.pressed.connect(close)
	Characters.selection_changed.connect(func(_c: CharacterData) -> void: _refresh())


func open() -> void:
	visible = true
	_build_cards()
	_refresh()
	UIUtils.chain_focus(self)
	start_button.grab_focus()


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


func _build_cards() -> void:
	UIUtils.clear_children(cards_row)
	_cards.clear()
	for character in Characters.get_all():
		var card := _build_card(character)
		cards_row.add_child(card)
		_cards[character.id] = card


func _build_card(character: CharacterData) -> Button:
	# Le bouton EST la carte : sélection au clic, focus clavier/manette gratuit.
	var card := Button.new()
	# Variation de thème : une carte est un panneau cliquable, pas un bouton doré
	# — sur le doré du kit, les noms colorés des personnages sont illisibles.
	card.theme_type_variation = &"CardButton"
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(240, 288)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(func() -> void: Characters.select(character.id))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(StringName("margin_" + side), 14)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	if character.portrait != null:
		var portrait := TextureRect.new()
		portrait.texture = character.portrait
		portrait.custom_minimum_size = Vector2(0, 96)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Pixel art : sans Nearest, la carte affiche une bouillie floue.
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(portrait)

	box.add_child(_label(character.display_name, 26, character.color, 1))
	box.add_child(_label(character.title, 14, Color(0.78, 0.74, 0.72), 1))
	box.add_child(_label(character.archetype.to_upper(), 13, character.color, 1))
	box.add_child(HSeparator.new())

	var desc := _label(character.description, 12, Color(0.72, 0.7, 0.7), 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	return card


func _label(text: String, size: int, color: Color, align: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.horizontal_alignment = align as HorizontalAlignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(_delta: float) -> void:
	if not visible:
		return
	for id in _cards:
		(_cards[id] as Button).button_pressed = id == Characters.selected_id


func _refresh() -> void:
	var character := Characters.get_selected()
	if character == null:
		return
	stats_label.text = "%d PV   ·   %d vitesse   ·   %.0f DPS de départ   ·   %d portée" % [
		roundi(character.max_health), roundi(character.move_speed),
		character.get_base_dps(), roundi(character.targeting_range)]
	if character.passive_name != "":
		passive_label.text = "%s — %s" % [character.passive_name, character.passive_description]
		passive_label.add_theme_color_override(&"font_color", character.color)
	else:
		passive_label.text = ""
	start_button.text = "COMMENCER AVEC %s" % character.display_name.to_upper()
