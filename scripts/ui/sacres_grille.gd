class_name SacresGrille
extends GridContainer
## LES OBJETS SACRÉS (0.9.3) : ceux qui s'achètent avec des clés, en vignettes.
##
## Ils étaient une liste qui défilait, texte coloré et bouton de prix : on n'y
## voyait ni l'objet ni ce qui restait à prendre. Ce sont maintenant des
## vignettes, comme dans la collection, TOUTES affichées — les acquis compris —,
## pour qu'on voie d'un coup d'œil ce qu'on a et ce qui reste. Treize vignettes
## tiennent sur une ligne à la Forge ; la fin de run les range sur deux.
##
## Le nom et l'effet passent par `survole` : chaque écran les montre dans sa
## barre de détail, la vignette n'a la place que pour l'icône et le prix.

signal survole(item: ItemData)

## Vignette, et icône dedans à l'échelle ENTIÈRE ×3 (README, « Les icônes
## d'objets »).
const VIGNETTE := Vector2(84, 96)
const ICONE := 48.0
const OR := Color(1.0, 0.85, 0.39)
const GRIS := Color(0.55, 0.5, 0.5)
const ACQUIS := Color(0.91, 0.722, 0.282)
const TEXTE_ACQUIS := Color(0.95, 0.9, 0.78)


func _ready() -> void:
	add_theme_constant_override(&"h_separation", 8)
	add_theme_constant_override(&"v_separation", 8)


func construire() -> void:
	UIUtils.clear_children(self)
	for item in objets():
		add_child(_vignette(item))


## Les objets à clé, du moins cher au plus cher : l'ordre dans lequel on les
## achète.
static func objets() -> Array[ItemData]:
	var liste: Array[ItemData] = []
	for item in ItemDB.get_all():
		if item.key_cost > 0:
			liste.append(item)
	liste.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.key_cost < b.key_cost if a.key_cost != b.key_cost else a.id < b.id)
	return liste


## Le texte de la barre de détail : nom, effet, et où en est l'objet.
static func detail(item: ItemData) -> String:
	var etat: String = TranslationServer.translate("Acquis") if SaveGame.is_unlocked(item.id) \
		else _prix(item)
	return "%s  —  %s   ·   %s" % [item.display_name, item.description, etat]


static func _prix(item: ItemData) -> String:
	return (TranslationServer.translate("%d clé") if item.key_cost == 1
		else TranslationServer.translate("%d clés")) % item.key_cost


func _vignette(item: ItemData) -> Button:
	var acquis := SaveGame.is_unlocked(item.id)
	var abordable := not acquis and SaveGame.banked_keys >= item.key_cost
	var b := Button.new()
	# Nom stable : c'est par lui que le focus se retrouve après reconstruction.
	b.name = "objet_%s" % item.id
	b.theme_type_variation = &"CardButton"
	b.custom_minimum_size = VIGNETTE
	# Acquis ou trop cher, la vignette ne fait rien, mais elle reste
	# focalisable : à la manette, c'est le seul moyen d'en lire le détail.
	b.disabled = not abordable
	b.set_meta(UIUtils.INSPECTABLE, true)
	if abordable:
		b.pressed.connect(func() -> void: SaveGame.unlock_item(item))
	# Acquis : le fond doré plein d'un nœud acquis de la Forge. Le même code
	# visuel sur tout l'écran — un doré de texte seul se confondait avec le prix
	# d'un objet abordable.
	if acquis:
		var fond := Ecran.case(true, 0.0)
		fond.modulate_color = Color(1.0, 0.86, 0.62)
		for etat in [&"normal", &"disabled", &"hover"]:
			b.add_theme_stylebox_override(etat, fond)
	b.focus_entered.connect(func() -> void: survole.emit(item))
	b.mouse_entered.connect(func() -> void: survole.emit(item))

	var image := TextureRect.new()
	image.texture = item.icon
	image.size = Vector2(ICONE, ICONE)
	image.position = Vector2((VIGNETTE.x - ICONE) * 0.5, 8.0)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Trop cher : éteint, mais on reconnaît l'objet — c'est ce qui donne envie.
	image.modulate = Color.WHITE if acquis or abordable else Color(1, 1, 1, 0.4)
	b.add_child(image)

	# Le liseré de sa rareté, comme dans la collection.
	var lisere := ColorRect.new()
	lisere.color = item.get_rarity_color()
	lisere.position = Vector2(12.0, 60.0)
	lisere.size = Vector2(VIGNETTE.x - 24.0, 3.0)
	lisere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lisere)

	var prix := Label.new()
	prix.text = tr("Acquis") if acquis else _prix(item)
	prix.position = Vector2(0.0, 64.0)
	prix.size = Vector2(VIGNETTE.x, 26.0)
	prix.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prix.add_theme_font_size_override(&"font_size", 18)
	prix.add_theme_color_override(&"font_color", TEXTE_ACQUIS if acquis else (OR if abordable else GRIS))
	prix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(prix)
	return b
