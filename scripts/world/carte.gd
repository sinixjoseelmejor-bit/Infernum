class_name Carte
extends Node2D
## La carte de l'enfer : ce que `GenerateurCarte` décide, rendu jouable.
##
## Elle remplace `DecorScatter`. Même socle — un lieu par parcelle de 950 px,
## seules les parcelles visibles portent des nœuds, recyclés d'une parcelle à
## l'autre — mais le décor n'est plus seulement regardé :
##
##   - les MONUMENTS BLOQUENT. Joueur, ennemis et TOUS les projectiles, des deux
##     camps. C'est ce qui rend l'obstacle honnête : la règle qui interdisait
##     toute collision au décor disait qu'un obstacle qui arrête le joueur sans
##     arrêter ce qui le frappe serait une trahison. Celui-ci arrête les deux.
##     Les boss, eux, passent : un colosse ne se laisse pas coincer derrière une
##     statue, et un boss bloqué serait un combat gagné sans le jouer.
##   - la LAVE BRÛLE tout ce qui marche dessus, joueur et ennemis — les boss
##     exceptés. Elle se voit en permanence : c'est du placement pur, et y
##     attirer la horde devient une tactique.
##   - les ennemis CONTOURNENT les obstacles (`contourner`). Les obstacles sont
##     convexes et espacés, donc un évitement local suffit : pas de carte de flux.
##
## Le reste du jeu l'interroge par `Carte.courante` : les ennemis pour
## contourner, les vagues pour ne pas faire naître un ennemi dans un mur, le
## rayon de l'œil pour s'arrêter sur une statue. Absente (écran titre, tests),
## tout se comporte comme avant.

static var courante: Carte = null

const PIED := GenerateurCarte.PIED
## Distance origine-pieds retenue pour tous les ennemis : entre l'imp (21) et le
## joueur (37,5), mesurés dans le README. C'est là qu'ils touchent la lave.
const PIED_ENNEMI := 28.0
## Maille du registre des obstacles et de la lave.
const CELLULE := 256.0
## Parcelles entretenues au-delà du bord de l'écran. Les ennemis naissent à
## 700 px au plus du joueur : une parcelle de marge (950) les couvre, leurs
## obstacles existent donc avant eux.
const MARGE := 1
## Distance à laquelle un ennemi commence à dévier devant un obstacle.
const PORTEE_EVITEMENT := 150.0

## LA BRÛLURE, par pas de 0,25 s.
const TICK_LAVE := 0.25
## Le joueur perd UN COUP ENNEMI MOYEN PAR SECONDE dans la lave — l'unité de
## `WaveManager.get_hit_damage`, qui suit la courbe des vagues et donc le
## Déchaînement : tout ce qui résiste au joueur suit la même courbe. Traverser
## une rivière (0,5 s) coûte un demi-coup ; y rester, c'est mourir.
##
## La brûlure ne passe PAS par les i-frames et n'en donne pas : sans ça, se
## tenir dans la lave au milieu d'une mêlée rendrait intouchable au contact
## pour le prix d'un coup par seconde. Elle respecte l'armure, et l'invulnérabilité
## de la seconde chance.
const LAVE_COUPS_PAR_S := 1.0
## Les ennemis perdent 30 % de leurs PV max par seconde : un peu plus de trois
## secondes pour y mourir, quelle que soit la vague. En pourcentage, parce que
## leurs PV suivent la courbe et qu'un chiffre fixe cesserait de compter.
const LAVE_PART_PV_ENNEMI := 0.30
## Érosion du masque de lave, en pixels de planche : la zone qui brûle est un
## peu PLUS PETITE que la lave dessinée. Un pied posé sur le bord rougeoyant ne
## brûle pas — mieux vaut une image qui promet plus que le coup.
const LAVE_EROSION := 2

@export_group("Carte")
## 0 : une graine tirée à chaque run. Autre valeur : toujours la même carte.
@export var graine_fixe: int = 0

@export_group("Lumière")
## Le décor d'origine dans la même lumière que le sol (voir decor_scatter.gd,
## dont ces valeurs viennent).
@export var teinte: Color = Color(0.59, 0.66, 0.75)
@export var teinte_profonde: Color = Color(0.88, 0.76, 0.66)
## Les pièces de l'enfer sont déjà sombres dans leurs planches : la teinte du
## sol ne leur est appliquée qu'à moitié, sinon elles s'éteignent.
@export_range(0.0, 1.0, 0.05) var part_teinte_enfer: float = 0.5
## LA LUMIÈRE du feu et de la lave : de vraies lumières 2D, additives, qui
## éclairent le sol et le décor — pas les créatures (voir `MASQUE_DECOR`).
@export var energie_lave: float = 1.0
@export var energie_feu: float = 1.3
## L'OMBRE DE CONTACT : une ellipse sombre glissée sous le pied de chaque
## pièce dressée, comme celle que portent les personnages dans leurs planches.
## Sans elle, une statue semblait collée sur le sol plutôt que posée dessus.
@export_range(0.0, 1.0, 0.05) var ombre_contact_alpha: float = 0.7

@export_group("Lisibilité")
@export_range(0.0, 1.0, 0.05) var voile_alpha: float = 0.35
## Hauteur À L'ÉCRAN au-delà de laquelle une pièce peut cacher le joueur, dont
## le dessin mesure 22 px de source à l'échelle 3.
@export var voile_hauteur_min: float = 60.0
@export var voile_vitesse: float = 7.0

## Le fondu du changement d'étage, en secondes, à l'aller.
const FONDU := 0.25

## Le calque de lumière du décor. Le sol et les pièces de la carte y sont ; les
## créatures, les zones annoncées et les projectiles non. Un joueur orangé près
## d'un bassin se lirait comme un joueur qui BRÛLE — l'éclair de la brûlure est
## orange — et une zone annoncée éclaircie par la lave perdrait son contraste.
const MASQUE_DECOR := 2
const COULEUR_LAVE := Color(1.0, 0.38, 0.1)
const COULEUR_FEU := Color(1.0, 0.62, 0.28)


var graine: int = 0
var _gen := GenerateurCarte.new()
var _textures: Dictionary = {}          # id -> Texture2D
var _masques: Dictionary = {}           # id -> {"l", "h", "m": PackedByteArray}
var _actives: Dictionary = {}           # Vector2i -> {"sprites", "corps", "poses"}
var _libres: Array[Sprite2D] = []
var _corps_libres: Array[StaticBody2D] = []
var _formes: Dictionary = {}            # clé -> Shape2D
var _fenetre := Rect2i(0, 0, -1, -1)
var _obstacles: Dictionary = {}         # Vector2i -> Array[Dictionary]
var _laves: Dictionary = {}             # Vector2i -> Array[Dictionary]
var _ponts: Dictionary = {}             # Vector2i -> Array[Dictionary]
var _hauts: Array[Sprite2D] = []
var _joueur: Node2D
var _vagues: Node
var _tick: float = 0.0
var _compteur: int = 0
var _lumiere_texture: Texture2D
var _ombre_texture: Texture2D
var _braises_couleurs: Gradient
var _feu_materiau: ShaderMaterial
var _lumieres_libres: Array[PointLight2D] = []
var _braises_libres: Array[CPUParticles2D] = []
## Les flammes à faire vaciller : {"l": PointLight2D, "e": énergie, "p": phase}.
var _flammes: Array[Dictionary] = []
var _temps: float = 0.0
var _pret := false
## Dessine obstacles et lave (panneau de développement), sur un calque posé
## au-dessus de tout : dessinées par la carte elle-même, les formes passeraient
## sous les statues qu'elles décrivent.
var montrer_formes := false:
	set(v):
		montrer_formes = v
		if _calque_formes != null:
			_calque_formes.queue_redraw()
var _calque_formes: Node2D


func _enter_tree() -> void:
	courante = self


func _exit_tree() -> void:
	if courante == self:
		courante = null


func _ready() -> void:
	# Le tri en Y d'un parent n'englobe ses petits-enfants que si le nœud
	# intermédiaire trie aussi.
	y_sort_enabled = true
	graine = graine_fixe if graine_fixe != 0 else randi()
	_gen.graine = graine
	GameEvents.arena_depth_changed.connect(_on_depth_changed)
	_pret = _charger()
	_preparer_rendu()
	_calque_formes = Node2D.new()
	_calque_formes.z_index = 50
	_calque_formes.draw.connect(_dessiner_formes)
	add_child(_calque_formes)
	# Dépôt fraîchement cloné : les planches ne sont pas encore extraites (voir
	# tools/extract_assets.py). La carte s'efface alors sans un mot — ni décor,
	# ni obstacle, ni lave : le jeu d'avant, plutôt qu'une carte à trous.
	if not _pret:
		set_process(false)


## Nouvelle carte sur-le-champ (panneau de développement).
func nouvelle_graine(valeur: int = 0) -> void:
	graine = valeur if valeur != 0 else randi()
	_gen.graine = graine
	_tout_effacer()


func etage() -> int:
	return _gen.etage


# --- Chargement --------------------------------------------------------------

func _charger() -> bool:
	var ids: Array = EnferDB.PIECES.keys()
	for id: StringName in ids:
		var chemin := EnferDB.chemin(id)
		if not ResourceLoader.exists(chemin):
			return false
		_textures[id] = load(chemin)
	var vieux: Array = GenerateurCarte.RUINE_MUR + GenerateurCarte.RUINE_COEUR \
		+ GenerateurCarte.RUINE_SOL + GenerateurCarte.POTERIE + GenerateurCarte.VEGETATION \
		+ GenerateurCarte.ROCHE_GROS + GenerateurCarte.ROCHE_MOYEN \
		+ GenerateurCarte.ROCHE_PETIT + [GenerateurCarte.RUINE_COIN, GenerateurCarte.ROCHE_TETE]
	for id: StringName in vieux:
		var chemin := "res://assets/sprites/decor/%s.png" % id
		if not ResourceLoader.exists(chemin):
			return false
		_textures[id] = load(chemin)
	# Tailles et pieds de toutes les pièces : ce sont les emprises des règles du
	# générateur, et le pied cale aussi l'ombre de contact.
	for id: StringName in _textures.keys():
		GenerateurCarte.mesurer(id, _textures[id])
	return true


## LE MASQUE DE LAVE d'une pièce : quels pixels brûlent.
##
## Lu dans l'image et non décrit à la main : une rivière coudée ou un bassin en
## trèfle n'ont pas de forme simple, et une forme approchée brûlerait sur la
## berge ou épargnerait le milieu. Critère de couleur mesuré sur les planches :
## la lave est orange à jaune (rouge fort, bleu faible), la berge est grise.
##
## Deux passes ensuite. Une FERMETURE bouche les îlots de roche dans le courant
## — un pied posé sur un caillou de 4 px au milieu d'une rivière n'a rien à y
## gagner. Puis l'ÉROSION de `LAVE_EROSION` px, qui rend la zone brûlante un peu
## plus petite que le dessin.
func _masque_lave(id: StringName) -> Dictionary:
	if _masques.has(id):
		return _masques[id]
	var img: Image = (_textures[id] as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var l := img.get_width()
	var h := img.get_height()
	var octets := img.get_data()
	var m := PackedByteArray()
	m.resize(l * h)
	for i in l * h:
		var r := octets[i * 4]
		var g := octets[i * 4 + 1]
		var b := octets[i * 4 + 2]
		m[i] = 1 if (octets[i * 4 + 3] > 128 and r > 160 and g > 50 and b < 110
			and float(r) > float(g) * 1.25) else 0
	m = _morpho(m, l, h, 3, true)
	m = _morpho(m, l, h, 3 + LAVE_EROSION, false)
	var masque := {"l": l, "h": h, "m": m}
	_masques[id] = masque
	return masque


## Dilatation (`grossir`) ou érosion carrée de rayon `r`, en deux passes
## séparées et par sommes glissantes : un pixel vaut la cible dès qu'une seule
## case de sa fenêtre la vaut. Hors de l'image, rien ne brûle.
static func _morpho(m: PackedByteArray, l: int, h: int, r: int, grossir: bool) -> PackedByteArray:
	var vise := 1 if grossir else 0
	var tmp := _passe(m, l, h, r, vise, 1, l)
	return _passe(tmp, h, l, r, vise, l, 1)


## Une passe le long d'un axe : `n` pixels par ligne, `lignes` lignes, `pas`
## entre deux pixels d'une ligne et `saut` entre deux lignes.
static func _passe(m: PackedByteArray, n: int, lignes: int, r: int, vise: int,
		pas: int, saut: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(m.size())
	for ligne in lignes:
		var base := ligne * saut
		# Nombre de pixels « cible » dans la fenêtre [i - r, i + r]. Le hors-
		# image compte comme 0 : il ne brûle pas.
		var compte := 0
		for k in range(0, mini(r, n - 1) + 1):
			if m[base + k * pas] == vise:
				compte += 1
		if vise == 0:
			compte += r
		for i in n:
			out[base + i * pas] = vise if compte > 0 else 1 - vise
			var sort := i - r
			var entre := i + r + 1
			if sort >= 0:
				if m[base + sort * pas] == vise:
					compte -= 1
			elif vise == 0:
				compte -= 1
			if entre < n:
				if m[base + entre * pas] == vise:
					compte += 1
			elif vise == 0:
				compte += 1
	return out


func _preparer_rendu() -> void:
	# La lumière : forte au centre, retombée douce — un disque à bord franc se
	# lirait comme un projecteur.
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	degrade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45),
		Color(1, 1, 1, 0)])
	_lumiere_texture = _radial(degrade, 256)
	# L'ombre : noire au centre, fondue au bord.
	var sombre := Gradient.new()
	sombre.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	sombre.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.75),
		Color(0, 0, 0, 0)])
	_ombre_texture = _radial(sombre, 64)
	_braises_couleurs = Gradient.new()
	_braises_couleurs.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	_braises_couleurs.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 1.0),
		Color(1.0, 0.45, 0.1, 0.9), Color(0.6, 0.1, 0.05, 0.0)])
	var shader := Shader.new()
	shader.code = SHADER_FEU
	_feu_materiau = ShaderMaterial.new()
	_feu_materiau.shader = shader


static func _radial(degrade: Gradient, taille: int) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.gradient = degrade
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = taille
	tex.height = taille
	return tex


## LE FEU VIT. Seuls les pixels incandescents bougent — la pierre d'un brasero
## reste immobile, c'est la flamme qui vacille. Un bruit de phase par endroit du
## monde : deux braseros voisins ne battent pas à l'unisson, ce qui se verrait
## tout de suite.
const SHADER_FEU := """
shader_type canvas_item;
varying vec2 monde;
void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 c = COLOR;
	float chaud = smoothstep(0.35, 0.75, c.r - c.b * 0.9) * step(0.15, c.g);
	float phase = dot(floor(monde / 48.0), vec2(1.7, 2.3));
	float batt = sin(TIME * 7.0 + phase) * 0.5 + sin(TIME * 12.3 + phase * 1.9) * 0.3;
	COLOR.rgb = c.rgb * (1.0 + chaud * batt * 0.16);
}
"""


# --- Parcelles ---------------------------------------------------------------

func _process(delta: float) -> void:
	_voiler(delta)
	_bruler_si_besoin(delta)
	_vaciller(delta)
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var centre := camera.get_screen_center_position()
	var vue: Vector2 = get_viewport_rect().size / camera.zoom
	var cote := GenerateurCarte.ZONE_COTE
	var fenetre := Rect2i(
		int(floor((centre.x - vue.x * 0.5) / cote)) - MARGE,
		int(floor((centre.y - vue.y * 0.5) / cote)) - MARGE,
		int(ceil(vue.x / cote)) + MARGE * 2 + 1,
		int(ceil(vue.y / cote)) + MARGE * 2 + 1)
	if fenetre == _fenetre:
		return
	_fenetre = fenetre
	_ramasser(fenetre)
	_semer(fenetre)
	_indexer()


func _ramasser(fenetre: Rect2i) -> void:
	for parcelle: Vector2i in _actives.keys():
		if fenetre.has_point(parcelle):
			continue
		_liberer(parcelle)


func _liberer(parcelle: Vector2i) -> void:
	var entree: Dictionary = _actives[parcelle]
	for sprite: Sprite2D in entree["sprites"]:
		sprite.visible = false
		_libres.append(sprite)
	for corps: StaticBody2D in entree["corps"]:
		corps.process_mode = Node.PROCESS_MODE_DISABLED
		corps.visible = false
		_corps_libres.append(corps)
	for lumiere: PointLight2D in entree["lumieres"]:
		lumiere.enabled = false
		lumiere.visible = false
		_lumieres_libres.append(lumiere)
	for braises: CPUParticles2D in entree["braises"]:
		braises.emitting = false
		braises.visible = false
		_braises_libres.append(braises)
	_actives.erase(parcelle)


func _tout_effacer() -> void:
	for parcelle: Vector2i in _actives.keys():
		_liberer(parcelle)
	_fenetre = Rect2i(0, 0, -1, -1)
	_indexer()


func _semer(fenetre: Rect2i) -> void:
	for py in range(fenetre.position.y, fenetre.end.y):
		for px in range(fenetre.position.x, fenetre.end.x):
			var parcelle := Vector2i(px, py)
			if not _actives.has(parcelle):
				_engendrer(parcelle)


func _engendrer(parcelle: Vector2i) -> void:
	var poses := _gen.engendrer(parcelle)
	var sprites: Array[Sprite2D] = []
	var corps: Array[StaticBody2D] = []
	var lumieres: Array[PointLight2D] = []
	var braises: Array[CPUParticles2D] = []
	for pose: Dictionary in poses:
		if GenerateurCarte.bloque(pose):
			corps.append(_poser_corps(pose))
		# Un mur n'a pas d'image : ses pans sont posés à part.
		if pose.has("mur"):
			continue
		sprites.append(_poser(pose))
		if pose["vieux"]:
			# Le décor d'origine porte ses ombres dans ses planches.
			continue
		var info := EnferDB.info(pose["id"])
		if not info.has("sol"):
			_poser_ombres(pose, info, sprites)
		if info.has("lueur"):
			_poser_lumieres(pose, info, lumieres)
		if info.get("braises", false):
			braises.append(_poser_braises(pose, info))
	_actives[parcelle] = {"sprites": sprites, "corps": corps, "poses": poses,
		"lumieres": lumieres, "braises": braises}


func _prendre_sprite() -> Sprite2D:
	if not _libres.is_empty():
		return _libres.pop_back()
	var sprite := Sprite2D.new()
	add_child(sprite)
	return sprite


func _poser(pose: Dictionary) -> Sprite2D:
	var id: StringName = pose["id"]
	var texture: Texture2D = _textures[id]
	var sprite := _prendre_sprite()
	var ech: float = pose["e"]
	var info := EnferDB.info(id) if not pose["vieux"] else {}
	var plate := info.has("sol")
	sprite.texture = texture
	sprite.scale = Vector2(ech, ech)
	sprite.rotation = pose["r"]
	sprite.skew = 0.0
	sprite.flip_h = pose["fh"]
	sprite.flip_v = pose["fv"]
	sprite.position = pose["p"]
	sprite.z_index = int(info["sol"]) if plate else 0
	# La lave n'est éclairée par personne, pas même par sa propre lumière : elle
	# est déjà la chose la plus claire de l'écran, éclairée elle saturait.
	sprite.light_mask = 0 if info.get("lave", false) else MASQUE_DECOR
	sprite.material = _feu_materiau if info.get("feu", false) or info.get("lave", false) else null
	# Filtrage net, comme les personnages. Comparé en capture au filtrage doux :
	# le net garde le trait du pixel art, le doux l'estompe sans rien gagner —
	# ces planches n'ayant pas de grille régulière, l'irrégularité d'un pixel
	# sur deux à l'échelle 1,5 ne s'y voit pas. Sur un écran de 1440 lignes,
	# l'échelle réelle tombe à 2, et le rendu est exact.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Une pièce plate est centrée sur sa position ; une pièce dressée pose sa
	# base `PIED` px sous son nœud (voir l'en-tête du générateur).
	sprite.offset = Vector2.ZERO if plate \
		else Vector2(0.0, -texture.get_height() * 0.5 + PIED / ech)
	sprite.self_modulate = _teinte_de(pose, info)
	sprite.visible = true
	return sprite


func _teinte_de(pose: Dictionary, info: Dictionary) -> Color:
	var base := teinte_profonde if _gen.etage == GenerateurCarte.PROFONDEUR else teinte
	if pose["vieux"]:
		return base
	# Ce qui brûle éclaire : la lave et le feu ne prennent pas la lumière du sol.
	if info.get("lave", false):
		return Color.WHITE
	# Les fissures et la roche refroidie autour des bassins sont ÉTEINTES : à
	# pleine lumière, elles rougeoyaient autant que la lave (vu en capture), et
	# le joueur ne pouvait plus distinguer ce qui brûle de ce qui a brûlé.
	if info.has("sol") and info.get("feu", false):
		return Color.WHITE.lerp(base, part_teinte_enfer) * Color(0.62, 0.55, 0.55)
	var part := part_teinte_enfer * (0.5 if info.get("feu", false) else 1.0)
	return Color.WHITE.lerp(base, part)


## L'OMBRE d'une pièce dressée : une ellipse sombre GLISSÉE SOUS SON PIED,
## comme celle que portent les personnages dans leurs planches.
##
## Elle épouse le pied réel de la pièce — un socle, une roche, le manche d'une
## torche —, mesuré dans l'image (voir `GenerateurCarte.mesurer`), et se centre un peu AU-DESSUS
## de la base : l'essentiel passe sous la pièce, il n'en dépasse qu'un liseré
## sur les côtés et dessous. Deux versions écartées, parce que les objets
## avaient l'air de VOLER :
##   - une ellipse large comme toute l'image et centrée sous la base : une tache
##     sombre séparée de la roche par un espace, le signe même d'un objet en
##     l'air ;
##   - une ombre PORTÉE vers la droite, la silhouette inclinée depuis la base :
##     pour une pièce large en bas, sa partie proche du sol est cachée par la
##     pièce, et il n'en restait qu'une bande sortant à mi-hauteur, détachée.
func _poser_ombres(pose: Dictionary, _info: Dictionary, sprites: Array[Sprite2D]) -> void:
	var ech: float = pose["e"]
	var pied: Vector2 = GenerateurCarte.pieds.get(pose["id"], Vector2(40.0, 0.0))
	var decalage := pied.y * ech * (-1.0 if pose["fh"] else 1.0)
	var largeur := pied.x * ech * 1.15 + 6.0
	var hauteur := clampf(largeur * 0.28, 8.0, 30.0)
	var contact := _prendre_sprite()
	contact.texture = _ombre_texture
	contact.material = null
	contact.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	contact.rotation = 0.0
	contact.skew = 0.0
	contact.flip_h = false
	contact.flip_v = false
	contact.offset = Vector2.ZERO
	var w := float(_ombre_texture.get_width())
	contact.scale = Vector2(largeur / w, hauteur / w)
	contact.position = Vector2(pose["p"]) + Vector2(decalage, PIED - hauteur * 0.18)
	contact.z_index = EnferDB.SOL_OMBRE
	# Aucune ombre n'est éclairée : la lumière 2D de Godot s'applique aux
	# couleurs de l'IMAGE et non à la teinte du sprite, une ombre sous un
	# brasier se serait éclaircie au lieu d'assombrir.
	contact.light_mask = 0
	contact.self_modulate = Color(0.0, 0.0, 0.0, ombre_contact_alpha)
	contact.visible = true
	sprites.append(contact)


## LA LUMIÈRE d'une pièce qui éclaire. Posée au sol — aux pieds d'une pièce
## dressée —, ovale comme le sol vu en perspective. Une rivière en porte une par
## tronçon de 220 px, le long de son cours.
func _poser_lumieres(pose: Dictionary, info: Dictionary, lumieres: Array[PointLight2D]) -> void:
	var rayon: float = info["lueur"]
	var flamme: bool = info.get("flamme", false)
	var p: Vector2 = pose["p"]
	var points: Array[Vector2] = [p if info.has("sol") else p + Vector2(0.0, PIED)]
	if String(pose["id"]).begins_with("riviere_") and pose["id"] != &"riviere_coude":
		var t: Texture2D = _textures[pose["id"]]
		var longueur: float = t.get_height() * float(pose["e"])
		var n := maxi(1, roundi(longueur / 220.0))
		points.clear()
		for i in n:
			var le_long := (float(i) + 0.5) / float(n) * longueur - longueur * 0.5
			points.append(p + Vector2(0.0, le_long).rotated(float(pose["r"])))
	for point in points:
		var lumiere: PointLight2D
		if _lumieres_libres.is_empty():
			lumiere = PointLight2D.new()
			lumiere.texture = _lumiere_texture
			lumiere.blend_mode = Light2D.BLEND_MODE_ADD
			lumiere.range_item_cull_mask = MASQUE_DECOR
			lumiere.shadow_enabled = false
			add_child(lumiere)
		else:
			lumiere = _lumieres_libres.pop_back()
		lumiere.position = point
		lumiere.texture_scale = rayon * 2.0 / float(_lumiere_texture.get_width())
		lumiere.scale = Vector2(1.0, 0.75)
		lumiere.color = COULEUR_FEU if flamme else COULEUR_LAVE
		lumiere.energy = energie_feu if flamme else energie_lave
		lumiere.set_meta(&"flamme", flamme)
		lumiere.enabled = true
		lumiere.visible = true
		lumieres.append(lumiere)


## LES BRAISES qui s'élèvent de la lave et des grands feux : quelques points
## orange qui montent et s'éteignent. Peu nombreuses — c'est une ambiance, pas
## un effet qui se dispute l'écran avec les projectiles.
func _poser_braises(pose: Dictionary, info: Dictionary) -> CPUParticles2D:
	var braises: CPUParticles2D
	if _braises_libres.is_empty():
		braises = CPUParticles2D.new()
		braises.amount = 7
		braises.lifetime = 1.8
		braises.preprocess = 1.8
		braises.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		braises.direction = Vector2.UP
		braises.spread = 22.0
		braises.gravity = Vector2(0.0, -12.0)
		braises.initial_velocity_min = 18.0
		braises.initial_velocity_max = 42.0
		braises.scale_amount_min = 2.0
		braises.scale_amount_max = 3.0
		braises.color_ramp = _braises_couleurs
		braises.z_index = EnferDB.BRAISES
		braises.light_mask = 0
		add_child(braises)
	else:
		braises = _braises_libres.pop_back()
	var texture: Texture2D = _textures[pose["id"]]
	var taille := Vector2(texture.get_width(), texture.get_height()) * float(pose["e"])
	if absf(sin(float(pose["r"]))) > 0.5:
		taille = Vector2(taille.y, taille.x)
	var p: Vector2 = pose["p"]
	var plate: bool = info.has("sol")
	braises.position = p if plate else p + Vector2(0.0, PIED - taille.y * 0.35)
	braises.emission_rect_extents = taille * Vector2(0.35, 0.3 if plate else 0.1)
	braises.amount = clampi(roundi(taille.x * taille.y / 3000.0), 4, 12)
	braises.visible = true
	braises.emitting = true
	braises.restart()
	return braises


## Les flammes vacillent : deux sinus sans rapport simple, une phase par flamme.
## La lave, elle, reste stable — elle couve, elle ne danse pas.
func _vaciller(delta: float) -> void:
	_temps += delta
	for f: Dictionary in _flammes:
		var l: PointLight2D = f["l"]
		var ph: float = f["p"]
		l.energy = energie_feu * (1.0 + 0.12 * sin(_temps * 7.3 + ph)
			+ 0.07 * sin(_temps * 12.9 + ph * 1.7))


func _poser_corps(pose: Dictionary) -> StaticBody2D:
	var corps: StaticBody2D
	if _corps_libres.is_empty():
		corps = StaticBody2D.new()
		corps.collision_layer = Layers.WORLD
		corps.collision_mask = 0
		corps.add_child(CollisionShape2D.new())
		add_child(corps)
	else:
		corps = _corps_libres.pop_back()
	var dims: Vector2 = pose["mur"] if pose.has("mur") else EnferDB.obstacle(pose["id"])
	var forme := corps.get_child(0) as CollisionShape2D
	forme.shape = _forme(dims)
	# La capsule de Godot est verticale : couchée d'un quart de tour.
	forme.rotation = PI * 0.5 if dims.x > 0.0 else 0.0
	corps.rotation = pose["r"]
	corps.position = pose["p"]
	corps.process_mode = Node.PROCESS_MODE_INHERIT
	corps.visible = true
	return corps


func _forme(dims: Vector2) -> Shape2D:
	if _formes.has(dims):
		return _formes[dims]
	var forme: Shape2D
	if dims.x > 0.0:
		var capsule := CapsuleShape2D.new()
		capsule.radius = dims.y
		capsule.height = (dims.x + dims.y) * 2.0
		forme = capsule
	else:
		var cercle := CircleShape2D.new()
		cercle.radius = dims.y
		forme = cercle
	_formes[dims] = forme
	return forme


# --- Registre ----------------------------------------------------------------

## Reconstruit le registre des obstacles et de la lave. Il ne bouge qu'en
## franchissant une frontière de parcelle : une quinzaine de parcelles à relire,
## quelques pièces chacune.
func _indexer() -> void:
	_obstacles.clear()
	_laves.clear()
	_ponts.clear()
	_hauts.clear()
	_flammes.clear()
	for entree: Dictionary in _actives.values():
		for lumiere: PointLight2D in entree["lumieres"]:
			if lumiere.get_meta(&"flamme", false):
				_flammes.append({"l": lumiere, "p": lumiere.position.x * 0.013
					+ lumiere.position.y * 0.021})
		var sprites: Array = entree["sprites"]
		for sprite: Sprite2D in sprites:
			if sprite.z_index == 0 and sprite.texture != null \
					and sprite.texture.get_height() * sprite.scale.y >= voile_hauteur_min:
				_hauts.append(sprite)
		for pose: Dictionary in entree["poses"]:
			if pose["vieux"]:
				continue
			var id: StringName = pose["id"]
			if GenerateurCarte.bloque(pose):
				var o := GenerateurCarte.forme_obstacle(pose)
				_compteur += 1
				o["i"] = _compteur
				var boite := Rect2(o["a"], Vector2.ZERO).expand(o["b"]) \
					.grow(float(o["r"]) + PORTEE_EVITEMENT + 40.0)
				_inscrire(_obstacles, boite, o)
			var info := EnferDB.info(id)
			if info.get("lave", false) or id in GenerateurCarte.PONTS:
				var t: Texture2D = _textures[id]
				var xf := Transform2D(float(pose["r"]), Vector2(pose["e"], pose["e"]), 0.0,
					pose["p"])
				var entree_lave := {"inv": xf.affine_inverse(),
					"l": t.get_width(), "h": t.get_height(),
					"fh": pose["fh"], "fv": pose["fv"], "id": id}
				var boite := GenerateurCarte.emprise(pose)
				entree_lave["boite"] = boite
				if info.get("lave", false):
					entree_lave["masque"] = _masque_lave(id)
					_inscrire(_laves, boite, entree_lave)
				else:
					_inscrire(_ponts, boite, entree_lave)
	if _calque_formes != null:
		_calque_formes.queue_redraw()


func _inscrire(registre: Dictionary, boite: Rect2, entree: Dictionary) -> void:
	var c0 := Vector2i((boite.position / CELLULE).floor())
	var c1 := Vector2i((boite.end / CELLULE).floor())
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var cle := Vector2i(cx, cy)
			if not registre.has(cle):
				registre[cle] = []
			registre[cle].append(entree)


static func _cellule(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELLULE), floori(p.y / CELLULE))


# --- Questions posées par le reste du jeu -----------------------------------

## L'ÉVITEMENT. `vitesse` est la vitesse VOULUE par l'ennemi ; la carte la
## renvoie déviée le long des obstacles qu'il s'apprête à percuter.
##
## Chaque obstacle proche et DEVANT pousse la direction vers sa tangente, d'autant
## plus fort qu'il est proche et en face. Le côté est celui qui garde le cap ; en
## plein face-à-face, où les deux se valent, c'est l'identité de l'ennemi qui
## tranche — une moitié de la horde passe à gauche, l'autre à droite, et aucune
## n'hésite d'une image à l'autre. Les obstacles étant convexes et espacés d'au
## moins `GenerateurCarte.ECART`, suivre la tangente mène toujours au bout.
func contourner(pos: Vector2, vitesse: Vector2, rayon: float, cote: int) -> Vector2:
	var liste: Array = _obstacles.get(_cellule(pos), [])
	if liste.is_empty():
		return vitesse
	var norme := vitesse.length()
	if norme < 1.0:
		return vitesse
	var dir := vitesse / norme
	var voulu := dir
	for o: Dictionary in liste:
		var proche := _point_segment(pos, o["a"], o["b"])
		var ecart := pos - proche
		var d := ecart.length()
		var jeu := d - float(o["r"]) - rayon - 4.0
		if jeu > PORTEE_EVITEMENT:
			continue
		var n := ecart / d if d > 0.001 else Vector2.RIGHT
		var face := -n.dot(dir)
		if face <= 0.0:
			continue
		var t := n.orthogonal()
		var cap := t.dot(dir)
		var rond: bool = o["a"] == o["b"]
		if rond and absf(cap) < 0.08:
			# Un cercle : le côté du cap suffit, sauf en plein face-à-face.
			t *= 1.0 if (cote & 1) == 0 else -1.0
		elif not rond and absf(cap) < 0.25:
			# Presque en face : chacun passe du côté où il se trouve déjà par
			# rapport au CENTRE de l'obstacle. Tiré au hasard, le côté faisait se
			# croiser ceux de gauche et ceux de droite devant un chevalet, et ils
			# se bloquaient les uns les autres contre lui (mesuré : 5 à 10 imps
			# sur 12 passaient). Pile au centre, l'identité tranche.
			var cote_centre := (pos - (Vector2(o["a"]) + Vector2(o["b"])) * 0.5).dot(t)
			if absf(cote_centre) < 2.0:
				cote_centre = 1.0 if (cote & 1) == 0 else -1.0
			if cote_centre < 0.0:
				t = -t
		elif cap < 0.0:
			t = -t
		var force := clampf(1.0 - jeu / PORTEE_EVITEMENT, 0.0, 1.0) * face
		voulu = voulu.lerp(t, force)
	if voulu.length_squared() < 0.0001:
		return vitesse
	return voulu.normalized() * norme


## Ce point brûle-t-il ? C'est la question que pose la brûlure avec les PIEDS
## d'une créature. Un pont posé sur la lave protège.
func en_lave(point: Vector2) -> bool:
	var cellule := _cellule(point)
	var laves: Array = _laves.get(cellule, [])
	if laves.is_empty():
		return false
	for pont: Dictionary in _ponts.get(cellule, []):
		if _dans_image(pont, point, false):
			return false
	for lave: Dictionary in laves:
		if _dans_image(lave, point, true):
			return true
	return false


func _dans_image(entree: Dictionary, point: Vector2, masque: bool) -> bool:
	if not (entree["boite"] as Rect2).has_point(point):
		return false
	var l: int = entree["l"]
	var h: int = entree["h"]
	var local: Vector2 = (entree["inv"] as Transform2D) * point + Vector2(l, h) * 0.5
	var x := int(local.x)
	var y := int(local.y)
	if x < 0 or y < 0 or x >= l or y >= h:
		return false
	if not masque:
		return true
	if entree["fh"]:
		x = l - 1 - x
	if entree["fv"]:
		y = h - 1 - y
	var m: Dictionary = entree["masque"]
	return (m["m"] as PackedByteArray)[y * l + x] == 1


## Un corps de ce rayon tiendrait-il ici sans toucher un obstacle ni la lave ?
## Les vagues s'en servent pour ne pas faire naître un ennemi dans une statue.
func libre(point: Vector2, rayon: float) -> bool:
	for o: Dictionary in _obstacles.get(_cellule(point), []):
		var d := point.distance_to(_point_segment(point, o["a"], o["b"]))
		if d < float(o["r"]) + rayon:
			return false
	return not en_lave(point + Vector2(0.0, PIED_ENNEMI))


## Jusqu'où va un trait parti de `origine` avant de heurter un obstacle ? Le
## rayon de l'œil s'y arrête, comme les projectiles.
func portee_libre(origine: Vector2, direction: Vector2, longueur: float) -> float:
	var vus: Dictionary = {}
	var candidats: Array[Dictionary] = []
	var pas := CELLULE * 0.5
	var t := 0.0
	while t <= longueur + pas:
		for o: Dictionary in _obstacles.get(_cellule(origine + direction * minf(t, longueur)), []):
			if not vus.has(o["i"]):
				vus[o["i"]] = true
				candidats.append(o)
		t += pas
	if candidats.is_empty():
		return longueur
	var meilleur := longueur
	for o: Dictionary in candidats:
		# Marche le long du trait par pas de 6 px, puis dichotomie : un trait ne
		# croise jamais plus de deux ou trois obstacles.
		var s := 0.0
		while s < meilleur:
			var p := origine + direction * s
			if p.distance_to(_point_segment(p, o["a"], o["b"])) <= float(o["r"]):
				# Affiné par dichotomie : le trait s'arrête AU BORD de la statue,
				# pas jusqu'à 6 px en deçà.
				var avant := maxf(0.0, s - 6.0)
				for _k in 5:
					var milieu := (avant + s) * 0.5
					var q := origine + direction * milieu
					if q.distance_to(_point_segment(q, o["a"], o["b"])) <= float(o["r"]):
						s = milieu
					else:
						avant = milieu
				meilleur = s
				break
			s += 6.0
	return meilleur


static func _point_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return a
	return a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0)


# --- La brûlure --------------------------------------------------------------

func _bruler_si_besoin(delta: float) -> void:
	if _laves.is_empty():
		_tick = 0.0
		return
	_tick += delta
	if _tick < TICK_LAVE:
		return
	_tick -= TICK_LAVE
	var joueur := _le_joueur()
	if joueur != null and en_lave(joueur.global_position + Vector2(0.0, PIED)) \
			and joueur.has_method(&"brule"):
		joueur.call(&"brule", LAVE_COUPS_PAR_S * TICK_LAVE * _coup_reference())
	for noeud in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var ennemi := noeud as Node2D
		if ennemi == null or ennemi.is_queued_for_deletion() or ennemi.is_in_group(Groups.BOSSES):
			continue
		if not en_lave(ennemi.global_position + Vector2(0.0, PIED_ENNEMI)):
			continue
		var sante := ennemi.get_node_or_null(^"Health") as Health
		if sante == null or not ennemi.has_method(&"apply_damage"):
			continue
		ennemi.call(&"apply_damage", sante.max_health * LAVE_PART_PV_ENNEMI * TICK_LAVE,
			null, Vector2.ZERO)


func _le_joueur() -> Node2D:
	if not is_instance_valid(_joueur):
		_joueur = get_tree().get_first_node_in_group(Groups.PLAYER) as Node2D
	return _joueur


func _coup_reference() -> float:
	if not is_instance_valid(_vagues):
		_vagues = get_tree().get_first_node_in_group(Groups.WAVE_MANAGER)
	if _vagues != null and _vagues.has_method(&"get_hit_damage"):
		return float(_vagues.call(&"get_hit_damage"))
	return 11.0


# --- Changement d'étage ------------------------------------------------------

## ON DESCEND. Le paysage entier change d'un coup, derrière un fondu au noir : un
## changement à vue, pièce par pièce, se lirait comme un bug d'affichage.
##
## L'endroit où se tient le joueur devient une exclusion (règle 3) : le nouvel
## étage ne peut pas faire surgir une statue sur lui, ni de la lave sous ses
## pieds. Le sol change au même instant — voir `FloorTiler`, qui attend `FONDU`.
func _on_depth_changed(profond: bool) -> void:
	var cible := GenerateurCarte.PROFONDEUR if profond else GenerateurCarte.SURFACE
	if cible == _gen.etage:
		return
	var joueur := _le_joueur()
	if joueur != null:
		_gen.exclusions.append(joueur.global_position)
	var voile := CanvasLayer.new()
	voile.layer = 60
	var noir := ColorRect.new()
	noir.color = Color(0.0, 0.0, 0.0, 0.0)
	noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.add_child(noir)
	add_child(voile)
	var tween := create_tween()
	tween.tween_property(noir, ^"color:a", 1.0, FONDU)
	tween.tween_callback(func() -> void:
		_gen.etage = cible
		# Les masques de lave coûtent 75 ms en tout (mesuré), dont 13 à 26 par
		# tronçon de rivière : calculés à la première rencontre, ils faisaient
		# saccader le jeu. Ici l'écran est noir.
		if cible == GenerateurCarte.PROFONDEUR:
			for id: StringName in EnferDB.PIECES.keys():
				if EnferDB.info(id).get("lave", false):
					_masque_lave(id)
		_tout_effacer())
	tween.tween_property(noir, ^"color:a", 0.0, FONDU * 2.0)
	tween.tween_callback(voile.queue_free)


# --- Lisibilité --------------------------------------------------------------

## Efface les pièces hautes derrière lesquelles se tient le joueur (voir
## decor_scatter.gd, d'où ce voile vient : une tour de 171 px avalait un joueur
## de 84).
func _voiler(delta: float) -> void:
	var joueur := _le_joueur()
	var p: Vector2 = joueur.global_position if joueur != null else Vector2.INF
	for sprite: Sprite2D in _hauts:
		if not sprite.visible:
			continue
		var cible := 1.0
		if p != Vector2.INF:
			var demi: float = sprite.texture.get_width() * sprite.scale.x * 0.5
			var hauteur: float = sprite.texture.get_height() * sprite.scale.y
			if absf(p.x - sprite.position.x) < demi and p.y < sprite.position.y \
					and p.y > sprite.position.y - hauteur:
				cible = voile_alpha
		if not is_equal_approx(sprite.self_modulate.a, cible):
			sprite.self_modulate.a = move_toward(sprite.self_modulate.a, cible,
				voile_vitesse * delta)


# --- Panneau de développement ------------------------------------------------

func _dessiner_formes() -> void:
	if not montrer_formes:
		return
	var c := _calque_formes
	for liste: Array in _obstacles.values():
		for o: Dictionary in liste:
			var a: Vector2 = o["a"]
			var b: Vector2 = o["b"]
			var r: float = o["r"]
			c.draw_circle(a, r, Color(0.3, 0.8, 1.0, 0.35))
			c.draw_circle(b, r, Color(0.3, 0.8, 1.0, 0.35))
			if a != b:
				c.draw_line(a, b, Color(0.3, 0.8, 1.0, 0.35), r * 2.0)
	for liste: Array in _laves.values():
		for lave: Dictionary in liste:
			c.draw_rect(lave["boite"], Color(1.0, 0.3, 0.1, 0.6), false, 2.0)
