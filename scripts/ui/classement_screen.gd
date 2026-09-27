extends CanvasLayer
## L'écran du CLASSEMENT (0.9.3) : les dix meilleures runs de chaque tableau.
##
## Deux onglets, le classique et le Déchaînement (voir `Classement`). L'onglet
## ouvert est le bouton DORÉ, l'autre est secondaire : un seul bouton principal
## par écran, et c'est celui où l'on est.
##
## Les lignes du profil actif sont en or : dans un classement partagé, on se
## cherche d'abord soi-même.

const LIGNES := 10
const OR := Color(1.0, 0.82, 0.4)
const GRIS := Color(0.68, 0.64, 0.64)
const BLANC := Color(0.92, 0.9, 0.9)
## Largeur des colonnes : rang, joueur, damné, vague, éliminations, temps.
const COLONNES := [70.0, 270.0, 170.0, 110.0, 170.0, 110.0]

@onready var onglet_classique: Button = %OngletClassique
@onready var onglet_dechaine: Button = %OngletDechaine
@onready var table: VBoxContainer = %ClassementTable
@onready var fermer: Button = %ClassementFermer

var _tableau: StringName = Classement.CLASSIQUE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	fermer.pressed.connect(close)
	onglet_classique.pressed.connect(_montrer.bind(Classement.CLASSIQUE))
	onglet_dechaine.pressed.connect(_montrer.bind(Classement.DECHAINE))
	Classement.change.connect(func() -> void:
		if visible:
			_construire())


func open() -> void:
	visible = true
	_montrer(Classement.CLASSIQUE)
	onglet_classique.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _montrer(tableau: StringName) -> void:
	_tableau = tableau
	onglet_classique.theme_type_variation = &"" if tableau == Classement.CLASSIQUE \
		else &"SecondaryButton"
	onglet_dechaine.theme_type_variation = &"" if tableau == Classement.DECHAINE \
		else &"SecondaryButton"
	_construire()


func _construire() -> void:
	UIUtils.clear_children(table)
	table.add_child(_ligne([tr("RANG"), tr("JOUEUR"), tr("DAMNÉ"), tr("VAGUE"),
		tr("ÉLIMINATIONS"), tr("TEMPS")], GRIS, 16))
	var entrees := Classement.entrees(_tableau)
	if entrees.is_empty():
		var vide := Label.new()
		vide.text = tr("Aucune run enregistrée pour l'instant.") if _tableau == Classement.CLASSIQUE \
			else tr("Aucune run déchaînée pour l'instant. Le Déchaînement s'arme à la Forge, après Lucifer.")
		vide.add_theme_color_override(&"font_color", GRIS)
		vide.add_theme_font_size_override(&"font_size", 18)
		vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vide.custom_minimum_size = Vector2(0, 60)
		table.add_child(vide)
		return
	for i in mini(LIGNES, entrees.size()):
		var e: Dictionary = entrees[i]
		var perso := Characters.get_character(StringName(e["personnage"]))
		var moi: bool = int(e.get("profil", -1)) == SaveGame.active_slot \
			and SaveGame.nom_affiche(int(e["profil"]), String(e["nom"])) == SaveGame.profile_name
		table.add_child(_ligne([
			_rang(i + 1),
			# Un nom par défaut (« Profil 2 ») suit la langue du jeu, pas celle
			# du jour où la run a été jouée.
			SaveGame.nom_affiche(int(e.get("profil", 0)), String(e["nom"])),
			perso.display_name if perso != null else "—",
			str(int(e["vague"])),
			str(int(e["eliminations"])),
			HUD._format_time(float(e["temps"])),
		], OR if moi else BLANC, 20))


static func _rang(n: int) -> String:
	return TranslationServer.translate("1er") if n == 1 \
		else TranslationServer.translate("%de") % n


func _ligne(cellules: Array, couleur: Color, taille: int) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 8)
	for i in cellules.size():
		var l := Label.new()
		l.text = cellules[i]
		l.custom_minimum_size = Vector2(COLONNES[i], 0)
		l.add_theme_color_override(&"font_color", couleur)
		l.add_theme_font_size_override(&"font_size", taille)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i in [1, 2] \
			else HORIZONTAL_ALIGNMENT_CENTER
		ligne.add_child(l)
	return ligne
