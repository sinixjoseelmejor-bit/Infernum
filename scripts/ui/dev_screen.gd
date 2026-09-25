extends CanvasLayer
## Panneau de développement : sauter des vagues, s'offrir des objets, se rendre
## invulnérable. Ouvert par la touche `dev_console` (F12), derrière un mot de
## passe.
##
## CE MOT DE PASSE N'EST PAS UNE SÉCURITÉ, et il ne faut pas se raconter le
## contraire. Le jeu tourne sur la machine du joueur : quiconque sait ouvrir un
## `.pck` trouvera de quoi le contourner, et l'empreinte stockée ici ne résiste
## pas à une attaque par dictionnaire sur un mot courant. C'est un VERROU CONTRE
## LA CURIOSITÉ — il empêche d'ouvrir le panneau par accident ou par jeu, ce qui
## est exactement le besoin. Pour que ce soit une vraie protection il faudrait
## que le jeu ne contienne pas le panneau du tout, donc une version séparée.
##
## L'empreinte est un SHA-256, pas le mot lui-même : une chaîne en clair dans
## l'exécutable se lit avec n'importe quel éditeur hexadécimal, et se lirait donc
## sans même chercher. Pour changer le mot :
##
##     python -c "import hashlib;print(hashlib.sha256(b'nouveau').hexdigest())"
##
## CE PANNEAU N'EXISTE QUE DANS L'ARÈNE. Il est instancié par `main.tscn` et
## nulle part ailleurs : tout ce qu'il pilote (vagues, objets, joueur) n'a de
## sens qu'en partie.
##
## QUI POSSÈDE LA PAUSE — ET POURQUOI CE PANNEAU FAIT EXCEPTION. Le menu de
## pause et la fiche de run refusent de s'ouvrir quand un autre écran détient
## déjà la pause : sinon les refermer relancerait la partie alors que la
## boutique est encore affichée. Ce panneau a d'abord suivi la même règle, et
## c'était une erreur — il devenait muet pendant la sélection de malédiction et
## dans la boutique, c'est-à-dire précisément là où l'on veut sauter des vagues.
##
## Il s'ouvre donc par-dessus n'importe quoi, et REND la pause telle qu'il l'a
## trouvée : ouvert depuis la boutique, le refermer laisse la boutique en pause ;
## ouvert en pleine action, le refermer relance la partie.

## SHA-256 du mot de passe. Voir l'en-tête pour le régénérer.
const EMPREINTE := "dd0bc9804296758bb6bf857d3089e572ea1c5109c4576fbeaa53da446e4e644a"

## Vagues de boss, proposées en raccourci : y sauter fait apparaître le boss,
## c'est le même chemin que le jeu normal.
const VAGUES_BOSS := [5, 10, 15, 20, 25]

const TITRE := Color(1.0, 0.62, 0.16)
const AVERTISSEMENT := Color(1.0, 0.45, 0.4)

## Déverrouillé pour la durée de la session, pas du profil : relancer le jeu
## redemande le mot de passe. Un dossier de sauvegarde ne doit pas garder trace
## de qui a triché.
static var _ouvert: bool = false

var _fond: ColorRect
var _boite: VBoxContainer
var _mdp: LineEdit
var _erreur: Label
var _journal: Label
var _choix_objet: OptionButton
var _vague: SpinBox
var _confirme_reset: bool = false
## Pause trouvée à l'ouverture, rendue à la fermeture. Voir l'en-tête.
var _pause_avant: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"dev_console"):
		return
	if visible:
		fermer()
	else:
		ouvrir()
	get_viewport().set_input_as_handled()


func ouvrir() -> void:
	_pause_avant = get_tree().paused
	if _fond == null:
		_construire()
	_rafraichir()
	visible = true
	get_tree().paused = true
	if _ouvert:
		_vague.get_line_edit().grab_focus()
	else:
		_mdp.text = ""
		_mdp.grab_focus()


func fermer() -> void:
	visible = false
	get_tree().paused = _pause_avant


# --- Construction ------------------------------------------------------------

func _construire() -> void:
	_fond = ColorRect.new()
	_fond.color = Color(0.02, 0.01, 0.02, 0.86)
	_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fond)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(760, 0)
	centre.add_child(panneau)

	var marge := MarginContainer.new()
	for cote in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + cote, 24)
	panneau.add_child(marge)

	_boite = VBoxContainer.new()
	_boite.add_theme_constant_override(&"separation", 10)
	marge.add_child(_boite)


## Rebâti à chaque ouverture : le contenu dépend du déverrouillage, et les
## objets du catalogue chargé.
func _rafraichir() -> void:
	for enfant in _boite.get_children():
		enfant.queue_free()
	if _ouvert:
		_construire_outils()
	else:
		_construire_verrou()


func _construire_verrou() -> void:
	_boite.add_child(_titre("Mode développement"))
	_boite.add_child(_paragraphe("Mot de passe administrateur."))
	_mdp = LineEdit.new()
	_mdp.secret = true
	_mdp.placeholder_text = "mot de passe"
	_mdp.text_submitted.connect(_valider)
	_boite.add_child(_mdp)
	_erreur = Label.new()
	_erreur.add_theme_color_override(&"font_color", AVERTISSEMENT)
	_boite.add_child(_erreur)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 8)
	_boite.add_child(ligne)
	ligne.add_child(_bouton("Entrer", func() -> void: _valider(_mdp.text)))
	ligne.add_child(_bouton("Fermer", fermer))


func _valider(saisie: String) -> void:
	if saisie.sha256_text() != EMPREINTE:
		_erreur.text = "Mot de passe refusé."
		_mdp.text = ""
		_mdp.grab_focus()
		return
	_ouvert = true
	_rafraichir()
	_vague.get_line_edit().grab_focus()


func _construire_outils() -> void:
	_boite.add_child(_titre("Mode développement"))

	# --- Vagues --------------------------------------------------------------
	_boite.add_child(_section("Vagues"))
	var ligne_vague := HBoxContainer.new()
	ligne_vague.add_theme_constant_override(&"separation", 8)
	_boite.add_child(ligne_vague)
	_vague = SpinBox.new()
	_vague.min_value = 1
	_vague.max_value = 60
	_vague.value = maxi(1, RunState.wave)
	ligne_vague.add_child(_vague)
	ligne_vague.add_child(_bouton("Y aller", func() -> void: _aller(int(_vague.value))))
	ligne_vague.add_child(_bouton("Vague suivante", func() -> void: _aller(RunState.wave + 1)))
	ligne_vague.add_child(_bouton("Tuer tout", _tuer_tout))

	var ligne_boss := HBoxContainer.new()
	ligne_boss.add_theme_constant_override(&"separation", 8)
	_boite.add_child(ligne_boss)
	ligne_boss.add_child(_texte("Boss :"))
	for v: int in VAGUES_BOSS:
		ligne_boss.add_child(_bouton("Vague %d" % v, func() -> void: _aller(v)))

	# --- Ressources et objets ------------------------------------------------
	_boite.add_child(_section("Run"))
	var ligne_res := HBoxContainer.new()
	ligne_res.add_theme_constant_override(&"separation", 8)
	_boite.add_child(ligne_res)
	ligne_res.add_child(_bouton("+1 000 âmes", func() -> void:
		RunState.add_souls(1000)
		_dire("1 000 âmes")))
	ligne_res.add_child(_bouton("+10 clés (run)", func() -> void:
		RunState.add_keys(10)
		_dire("10 clés dans la run")))

	var ligne_obj := HBoxContainer.new()
	ligne_obj.add_theme_constant_override(&"separation", 8)
	_boite.add_child(ligne_obj)
	_choix_objet = OptionButton.new()
	_choix_objet.custom_minimum_size = Vector2(300, 0)
	for item: ItemData in ItemDB.get_all():
		_choix_objet.add_item("%s  (%s)" % [item.display_name, item.get_rarity_name()])
	ligne_obj.add_child(_choix_objet)
	ligne_obj.add_child(_bouton("Donner", func() -> void: _donner(false)))
	ligne_obj.add_child(_bouton("Au maximum", func() -> void: _donner(true)))
	_boite.add_child(_bouton("Tout le catalogue au maximum", _tout_donner))

	# --- Joueur ---------------------------------------------------------------
	_boite.add_child(_section("Joueur"))
	var invuln := CheckButton.new()
	invuln.text = "Invulnérable"
	invuln.button_pressed = _sante() != null and _sante().invincible
	invuln.toggled.connect(func(actif: bool) -> void:
		var sante := _sante()
		if sante != null:
			sante.invincible = actif
			_dire("invulnérabilité " + ("active" if actif else "coupée")))
	_boite.add_child(invuln)

	var ligne_j := HBoxContainer.new()
	ligne_j.add_theme_constant_override(&"separation", 8)
	_boite.add_child(ligne_j)
	ligne_j.add_child(_bouton("Soin complet", func() -> void:
		var sante := _sante()
		if sante != null:
			sante.heal(sante.max_health)
			_dire("soigné")))
	ligne_j.add_child(_texte("Vitesse du jeu"))
	var vitesse := HSlider.new()
	vitesse.min_value = 0.25
	vitesse.max_value = 3.0
	vitesse.step = 0.25
	vitesse.value = Engine.time_scale
	vitesse.custom_minimum_size = Vector2(200, 0)
	var valeur := _texte("x%.2f" % Engine.time_scale)
	vitesse.value_changed.connect(func(v: float) -> void:
		Engine.time_scale = v
		valeur.text = "x%.2f" % v)
	ligne_j.add_child(vitesse)
	ligne_j.add_child(valeur)

	# --- Profil ---------------------------------------------------------------
	_boite.add_child(_section("Profil"))
	var garde := _paragraphe("Ces boutons ÉCRIVENT dans le profil actif, pas dans"
		+ " la run. Utilisez un profil dédié.")
	garde.add_theme_color_override(&"font_color", AVERTISSEMENT)
	_boite.add_child(garde)
	var ligne_p := HBoxContainer.new()
	ligne_p.add_theme_constant_override(&"separation", 8)
	_boite.add_child(ligne_p)
	ligne_p.add_child(_bouton("Débloquer la Forge du personnage", func() -> void:
		for id: StringName in Forge.get_ids_for_selected():
			SaveGame.unlock_forge(Characters.selected_id, id)
		_dire("Forge complète pour %s" % Characters.get_selected().display_name)))
	ligne_p.add_child(_bouton("+%d clés au profil" % Forge.get_total_cost(), func() -> void:
		SaveGame.add_keys(Forge.get_total_cost())
		_dire("clés versées au profil")))
	var reset := Button.new()
	reset.text = "Réinitialiser la Forge"
	reset.pressed.connect(func() -> void: _reinitialiser(reset))
	ligne_p.add_child(reset)

	# Hélel se mérite en abattant Lucifer avec les trois damnés : trois runs
	# complètes pour vérifier un combat, c'est trop. Le portail s'ouvre ici.
	var ligne_h := HBoxContainer.new()
	ligne_h.add_theme_constant_override(&"separation", 8)
	_boite.add_child(ligne_h)
	ligne_h.add_child(_bouton("Briser les trois sceaux", func() -> void:
		for character in Characters.get_all():
			SaveGame.break_seal(character.id)
		_dire("trois sceaux brisés : le portail s'ouvrira à la mort de Lucifer")))
	ligne_h.add_child(_bouton("Rendre les sceaux", func() -> void:
		SaveGame.dev_clear_seals()
		_dire("sceaux rendus")))
	ligne_h.add_child(_bouton("Combattre Hélel maintenant", func() -> void:
		var director := get_tree().get_first_node_in_group(&"story_director")
		if director == null:
			_dire("seulement dans l'arène, run lancée")
			return
		fermer()
		director.call(&"dev_start_helel")))

	_journal = _texte("")
	_journal.add_theme_color_override(&"font_color", Color(0.55, 0.85, 0.6))
	_boite.add_child(_journal)
	_boite.add_child(_bouton("Fermer  (F12)", fermer))


# --- Actions -----------------------------------------------------------------

func _aller(cible: int) -> void:
	var waves := get_tree().get_first_node_in_group(Groups.WAVE_MANAGER) as WaveManager
	if waves == null:
		_dire("pas de gestionnaire de vagues")
		return
	waves.dev_jump_to_wave(cible)
	_vague.value = cible
	_dire("vague %d" % cible)


func _tuer_tout() -> void:
	var n := 0
	for ennemi in get_tree().get_nodes_in_group(&"enemies"):
		if ennemi.has_method(&"apply_damage"):
			# Par les dégâts et non par `queue_free` : les âmes tombent, les
			# compteurs de vague avancent, la vague se termine normalement.
			ennemi.call(&"apply_damage", 1.0e9, null, Vector2.ZERO)
			n += 1
	_dire("%d ennemis tués" % n)


func _donner(au_maximum: bool) -> void:
	var tous := ItemDB.get_all()
	var i := _choix_objet.selected
	if i < 0 or i >= tous.size():
		return
	var item: ItemData = tous[i]
	var n := 0
	while RunState.can_take(item):
		RunState.add_item(item)
		n += 1
		if not au_maximum:
			break
	_dire("%s x%d" % [item.display_name, n])


func _tout_donner() -> void:
	var n := 0
	for item: ItemData in ItemDB.get_all():
		while RunState.can_take(item):
			RunState.add_item(item)
			n += 1
	_dire("%d exemplaires distribués" % n)


## Deux clics : le premier arme, le second efface. Débloquer est additif et se
## rattrape, effacer ne se rattrape pas.
func _reinitialiser(bouton: Button) -> void:
	if not _confirme_reset:
		_confirme_reset = true
		bouton.text = "Confirmer ?"
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(bouton) and _confirme_reset:
			_confirme_reset = false
			bouton.text = "Réinitialiser la Forge"
		return
	_confirme_reset = false
	bouton.text = "Réinitialiser la Forge"
	var ids: Array = []
	for noeud: Dictionary in Forge.NODES:
		ids.append(noeud["id"])
	SaveGame.dev_lock_forge(Characters.selected_id, ids)
	_dire("Forge de %s remise à zéro" % Characters.get_selected().display_name)


func _sante() -> Health:
	var joueur := get_tree().get_first_node_in_group(&"player")
	if joueur == null or not is_instance_valid(joueur):
		return null
	return joueur.get_node_or_null("Health") as Health


func _dire(message: String) -> void:
	if _journal != null:
		_journal.text = message


# --- Petits constructeurs ----------------------------------------------------

func _titre(texte: String) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override(&"font_size", 24)
	l.add_theme_color_override(&"font_color", TITRE)
	return l


func _section(texte: String) -> Label:
	var l := Label.new()
	l.text = texte.to_upper()
	l.add_theme_font_size_override(&"font_size", 13)
	l.add_theme_color_override(&"font_color", TITRE)
	return l


## Étiquette d'une seule ligne. SURTOUT PAS de repli automatique : dans une
## boîte horizontale, un label qui se replie tombe à sa largeur minimale et
## s'écrit une lettre par ligne, ce qui étire toute la rangée.
func _texte(contenu: String) -> Label:
	var l := Label.new()
	l.text = contenu
	return l


## Paragraphe, lui replié : il occupe toute la largeur du panneau.
func _paragraphe(contenu: String) -> Label:
	var l := Label.new()
	l.text = contenu
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.pressed.connect(action)
	return b
