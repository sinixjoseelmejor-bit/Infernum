class_name DecorScatter
extends Node2D
## Décor de l'arène : des ZONES engendrées, semées à l'infini.
##
## LE PROBLÈME DE FOND : l'arène n'a pas de bord. Le joueur marche indéfiniment
## et les ennemis apparaissent en anneau autour de lui. Des objets posés une fois
## dans la scène formeraient un îlot qu'il quitte en quelques secondes.
##
## DEUX VERSIONS ÉCARTÉES, et c'est la raison qui compte :
##
## 1. UNE PIÈCE PAR CELLULE, tirée indépendamment. Ça marchait et ça ne voulait
##    rien dire : aucune de ces pierres n'expliquait la présence des autres, et
##    l'œil ne lisait qu'un bruit régulier. Un décor n'est pas une densité.
## 2. DES COMPOSITIONS ANCRÉES, quelques pièces dispersées autour d'un point
##    selon une forme. Mieux, mais toujours du semis : un tas de pierres reste un
##    tas de pierres, il ne dit pas d'où elles viennent.
##
## CE QUI EST EN PLACE : deux GÉNÉRATEURS, un par famille, qui construisent une
## zone au lieu de disperser des pièces.
##
##   `_zone_ruine`   — une EMPREINTE de bâtiment. On tire un rectangle en
##                     modules, on parcourt son périmètre, et on dresse une
##                     colonne à chaque emplacement sauf ceux que l'érosion a
##                     emportés. L'œil reconnaît un bâtiment à son PLAN, pas à
##                     ses pierres : c'est le rectangle interrompu qui fait la
##                     ruine. L'intérieur reçoit des gravats, parfois un autel,
##                     de la poterie, et la végétation qui reprend la place.
##   `_zone_rochers` — une PENTE. Les gros blocs en tête, les débris qui
##                     s'éparpillent en éventail vers le bas, de plus en plus
##                     petits et de plus en plus écartés. C'est ce gradient qui
##                     raconte la chute ; un nuage de pierres de taille égale ne
##                     raconte rien.
##
## CHAQUE PARCELLE PORTE UNE ZONE, mais les zones ont une TAILLE. Mesuré en jeu
## sur la version précédente, où trois parcelles sur dix seulement étaient
## servies : une vue sur quatre ne montrait rien, et une marche en ligne droite
## traversait jusqu'à 4 840 px de sol nu, soit vingt secondes sans rien croiser.
## Des parcelles tirées indépendamment s'agglutinent et laissent du vide
## ailleurs ; c'est la loi des grands nombres, pas un mauvais réglage.
##
## On remplace donc le tirage d'occupation par un tirage de TAILLE. Une petite
## zone reste une SCÈNE et non une pierre perdue : un affleurement de trois
## blocs qui se touchent, un pan de mur tombé avec ses gravats au pied. C'est ce
## qui permet d'en mettre partout sans revenir au bruit du début.
##
## CE QUI NE CHANGE PAS : tout sort d'un HACHAGE des coordonnées de la parcelle,
## jamais d'un tirage au sort. Une parcelle revue redonne la même zone, pierre
## par pierre, au pixel près, sans qu'on mémorise rien — et c'est infini par
## construction. Seules les parcelles visibles portent des sprites, recyclés
## d'une parcelle à l'autre.
##
## LE DÉCOR N'A AUCUNE COLLISION. Dans un jeu où l'on lit le sol pour esquiver,
## un obstacle qui arrête le joueur sans arrêter ce qui le frappe serait une
## trahison. Les zones annoncées et les projectiles vivent dans un autre
## conteneur, dessiné par-dessus : rien du décor ne peut les masquer.
##
## DEUX CORRECTIONS MESURÉES EN CAPTURE, à ne pas défaire :
##
## 1. LES CRÉATURES NE SE TRIENT PAS SUR LEURS PIEDS. Leurs planches sont des
##    frames de 100 × 100 où le dessin flotte au milieu : l'origine du nœud tombe
##    à mi-corps, les pieds 21 à 37,5 px plus bas selon l'entité. Un décor trié
##    sur sa base passait devant un joueur dont les pieds étaient visiblement
##    plus bas que la pierre. Voir `PIED_CREATURE`.
## 2. UNE PIÈCE HAUTE AVALE LE JOUEUR ENTIER. Une tour de gravats fait 171 px et
##    le joueur 84 : elle n'en laissait pas un pixel. Voir `_voiler`.

## Côté d'une parcelle. C'est l'échelle du PAYSAGE : CHAQUE parcelle porte une
## zone, donc c'est ce pas qui borne la distance entre deux choses à regarder.
## Un écran 1920 × 1080 en contient 2,3.
const ZONE_COTE := 950.0
## Parcelles entretenues au-delà du bord de l'écran. Une suffit : elle vaut
## 900 px, et aucune zone ne s'étend aussi loin de son ancrage.
const MARGE := 1
## Côté d'un bloc de stratification, en parcelles. Voir `_occupee`.
const BLOC := 2
## Le joueur commence toujours à l'origine du monde, et il y regarde avant de
## bouger. Une zone est donc garantie à cette distance de lui : assez loin pour
## ne pas être dans ses jambes au premier écran, assez près pour être vue sans
## marcher. Sans cette garantie, le début de partie tombait une fois sur trois
## sur du sol nu à perte de vue.
const DEPART_DISTANCE := 380.0
## Pas de la trame d'une ruine, en pixels. C'est l'entraxe des colonnes, donc
## l'unité qui donne son échelle au bâtiment. Resserré en même temps que les
## pièces de mur ont rétréci : à 115 px elles ne se touchaient plus et le mur
## cessait de se lire comme un mur.
const MODULE := 95.0
## Distance entre l'origine d'une créature et ses pieds, en pixels du monde.
## Relevé sur les planches : c'est la valeur du JOUEUR (37,5), pas la moyenne,
## parce que c'est la silhouette que l'œil suit. L'écart résiduel avec un imp
## (21) vaut 16 px, un cinquième de corps. Le décor est dessiné sa base à cette
## distance sous son nœud, de sorte que « comparer les origines », ce que fait
## le tri en Y, revienne à comparer des points de contact.
const PIED_CREATURE := 37.5

## Échelle par pièce, quand elle diffère de `echelle`.
##
## Quatre pièces du pack sont bâties sur le MÊME SOCLE DE BANC DE PIERRE : le
## banc nu (`autel`), le banc chargé de gravats, le banc surmonté d'une dalle
## levée, et celui surmonté d'une tour. Ce sont les pièces qu'on croise le plus,
## puisqu'elles montent les murs des ruines, et à pleine échelle la tour faisait
## 231 px contre 84 au joueur — près de trois fois lui. Elles passent donc à 2.
##
## DEUX, ET PAS 2,5. C'est du pixel art : à une échelle fractionnaire un pixel
## sur deux serait deux fois plus large que son voisin. La même règle vaut pour
## les icônes d'objets et pour les personnages.
const ECHELLE_PIECE := {
	"autel": 2.0,
	"gravats": 2.0,
	"pierre_levee": 2.0,
	"tour": 2.0,
}

## Pièces dont la symétrie est autorisée. Interdite sur `autel`, qui porte une
## gravure : une gravure retournée se voit.
const MIROIR := ["caillou", "roche_petite", "roche", "dalles", "rocaille",
	"gravats", "touffe", "buisson_petit", "buisson", "urne", "jarre",
	"pierre_levee", "anneau"]

## Les rôles. Une pièce n'est plus tirée dans un sac commun : elle est tirée dans
## le rôle qu'elle tient là où elle est posée.
const RUINE_MUR := ["pierre_levee", "gravats"]
const RUINE_COIN := "tour"
const RUINE_COEUR := ["autel", "anneau"]
const RUINE_SOL := ["dalles", "gravats", "roche_petite"]
const POTERIE := ["urne", "jarre"]
const VEGETATION := ["touffe", "buisson_petit", "buisson"]
const ROCHE_TETE := "rocaille"
const ROCHE_GROS := ["roche", "rocaille"]
const ROCHE_MOYEN := ["roche", "roche_petite"]
const ROCHE_PETIT := ["caillou", "dalles", "roche_petite"]

## Les deux familles et leur fréquence. L'éboulis domine : c'est du terrain, et
## du terrain il y en a partout. Une ruine raconte quelque chose, donc elle se
## fait plus rare.
const ZONE_ROCHERS := 0
const ZONE_RUINE := 1
const POIDS := [3, 2]

## Les trois tailles, et leur fréquence. Le petit domine largement : c'est lui
## qui meuble le sol sans l'encombrer, et c'est la grande, rare, qu'on aperçoit
## de loin et vers laquelle on marche.
const PETIT := 0
const MOYEN := 1
const GRAND := 2
const POIDS_TAILLE := [58, 32, 10]

@export_group("Semis")
## Part des parcelles qui portent une zone. À 1, aucune n'est vide et c'est le
## réglage voulu : la variété vient de la TAILLE des zones, pas de leur absence.
## Baisser cette valeur ramène des trous, et avec eux les longues marches sur du
## sol nu ; le plancher de 0,25 vient de la stratification de `_occupee`.
@export_range(0.25, 1.0, 0.01) var densite: float = 1.0
## Les planches sont du pixel art de 32 px, comme les personnages, qui sont
## dessinés à 3 px par pixel source. Toute autre valeur donnerait des pixels de
## tailles inégales à côté d'eux.
@export var echelle: float = 3.0
## Change tout le paysage d'un coup, sans toucher au reste.
@export var graine: int = 20260916

@export_group("Lumière")
## Le décor est posé dans la MÊME lumière que le sol, et une pierre et demie plus
## claire que lui — pas davantage. Sans cette teinte les pièces sortaient des
## planches à pleine luminosité, soit deux fois le sol : elles devenaient la
## chose la plus contrastée de l'écran, devant le joueur, ce qui inverse la
## lecture d'un jeu où l'on suit une petite silhouette sombre.
@export var teinte: Color = Color(0.88, 0.76, 0.66)
## Le second étage est une pierre froide : le décor s'y refroidit avec elle,
## sinon la pierre beige y flotte. Il y est aussi un peu plus sombre qu'en
## surface (1,3 fois le sol contre 1,5) : le carreau froid a ses propres joints
## très marqués, et le décor n'a pas à rivaliser avec eux en plus du joueur.
@export var teinte_profonde: Color = Color(0.59, 0.66, 0.75)

@export_group("Lisibilité")
## Opacité d'une pièce derrière laquelle se tient le joueur. À 0 elle disparaît
## et le décor clignote ; à 1 le joueur se perd. 0,35 laisse lire la silhouette
## et la pièce en même temps.
@export_range(0.0, 1.0, 0.05) var voile_alpha: float = 0.35
## Hauteur de source au-delà de laquelle une pièce peut cacher une créature. Le
## dessin du joueur mesure 22 px de source : au-dessus de 20, une pièce posée à
## ses pieds dépasse sa tête. Seuls le caillou et les dalles (19) restent en
## dessous, et c'est heureux — on marche dessus sans arrêt.
@export var voile_hauteur_min: int = 20
## Vitesse du fondu, en opacité par seconde. Un basculement sec se remarquerait
## plus que l'occultation qu'il corrige.
@export var voile_vitesse: float = 7.0

var _textures: Dictionary = {}          # identifiant -> Texture2D
var _actives: Dictionary = {}           # Vector2i -> Array[Sprite2D]
var _libres: Array[Sprite2D] = []
var _fenetre := Rect2i(0, 0, -1, -1)
var _joueur: Node2D

# Suite de tirages de la parcelle en cours d'engendrement. Voir `_d`.
var _px: int = 0
var _py: int = 0
var _canal: int = 0


func _ready() -> void:
	# Le tri en Y d'un parent n'englobe ses petits-enfants que si le nœud
	# intermédiaire trie aussi : sans cette ligne, tout le décor passerait en
	# bloc devant ou derrière les créatures.
	y_sort_enabled = true
	modulate = teinte
	GameEvents.arena_depth_changed.connect(_on_depth_changed)

	var manquantes: Array[String] = []
	for id: String in (RUINE_MUR + RUINE_COEUR + RUINE_SOL + POTERIE + VEGETATION
			+ ROCHE_GROS + ROCHE_MOYEN + ROCHE_PETIT + [RUINE_COIN, ROCHE_TETE]):
		if _textures.has(id):
			continue
		var chemin := "res://assets/sprites/decor/%s.png" % id
		if ResourceLoader.exists(chemin):
			_textures[id] = load(chemin)
		else:
			manquantes.append(id)
	# Dépôt fraîchement cloné : les planches ne sont pas encore extraites (voir
	# tools/extract_assets.py). Le décor s'efface alors sans un mot plutôt que de
	# s'engendrer à trous ; le jeu n'en dépend pas.
	if not manquantes.is_empty():
		set_process(false)


func _on_depth_changed(deep: bool) -> void:
	modulate = teinte_profonde if deep else teinte


func _process(delta: float) -> void:
	# Le voile se joue à chaque image : c'est un fondu.
	_voiler(delta)
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var centre := camera.get_screen_center_position()
	var vue: Vector2 = get_viewport_rect().size / camera.zoom
	var fenetre := Rect2i(
		int(floor((centre.x - vue.x * 0.5) / ZONE_COTE)) - MARGE,
		int(floor((centre.y - vue.y * 0.5) / ZONE_COTE)) - MARGE,
		int(ceil(vue.x / ZONE_COTE)) + MARGE * 2 + 1,
		int(ceil(vue.y / ZONE_COTE)) + MARGE * 2 + 1)
	# Le semis ne se recalcule qu'en franchissant une frontière de parcelle.
	if fenetre == _fenetre:
		return
	_fenetre = fenetre
	_ramasser(fenetre)
	_semer(fenetre)


# --- Semis -------------------------------------------------------------------

## Rend au vivier les sprites des parcelles sorties du champ.
func _ramasser(fenetre: Rect2i) -> void:
	for parcelle: Vector2i in _actives.keys():
		if fenetre.has_point(parcelle):
			continue
		for sprite: Sprite2D in _actives[parcelle]:
			sprite.visible = false
			_libres.append(sprite)
		_actives.erase(parcelle)


func _semer(fenetre: Rect2i) -> void:
	for py in range(fenetre.position.y, fenetre.end.y):
		for px in range(fenetre.position.x, fenetre.end.x):
			var parcelle := Vector2i(px, py)
			if _actives.has(parcelle):
				continue
			if not _occupee(px, py):
				continue
			_engendrer(parcelle)


## Cette parcelle porte-t-elle une zone ?
##
## Un tirage indépendant par parcelle laisse des TROUS, et ce sont eux qu'on
## voyait en jeu : une vue sur sept ne montrait rien, et il arrivait de marcher
## très longtemps sans rien croiser. C'est la loi des grands nombres qui veut
## ça — des points indépendants s'agglutinent et laissent du vide ailleurs.
##
## On STRATIFIE donc : dans chaque bloc de 2 × 2 parcelles, une parcelle
## DÉSIGNÉE porte toujours une zone, et les trois autres gardent leur tirage.
## Le vide est ainsi borné par la taille d'un bloc, 1800 px, au lieu d'être sans
## limite. La désignée est choisie par hachage du bloc, donc elle change d'un
## bloc à l'autre : la garantie ne dessine pas de trame régulière.
##
## `densite` reste le taux d'occupation TOTAL visé ; la part tirée s'en déduit,
## la garantie fournissant déjà un quart des parcelles. En dessous de 0,25 la
## consigne est donc inatteignable, et c'est voulu.
func _occupee(px: int, py: int) -> bool:
	# La parcelle du point de départ, toujours : voir DEPART_DISTANCE.
	if px == 0 and py == 0:
		return true
	# Décalages arithmétiques, et non une division : ils donnent le bon bloc
	# pour les coordonnées négatives, ce qu'une division tronquée ne fait pas.
	var rang := (px & 1) + (py & 1) * BLOC
	if rang == int(_h(px >> 1, py >> 1, 900) * float(BLOC * BLOC)):
		return true
	var part := maxf(0.0, (densite - 0.25) / 0.75)
	return _h(px, py, 0) <= part


func _engendrer(parcelle: Vector2i) -> void:
	# Ouverture de la suite de tirages de cette parcelle. Tout ce qui suit lit
	# dans cette suite, dans l'ordre : c'est ce qui rend la zone reproductible
	# sans qu'on ait à numéroter un canal par pièce.
	_px = parcelle.x
	_py = parcelle.y
	_canal = 0

	# Ancrage au centre de la parcelle, à 280 px près. Il faut ce jeu-là : chaque
	# parcelle étant servie, un ancrage serré alignerait les zones sur une trame
	# de 950 px et la régularité se verrait. Deux voisines peuvent déborder l'une
	# sur l'autre, ce qui est sans gravité : une ruine au pied d'un éboulis reste
	# une scène, là où deux pierres isolées ne l'étaient pas.
	var ancre := Vector2(
		(float(_px) + 0.5) * ZONE_COTE + (_d() - 0.5) * 560.0,
		(float(_py) + 0.5) * ZONE_COTE + (_d() - 0.5) * 560.0)
	# Au départ, la zone se pose à distance fixe du joueur plutôt qu'au hasard
	# dans la parcelle : c'est le seul endroit du monde dont on sait d'avance
	# qu'il sera regardé.
	if _px == 0 and _py == 0:
		ancre = Vector2.RIGHT.rotated(_d() * TAU) * DEPART_DISTANCE

	var famille := _tirer_pondere(POIDS)
	var taille := _tirer_pondere(POIDS_TAILLE)
	var sprites: Array[Sprite2D] = []
	if famille == ZONE_RUINE:
		_zone_ruine(ancre, sprites, taille)
	else:
		_zone_rochers(ancre, sprites, taille)
	_actives[parcelle] = sprites


func _tirer_pondere(poids: Array) -> int:
	var total := 0
	for p: int in poids:
		total += p
	var seuil := _d() * float(total)
	var acc := 0.0
	for i in poids.size():
		acc += float(poids[i])
		if seuil < acc:
			return i
	return poids.size() - 1


# --- Générateur : la ruine ---------------------------------------------------

## UNE EMPREINTE DE BÂTIMENT, aux murs tombés par endroits.
##
## Le plan est un rectangle de `mods_x` par `mods_y` modules. On visite tous les
## nœuds de sa trame, on ne garde que ceux du BORD, et l'érosion en emporte une
## part. Ce qui reste dessine un rectangle interrompu, et c'est ce rectangle que
## l'œil lit comme une ruine. Les quatre coins reçoivent souvent la tour, la
## pièce la plus haute : un angle debout tient le plan mieux qu'un pan de mur.
##
## En PETIT, il n'y a pas de plan : juste un pan de mur tombé, une ou deux
## pierres debout et leurs gravats au pied. C'est assez pour faire une scène, et
## ça ne prétend pas au bâtiment.
func _zone_ruine(ancre: Vector2, sprites: Array[Sprite2D], taille: int) -> void:
	var axe := _d() * TAU
	if taille == PETIT:
		for i in _d_entre(1, 2):
			var debout := _d_dans(RUINE_MUR)
			sprites.append(_poser(debout,
				ancre + Vector2.RIGHT.rotated(axe) * (float(i) * MODULE * 0.85)))
		_remplir(ancre, axe, Vector2(70.0, 60.0), RUINE_SOL, _d_entre(1, 2), sprites)
		return

	var mods_x := _d_entre(2, 2) if taille == MOYEN else _d_entre(3, 4)
	var mods_y := _d_entre(2, 2) if taille == MOYEN else _d_entre(2, 3)
	var erosion := lerpf(0.30, 0.62, _d())
	var demi := Vector2(float(mods_x), float(mods_y)) * MODULE * 0.5

	for iy in mods_y + 1:
		for ix in mods_x + 1:
			if not (ix == 0 or iy == 0 or ix == mods_x or iy == mods_y):
				continue
			# Trois tirages par emplacement, toujours, quelle que soit la
			# branche prise : la suite reste alignée d'une pièce à l'autre.
			var tombe := _d()
			var d_coin := _d()
			var mur := _d_dans(RUINE_MUR)
			if tombe < erosion:
				continue
			var coin := (ix == 0 or ix == mods_x) and (iy == 0 or iy == mods_y)
			var id: String = RUINE_COIN if coin and d_coin < 0.45 else mur
			var local := Vector2(float(ix), float(iy)) * MODULE - demi
			# Un mur écroulé n'est pas au cordeau.
			local += Vector2(_d() - 0.5, _d() - 0.5) * 26.0
			sprites.append(_poser(id, ancre + local.rotated(axe)))

	_remplir(ancre, axe, demi * 1.7, RUINE_SOL, _d_entre(1, 2), sprites)
	if taille < GRAND:
		return

	# La grande ruine seule a un cœur, de la poterie et la végétation qui
	# reprend la place : c'est ce qui en fait un endroit et non un tas.
	var coeur := _d()
	var id_coeur := _d_dans(RUINE_COEUR)
	if coeur < 0.55:
		sprites.append(_poser(id_coeur, ancre))
	_remplir(ancre, axe, demi * 1.5, POTERIE, _d_entre(1, 2), sprites)
	_remplir(ancre, axe, demi * 2.1, VEGETATION, _d_entre(0, 2), sprites)


## Sème `nombre` pièces d'un rôle dans un rectangle centré sur l'ancre.
func _remplir(ancre: Vector2, axe: float, demi: Vector2, role: Array,
		nombre: int, sprites: Array[Sprite2D]) -> void:
	for _i in nombre:
		var id := _d_dans(role)
		var p := Vector2((_d() - 0.5) * demi.x * 2.0, (_d() - 0.5) * demi.y * 2.0)
		sprites.append(_poser(id, ancre + p.rotated(axe)))


# --- Générateur : l'éboulis --------------------------------------------------

## UNE PENTE. En tête, un ou deux blocs. Puis les débris, dont la TAILLE
## DÉCROÎT et l'ÉCART CROÎT à mesure qu'on descend : un éventail. C'est ce
## double gradient qui donne une direction à la chute, donc un sens à la scène.
##
## En PETIT, il n'y a pas de pente : un affleurement, un bloc et deux éclats à
## son pied. Trois pierres qui se touchent font une chose ; trois pierres
## espacées font du bruit, et c'est tout le sujet.
func _zone_rochers(ancre: Vector2, sprites: Array[Sprite2D], taille: int) -> void:
	var pente := _d() * TAU
	if taille == PETIT:
		sprites.append(_poser(ROCHE_TETE, ancre))
		for _i in _d_entre(1, 2):
			var id := _d_dans(ROCHE_PETIT)
			var p := Vector2.RIGHT.rotated(_d() * TAU) * lerpf(75.0, 140.0, _d())
			sprites.append(_poser(id, ancre + p))
		return

	var longueur: float = lerpf(220.0, 320.0, _d()) if taille == MOYEN \
		else lerpf(300.0, 430.0, _d())
	var tetes: int = 1 if taille == MOYEN else _d_entre(1, 2)
	for _i in tetes:
		var t := Vector2((_d() - 0.5) * 90.0, (_d() - 0.5) * 70.0)
		sprites.append(_poser(ROCHE_TETE, ancre + t))

	var nombre: int = _d_entre(4, 6) if taille == MOYEN else _d_entre(7, 10)
	for i in nombre:
		# Progression le long de la pente, irrégulière mais monotone.
		var t := (float(i) + _d()) / float(nombre)
		var gros := _d_dans(ROCHE_GROS)
		var moyen := _d_dans(ROCHE_MOYEN)
		var petit := _d_dans(ROCHE_PETIT)
		var id: String = gros if t < 0.35 else (moyen if t < 0.7 else petit)
		var travers := (_d() - 0.5) * 2.0 * (45.0 + t * 120.0)
		var p := Vector2.RIGHT.rotated(pente) * (t * longueur) \
			+ Vector2.DOWN.rotated(pente) * travers
		sprites.append(_poser(id, ancre + p))

	# Quelques touffes sur les flancs : rien ne pousse au milieu des blocs.
	if taille == GRAND:
		for _i in _d_entre(0, 2):
			var id := _d_dans(VEGETATION)
			var le_long := _d() * longueur
			var cote: float = (1.0 if _d() < 0.5 else -1.0) * lerpf(140.0, 220.0, _d())
			var p := Vector2.RIGHT.rotated(pente) * le_long \
				+ Vector2.DOWN.rotated(pente) * cote
			sprites.append(_poser(id, ancre + p))


# --- Pose --------------------------------------------------------------------

func _poser(id: String, ou: Vector2) -> Sprite2D:
	var texture: Texture2D = _textures[id]
	var sprite: Sprite2D
	if _libres.is_empty():
		sprite = Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	else:
		sprite = _libres.pop_back()
	var ech: float = ECHELLE_PIECE.get(id, echelle)
	sprite.texture = texture
	sprite.scale = Vector2(ech, ech)
	# Un sprite recyclé peut sortir du vivier à demi effacé.
	sprite.self_modulate.a = 1.0
	# `offset` est en espace texture, donc avant l'échelle : d'où la division.
	# Elle se fait par l'échelle DE LA PIÈCE, sinon une pièce rétrécie ne
	# poserait plus ses pieds au même endroit que les autres et se trierait mal.
	sprite.offset = Vector2(0.0, -texture.get_height() * 0.5 + PIED_CREATURE / ech)
	sprite.flip_h = MIROIR.has(id) and _d() < 0.5
	sprite.position = ou
	sprite.visible = true
	return sprite


# --- Lisibilité --------------------------------------------------------------

## Efface les pièces hautes derrière lesquelles se tient le joueur.
##
## Le décalage `PIED_CREATURE` s'applique des deux côtés et s'annule donc : il
## suffit de comparer les origines, comme le fait le tri en Y. Le joueur est
## « derrière » quand son origine est au-dessus de celle de la pièce et à moins
## d'une hauteur de pièce — devant, il est dessiné par-dessus et tout va bien,
## c'est le cas qu'on ne touche pas.
func _voiler(delta: float) -> void:
	if not is_instance_valid(_joueur):
		_joueur = get_tree().get_first_node_in_group(&"player") as Node2D
	var p: Vector2 = _joueur.global_position if is_instance_valid(_joueur) else Vector2.INF
	for sprites: Array in _actives.values():
		for sprite: Sprite2D in sprites:
			var cible := 1.0
			if sprite.texture.get_height() >= voile_hauteur_min and p != Vector2.INF:
				var demi: float = sprite.texture.get_width() * sprite.scale.x * 0.5
				var hauteur: float = sprite.texture.get_height() * sprite.scale.y
				var colonne := absf(p.x - sprite.position.x) < demi
				var bande := (p.y < sprite.position.y
						and p.y > sprite.position.y - hauteur)
				if colonne and bande:
					cible = voile_alpha
			if not is_equal_approx(sprite.self_modulate.a, cible):
				sprite.self_modulate.a = move_toward(sprite.self_modulate.a, cible,
					voile_vitesse * delta)


# --- Tirages -----------------------------------------------------------------

## Tire le nombre suivant de la suite de la parcelle en cours.
##
## L'ORDRE DES APPELS FAIT PARTIE DE LA DÉFINITION DU PAYSAGE : réordonner les
## tirages, ou en sauter un dans une branche, change toute la carte. C'est sans
## conséquence pour le jeu, mais ça veut dire que les générateurs tirent toujours
## le même nombre de fois par pièce, quelle que soit la branche prise.
func _d() -> float:
	_canal += 1
	return _h(_px, _py, _canal)


func _d_entre(a: int, b: int) -> int:
	return mini(a + int(_d() * float(b - a + 1)), b)


func _d_dans(role: Array) -> String:
	return role[mini(int(_d() * float(role.size())), role.size() - 1)]


## Hachage entier des coordonnées de parcelle -> [0, 1[. Déterministe, sans
## état, et décorrélé d'un canal à l'autre : c'est ce qui permet de tirer une
## zone entière, pièce par pièce, à partir des mêmes deux coordonnées.
func _h(px: int, py: int, canal: int) -> float:
	var n := (px * 73856093) ^ (py * 19349663) ^ (canal * 83492791) ^ (graine * 2654435761)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / 16777216.0
