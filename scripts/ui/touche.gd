class_name Touche
extends Control
## UNE TOUCHE À L'ÉCRAN : celle qu'il faut presser, dessinée comme une touche.
##
## Trois cas :
##   - la planche la possède (lettres, flèches, F1 à F12, quelques signes) :
##     on dessine sa case telle quelle ;
##   - elle ne la possède pas (Espace, Tab, Échap…) : une touche VIERGE étirée,
##     son nom écrit dessus (voir `tools/extract_assets.py`, `touches`) ;
##   - une manette sert : un bouton rond, sa lettre dans sa couleur.
##
## Liée à une ACTION, elle lit la vraie touche dans la table d'entrées — et sur
## la disposition de clavier du joueur : une touche physique « W » s'affiche
## « Z » sur un clavier AZERTY. Elle s'enfonce tant que l'action est pressée :
## l'écran confirme l'appui, c'est la moitié de l'intérêt d'une touche dessinée.
##
## Planches absentes (dépôt fraîchement cloné) : le nom entre crochets, en texte.

const PLANCHE := "res://assets/sprites/ui/touches.png"
const VIERGE := "res://assets/sprites/ui/touche_vide.png"
## Côté d'une case, en pixels de planche.
const CASE := 16
## Colonnes de la touche vierge : bord gauche, milieu étirable, bord droit.
const BORD_G := 5
const BORD_D := 6
## Rangées occupées par la face où s'écrit l'étiquette (y 4 à 8 compris).
const FACE_HAUT := 4
const FACE_BAS := 9

## Position de chaque étiquette dans la planche, rangée normale ; la version
## enfoncée est sept rangées plus bas.
const GLYPHES := {
	"↑": Vector2i(0, 0), "↓": Vector2i(1, 0), "←": Vector2i(2, 0), "→": Vector2i(3, 0),
	"F1": Vector2i(4, 0), "F2": Vector2i(5, 0), "F3": Vector2i(6, 0), "F4": Vector2i(7, 0),
	"F5": Vector2i(0, 1), "F6": Vector2i(1, 1), "F7": Vector2i(2, 1), "F8": Vector2i(3, 1),
	"F9": Vector2i(4, 1), "F10": Vector2i(5, 1), "F11": Vector2i(6, 1), "F12": Vector2i(7, 1),
	"A": Vector2i(0, 2), "B": Vector2i(1, 2), "C": Vector2i(2, 2), "D": Vector2i(3, 2),
	"E": Vector2i(4, 2), "F": Vector2i(5, 2), "G": Vector2i(6, 2), "H": Vector2i(7, 2),
	"I": Vector2i(0, 3), "J": Vector2i(1, 3), "K": Vector2i(2, 3), "L": Vector2i(3, 3),
	"M": Vector2i(4, 3), "N": Vector2i(5, 3), "O": Vector2i(6, 3), "P": Vector2i(7, 3),
	"Q": Vector2i(0, 4), "R": Vector2i(1, 4), "S": Vector2i(2, 4), "T": Vector2i(3, 4),
	"U": Vector2i(4, 4), "V": Vector2i(5, 4), "W": Vector2i(6, 4), "X": Vector2i(7, 4),
	"Y": Vector2i(0, 5), "Z": Vector2i(1, 5), ".": Vector2i(2, 5), ",": Vector2i(3, 5),
	"?": Vector2i(4, 5), "/": Vector2i(5, 5), "\\": Vector2i(6, 5), ";": Vector2i(7, 5),
	"'": Vector2i(0, 6), "[": Vector2i(1, 6), "]": Vector2i(2, 6), "=": Vector2i(3, 6),
	"-": Vector2i(4, 6), "~": Vector2i(5, 6),
}
const DECALAGE_ENFONCEE := 7
## Hauteur d'une capitale, en part de l'ascendante de la police : l'ascendante
## réserve la place des accents, centrer sur elle poserait le texte trop bas.
const HAUTEUR_CAPITALE := 0.72

## Les noms de touches que Godot renvoie, en français et en capitales (traduits
## à la lecture, comme tout texte du jeu).
const NOMS := {
	"Space": "ESPACE", "Tab": "TAB", "Escape": "ÉCHAP", "Enter": "ENTRÉE",
	"Shift": "MAJ", "Ctrl": "CTRL", "Alt": "ALT", "Backspace": "RETOUR",
	"Up": "↑", "Down": "↓", "Left": "←", "Right": "→",
}

## Boutons de manette : lettre et couleur (disposition Xbox, celle que Godot
## nomme par défaut).
const BOUTONS := {
	JOY_BUTTON_A: ["A", Color(0.45, 0.85, 0.35)], JOY_BUTTON_B: ["B", Color(0.95, 0.35, 0.3)],
	JOY_BUTTON_X: ["X", Color(0.35, 0.6, 1.0)], JOY_BUTTON_Y: ["Y", Color(1.0, 0.85, 0.3)],
	JOY_BUTTON_BACK: ["SELECT", Color(0.8, 0.8, 0.85)],
	JOY_BUTTON_START: ["START", Color(0.8, 0.8, 0.85)],
	JOY_BUTTON_LEFT_SHOULDER: ["LB", Color(0.8, 0.8, 0.85)],
	JOY_BUTTON_RIGHT_SHOULDER: ["RB", Color(0.8, 0.8, 0.85)],
}

## L'action dont on affiche la touche. Vide : `texte` fait foi.
@export var action: StringName = &""
## L'étiquette à afficher quand aucune action n'est liée.
@export var texte: String = ""
## Échelle entière : c'est du pixel art.
@export var echelle: int = 2
## Afficher le bouton de manette plutôt que la touche.
var manette := false:
	set(v):
		manette = v
		_actualiser()

static var _planche: Texture2D
static var _vierge: Texture2D
static var _charge := false

var _etiquette := ""
var _bouton := ""
var _couleur_bouton := Color.WHITE
var _enfoncee := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _charge:
		_charge = true
		if ResourceLoader.exists(PLANCHE) and ResourceLoader.exists(VIERGE):
			_planche = load(PLANCHE)
			_vierge = load(VIERGE)
	_actualiser()


func _process(_delta: float) -> void:
	if action == &"":
		return
	var appui := Input.is_action_pressed(action)
	if appui != _enfoncee:
		_enfoncee = appui
		queue_redraw()


## L'étiquette de la touche clavier liée à une action, sur la disposition du
## joueur. Vide si l'action n'a pas de touche.
static func nom_de(action_: StringName) -> String:
	if not InputMap.has_action(action_):
		return ""
	for ev in InputMap.action_get_events(action_):
		var touche := ev as InputEventKey
		if touche == null:
			continue
		var code := touche.keycode
		if touche.physical_keycode != KEY_NONE:
			code = DisplayServer.keyboard_get_keycode_from_physical(touche.physical_keycode)
		var nom := OS.get_keycode_string(code)
		return TranslationServer.translate(NOMS[nom]) if NOMS.has(nom) else nom.to_upper()
	return ""


## Le bouton de manette lié à une action : [lettre, couleur], ou [].
static func bouton_de(action_: StringName) -> Array:
	if not InputMap.has_action(action_):
		return []
	for ev in InputMap.action_get_events(action_):
		var bouton := ev as InputEventJoypadButton
		if bouton != null:
			return BOUTONS.get(bouton.button_index, [str(bouton.button_index), Color.WHITE])
	return []


## Le nom de la touche est dessiné, pas posé dans un Label : il ne suit pas un
## changement de langue tout seul.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_actualiser()


func _actualiser() -> void:
	if not is_inside_tree():
		return
	_etiquette = nom_de(action) if action != &"" else texte
	var b := bouton_de(action) if action != &"" else []
	_bouton = b[0] if not b.is_empty() else ""
	_couleur_bouton = b[1] if not b.is_empty() else Color.WHITE
	custom_minimum_size = _taille()
	update_minimum_size()
	queue_redraw()


func _police() -> Font:
	return get_theme_font(&"font", &"TitleLabel")


## Taille de police qui remplit la face d'une touche vierge : ses 5 rangées
## de face, à l'échelle.
func _taille_police() -> int:
	return (FACE_BAS - FACE_HAUT) * echelle + 4


func _largeur_texte(s: String, taille: int) -> float:
	return _police().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x


func _taille() -> Vector2:
	var cote := float(CASE * echelle)
	if manette and _bouton != "":
		var l := maxf(cote * 0.8, _largeur_texte(_bouton, _taille_police()) + 14.0)
		return Vector2(l, cote)
	if _planche == null:
		return Vector2(_largeur_texte("[%s]" % _etiquette, _taille_police() + 4), cote)
	if GLYPHES.has(_etiquette):
		return Vector2(cote, cote)
	var milieu := maxf(float(CASE - BORD_G - BORD_D) * echelle,
		_largeur_texte(_etiquette, _taille_police()) + 2.0 * echelle)
	return Vector2(float(BORD_G + BORD_D) * echelle + milieu, cote)


func _draw() -> void:
	var cote := float(CASE * echelle)
	if manette and _bouton != "":
		_dessiner_bouton(cote)
		return
	if _planche == null:
		draw_string(_police(), Vector2(0.0, cote * 0.72), "[%s]" % _etiquette,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _taille_police() + 4, Color.WHITE)
		return
	var ligne := DECALAGE_ENFONCEE if _enfoncee else 0
	if GLYPHES.has(_etiquette):
		var g: Vector2i = GLYPHES[_etiquette]
		draw_texture_rect_region(_planche, Rect2(Vector2.ZERO, Vector2(cote, cote)),
			Rect2(Vector2(g.x, g.y + ligne) * CASE, Vector2(CASE, CASE)))
		return
	# La touche vierge étirée : bord gauche, milieu, bord droit.
	var src_x := 16.0 if _enfoncee else 0.0
	var l := size.x
	var e := float(echelle)
	draw_texture_rect_region(_vierge, Rect2(0.0, 0.0, BORD_G * e, cote),
		Rect2(src_x, 0.0, BORD_G, CASE))
	draw_texture_rect_region(_vierge, Rect2(BORD_G * e, 0.0, l - (BORD_G + BORD_D) * e, cote),
		Rect2(src_x + BORD_G, 0.0, CASE - BORD_G - BORD_D, CASE))
	draw_texture_rect_region(_vierge, Rect2(l - BORD_D * e, 0.0, BORD_D * e, cote),
		Rect2(src_x + CASE - BORD_D, 0.0, BORD_D, CASE))
	# L'étiquette sur la face : blanche au repos, bleue enfoncée — les deux
	# couleurs de la planche. Enfoncée, la face descend d'une rangée.
	var taille := _taille_police()
	var couleur := Color(0.63, 0.79, 1.0) if _enfoncee else Color.WHITE
	var police := _police()
	var milieu_face := (float(FACE_HAUT + FACE_BAS) * 0.5 + (1.0 if _enfoncee else 0.0)) * e
	# La ligne de base sous le milieu de la face, d'une demi-hauteur de capitale.
	var base := milieu_face + police.get_ascent(taille) * HAUTEUR_CAPITALE * 0.5
	draw_string(police, Vector2(0.0, base), _etiquette, HORIZONTAL_ALIGNMENT_CENTER, l,
		taille, couleur)


## Un bouton de manette : pastille ronde (ou gélule pour SELECT et START),
## lettre dans sa couleur. Enfoncé, il s'assombrit et descend d'un cran.
func _dessiner_bouton(cote: float) -> void:
	var e := float(echelle)
	var dy := e if _enfoncee else 0.0
	var r := cote * 0.42
	var c := Vector2(size.x * 0.5, cote * 0.5 + dy)
	var fond := Color(0.1, 0.08, 0.1) if not _enfoncee else Color(0.05, 0.04, 0.05)
	if size.x > cote:
		var rect := Rect2(Vector2(r * 0.4, c.y - r), Vector2(size.x - r * 0.8, r * 2.0))
		var style := StyleBoxFlat.new()
		style.bg_color = fond
		style.border_color = _couleur_bouton.darkened(0.3)
		style.set_border_width_all(int(e))
		style.set_corner_radius_all(int(r))
		draw_style_box(style, rect)
	else:
		draw_circle(c, r + e, _couleur_bouton.darkened(0.35))
		draw_circle(c, r, fond)
	var taille := _taille_police()
	var police := _police()
	draw_string(police, Vector2(0.0, c.y + police.get_ascent(taille) * 0.35), _bouton,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, taille,
		_couleur_bouton.darkened(0.3) if _enfoncee else _couleur_bouton)
