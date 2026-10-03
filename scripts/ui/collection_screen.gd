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
##
## Deux autres onglets depuis la 0.10.1 : le BESTIAIRE (`Bestiaire`), chaque
## créature recensée à sa première élimination, et le REGISTRE de l'Accusateur
## (`Registre`), les pages de Lucifer, trouvées en avançant dans l'histoire.

enum Onglet { OBJETS, BESTIAIRE, REGISTRE }

## Taille d'une vignette, et de l'icône dedans. ENTIÈRE : l'icône fait 16 px,
## affichée à 3, et le détail à 6 — une échelle fractionnaire donnerait des
## pixels de largeurs inégales (README, « Les icônes d'objets »).
const VIGNETTE := 72.0
const ICONE := 48.0
## Le bestiaire : le portrait recadré (`Bestiaire.CADRAGE`, 46 × 42), affiché
## à 3 dans la grille et à 4 dans le détail — à 2, un imp n'y faisait que
## 40 px de haut. Quatre colonnes font la largeur des huit colonnes d'objets.
const PORTRAIT := Vector2(138, 126)
const PORTRAIT_DETAIL := Vector2(184, 168)
const VIGNETTE_BETE := Vector2(148, 136)
const COLONNES := {Onglet.OBJETS: 8, Onglet.BESTIAIRE: 4, Onglet.REGISTRE: 2}
## Deux colonnes de pages, à la même largeur que les autres grilles.
const PAGE := Vector2(312, 52)
const SILHOUETTE := Color(0.0, 0.0, 0.0, 0.55)
const GRIS := Color(0.68, 0.64, 0.64)
const OR := Color(1.0, 0.82, 0.4)
const ROUGE_BOSS := Color(0.95, 0.35, 0.25)
const PARCHEMIN := Color(0.93, 0.86, 0.72)

var _onglet: Onglet = Onglet.OBJETS

@onready var onglets := {
	Onglet.OBJETS: %CollectionOngletObjets as Button,
	Onglet.BESTIAIRE: %CollectionOngletBestiaire as Button,
	Onglet.REGISTRE: %CollectionOngletRegistre as Button,
}
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
	var groupe := ButtonGroup.new()
	for onglet in onglets:
		var bouton: Button = onglets[onglet]
		bouton.button_group = groupe
		bouton.pressed.connect(_choisir.bind(onglet))


func open() -> void:
	visible = true
	_choisir(_onglet)
	var premiere := grille.get_child(0) as Control if grille.get_child_count() > 0 else null
	if premiere != null:
		premiere.grab_focus()
	else:
		fermer.grab_focus()
	Ecran.apparaitre(self)


func _choisir(onglet: Onglet) -> void:
	_onglet = onglet
	# L'onglet ouvert est doré, les autres sombres : le bouton enfoncé du
	# thème ne se distinguait pas assez du survol.
	for autre in onglets:
		var bouton: Button = onglets[autre]
		bouton.set_pressed_no_signal(autre == onglet)
		bouton.theme_type_variation = &"" if autre == onglet else &"SecondaryButton"
	_construire()


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
	grille.columns = COLONNES[_onglet]
	icone.visible = _onglet != Onglet.REGISTRE
	icone.material = null
	match _onglet:
		Onglet.BESTIAIRE:
			icone.custom_minimum_size = PORTRAIT_DETAIL
			_construire_bestiaire()
		Onglet.REGISTRE:
			_construire_registre()
		_:
			icone.custom_minimum_size = Vector2(96, 96)
			_construire_objets()


func _construire_objets() -> void:
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


# --- Le bestiaire ------------------------------------------------------------

func _construire_bestiaire() -> void:
	for fiche: Dictionary in Bestiaire.CREATURES:
		grille.add_child(_vignette_bete(fiche))
	compte.text = tr("%d / %d créatures recensées") % [Bestiaire.nombre_connues(),
		Bestiaire.CREATURES.size()]
	_detail_bete(Bestiaire.CREATURES[0])


## Le portrait d'une créature, et le matériau d'Hélel : sa lumière d'or.
func _peindre(image: TextureRect, fiche: Dictionary, connue: bool) -> void:
	var secrete: bool = fiche.get("secret", false) and not connue
	image.texture = null if secrete else Bestiaire.portrait(fiche)
	image.modulate = Color.WHITE if connue else SILHOUETTE
	image.material = BossHelel.make_aurore_material() \
		if connue and fiche["id"] == &"helel" else null


func _vignette_bete(fiche: Dictionary) -> Button:
	var connue := Bestiaire.connue(fiche)
	var b := Button.new()
	b.name = "bete_%s" % fiche["id"]
	b.theme_type_variation = &"CardButton"
	b.custom_minimum_size = VIGNETTE_BETE
	b.focus_entered.connect(_detail_bete.bind(fiche))
	b.mouse_entered.connect(_detail_bete.bind(fiche))
	var image := TextureRect.new()
	image.size = PORTRAIT
	image.position = (VIGNETTE_BETE - PORTRAIT) * 0.5
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peindre(image, fiche, connue)
	b.add_child(image)
	if fiche.get("secret", false) and not connue:
		b.text = "?"
	# Le liseré des boss, comme celui de la rareté dans l'album.
	if connue and fiche.get("boss", false):
		var lisere := ColorRect.new()
		lisere.color = ROUGE_BOSS
		lisere.position = Vector2(14.0, VIGNETTE_BETE.y - 8.0)
		lisere.size = Vector2(VIGNETTE_BETE.x - 28.0, 3.0)
		lisere.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lisere)
	return b


func _detail_bete(fiche: Dictionary) -> void:
	var connue := Bestiaire.connue(fiche)
	var boss: bool = fiche.get("boss", false)
	_peindre(icone, fiche, connue)
	if fiche.get("secret", false) and not connue:
		rarete.text = "???"
	else:
		rarete.text = tr("Boss") if boss else tr("Créature")
	rarete.add_theme_color_override(&"font_color", ROUGE_BOSS if boss else GRIS)
	if not connue:
		nom.text = "???"
		nom.add_theme_color_override(&"font_color", GRIS)
		texte.text = tr("Pas encore abattu.")
		etat.text = ""
		return
	nom.text = fiche["nom"]
	nom.add_theme_color_override(&"font_color", ROUGE_BOSS if boss else PARCHEMIN)
	texte.text = "%s\n\n%s" % [tr(fiche["histoire"]), tr(fiche["conseil"])]
	var fois := SaveGame.nombre_tues(fiche["id"])
	if fois == 0:
		# Vaincu avant que le bestiaire ne tienne ses comptes.
		etat.text = tr("Vaincu")
	else:
		etat.text = tr("Abattu une fois") if fois == 1 else tr("Abattu %d fois") % fois
	etat.add_theme_color_override(&"font_color", GRIS)


# --- Le Registre -------------------------------------------------------------

const ROMAINS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]


func _construire_registre() -> void:
	for i in Registre.FRAGMENTS.size():
		grille.add_child(_page(i))
	compte.text = tr("%d / %d fragments retrouvés") % [Registre.nombre_trouves(),
		Registre.FRAGMENTS.size()]
	_detail_page(0)


func _titre_page(i: int) -> String:
	var fragment: Dictionary = Registre.FRAGMENTS[i]
	if fragment.get("secret", false) and not Registre.trouve(fragment):
		return "???"
	return tr(fragment["titre"])


func _page(i: int) -> Button:
	var trouve := Registre.trouve(Registre.FRAGMENTS[i])
	var b := Button.new()
	b.name = "page_%d" % i
	b.theme_type_variation = &"CardButton"
	b.custom_minimum_size = PAGE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "  %s.  %s" % [ROMAINS[i], _titre_page(i)]
	b.add_theme_color_override(&"font_color", PARCHEMIN if trouve else GRIS * Color(1, 1, 1, 0.7))
	b.focus_entered.connect(_detail_page.bind(i))
	b.mouse_entered.connect(_detail_page.bind(i))
	return b


func _detail_page(i: int) -> void:
	var fragment: Dictionary = Registre.FRAGMENTS[i]
	var trouve := Registre.trouve(fragment)
	rarete.text = tr("Fragment %s") % ROMAINS[i]
	rarete.add_theme_color_override(&"font_color", GRIS)
	nom.text = _titre_page(i)
	nom.add_theme_color_override(&"font_color", PARCHEMIN if trouve else GRIS)
	if trouve:
		texte.text = fragment["texte"]
		etat.text = ""
		return
	texte.text = tr("Pas encore trouvé.")
	etat.text = fragment["condition"]
	etat.add_theme_color_override(&"font_color", OR)
