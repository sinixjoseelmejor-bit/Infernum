class_name HUD
extends CanvasLayer
## L'AFFICHAGE TÊTE HAUTE — tout ce qu'il faut savoir en pleine vague, et rien
## qui se lise mieux ailleurs.
##
## Quatre coins, quatre questions :
##   haut gauche   QUI suis-je, et dans quel état : portrait et nom du damné
##                 (ils changent pendant le combat contre Hélel), la vie, le
##                 pouvoir et sa touche, la seconde chance si elle reste ;
##   haut centre   OÙ en est la run : la vague, son temps, le prochain boss, le
##                 pacte et les malédictions en jeu, le Déchaînement — et la
##                 barre du boss quand il est là ;
##   haut droite   CE QUE j'ai gagné : âmes, clés, éliminations, temps de run ;
##   bas centre    CE QUE je porte : un emplacement par objet, sa rareté et son
##                 nombre d'exemplaires — l'orbite autour du joueur montre les
##                 objets, pas combien.
##
## Ce qui n'y est PAS, volontairement : les statistiques détaillées (la fiche,
## touche Tab, les décompose par source) et les jauges de pouvoir au sol, qui
## restent aux pieds du joueur — l'œil est là pendant le combat. Le coin haut
## gauche répète l'état du pouvoir pour qui veut le vérifier d'un coup d'œil, et
## surtout donne sa TOUCHE, qu'aucune jauge au sol ne disait.
##
## Tout est construit par code : l'écran s'adapte au personnage, au mode et aux
## objets, et une scène figée pour chaque combinaison n'aurait aucun sens.
##
## Il vit au calque 2, au-dessus du vignetage (1) : les coins de l'écran sont
## sombres, l'interface y reste lisible. Aucun texte n'y est posé sans contour.

const COEUR := preload("res://assets/sprites/ui/heart.png")
const AME := preload("res://assets/sprites/ui/coin.png")
const CLE := preload("res://assets/sprites/ui/lock.png")
const ETOILE := preload("res://assets/sprites/ui/star.png")
const RAIL := preload("res://assets/sprites/ui/bar_track.png")
const REMPLI := preload("res://assets/sprites/ui/bar_fill.png")

const CONTOUR := Color(0.05, 0.02, 0.02)
const GRIS := Color(0.78, 0.74, 0.76)
const AME_COULEUR := Color(0.56, 0.94, 1.0)
const CLE_COULEUR := Color(1.0, 0.85, 0.39)
const OR := Color(1.0, 0.82, 0.4)
const PACTE_COULEUR := Color(0.78, 0.55, 1.0)
const DANGER_COULEUR := Color(1.0, 0.42, 0.34)
const MARGE := 24.0

## Sous ce ratio de PV, la barre bat — en même temps que le cœur de l'audio.
const VIE_BASSE := 0.25
## La traînée blanche d'une perte de PV : elle attend, puis rattrape la vie.
const TRAINEE_ATTENTE := 0.35
const TRAINEE_VITESSE := 0.9

## Les pouvoirs, par identifiant : leur nom et leur couleur. Les mêmes teintes
## que les jauges au sol, sans quoi le coin et les pieds se contrediraient.
const POUVOIRS := {
	&"dash": {"nom": "LA RUÉE", "couleur": Color(0.72, 0.88, 1.0)},
	&"blood_price": {"nom": "LE PRIX DU SANG", "couleur": Color(1.0, 0.32, 0.26)},
	&"steadfast": {"nom": "REFUS DE PLIER", "couleur": Color(1.0, 0.86, 0.45)},
}

var wave_manager: WaveManager

var _racine: Control
var _portrait: TextureRect
var _cadre_portrait: Panel
var _nom: Label
var _coeur: TextureRect
var _barre_vie: ProgressBar
var _barre_trainee: ProgressBar
var _texte_vie: Label
var _jauge_pouvoir: JaugePouvoir
var _nom_pouvoir: Label
var _touche_pouvoir: Touche
var _touche_fiche: Touche
var _etat_pouvoir: Label
var _ligne_revive: HBoxContainer
var _texte_revive: Label

var _vague: Label
var _chrono: Label
var _barre_vague: ProgressBar
var _info_boss: Label
var _pacte: Label
var _pacte_detail: Label
var _maledictions: Label
var _dechaine: Label

var _panneau_boss: VBoxContainer
var _nom_boss: Label
var _barre_boss: ProgressBar
var _pourcent_boss: Label
var _phase_boss: Label
var _boss: Node2D
var _phase_texte := ""

var _ames: Label
var _cles: Label
var _eliminations: Label
var _temps: Label

var _objets: HFlowContainer
var _aide_fiche: Label
var _annonce_titre: Label
var _annonce_detail: Label

var _joueur: Player
var _trainee_attente: float = 0.0
var _temps_anim: float = 0.0
var _manette := false


func _ready() -> void:
	_racine = $Root
	_construire_joueur()
	_construire_centre()
	_construire_butin()
	_construire_objets()
	_construire_annonce()
	# Le joystick virtuel reste par-dessus tout le reste.
	_racine.move_child($Root/Joystick, -1)

	GameEvents.player_health_changed.connect(_on_health_changed)
	GameEvents.player_revived.connect(func(_p: Node2D) -> void: _maj_revive())
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.wave_started.connect(_on_wave_started)
	GameEvents.wave_cleared.connect(_on_wave_cleared)
	RunState.souls_changed.connect(_on_souls_changed)
	RunState.keys_changed.connect(_on_keys_changed)
	RunState.item_gained.connect(func(_i: ItemData, _n: int) -> void: _maj_objets())
	RunState.item_lost.connect(func(_i: ItemData, _n: int) -> void: _maj_objets())
	RunState.run_reset.connect(_tout_rafraichir)
	Characters.run_character_swapped.connect(func(_c: CharacterData) -> void: _maj_personnage())
	WaveMods.modifier_changed.connect(func(_m: Dictionary) -> void: _maj_pacte())

	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_health_changed.connect(_on_boss_health_changed)
	GameEvents.boss_phase_changed.connect(_on_boss_phase_changed)
	GameEvents.boss_enraged.connect(func(_b: Node2D) -> void: _maj_phase_boss())
	GameEvents.boss_died.connect(_on_boss_died)
	GameEvents.announce.connect(_on_announce)

	_panneau_boss.visible = false
	# Le joueur et la run se remettent à zéro APRÈS ce `_ready` (main.gd) : on
	# lit l'état initial une image plus tard.
	_tout_rafraichir.call_deferred()


func bind_wave_manager(manager: WaveManager) -> void:
	wave_manager = manager


func _tout_rafraichir() -> void:
	_joueur = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if _joueur != null:
		var sante: Health = _joueur.health
		_on_health_changed(sante.current, sante.max_health)
		_barre_trainee.value = _barre_vie.value
	_maj_personnage()
	_maj_revive()
	_maj_pacte()
	_maj_objets()
	_on_souls_changed(RunState.souls)
	_on_keys_changed(RunState.keys)
	_eliminations.text = tr("ÉLIMINATIONS  %d") % RunState.kills


# --- Construction ------------------------------------------------------------

func _etiquette(texte: String, taille: int, couleur: Color = Color.WHITE,
		titre: bool = true, contour: int = 6) -> Label:
	var l := Label.new()
	if titre:
		l.theme_type_variation = &"TitleLabel"
	l.text = texte
	l.add_theme_font_size_override(&"font_size", taille)
	l.add_theme_color_override(&"font_color", couleur)
	l.add_theme_color_override(&"font_outline_color", CONTOUR)
	l.add_theme_constant_override(&"outline_size", contour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icone(texture: Texture2D, taille: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.custom_minimum_size = Vector2(taille, taille)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _style_barre(texture: Texture2D, teinte: Color = Color.WHITE) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = texture
	for cote in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_texture_margin(cote, 2.0)
	s.modulate_color = teinte
	return s


func _barre(fond: StyleBox, rempli: StyleBox) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.add_theme_stylebox_override(&"background", fond)
	b.add_theme_stylebox_override(&"fill", rempli)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.max_value = 100.0
	b.value = 100.0
	return b


## HAUT GAUCHE : le damné. Portrait encadré de sa couleur, son nom, la vie avec
## sa traînée, le pouvoir et sa touche, la seconde chance.
func _construire_joueur() -> void:
	_cadre_portrait = Panel.new()
	_cadre_portrait.position = Vector2(MARGE, 18.0)
	_cadre_portrait.size = Vector2(72.0, 72.0)
	_cadre_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_cadre_portrait)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(6.0, 6.0)
	_portrait.size = Vector2(60.0, 60.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre_portrait.add_child(_portrait)

	var x := MARGE + 84.0
	_nom = _etiquette("", 26)
	_nom.position = Vector2(x, 10.0)
	_racine.add_child(_nom)

	_coeur = _icone(COEUR, 30.0)
	_coeur.position = Vector2(x - 2.0, 44.0)
	_coeur.size = Vector2(30.0, 30.0)
	_coeur.pivot_offset = Vector2(15.0, 15.0)
	_racine.add_child(_coeur)
	# La traînée d'abord, la vraie vie par-dessus sur fond transparent : une
	# perte se lit en blanc, le temps d'être vue, avant de se résorber.
	_barre_trainee = _barre(_style_barre(RAIL), _style_barre(REMPLI, Color(2.2, 2.0, 1.9)))
	_barre_trainee.position = Vector2(x + 34.0, 44.0)
	_barre_trainee.size = Vector2(330.0, 30.0)
	_racine.add_child(_barre_trainee)
	_barre_vie = _barre(StyleBoxEmpty.new(), _style_barre(REMPLI))
	_barre_vie.position = _barre_trainee.position
	_barre_vie.size = _barre_trainee.size
	_racine.add_child(_barre_vie)
	_texte_vie = _etiquette("100 / 100", 20, Color.WHITE, true, 5)
	_texte_vie.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texte_vie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte_vie.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_barre_vie.add_child(_texte_vie)

	var ligne := HBoxContainer.new()
	ligne.position = Vector2(MARGE, 100.0)
	ligne.add_theme_constant_override(&"separation", 10)
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(ligne)
	_jauge_pouvoir = JaugePouvoir.new()
	_jauge_pouvoir.custom_minimum_size = Vector2(46.0, 46.0)
	ligne.add_child(_jauge_pouvoir)
	var textes := VBoxContainer.new()
	textes.add_theme_constant_override(&"separation", -4)
	textes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(textes)
	var titre := HBoxContainer.new()
	titre.add_theme_constant_override(&"separation", 10)
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textes.add_child(titre)
	_nom_pouvoir = _etiquette("", 22)
	titre.add_child(_nom_pouvoir)
	# La touche du pouvoir, dessinée comme une touche : elle s'enfonce à l'appui.
	_touche_pouvoir = Touche.new()
	_touche_pouvoir.action = &"dash"
	_touche_pouvoir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.add_child(_touche_pouvoir)
	_etat_pouvoir = _etiquette("", 18, GRIS, true, 5)
	textes.add_child(_etat_pouvoir)

	_ligne_revive = HBoxContainer.new()
	_ligne_revive.position = Vector2(MARGE + 8.0, 152.0)
	_ligne_revive.add_theme_constant_override(&"separation", 8)
	_ligne_revive.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_ligne_revive)
	_ligne_revive.add_child(_icone(ETOILE, 26.0))
	_texte_revive = _etiquette(tr("SECONDE CHANCE"), 20, OR, true, 5)
	_ligne_revive.add_child(_texte_revive)


## HAUT CENTRE : la vague et ce qui pèse sur elle, puis le boss.
func _construire_centre() -> void:
	var pile := VBoxContainer.new()
	pile.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pile.offset_left = -460.0
	pile.offset_right = 460.0
	pile.offset_top = 6.0
	pile.alignment = BoxContainer.ALIGNMENT_BEGIN
	pile.add_theme_constant_override(&"separation", 0)
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(pile)

	_vague = _etiquette(tr("VAGUE %d") % 1, 50, Color(1.0, 0.55, 0.3), true, 10)
	_vague.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(_vague)
	_chrono = _etiquette("", 30, Color.WHITE, true, 7)
	_chrono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(_chrono)
	var boite := CenterContainer.new()
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite.custom_minimum_size = Vector2(0.0, 12.0)
	pile.add_child(boite)
	_barre_vague = _barre(_style_barre(RAIL), _style_barre(REMPLI, Color(1.3, 0.85, 0.55)))
	_barre_vague.custom_minimum_size = Vector2(300.0, 10.0)
	boite.add_child(_barre_vague)
	_info_boss = _etiquette("", 18, GRIS, true, 5)
	_info_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(_info_boss)
	_dechaine = _etiquette(tr("DÉCHAÎNEMENT"), 22, DANGER_COULEUR, true, 6)
	_dechaine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(_dechaine)
	_pacte = _etiquette("", 22, PACTE_COULEUR, true, 6)
	_pacte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(_pacte)
	_pacte_detail = _etiquette("", 17, Color(0.86, 0.8, 0.95), false, 4)
	_pacte_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(_pacte_detail)
	_maledictions = _etiquette("", 17, Color(0.95, 0.55, 0.5), false, 4)
	_maledictions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(_maledictions)

	_panneau_boss = VBoxContainer.new()
	_panneau_boss.add_theme_constant_override(&"separation", 2)
	_panneau_boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.add_child(_panneau_boss)
	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0.0, 8.0)
	_panneau_boss.add_child(espace)
	_nom_boss = _etiquette("", 30, Color(1.0, 0.35, 0.25), true, 7)
	_nom_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panneau_boss.add_child(_nom_boss)
	_barre_boss = _barre(_style_barre(RAIL, Color(1.0, 0.94, 0.9)),
		_style_barre(REMPLI, Color(1.35, 0.92, 0.78)))
	_barre_boss.custom_minimum_size = Vector2(0.0, 26.0)
	_panneau_boss.add_child(_barre_boss)
	_pourcent_boss = _etiquette("", 18, Color.WHITE, true, 5)
	_pourcent_boss.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pourcent_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pourcent_boss.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_barre_boss.add_child(_pourcent_boss)
	_phase_boss = _etiquette("", 17, GRIS, true, 5)
	_phase_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panneau_boss.add_child(_phase_boss)


## HAUT DROITE : ce que la run a rapporté.
func _construire_butin() -> void:
	var pile := VBoxContainer.new()
	pile.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pile.offset_left = -320.0
	pile.offset_right = -MARGE
	pile.offset_top = 14.0
	pile.add_theme_constant_override(&"separation", 2)
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(pile)
	_ames = _ligne_butin(pile, AME, 32.0, 30, AME_COULEUR)
	_cles = _ligne_butin(pile, CLE, 32.0, 30, CLE_COULEUR)
	# Pas d'icône pour les éliminations : la seule croix du kit est rouge et se
	# lisait comme un bouton « fermer ».
	_eliminations = _ligne_butin(pile, null, 0.0, 24, Color(0.92, 0.88, 0.86))
	_temps = _ligne_butin(pile, null, 0.0, 20, GRIS)


func _ligne_butin(pile: VBoxContainer, icone: Texture2D, taille_icone: float,
		taille: int, couleur: Color) -> Label:
	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_END
	ligne.add_theme_constant_override(&"separation", 8)
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.add_child(ligne)
	var l := _etiquette("0", taille, couleur)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ligne.add_child(l)
	if icone != null:
		ligne.add_child(_icone(icone, taille_icone))
	return l


## BAS CENTRE : les objets portés, une case chacun.
func _construire_objets() -> void:
	var bas := VBoxContainer.new()
	bas.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bas.offset_left = -560.0
	bas.offset_right = 560.0
	bas.offset_bottom = -14.0
	bas.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_theme_constant_override(&"separation", 2)
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(bas)
	_objets = HFlowContainer.new()
	_objets.alignment = FlowContainer.ALIGNMENT_CENTER
	_objets.add_theme_constant_override(&"h_separation", 4)
	_objets.add_theme_constant_override(&"v_separation", 4)
	_objets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_child(_objets)
	var aide := HBoxContainer.new()
	aide.alignment = BoxContainer.ALIGNMENT_CENTER
	aide.add_theme_constant_override(&"separation", 8)
	aide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_child(aide)
	_touche_fiche = Touche.new()
	_touche_fiche.action = &"show_stats"
	_touche_fiche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	aide.add_child(_touche_fiche)
	_aide_fiche = _etiquette(tr("FICHE DES STATISTIQUES"), 16, GRIS, false, 4)
	_aide_fiche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	aide.add_child(_aide_fiche)


func _construire_annonce() -> void:
	_annonce_titre = _etiquette("", 70, Color.WHITE, true, 12)
	_annonce_titre.set_anchors_preset(Control.PRESET_CENTER)
	_annonce_titre.anchor_top = 0.42
	_annonce_titre.anchor_bottom = 0.42
	_annonce_titre.offset_left = -520.0
	_annonce_titre.offset_right = 520.0
	_annonce_titre.offset_top = -24.0
	_annonce_titre.offset_bottom = 58.0
	_annonce_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce_titre.modulate.a = 0.0
	_racine.add_child(_annonce_titre)
	_annonce_detail = _etiquette("", 19, Color(0.88, 0.85, 0.9), false, 4)
	_annonce_detail.set_anchors_preset(Control.PRESET_CENTER)
	_annonce_detail.anchor_top = 0.42
	_annonce_detail.anchor_bottom = 0.42
	_annonce_detail.offset_left = -420.0
	_annonce_detail.offset_right = 420.0
	_annonce_detail.offset_top = 60.0
	_annonce_detail.offset_bottom = 124.0
	_annonce_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_annonce_detail.modulate.a = 0.0
	_racine.add_child(_annonce_detail)


# --- Chaque image -------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Les touches affichées suivent le dernier appareil touché.
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion
			and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		_basculer_manette(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		_basculer_manette(false)


func _basculer_manette(manette: bool) -> void:
	if manette == _manette:
		return
	_manette = manette
	_maj_aide()


func _process(delta: float) -> void:
	_temps_anim += delta
	_animer_vie(delta)
	_maj_pouvoir()
	_temps.text = tr("TEMPS  %s") % _format_time(RunState.run_time)
	if wave_manager == null:
		return
	var boss_en_jeu := wave_manager.is_boss_wave()
	match wave_manager.state:
		WaveManager.State.RUNNING:
			# Une vague de boss n'a pas de compte à rebours : elle dure le combat.
			if boss_en_jeu:
				_chrono.text = tr("BOSS  ·  %s") % _format_time(wave_manager.time_left)
				_barre_vague.visible = false
			else:
				_chrono.text = _format_time(wave_manager.time_left)
				var duree := wave_manager.curve.wave_duration(wave_manager.wave)
				_barre_vague.visible = true
				_barre_vague.value = 100.0 * (1.0 - wave_manager.time_left / maxf(0.01, duree))
		WaveManager.State.INTERMISSION:
			_chrono.text = tr("PRÉPAREZ-VOUS")
			_barre_vague.visible = false
		WaveManager.State.COLLECTING:
			_chrono.text = "VAGUE TERMINÉE"
			_barre_vague.visible = false
		_:
			_chrono.text = "--:--"
			_barre_vague.visible = false
	_maj_info_boss()
	_dechaine.visible = RunState.unleashed
	if is_instance_valid(_boss):
		_maj_phase_boss()


static func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]


## La barre de vie : la traînée rattrape la vie, et sous 25 % tout bat — la
## barre et le cœur, au rythme du battement que joue l'audio.
func _animer_vie(delta: float) -> void:
	if _trainee_attente > 0.0:
		_trainee_attente -= delta
	elif _barre_trainee.value > _barre_vie.value:
		_barre_trainee.value = maxf(_barre_vie.value,
			_barre_trainee.value - _barre_vie.max_value * TRAINEE_VITESSE * delta)
	var ratio := _barre_vie.value / maxf(1.0, _barre_vie.max_value)
	if ratio < VIE_BASSE and ratio > 0.0:
		var battement := pow(maxf(0.0, sin(_temps_anim * TAU * 1.25)), 6.0)
		_barre_vie.self_modulate = Color(1.0 + 0.8 * battement, 1.0, 1.0)
		_coeur.scale = Vector2.ONE * (1.0 + 0.22 * battement)
	else:
		_barre_vie.self_modulate = Color.WHITE
		_coeur.scale = Vector2.ONE


func _maj_pouvoir() -> void:
	if not is_instance_valid(_joueur):
		return
	var etat := _joueur.etat_pouvoir()
	var id: StringName = etat["id"]
	var visible_ := POUVOIRS.has(id)
	_jauge_pouvoir.visible = visible_
	_nom_pouvoir.visible = visible_
	_touche_pouvoir.visible = visible_
	_etat_pouvoir.visible = visible_
	if not visible_:
		return
	var info: Dictionary = POUVOIRS[id]
	var couleur: Color = info["couleur"]
	var nom: String = tr(info["nom"])
	var texte := ""
	match id:
		&"dash":
			texte = tr("PRÊTE") if etat["pret"] else tr("%.1f s") % float(etat["reste"])
		&"blood_price":
			var pc := roundi(float(etat["part"]) * 100.0)
			texte = tr("MARQUE %d %%") % pc if etat["pret"] \
				else tr("MARQUE %d %%  ·  %d %% requis") % [pc, roundi(float(etat["minimum"]) * 100.0)]
		&"steadfast":
			if etat["jugement"]:
				nom = tr("LE JUGEMENT")
				texte = tr("FERVEUR PLEINE")
			else:
				texte = (tr("PARADE PRÊTE") if etat["pret"] else tr("%.1f s") % float(etat["reste"])) \
					+ tr("  ·  FERVEUR %d / %d") % [etat["charges"], etat["charges_max"]]
	_nom_pouvoir.text = nom
	_nom_pouvoir.add_theme_color_override(&"font_color", couleur if etat["pret"] else GRIS)
	_etat_pouvoir.text = texte
	_jauge_pouvoir.couleur = couleur
	_jauge_pouvoir.part = etat["part"]
	_jauge_pouvoir.pret = etat["pret"]
	_jauge_pouvoir.minimum = etat.get("minimum", 0.0)
	_jauge_pouvoir.charges = etat.get("charges", 0)
	_jauge_pouvoir.charges_max = etat.get("charges_max", 0)
	_jauge_pouvoir.jugement = etat.get("jugement", false)


## Le prochain boss, pour qu'une porte ne tombe jamais par surprise.
func _maj_info_boss() -> void:
	if wave_manager.is_final_fight():
		_info_boss.text = ""
		return
	var intervalle := wave_manager.boss_wave_interval
	var vague := wave_manager.wave
	if wave_manager.state == WaveManager.State.INTERMISSION:
		vague += 1
	if wave_manager.is_boss_wave() and wave_manager.state == WaveManager.State.RUNNING:
		_info_boss.text = ""
		return
	@warning_ignore("integer_division")
	var prochaine := ((vague - 1) / intervalle + 1) * intervalle
	if prochaine < vague:
		prochaine += intervalle
	var dans := prochaine - wave_manager.wave
	if dans <= 1:
		_info_boss.text = "BOSS À LA PROCHAINE VAGUE"
		_info_boss.add_theme_color_override(&"font_color", DANGER_COULEUR)
	else:
		_info_boss.text = tr("BOSS DANS %d VAGUES") % dans
		_info_boss.add_theme_color_override(&"font_color", GRIS)


# --- Événements ---------------------------------------------------------------

func _on_health_changed(current: float, maximum: float) -> void:
	var avant := _barre_vie.value
	_barre_vie.max_value = maximum
	_barre_trainee.max_value = maximum
	_barre_vie.value = current
	if current < avant:
		_trainee_attente = TRAINEE_ATTENTE
	else:
		_barre_trainee.value = maxf(_barre_trainee.value, current)
	if _barre_trainee.value < current:
		_barre_trainee.value = current
	_texte_vie.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _maj_personnage() -> void:
	var perso := Characters.get_selected()
	if perso == null:
		return
	_portrait.texture = perso.portrait
	_nom.text = perso.display_name.to_upper()
	_nom.add_theme_color_override(&"font_color", perso.color)
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Color(0.06, 0.03, 0.05, 0.78)
	cadre.border_color = perso.color
	cadre.set_border_width_all(3)
	cadre.set_corner_radius_all(4)
	_cadre_portrait.add_theme_stylebox_override(&"panel", cadre)
	# Un changement de corps (Hélel) se voit aussi ici : le cadre claque.
	_cadre_portrait.pivot_offset = _cadre_portrait.size * 0.5
	var anim := create_tween()
	_cadre_portrait.scale = Vector2(1.18, 1.18)
	anim.tween_property(_cadre_portrait, ^"scale", Vector2.ONE, 0.25)


func _maj_revive() -> void:
	_ligne_revive.visible = RunState.revives_left > 0
	_texte_revive.text = tr("SECONDE CHANCE") if RunState.revives_left == 1 \
		else tr("SECONDE CHANCE  ×%d") % RunState.revives_left


func _maj_pacte() -> void:
	var pacte: Dictionary = WaveMods.current
	_pacte.visible = not pacte.is_empty()
	_pacte_detail.visible = not pacte.is_empty()
	if not pacte.is_empty():
		_pacte.text = tr("PACTE : %s") % tr(str(pacte.get("name", ""))).to_upper()
		_pacte_detail.text = tr(str(pacte.get("desc", "")))
	var n := Curses.active.size()
	_maledictions.visible = n > 0
	if n > 0:
		_maledictions.text = (tr("%d MALÉDICTIONS  ·  DANGER %d") if n > 1
			else tr("%d MALÉDICTION  ·  DANGER %d")) % [n, Curses.get_danger()]


func _maj_objets() -> void:
	UIUtils.clear_children(_objets)
	# `owned_items` porte une entrée PAR EXEMPLAIRE : une case par objet
	# distinct, le nombre dans le coin.
	var vus: Dictionary = {}
	for item: ItemData in RunState.owned_items:
		if vus.has(item.id):
			continue
		vus[item.id] = true
		_objets.add_child(_case_objet(item, int(RunState.owned_counts.get(item.id, 1))))
	_maj_aide()


func _maj_aide() -> void:
	_touche_fiche.manette = _manette
	_touche_pouvoir.manette = _manette


## Une case d'objet : l'icône à l'échelle 2 (16 px de source, échelle entière),
## un liseré de la couleur de sa rareté, et son nombre d'exemplaires s'il en a
## plusieurs.
func _case_objet(item: ItemData, nombre: int) -> Control:
	var case_ := Panel.new()
	case_.custom_minimum_size = Vector2(42.0, 42.0)
	case_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.04, 0.72)
	style.border_color = item.get_rarity_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	case_.add_theme_stylebox_override(&"panel", style)
	var icone := TextureRect.new()
	icone.texture = item.icon
	icone.position = Vector2(5.0, 5.0)
	icone.size = Vector2(32.0, 32.0)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case_.add_child(icone)
	if nombre > 1:
		var n := _etiquette("%d" % nombre, 16, Color.WHITE, true, 4)
		n.position = Vector2(26.0, 20.0)
		n.size = Vector2(14.0, 20.0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		case_.add_child(n)
	return case_


func _on_enemy_died(_enemy: Node2D, _position: Vector2) -> void:
	_eliminations.text = tr("ÉLIMINATIONS  %d") % RunState.kills


func _on_wave_started(index: int) -> void:
	_vague.text = tr("VAGUE %d") % index
	_sauter(_vague)
	# Les malédictions se choisissent à l'écran d'ouverture, APRÈS la mise en
	# place de l'interface : on les relit au début de chaque vague.
	_maj_pacte()


func _on_wave_cleared(_index: int) -> void:
	_chrono.text = "VAGUE TERMINÉE"


func _on_boss_spawned(boss: Node2D) -> void:
	_boss = boss
	_panneau_boss.visible = true
	var subtitle: String = tr(str(boss.get(&"subtitle")))
	_nom_boss.text = tr(str(boss.get(&"boss_name"))).to_upper()
	if subtitle != "":
		_nom_boss.text += "  —  " + subtitle
	_phase_texte = ""
	_on_boss_health_changed(boss.health.current, boss.health.max_health)


func _on_boss_health_changed(current: float, maximum: float) -> void:
	_barre_boss.max_value = maximum
	_barre_boss.value = current
	_pourcent_boss.text = tr("%d %%") % ceili(100.0 * current / maxf(1.0, maximum))


func _on_boss_phase_changed(phase: int, total: int) -> void:
	_phase_texte = tr("PHASE %d / %d") % [phase + 1, total]
	_maj_phase_boss()


## La phase, et le temps avant l'enragement : c'est la seule horloge du combat
## qui change ce que le boss fait, elle doit se voir.
func _maj_phase_boss() -> void:
	if not is_instance_valid(_boss):
		return
	var texte := _phase_texte
	if bool(_boss.get(&"is_enraged")):
		texte += "  ·  " + tr("ENRAGÉ")
		_phase_boss.add_theme_color_override(&"font_color", DANGER_COULEUR)
	else:
		var reste: float = float(_boss.get(&"enrage_time")) - float(_boss.get(&"fight_time"))
		texte += tr("  ·  ENRAGEMENT DANS %s") % _format_time(reste)
		_phase_boss.add_theme_color_override(&"font_color",
			Color(1.0, 0.7, 0.5) if reste < 20.0 else GRIS)
	_phase_boss.text = texte


func _on_boss_died(_b: Node2D) -> void:
	_boss = null
	_panneau_boss.visible = false


## Bandeau des grandes nouvelles. Il s'efface tout seul : rien à refermer, et
## surtout rien qui mette la partie en pause — la Clé des Abysses tombe en plein
## combat, et arrêter le jeu pour l'annoncer serait pire que ne rien dire.
func _on_announce(titre: String, detail: String, couleur: Color) -> void:
	_annonce_titre.text = titre
	_annonce_titre.add_theme_color_override(&"font_color", couleur)
	_annonce_detail.text = detail
	for etiquette: Label in [_annonce_titre, _annonce_detail]:
		var anim := create_tween()
		anim.tween_property(etiquette, ^"modulate:a", 1.0, 0.35)
		anim.tween_interval(4.0)
		anim.tween_property(etiquette, ^"modulate:a", 0.0, 1.2)


func _on_souls_changed(amount: int) -> void:
	_ames.text = str(amount)
	_sauter(_ames)


func _on_keys_changed(amount: int) -> void:
	_cles.text = str(amount)
	_sauter(_cles)


## Un petit saut quand un compteur change : on voit qu'il a bougé sans avoir à
## le relire.
func _sauter(l: Label) -> void:
	l.pivot_offset = l.size * Vector2(0.5, 0.5)
	var anim := create_tween()
	l.scale = Vector2(1.15, 1.15)
	anim.tween_property(l, ^"scale", Vector2.ONE, 0.18)


## LA JAUGE DU POUVOIR, dans le coin : un anneau qui se remplit, plein et
## lumineux quand l'appui produirait quelque chose. La Marque de Caïn y porte
## son seuil minimal ; la Ferveur de Job, ses charges en perles autour.
class JaugePouvoir extends Control:
	var couleur := Color.WHITE
	var part: float = 0.0
	var pret := false
	var minimum: float = 0.0
	var charges: int = 0
	var charges_max: int = 0
	var jugement := false
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		draw_circle(c, r + 3.0, Color(0.05, 0.02, 0.04, 0.8))
		draw_arc(c, r, 0.0, TAU, 48, Color(couleur, 0.22), 5.0, true)
		if part > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * part, 48,
				couleur if pret else Color(couleur, 0.6), 5.0, true)
		if minimum > 0.0:
			var a := -PI * 0.5 + TAU * minimum
			draw_line(c + Vector2.from_angle(a) * (r - 5.0), c + Vector2.from_angle(a) * (r + 5.0),
				Color.WHITE, 2.0)
		if pret:
			var souffle := 0.5 + 0.5 * sin(_t * 5.0)
			draw_circle(c, r - 7.0, Color(couleur, 0.25 + 0.2 * souffle))
		if jugement:
			draw_circle(c, r - 7.0, Color(1.0, 0.95, 0.7, 0.55 + 0.3 * sin(_t * 9.0)))
		for i in charges_max:
			var a := PI * 0.5 + (float(i) - float(charges_max - 1) * 0.5) * 0.5
			var p := c + Vector2.from_angle(a) * (r + 1.0)
			draw_circle(p, 4.5, Color(0.05, 0.02, 0.04))
			draw_circle(p, 3.2, couleur if i < charges else Color(couleur, 0.25))
