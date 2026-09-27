extends CanvasLayer
## L'ALBUM (0.9.3) : tous les objets du jeu, comme des vignettes à collectionner.
##
## Un objet est DÉCOUVERT dès qu'on l'a eu une fois en main, quelle que soit la
## run (`SaveGame.decouvrir`). Découvert, il montre son icône, son nom, ce qu'il
## fait et combien de fois on l'a obtenu ; sinon il n'est qu'une silhouette.
## La silhouette garde sa forme : c'est ce qui donne envie de la remplir.
##
## Un Sacré encore verrouillé le dit, avec son prix en clés : l'album est aussi
## une vitrine de la Forge.
##
## Tri par rareté, puis dans l'ordre du catalogue : les communes d'abord, les
## légendaires en dernier, comme on les rencontre en jouant.

## Taille d'une vignette, et de l'icône dedans. ENTIÈRE : l'icône fait 16 px,
## affichée à 3, et le détail à 6 — une échelle fractionnaire donnerait des
## pixels de largeurs inégales (README, « Les icônes d'objets »).
const VIGNETTE := 72.0
const ICONE := 48.0
const SILHOUETTE := Color(0.0, 0.0, 0.0, 0.55)
const GRIS := Color(0.68, 0.64, 0.64)
const OR := Color(1.0, 0.82, 0.4)

@onready var grille: GridContainer = %CollectionGrille
@onready var compte: Label = %CollectionCompte
@onready var icone: TextureRect = %CollectionIcone
@onready var nom: Label = %CollectionNom
@onready var rarete: Label = %CollectionRarete
@onready var texte: Label = %CollectionTexte
@onready var etat: Label = %CollectionEtat
@onready var fermer: Button = %CollectionFermer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	fermer.pressed.connect(close)
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func open() -> void:
	visible = true
	_construire()
	var premiere := grille.get_child(0) as Control if grille.get_child_count() > 0 else null
	if premiere != null:
		premiere.grab_focus()
	else:
		fermer.grab_focus()


func close() -> void:
	visible = false


## Échap / B : retour, comme tous les sous-écrans du menu.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _objets() -> Array[ItemData]:
	var liste := ItemDB.get_all()
	var ordre := {}
	for i in ItemDB.ITEMS.size():
		ordre[ItemDB.ITEMS[i]["id"]] = i
	liste.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return int(ordre.get(a.id, 0)) < int(ordre.get(b.id, 0)))
	return liste


func _construire() -> void:
	UIUtils.clear_children(grille)
	var objets := _objets()
	for item in objets:
		grille.add_child(_vignette(item))
	compte.text = tr("%d / %d objets découverts") % [SaveGame.nombre_decouverts(), objets.size()]
	if not objets.is_empty():
		_detail(objets[0])


func _vignette(item: ItemData) -> Button:
	var connu := SaveGame.est_decouvert(item.id)
	var b := Button.new()
	b.name = "objet_%s" % item.id
	b.theme_type_variation = &"CardButton"
	b.custom_minimum_size = Vector2(VIGNETTE, VIGNETTE)
	b.focus_entered.connect(_detail.bind(item))
	b.mouse_entered.connect(_detail.bind(item))
	var image := TextureRect.new()
	image.texture = item.icon
	image.custom_minimum_size = Vector2(ICONE, ICONE)
	image.size = Vector2(ICONE, ICONE)
	image.position = Vector2((VIGNETTE - ICONE) * 0.5, (VIGNETTE - ICONE) * 0.5 - 2.0)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.modulate = Color.WHITE if connu else SILHOUETTE
	b.add_child(image)
	# Un liseré de sa rareté sous l'icône, une fois découvert : l'album se lit
	# en couleurs à mesure qu'il se remplit.
	if connu:
		var lisere := ColorRect.new()
		lisere.color = item.get_rarity_color()
		lisere.position = Vector2(10.0, VIGNETTE - 9.0)
		lisere.size = Vector2(VIGNETTE - 20.0, 3.0)
		lisere.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lisere)
	return b


func _detail(item: ItemData) -> void:
	var connu := SaveGame.est_decouvert(item.id)
	icone.texture = item.icon
	icone.modulate = Color.WHITE if connu else SILHOUETTE
	rarete.text = item.get_rarity_name()
	rarete.add_theme_color_override(&"font_color", item.get_rarity_color())
	if connu:
		nom.text = item.display_name
		nom.add_theme_color_override(&"font_color", item.get_rarity_color())
		texte.text = item.description
		var fois := SaveGame.fois_obtenu(item.id)
		etat.text = tr("Obtenu une fois") if fois == 1 else tr("Obtenu %d fois") % fois
		etat.add_theme_color_override(&"font_color", GRIS)
		return
	nom.text = "???"
	nom.add_theme_color_override(&"font_color", GRIS)
	texte.text = tr("Pas encore trouvé.")
	if item.key_cost > 0 and not SaveGame.is_unlocked(item.id):
		etat.text = (tr("Sacré : à débloquer à la Forge pour %d clé") if item.key_cost == 1
			else tr("Sacré : à débloquer à la Forge pour %d clés")) % item.key_cost
		etat.add_theme_color_override(&"font_color", OR)
	else:
		etat.text = tr("Il vous attend en boutique.")
		etat.add_theme_color_override(&"font_color", GRIS)
