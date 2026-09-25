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
@onready var unleash_label: Label = %UnleashLabel
@onready var forge_button: Button = %CharForgeButton
@onready var back_button: Button = %CharBackButton

## Mesurées sur la plus longue des trois descriptions, à la taille de police
## ci-dessous : à remesurer si l'une d'elles s'allonge.
const CARD_MIN_SIZE := Vector2(400, 480)
## Hauteur visée du portrait ; le facteur réel est l'entier juste en dessous.
const PORTRAIT_HEIGHT := 176.0

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
	# La HAUTEUR porte le texte : un Label en autowrap ne réclame qu'une ligne,
	# c'est la carte qui doit prévoir la place de la description entière. À 288
	# elle était coupée au milieu d'une phrase pour les trois personnages.
	card.custom_minimum_size = CARD_MIN_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(func() -> void: Characters.select(character.id))
	# À la manette, se poser sur une carte CHOISIT le personnage : il n'y a rien
	# d'autre à faire sur une carte, et un appui sur A de plus avant de pouvoir
	# descendre sur « Commencer » était un pas pour rien. Pas au survol de la
	# souris : glisser vers le bouton en travers d'une autre carte la choisirait.
	card.focus_entered.connect(func() -> void:
		if not MenuNav.is_mouse_mode():
			Characters.select(character.id))

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
		# Agrandi d'un facteur ENTIER : à un facteur quelconque, un pixel sur deux
		# serait plus large que son voisin et le personnage paraîtrait déformé.
		var source := character.portrait.get_size()
		var facteur := maxf(1.0, floorf(PORTRAIT_HEIGHT / maxf(1.0, source.y)))
		portrait.custom_minimum_size = source * facteur
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Pixel art : sans Nearest, la carte affiche une bouillie floue.
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(portrait)

	box.add_child(_label(character.display_name, 32, character.color, 1))
	box.add_child(_label(character.title, 17, Color(0.82, 0.78, 0.76), 1))
	box.add_child(_label(character.archetype.to_upper(), 15, character.color, 1))
	# L'état de SA Forge, sur SA carte. Les clés sont communes au profil mais les
	# nœuds ne le sont pas : choisir un personnage, c'est aussi choisir dans quel
	# investissement on repart, et ça doit se voir avant de cliquer.
	var avancement := Forge.get_progress_for(character.id)
	var branche: String = String(Forge.BRANCHES_PERSO.get(character.id, ""))
	box.add_child(_label("Forge %d/%d  ·  branche %s" % [
		avancement.x, avancement.y, branche], 14, Color(0.72, 0.68, 0.66), 1))
	box.add_child(HSeparator.new())

	var desc := _label(character.description, 16, Color(0.78, 0.76, 0.76), 0)
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
	_refresh_dechainement()


## Un TÉMOIN, pas un interrupteur : le Déchaînement s'arme à la Forge, où l'on
## décide ce que devient un personnage. Il doit quand même se lire ici, juste
## au-dessus du bouton qui lance la partie — c'est le dernier moment pour
## s'apercevoir qu'on part en déchaîné sans l'avoir voulu.
func _refresh_dechainement() -> void:
	var arme := SaveGame.is_unleashed(Characters.selected_id)
	unleash_label.visible = arme
	if not arme:
		return
	unleash_label.text = "DÉCHAÎNEMENT ARMÉ — aucune limite, et un enfer qui double" \
		+ " de PV toutes les cinq vagues. Se désarme à la Forge."
	unleash_label.add_theme_color_override(&"font_color", Color(0.82, 0.58, 1.0))
