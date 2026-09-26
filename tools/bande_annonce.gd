extends Node
## LA BANDE-ANNONCE, TOURNÉE DANS LE JEU.
##
## Rien n'est monté après coup : ce script joue la vraie partie — les trois
## damnés et leur pouvoir, la lave, les boss, la boutique, la Forge, le
## Déchaînement — pose les cartons par-dessus, et Godot enregistre chaque image
## (Movie Maker). Le résultat est la vidéo finale, son compris.
##
##     godot --path . --resolution 1920x1080 --fixed-fps 60 \
##         --write-movie build/bande-annonce/infernum_en.avi \
##         res://tools/bande_annonce.tscn ++ en
##
## `++ fr` pour la version française. Le jeu tourne À TEMPS FIXE : une image
## vaut 1/60 s de vidéo, quelle que soit la vitesse réelle du rendu, et le
## montage se cale sur l'horloge des images, pas sur l'horloge murale.
##
## LA MUSIQUE DÉCIDE DU MONTAGE. « Cyber Wolf » a été choisie pour sa forme,
## mesurée sur son enveloppe : une intro calme (-18 dB), un trou à 8,1 s
## (-25 dB), puis l'attaque à 9,65 s (-12 dB). Le titre tombe sur l'attaque,
## les coupes suivent ensuite une grille de 2 s.
##
## ATTENTION : le tournage écrit dans le profil actif (histoire vue, dernier
## personnage). Sauvegarder `app_userdata/Infernum` avant, comparer et rendre
## après — comme pour un banc.

const ARENE := "res://scenes/main/main.tscn"
const MUSIQUE := "res://assets/audio/Music/wolfdudedodi-cyber-wolf-529967.ogg"
const RUGISSEMENT := "res://assets/audio/SoundEffects/BigRoar.ogg"
const ILLUSTRATION := "res://assets/sprites/menu/menu.jpg"
const LUCIFER := "res://assets/sprites/bosses/lucifer/lucifer_idle.png"
const IPS := 60.0

## L'attaque de la musique, et la grille qui en part.
const ATTAQUE := 9.65

const TEXTES := {
	"pari": {"en": "HEAVEN MADE A WAGER.", "fr": "LE CIEL A FAIT UN PARI."},
	"perdu": {"en": "THE ACCUSER LOST.", "fr": "L'ACCUSATEUR A PERDU."},
	"revanche": {"en": "NOW HE WANTS A REMATCH.", "fr": "IL VEUT SA REVANCHE."},
	"accroche": {"en": "An action roguelite in the depths of hell",
		"fr": "Un roguelite d'action au fond de l'enfer"},
	"portes": {"en": "HELL HAS NO GATES.\nIT HAS WAVES.",
		"fr": "L'ENFER N'A PAS DE PORTES.\nIL A DES VAGUES."},
	"profondeurs": {"en": "THE DEEPER YOU GO", "fr": "PLUS ON DESCEND"},
	"profondeurs_2": {"en": "the more it burns", "fr": "plus ça brûle"},
	"seigneurs": {"en": "FACE THE LORDS OF HELL", "fr": "AFFRONTEZ\nLES SEIGNEURS DE L'ENFER"},
	"forge": {"en": "DIE. FORGE.\nGO DEEPER.", "fr": "MOURIR. FORGER.\nDESCENDRE."},
	"dechaine": {"en": "UNLEASHED", "fr": "DÉCHAÎNEMENT"},
	"dechaine_2": {"en": "no limits left", "fr": "plus aucune limite"},
	"fin": {"en": "COMING SOON", "fr": "BIENTÔT DISPONIBLE"},
}

const COULEURS := {
	&"cain": Color(0.85, 0.22, 0.18),
	&"job": Color(0.55, 0.72, 0.85),
	&"loth": Color(0.95, 0.85, 0.5),
}

var langue := "en"
var _images := 0
var _t := 0.0

var _arene: Node
var _joueur: Node2D
var _vagues: WaveManager

var _calque: CanvasLayer
var _noir: ColorRect
var _flash: ColorRect
var _carton: Label
var _carton_2: Label
var _titre: Control
var _silhouette: TextureRect
var _musique: AudioStreamPlayer

## Le joueur est conduit : orbite autour d'une ancre, arrêt, ou course.
var _mode := &"orbite"
var _ancre := Vector2.ZERO
var _rayon := 230.0
var _vise := Vector2.ZERO


func _ready() -> void:
	# Lancé comme scène : il se recrée hors de la scène courante, sinon le
	# premier changement de scène le détruirait avec elle.
	if get_tree().current_scene == self:
		var realisateur: Node = (get_script() as GDScript).new()
		realisateur.name = "Realisateur"
		get_tree().root.add_child.call_deferred(realisateur)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	var args := OS.get_cmdline_user_args()
	langue = "fr" if args.has("fr") else "en"
	TranslationServer.set_locale(langue)
	# En fenêtre 16/9, quel que soit le réglage du joueur : en plein écran sur
	# un écran 21/9, le jeu se cale sur 2560 × 1080 et la vidéo en rogne les
	# côtés — le HUD en perdait ses deux colonnes. Sans passer par `Settings`,
	# qui l'écrirait dans son fichier.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_regler_son()
	_construire_calque()
	_tourner.call_deferred()


func _process(_delta: float) -> void:
	_images += 1
	_t = _images / IPS


func _physics_process(_delta: float) -> void:
	_conduire()


func _texte(cle: String) -> String:
	return TEXTES[cle][langue]


# --- Le son -------------------------------------------------------------------

## Les bus sont réglés ici, sans passer par `Settings` : ses volumes sont ceux
## du joueur (et s'écriraient dans son fichier), la vidéo a son propre mix.
##
## Mesuré sur un premier rendu : -16 à -17 dB RMS, crêtes à -2,2 dBFS. Tout
## monte de 3 dB, et un limiteur sur le bus principal tient les crêtes sous
## -1 dBFS — sans lui, le rugissement des boss saturait.
func _regler_son() -> void:
	for bus in [&"Musique", &"Effets"]:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_mute(i, false)
			AudioServer.set_bus_volume_db(i, 3.0 if bus == &"Musique" else -2.0)
	var limiteur := AudioEffectHardLimiter.new()
	limiteur.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiteur)
	_musique = AudioStreamPlayer.new()
	_musique.stream = load(MUSIQUE)
	_musique.bus = &"Musique"
	_musique.volume_db = -4.0
	add_child(_musique)


func _effets(actifs: bool) -> void:
	var i := AudioServer.get_bus_index(&"Effets")
	if i >= 0:
		AudioServer.set_bus_mute(i, not actifs)


func _rugir() -> void:
	var r := AudioStreamPlayer.new()
	r.stream = load(RUGISSEMENT)
	r.bus = &"Musique"
	r.volume_db = -2.0
	add_child(r)
	r.play()
	r.finished.connect(r.queue_free)


# --- Le calque des cartons ------------------------------------------------------

func _construire_calque() -> void:
	_calque = CanvasLayer.new()
	_calque.layer = 128
	add_child(_calque)

	_titre = Control.new()
	_titre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_titre.visible = false
	_calque.add_child(_titre)
	var fond := TextureRect.new()
	fond.texture = load(ILLUSTRATION)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fond.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fond.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_titre.add_child(fond)
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.35)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_titre.add_child(voile)
	var nom := _etiquette(210, Color(1.0, 0.45, 0.2), 18)
	nom.name = "Nom"
	nom.text = "INFERNUM"
	nom.position.y = -60
	_titre.add_child(nom)
	var accroche := _etiquette(44, Color(0.95, 0.9, 0.85), 8)
	accroche.name = "Accroche"
	accroche.theme_type_variation = &""
	accroche.position.y = 150
	_titre.add_child(accroche)

	_noir = ColorRect.new()
	_noir.color = Color.BLACK
	_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_calque.add_child(_noir)

	_silhouette = TextureRect.new()
	_silhouette.set_anchors_preset(Control.PRESET_CENTER)
	_silhouette.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_silhouette.visible = false
	var planche: Texture2D = load(LUCIFER)
	var image := AtlasTexture.new()
	image.atlas = planche
	image.region = Rect2(0, 0, planche.get_height(), planche.get_height())
	_silhouette.texture = image
	_silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_silhouette.stretch_mode = TextureRect.STRETCH_SCALE
	var cote := planche.get_height() * 11.0
	_silhouette.size = Vector2(cote, cote)
	_silhouette.position = Vector2(-cote * 0.5, -cote * 0.55)
	_calque.add_child(_silhouette)

	_carton = _etiquette(104, Color(0.96, 0.92, 0.86), 14)
	_carton.position.y = -40
	_calque.add_child(_carton)
	_carton_2 = _etiquette(46, Color(1.0, 0.55, 0.3), 8)
	_carton_2.theme_type_variation = &""
	_carton_2.position.y = 110
	_calque.add_child(_carton_2)

	_flash = ColorRect.new()
	_flash.color = Color(1, 0.95, 0.85)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.modulate.a = 0.0
	_calque.add_child(_flash)


func _etiquette(taille: int, couleur: Color, contour: int) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"TitleLabel"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", taille)
	l.add_theme_color_override(&"font_color", couleur)
	l.add_theme_color_override(&"font_outline_color", Color(0.08, 0.02, 0.02))
	l.add_theme_constant_override(&"outline_size", contour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Un carton : texte sur noir, fondu court à l'entrée et à la sortie.
func _montrer_carton(texte: String, sous_texte: String = "", sur_noir: bool = true) -> void:
	_noir.visible = sur_noir
	_noir.modulate.a = 1.0
	_carton.text = texte
	_carton_2.text = sous_texte
	for l: Label in [_carton, _carton_2]:
		l.modulate.a = 0.0
		l.scale = Vector2.ONE
		l.pivot_offset = Vector2(960, 540)
		var entree := create_tween().set_parallel()
		entree.tween_property(l, ^"modulate:a", 1.0, 0.18)
		l.scale = Vector2(1.06, 1.06)
		entree.tween_property(l, ^"scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)


func _cacher_carton(fondu: float = 0.12) -> void:
	for l: Label in [_carton, _carton_2]:
		create_tween().tween_property(l, ^"modulate:a", 0.0, fondu)


func _ouvrir(fondu: float = 0.0) -> void:
	_cacher_carton(0.08)
	if fondu <= 0.0:
		_noir.visible = false
		return
	var t := create_tween()
	t.tween_property(_noir, ^"modulate:a", 0.0, fondu)
	t.tween_callback(func() -> void:
		_noir.visible = false
		_noir.modulate.a = 1.0)


func _fermer() -> void:
	_noir.visible = true
	_noir.modulate.a = 1.0


func _eclair(force: float = 0.8) -> void:
	_flash.modulate.a = force
	create_tween().tween_property(_flash, ^"modulate:a", 0.0, 0.35)


# --- L'horloge du montage -------------------------------------------------------

func _jusqua(t: float) -> void:
	while _t < t:
		await get_tree().process_frame


## Avance la partie de `secondes` de jeu en `images` images de vidéo, son coupé :
## ce qui se prépare sous un carton ne doit ni se voir ni s'entendre.
func _avancer(secondes: float, images: int) -> void:
	var avant := AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Effets"))
	_effets(false)
	Engine.time_scale = clampf(secondes / (images / IPS), 1.0, 8.0)
	for _i in images:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_effets(not avant)


# --- Conduire le joueur -----------------------------------------------------------

func _conduire() -> void:
	if not is_instance_valid(_joueur):
		return
	var pos := _joueur.global_position
	var voulu := Vector2.ZERO
	match _mode:
		&"orbite":
			var a := _t * 1.1
			var cible := _ancre + Vector2(cos(a), sin(a * 1.37) * 0.7) * _rayon
			voulu = (cible - pos) / 70.0
		&"vers":
			voulu = (_vise - pos) / 50.0
		_:
			voulu = Vector2.ZERO
	PlayerInput.virtual_move = voulu.limit_length(1.0)


func _pouvoir() -> void:
	Input.action_press(&"dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"dash")


func _changer(id: StringName) -> void:
	if Characters.selected_id != id:
		Characters.swap_in_run(id)
		_joueur.call(&"swap_character", Characters.get_selected())
	var c := Characters.get_selected()
	GameEvents.announce.emit(c.display_name.to_upper(), c.title, COULEURS.get(id, Color.WHITE))


func _ennemis_proches(rayon: float) -> Vector2:
	var somme := Vector2.ZERO
	var n := 0
	for e in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var node := e as Node2D
		if node != null and node.global_position.distance_to(_joueur.global_position) < rayon:
			somme += node.global_position
			n += 1
	return somme / n if n > 0 else _joueur.global_position + Vector2.RIGHT * 200.0


func _donner(objets: Dictionary) -> void:
	for id: StringName in objets:
		var item := ItemDB.get_item(id)
		for _i in int(objets[id]):
			if item != null and RunState.can_take(item):
				RunState.add_item(item)


## Toute l'histoire est marquée vue : aucune cinématique ne doit couper un plan.
func _histoire_vue() -> void:
	for id: StringName in StoryDB.CINEMATIQUES:
		SaveGame.mark_story_seen(id)


# --- Le tournage ------------------------------------------------------------------

func _monter_arene(perso: StringName) -> void:
	# Directement, sans `select()` : il écrirait le dernier personnage joué.
	Characters.selected_id = perso
	get_tree().change_scene_to_file(ARENE)
	while get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		await get_tree().process_frame
	await get_tree().process_frame
	_arene = get_tree().current_scene
	Audio.stop_music()
	Audio.stop_ambiance()
	_arene.find_child("CurseSelect", true, false).call(&"_on_start_pressed")
	_joueur = _arene.find_child("Player", true, false) as Node2D
	_vagues = get_tree().get_first_node_in_group(Groups.WAVE_MANAGER) as WaveManager
	(_joueur.get(&"health") as Health).invincible = true
	_ancre = _joueur.global_position


func _tourner() -> void:
	_histoire_vue()
	_effets(false)
	_musique.play()

	# Sous les cartons, l'arène se remplit déjà : Caïn, vague 8, de quoi tirer.
	await _monter_arene(&"cain")
	_donner({&"trifid_shard": 2, &"eternal_ember": 1, &"damned_clock": 1, &"demon_bile": 3})
	_vagues.dev_jump_to_wave(8)

	# --- L'histoire, sur l'intro ---
	await _jusqua(0.5)
	_montrer_carton(_texte("pari"))
	await _jusqua(3.1)
	_cacher_carton()
	await _jusqua(3.35)
	_montrer_carton(_texte("perdu"))
	await _jusqua(5.6)
	_cacher_carton()
	await _jusqua(5.85)
	_montrer_carton(_texte("revanche"))
	await _jusqua(8.05)
	_cacher_carton(0.05)
	# Le trou de la musique : Lucifer sort de l'ombre, et rugit.
	_silhouette.visible = true
	_silhouette.modulate = Color(0.25, 0.02, 0.02, 0.0)
	var entree := create_tween()
	entree.tween_property(_silhouette, ^"modulate", Color(1.0, 0.62, 0.5, 1.0), 1.2)
	await _jusqua(8.25)
	_rugir()

	# --- Le titre, sur l'attaque ---
	await _jusqua(ATTAQUE)
	_silhouette.visible = false
	_titre.visible = true
	(_titre.get_node("Accroche") as Label).text = _texte("accroche")
	var nom := _titre.get_node("Nom") as Label
	nom.pivot_offset = Vector2(960, 540)
	nom.scale = Vector2(1.35, 1.35)
	create_tween().tween_property(nom, ^"scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_eclair(1.0)
	_noir.visible = false

	# --- Les trois damnés ---
	var t := ATTAQUE + 4.0
	await _jusqua(t)
	_titre.visible = false
	_effets(true)
	_eclair(0.6)
	_ancre = _joueur.global_position
	_mode = &"orbite"
	_changer(&"cain")
	# La Marque, pleine : le Prix du sang part au milieu du plan.
	var effets := _arene.find_child("CharacterEffects", true, false)
	effets.set(&"_wave_kills", 40)
	effets.call(&"_appliquer_marque")
	await _jusqua(t + 2.2)
	_pouvoir()

	t += 4.0
	await _jusqua(t)
	_eclair(0.6)
	_changer(&"job")
	_mode = &"arret"
	await _jusqua(t + 1.9)
	_joueur.call(&"add_ferveur", 99.0)
	_pouvoir()
	await _jusqua(t + 2.6)
	_mode = &"orbite"
	_ancre = _joueur.global_position

	t += 4.0
	await _jusqua(t)
	_eclair(0.6)
	_changer(&"loth")
	for k in 3:
		await _jusqua(t + 0.6 + k * 1.15)
		_mode = &"vers"
		var foule := _ennemis_proches(700.0)
		_vise = _joueur.global_position + (foule - _joueur.global_position).normalized() * 400.0
		await get_tree().physics_frame
		await get_tree().physics_frame
		_pouvoir()
	await _jusqua(t + 3.9)
	_mode = &"orbite"
	_ancre = _joueur.global_position

	# --- Les vagues ---
	t += 4.0
	await _jusqua(t)
	_montrer_carton(_texte("portes"))
	_changer(&"cain")
	_donner({&"trifid_shard": 2, &"predator_crown": 2})
	_vagues.dev_jump_to_wave(9)
	await _avancer(10.0, 100)
	await _jusqua(t + 2.0)
	_ouvrir()
	_ancre = _joueur.global_position

	# --- Les profondeurs ---
	t += 6.0
	await _jusqua(t)
	_fermer()
	_vagues.dev_jump_to_wave(13)
	await _avancer(2.0, 16)
	_poser_pres_de_la_lave()
	await _avancer(6.0, 20)
	_ouvrir()
	GameEvents.announce.emit(_texte("profondeurs"), _texte("profondeurs_2"), Color(1.0, 0.5, 0.2))

	# --- Les seigneurs ---
	t += 5.0
	await _jusqua(t)
	_montrer_carton(_texte("seigneurs"))
	_changer(&"job")
	await _jusqua(t + 2.0)
	var bosses := [5, 10, 15, 20, 25]
	for k in bosses.size():
		var debut := t + 2.0 + k * 2.0
		await _jusqua(debut)
		_fermer()
		_cacher_carton(0.01)
		_vagues.dev_jump_to_wave(bosses[k])
		await _avancer(1.0, 6)
		_rapprocher_boss()
		# Assez de jeu pour que le boss ait frappé : un boss à 100 %, immobile
		# à son entrée, ne raconte rien.
		await _avancer(2.4, 18)
		_ouvrir()
		_eclair(0.35)

	# --- La boutique et la Forge ---
	t += 12.0
	await _jusqua(t)
	_montrer_carton(_texte("forge"))
	# Lucifer s'en va sans mourir — sa mort ouvrirait la suite de l'histoire et
	# lâcherait la Clé des Abysses — et la boutique s'ouvre sur une vague
	# ordinaire, pas sur « Vague 25 terminée » avec sa barre encore affichée.
	_renvoyer_boss()
	_vagues.dev_jump_to_wave(12)
	await _avancer(2.0, 30)
	await _jusqua(t + 2.0)
	_ouvrir()
	RunState.souls = 480
	var boutique := _arene.find_child("Shop", true, false)
	boutique.call(&"open")
	await get_tree().process_frame
	for carte in boutique.find_children("*", "ItemCard", true, false):
		(carte.get(&"_buy_button") as Button).grab_focus()
		break
	await _jusqua(t + 4.0)
	boutique.call(&"close")
	var forge := _arene.find_child("Forge", true, false)
	forge.call(&"open")
	_eclair(0.3)
	await _jusqua(t + 6.0)
	forge.call(&"close")

	# --- Le Déchaînement ---
	t += 6.0
	_montrer_carton(_texte("dechaine"), _texte("dechaine_2"))
	get_tree().paused = false
	_changer(&"cain")
	RunState.unleashed = true
	for item: ItemData in ItemDB.get_all():
		while RunState.can_take(item):
			RunState.add_item(item)
	RunState.recompute_stats()
	_vagues.dev_jump_to_wave(22)
	await _avancer(14.0, 110)
	await _jusqua(t + 2.0)
	_ouvrir()
	_eclair(0.5)
	_ancre = _joueur.global_position
	_rayon = 320.0

	# --- La fin ---
	t += 8.0
	await _jusqua(t)
	_effets(false)
	_titre.visible = true
	(_titre.get_node("Accroche") as Label).text = _texte("fin")
	nom.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(nom, ^"scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_eclair(0.9)
	var fin := create_tween()
	fin.tween_interval(3.5)
	fin.tween_property(_musique, ^"volume_db", -60.0, 2.5)
	await _jusqua(t + 6.5)
	var noir := create_tween()
	_noir.visible = true
	_noir.modulate.a = 0.0
	noir.tween_property(_noir, ^"modulate:a", 1.0, 0.6)
	await _jusqua(t + 7.3)
	print("BANDE-ANNONCE terminee : %.2f s, %d images" % [_t, _images])
	get_tree().quit()


## Le joueur est posé à côté de la lave la plus proche : les ennemis qui le
## rejoignent la traversent, et brûlent.
func _poser_pres_de_la_lave() -> void:
	var carte := Carte.courante
	if carte == null:
		return
	var depart := _joueur.global_position
	for r in range(200, 2400, 100):
		for k in 32:
			var dir := Vector2.RIGHT.rotated(TAU * k / 32.0)
			var p := depart + dir * r
			if not carte.en_lave(p):
				continue
			# En reculant depuis la lave, le premier point libre à 240 px du bord.
			for recul in range(240, 600, 40):
				var q := p - dir * recul
				if not carte.en_lave(q) and carte.libre(q, 40.0):
					_joueur.global_position = q
					_ancre = q
					_rayon = 120.0
					return
	push_warning("bande-annonce : pas de lave trouvée")


func _renvoyer_boss() -> void:
	for boss in get_tree().get_nodes_in_group(Groups.BOSSES):
		boss.remove_from_group(Groups.BOSSES)
		boss.queue_free()
	var hud := _arene.find_child("HUD", true, false)
	(hud.get(&"_panneau_boss") as Control).visible = false
	hud.set(&"_boss", null)


func _rapprocher_boss() -> void:
	for boss in get_tree().get_nodes_in_group(Groups.BOSSES):
		var node := boss as Node2D
		if node != null:
			node.global_position = _joueur.global_position + Vector2(420, -140)
	_ancre = _joueur.global_position
	_rayon = 200.0
