class_name GenerateurCarte
extends RefCounted
## Le générateur de la carte : ce qu'il y a dans une parcelle, et rien d'autre.
##
## IL NE CRÉE AUCUN NŒUD. `engendrer` rend une liste de poses (pièce, position,
## échelle, rotation, miroir) : c'est `Carte` qui en fait des sprites, des
## obstacles et de la lave. Cette séparation n'est pas de la coquetterie — elle
## permet de vérifier les règles de jouabilité sur des milliers de parcelles sans
## lancer le jeu (`tools/test_carte.gd`).
##
## CE QUI NE CHANGE PAS DEPUIS LE DÉCOR D'ORIGINE (README, « Le décor de
## l'arène ») :
##   - le monde est découpé en parcelles de 950 px et CHACUNE porte un lieu ; ce
##     qui varie est leur TAILLE, petite six fois sur dix ;
##   - un lieu ENGENDRE une scène, il ne sème pas des pièces ;
##   - tout sort d'un HACHAGE des coordonnées de la parcelle : une parcelle revue
##     redonne le même lieu, pierre par pierre, sans rien mémoriser ;
##   - la parcelle de départ porte toujours un lieu, à 380 px du joueur.
##
## CE QUI CHANGE :
##   - la graine est TIRÉE À CHAQUE RUN : chaque partie a sa carte ;
##   - deux ÉTAGES, deux familles de lieux. En surface la pierre froide, les
##     forêts mortes, les cheminées éteintes, les buttes ; à la vague 11, on
##     descend dans la lave, les fosses et le sol qui se fend (pack 2DML SET 3,
##     depuis la 0.9.2) ;
##   - certaines pièces BLOQUENT et d'autres BRÛLENT, et ça impose des règles.
##
## LES RÈGLES DE JOUABILITÉ, garanties par construction et vérifiées par le test :
##   1. Entre deux obstacles, soit ils se touchent, soit il reste `ECART` px
##      libres — cinq imps de front. Jamais de goulet où la horde s'aligne pour
##      se faire faucher, jamais de poche.
##   2. Obstacles et lave restent à `BORD` px à l'intérieur de LEUR parcelle.
##      C'est ce qui garantit la règle 1 entre deux parcelles voisines, qui
##      s'engendrent sans se connaître : 2 × 80 = 160.
##   3. Rien de ce qui bloque ou brûle à moins de `EXCLUSION` px du point de
##      départ, ni de l'endroit où l'on se trouve quand on change d'étage.
##   4. La lave laisse `ECART_LAVE` px aux obstacles, ou les touche : pas de
##      couloir étroit entre un rocher et une fosse.
##   5. Une nappe de lave est FINIE : elle tient dans sa parcelle, d'une seule
##      pièce. Elle ne peut donc jamais enfermer personne.
##
## LES RÈGLES DE COMPOSITION, qui font qu'un lieu a un sens :
##   6. RIEN NE SE CHEVAUCHE. Chaque pièce dressée a une emprise au sol — son
##      PIED, mesuré dans son image — et deux pieds ne se recouvrent pas. Deux
##      pièces plates (fissure, nappe, plateau) non plus, et rien ne se dresse
##      sur le dessus d'un plateau.
##   7. RIEN NE TOMBE DANS LA LAVE : ni pièce dressée, ni fissure.
##   8. RIEN NE DÉBORDE DE SA PARCELLE : deux lieux voisins ne se mêlent pas.
##   9. CHAQUE PIÈCE A UN RÔLE ET UNE PLACE. L'herbe pousse au pied des arbres,
##      les fumerolles s'ouvrent au pied des cheminées, les cailloux gisent sur
##      la rive des bassins et au pied de la falaise d'un plateau, un monolithe
##      se dresse au milieu de la terre qu'il a fendue. Une pièce qui gêne
##      cherche une place à côté (`_placer`) avant de renoncer.
##
## Une pose qui enfreindrait une règle n'est pas posée : la pièce « est tombée ».
## Un lieu se lit encore avec un caillou en moins ; sans sa pièce maîtresse (la
## grappe de cheminées, le monolithe, le plateau), il ne se lirait plus, donc le
## lieu s'arrête là.

const ZONE_COTE := 950.0
const ECART := 160.0
const ECART_LAVE := 110.0
const BORD := 80.0
const EXCLUSION := 320.0
const DEPART_DISTANCE := 380.0
## Marge entre les pièces d'un lieu et le bord de sa parcelle (règle 8).
const MARGE_PARCELLE := 16.0

const SURFACE := 0
const PROFONDEUR := 1

const PETIT := 0
const MOYEN := 1
const GRAND := 2
const POIDS_TAILLE := [58, 32, 10]

## Distance entre l'origine d'une créature et ses pieds (README). Le décor est
## dessiné sa base à cette distance sous son nœud, pour que le tri en Y compare
## des points de contact.
const PIED := 37.5

# --- Les rôles des pièces ----------------------------------------------------
#
# Un rôle ne mélange jamais les étages : la surface est l'enfer FROID, rien n'y
# couve ni n'y rougeoie. Fissures ardentes, lave et bulles sont réservées à la
# profondeur ; les arbres y sont mauves, les buissons rouges.

const CHEMINEES := [&"cheminee_a", &"cheminee_b", &"cheminee_c", &"cheminee_haute",
	&"cheminees_duo"]
const GRAPPES := [&"cheminees_trio", &"cheminees_grappe", &"cheminees_paire"]
const ROCS := [&"aiguille", &"bloc_troue", &"menhir", &"rocher_creuse", &"rocher_penche"]
const MONOLITHES := [&"falaise", &"dome", &"colosse"]
const ARBRES := [&"arbre_a", &"arbre_b", &"arbre_c"]
const ARBRES_MAUVES := [&"arbre_mauve_a", &"arbre_mauve_b", &"arbre_mauve_c"]
const CAILLOUX := [&"caillou_a", &"caillou_b", &"caillou_c", &"galet"]
const GRAVIERS := [&"gravier_a", &"gravier_b"]
## Les têtes d'éboulis : des blocs BAS, qui se traversent.
const TETES_EBOULIS := [&"galet", &"cheminee_petite"]
const TROUS := [&"trou_a", &"trou_b", &"trou_c", &"trou_d"]
const FUMEROLLES := [&"fumerolle_a", &"fumerolle_b", &"fumerolle_c", &"fumerolle_d"]
const HERBES := [&"herbe_a", &"herbe_b", &"herbe_c"]
const HERBES_SECHES := [&"herbe_seche_a", &"herbe_seche_b", &"herbe_seche_c"]
const BUISSONS_FROIDS := [&"buisson_olive_a", &"buisson_olive_b", &"buisson_olive_c",
	&"buisson_sombre_a", &"buisson_sombre_b", &"buisson_sombre_c"]
const BUISSONS_ROUGES := [&"buisson_rouge_a", &"buisson_rouge_b", &"buisson_rouge_c"]
const FISSURES := [&"fissure_longue", &"sol_fendu"]
const BASSINS := [&"bassin_6x6", &"bassin_7x6"]
const LACS := [&"lac_8x7", &"lac_10x8"]
const FOSSES := [&"fosse_12x6", &"fosse_6x12"]
const BULLES := [&"bulle_a", &"bulle_b"]
const PLATEAUX := [&"plateau_6x6", &"plateau_7x6", &"plateau_b_6x6"]

## Les lieux de chaque étage, et leur poids. L'éboulis du décor d'origine garde
## sa place en surface : c'est du terrain. En profondeur, c'est la lave qui
## domine.
enum Lieu { EBOULIS, FORET, CHEMINEES, ROCHERS, BUTTE, BROUSSAILLES,
	CHAMP_LAVE, LAC, FOSSE }
const LIEUX := {
	SURFACE: {Lieu.EBOULIS: 24, Lieu.FORET: 20, Lieu.CHEMINEES: 18, Lieu.ROCHERS: 16,
		Lieu.BUTTE: 10, Lieu.BROUSSAILLES: 12},
	PROFONDEUR: {Lieu.CHAMP_LAVE: 24, Lieu.LAC: 12, Lieu.FOSSE: 14, Lieu.CHEMINEES: 16,
		Lieu.FORET: 12, Lieu.ROCHERS: 14, Lieu.BUTTE: 8},
}
## Les lieux de pur décor, qui ne bloquent presque pas : ils gardent plus de
## jeu dans leur parcelle (voir `engendrer`).
const LIEUX_LEGERS := [Lieu.EBOULIS, Lieu.BROUSSAILLES]

## Tolérance de chevauchement des pieds (règle 6), en part de la somme des
## rayons : 1 interdit tout contact, moins laisse des pièces SE TOUCHER. Une
## touffe d'herbe au pied d'un arbre le touche ; deux arbres, non.
const TOLERANCE := 1.0
const TOLERANCE_GRAPPE := 0.72

## Compteurs de `_placer`, lus par le test : combien de pièces ont dû chercher
## une place à côté, combien sont tombées.
static var poses_tentees := 0
static var poses_deplacees := 0
static var poses_tombees := 0

var graine: int = 20260916
var etage: int = SURFACE
## Points autour desquels rien ne bloque ni ne brûle (règle 3). L'origine y est
## toujours ; la carte y ajoute l'endroit du changement d'étage.
var exclusions: Array[Vector2] = [Vector2.ZERO]

# État de la parcelle en cours d'engendrement.
var _px: int = 0
var _py: int = 0
var _canal: int = 0
var _poses: Array[Dictionary] = []
var _obstacles: Array[Dictionary] = []   # {"a", "b", "r"}
var _laves: Array[Rect2] = []
var _pieds: Array[Dictionary] = []       # {"c", "rx", "ry"}
var _marques: Array[Rect2] = []
var _reliefs: Array[Rect2] = []
var _interieur := Rect2()
var _zone := Rect2()


## Le lieu d'une parcelle, en poses. Chaque pose : "id", "p" (position du
## nœud), "e" (échelle), "r" (rotation), "fh"/"fv" (miroirs), "vieux" (pièce
## du décor d'origine).
func engendrer(parcelle: Vector2i) -> Array[Dictionary]:
	_px = parcelle.x
	_py = parcelle.y
	_canal = 0
	_poses = []
	_obstacles = []
	_laves = []
	_pieds = []
	_marques = []
	_reliefs = []
	var coin := Vector2(parcelle) * ZONE_COTE
	var carre := Rect2(coin, Vector2(ZONE_COTE, ZONE_COTE))
	_interieur = carre.grow(-BORD)
	_zone = carre.grow(-MARGE_PARCELLE)

	var lieu: int = _tirer_lieu()
	var taille: int = _tirer_pondere(POIDS_TAILLE)
	# Un lieu qui bloque ou qui brûle reste près du centre de sa parcelle : il
	# doit tenir dans l'intérieur (règle 2). Le décor pur garde plus de jeu,
	# assez pour que la trame de 950 px ne se voie pas — mais il ne déborde plus
	# de sa parcelle (règle 8), ses pièces sont ramenées dedans. Les grandes
	# nappes de lave n'ont presque pas de jeu : une fosse fait 700 px de long
	# pour 790 d'intérieur.
	var jeu := 420.0 if lieu in LIEUX_LEGERS else 300.0
	if lieu in [Lieu.LAC, Lieu.FOSSE]:
		jeu = 60.0
	var ancre := coin + Vector2(ZONE_COTE, ZONE_COTE) * 0.5 \
		+ Vector2(_d() - 0.5, _d() - 0.5) * jeu
	if _px == 0 and _py == 0:
		ancre = Vector2.RIGHT.rotated(_d() * TAU) * DEPART_DISTANCE

	match lieu:
		Lieu.EBOULIS: _eboulis(ancre, taille)
		Lieu.FORET: _foret(ancre, taille)
		Lieu.CHEMINEES: _cheminees(ancre, taille)
		Lieu.ROCHERS: _rochers(ancre, taille)
		Lieu.BUTTE: _butte(ancre, taille)
		Lieu.BROUSSAILLES: _broussailles(ancre, taille)
		Lieu.CHAMP_LAVE: _champ_lave(ancre, taille)
		Lieu.LAC: _lac(ancre, taille)
		Lieu.FOSSE: _fosse(ancre, taille)
	return _poses


## Le lieu tiré pour une parcelle, sans l'engendrer (panneau dev, tests).
func lieu_de(parcelle: Vector2i) -> int:
	_px = parcelle.x
	_py = parcelle.y
	_canal = 0
	return _tirer_lieu()


func _tirer_lieu() -> int:
	var table: Dictionary = LIEUX[etage]
	var poids: Array = table.values()
	return table.keys()[_tirer_pondere(poids)]


# --- Les lieux des deux étages -----------------------------------------------

## LA FORÊT MORTE : des arbres espacés — assez pour qu'on passe entre eux, c'est
## l'écart des obstacles —, de l'herbe sèche et des buissons À LEURS PIEDS. En
## profondeur, les arbres sont mauves, les buissons rouges, et le sol se fend.
func _foret(a: Vector2, taille: int) -> void:
	var froid := etage == SURFACE
	var arbres := ARBRES if froid else ARBRES_MAUVES
	var touffes: Array = (HERBES + BUISSONS_FROIDS) if froid else (HERBES_SECHES + BUISSONS_ROUGES)
	var premier := _placer(_dans(arbres), a, 40.0)
	if premier.is_empty():
		return
	_au_pied(premier, touffes, _entre(1, 2))
	var n: int = [0, _entre(2, 3), _entre(4, 5)][taille]
	var phase := _d() * TAU
	for i in n:
		var ang := phase + TAU * (float(i) + _d() * 0.5) / float(maxi(n, 1))
		var p := a + Vector2(cos(ang), sin(ang) * 0.75) * lerpf(200.0, 290.0, _d())
		var arbre := _placer(_dans(arbres), p, 50.0)
		_au_pied(arbre, touffes, _entre(0, 2))
	if not froid:
		_semer(a, Vector2(260.0, 190.0), FISSURES, _entre(1, 2))
	if taille == GRAND:
		_semer(a, Vector2(300.0, 220.0), touffes, _entre(1, 3), true)


## LES CHEMINÉES : une grappe de cheminées volcaniques au centre, d'autres
## isolées autour, des fumerolles et du gravier À LEURS PIEDS. Le petit n'est
## qu'une cheminée et son trou. En profondeur, le sol se fend entre elles.
func _cheminees(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		var seule := _placer(_dans(CHEMINEES), a, 40.0)
		_au_pied(seule, TROUS + FUMEROLLES, 1)
		return
	var grappe := _placer(_dans(GRAPPES), a, 40.0)
	if grappe.is_empty():
		return
	_au_pied(grappe, FUMEROLLES, 1)
	_au_pied(grappe, GRAVIERS + [&"cheminee_petite"], 1)
	var n: int = 1 if taille == MOYEN else _entre(2, 3)
	var phase := _d() * TAU
	for i in n:
		var ang := phase + TAU * float(i) / float(n)
		var p := a + Vector2(cos(ang), sin(ang) * 0.75) * lerpf(230.0, 300.0, _d())
		var autre := _placer(_dans(CHEMINEES), p, 50.0)
		_au_pied(autre, TROUS + FUMEROLLES, _entre(0, 1))
	if etage == PROFONDEUR:
		_semer(a, Vector2(280.0, 200.0), FISSURES, _entre(1, 2))


## LES ROCHERS : en grand, un monolithe qui se voit de loin, deux rocs à ses
## côtés et des cailloux à son pied ; en profondeur, la terre CRAQUELÉE tout
## autour de lui. Sinon quelques rocs dressés et leurs cailloux.
func _rochers(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		var roc := _placer(_dans(ROCS), a, 40.0)
		_au_pied(roc, CAILLOUX, _entre(1, 2))
		return
	if taille == GRAND:
		if etage == PROFONDEUR:
			# Le cadre de fissures d'abord : le monolithe se dresse AU MILIEU.
			_placer(&"fissure_cadre", a + Vector2(0.0, PIED), 0.0)
		var monolithe := _placer(_dans(MONOLITHES), a, 30.0)
		if monolithe.is_empty():
			return
		_au_pied(monolithe, CAILLOUX + GRAVIERS, _entre(2, 3))
		_a_cote(monolithe, _dans(ROCS), -1.0)
		_a_cote(monolithe, _dans(ROCS), 1.0)
		return
	var premier := _placer(_dans(ROCS), a, 40.0)
	_au_pied(premier, CAILLOUX, _entre(1, 2))
	var second := _placer(_dans(ROCS), a + Vector2.RIGHT.rotated(_d() * TAU) * 240.0, 60.0)
	_au_pied(second, CAILLOUX + GRAVIERS, 1)
	if etage == PROFONDEUR:
		_semer(a, Vector2(240.0, 170.0), FISSURES, 1)


## LA BUTTE : un plateau de roche, le plus gros obstacle du jeu, avec ses
## éboulis AU PIED de sa falaise. La petite n'est qu'un rocher penché.
func _butte(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		var roc := _placer(&"rocher_penche", a, 40.0)
		_au_pied(roc, CAILLOUX, _entre(1, 2))
		return
	var plateau := _placer(_dans(PLATEAUX), a, 60.0, 1.0, 0.0, false)
	if plateau.is_empty():
		return
	_au_pied_rect(emprise(plateau), CAILLOUX + GRAVIERS, _entre(2, 3))
	if taille == GRAND:
		var cote := _signe()
		var bord := emprise(plateau)
		var p := Vector2(bord.get_center().x + cote * (bord.size.x * 0.5 + 200.0), bord.end.y - 60.0)
		var roc := _placer(_dans(ROCS), p - Vector2(0.0, PIED), 50.0)
		_au_pied(roc, CAILLOUX, 1)


## LES BROUSSAILLES : des buissons serrés et de l'herbe, rien qui bloque. Un
## repère qui se traverse.
func _broussailles(a: Vector2, taille: int) -> void:
	var n: int = [3, 5, 8][taille]
	var etendue: float = [110.0, 170.0, 250.0][taille]
	for _i in n:
		var p := a + Vector2(_d() - 0.5, (_d() - 0.5) * 0.7) * etendue * 2.0
		_placer(_dans(BUISSONS_FROIDS), p, 30.0, 1.0, 0.0, false, true)
	_semer(a, Vector2(etendue * 1.3, etendue), HERBES, _entre(1, 3), true)
	if taille == GRAND:
		_semer(a, Vector2(etendue * 1.2, etendue), CAILLOUX, _entre(1, 2), true)


# --- Profondeur : la lave ----------------------------------------------------
#
# LES NAPPES NE TOURNENT JAMAIS : la falaise est dessinée sur leur bord haut,
# un quart de tour la mettrait sur le côté (voir `tools/extract_enfer.py`).

## LE CHAMP DE LAVE : un ou deux bassins qui ne se touchent pas, leurs bulles,
## des cailloux SUR LA RIVE et des fumerolles autour. En grand, une cheminée à
## l'écart des bassins.
func _champ_lave(a: Vector2, taille: int) -> void:
	var bassins: Array[Dictionary] = []
	for i in [1, 1, 2][taille]:
		# Le second bassin s'écarte du premier : deux nappes soudées se liraient
		# comme une seule tache mal découpée.
		var p := a
		if i > 0:
			p += Vector2.RIGHT.rotated(_d() * TAU) * lerpf(400.0, 440.0, _d())
		var bassin := _placer(_dans(BASSINS), p, 50.0, 1.0, 0.0, false)
		if bassin.is_empty():
			continue
		bassins.append(bassin)
	for bassin: Dictionary in bassins:
		_bulles(bassin, _entre(1, 2))
		_sur_la_rive(bassin, CAILLOUX, _entre(1, 2))
	_semer(a, Vector2(300.0, 230.0), FUMEROLLES, _entre(1, 2), true)
	if taille >= MOYEN:
		_semer(a, Vector2(300.0, 230.0), FISSURES, _entre(1, 2))
	if taille == GRAND:
		var cheminee := _placer(_dans(CHEMINEES), a + Vector2(_signe() * 300.0, -220.0), 80.0)
		_au_pied(cheminee, FUMEROLLES, 1)


## LE LAC : une grande nappe, bulles et cailloux de rive. Le petit et le moyen
## ne sont qu'un bassin.
func _lac(a: Vector2, taille: int) -> void:
	var id: StringName = _dans(LACS) if taille == GRAND else _dans(BASSINS)
	var lac := _placer(id, a, 40.0, 1.0, 0.0, false)
	if lac.is_empty():
		_champ_lave(a, PETIT)
		return
	_bulles(lac, _entre(2, 4))
	_sur_la_rive(lac, CAILLOUX + GRAVIERS, _entre(2, 3))


## LA FOSSE : une longue nappe, couchée ou debout, qui coupe la parcelle sans
## jamais en sortir — elle est FINIE, on en fait le tour (règle 5). Posée d'un
## bloc ou pas du tout : faute de place, la parcelle devient un champ de lave.
func _fosse(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		_lac(a, PETIT)
		return
	var fosse := _placer(_dans(FOSSES), a, 40.0, 1.0, 0.0, false)
	if fosse.is_empty():
		_champ_lave(a, MOYEN)
		return
	_bulles(fosse, _entre(2, 3))
	_sur_la_rive(fosse, CAILLOUX, _entre(1, 3))


## Des bulles sur la lave d'une nappe : dans son milieu, jamais sur la falaise
## ni sur la rive. Posées sans règle — elles ne bloquent ni ne brûlent, et
## elles sont DANS la lave, qui ne se partage avec rien d'autre.
func _bulles(nappe: Dictionary, n: int) -> void:
	if nappe.is_empty():
		return
	var rect := emprise(nappe)
	# La falaise occupe le quart haut, la rive le bord : le milieu utile.
	var utile := Rect2(rect.position + rect.size * Vector2(0.28, 0.38), rect.size * Vector2(0.44, 0.38))
	for _i in n:
		var p := utile.position + Vector2(_d(), _d()) * utile.size
		_poses.append(_pose(_dans(BULLES), p))


# --- L'éboulis ---------------------------------------------------------------

## L'ÉBOULIS, repris du décor d'origine (README, « Le décor de l'arène ») : une
## PENTE, et rien qui bloque — comme l'éboulis d'origine, c'est du terrain, pas
## un mur. Un ou deux blocs bas en tête, puis les débris dont la taille
## DÉCROÎT et l'écart CROÎT à mesure qu'on descend — un éventail. C'est ce
## double gradient qui donne une direction à la chute ; un nuage de pierres de
## taille égale ne raconte rien. Le petit n'a pas de pente : un roc et deux
## éclats à son pied. Les pièces se serrent sans se chevaucher : trois pierres
## qui se touchent font une chose.
##
## Le décor d'origine (pack Texture) a quitté le jeu en 0.9.2 : sa pierre
## beige, peinte et lissée, jurait à côté du pixel art net du nouveau pack,
## comme elle jurait déjà en profondeur avec l'ancien.
func _eboulis(a: Vector2, taille: int) -> void:
	var pente := _d() * TAU
	if taille == PETIT:
		var tete := _placer(_dans(TETES_EBOULIS), a, 40.0)
		_au_pied(tete, CAILLOUX + GRAVIERS, _entre(1, 2))
		return
	var longueur: float = lerpf(220.0, 320.0, _d()) if taille == MOYEN \
		else lerpf(300.0, 430.0, _d())
	for _i in (1 if taille == MOYEN else _entre(1, 2)):
		_placer(_dans(TETES_EBOULIS), a + Vector2((_d() - 0.5) * 90.0, (_d() - 0.5) * 70.0),
			40.0, 1.0, 0.0, false, true)
	var nombre: int = _entre(4, 6) if taille == MOYEN else _entre(7, 10)
	for i in nombre:
		var t := (float(i) + _d()) / float(nombre)
		var gros: StringName = _dans([&"galet", &"caillou_a", &"caillou_b"])
		var moyen: StringName = _dans(GRAVIERS + TROUS)
		var petit: StringName = _dans(CAILLOUX)
		var id: StringName = gros if t < 0.35 else (moyen if t < 0.7 else petit)
		var travers := (_d() - 0.5) * 2.0 * (45.0 + t * 120.0)
		var p := Vector2.RIGHT.rotated(pente) * (t * longueur) \
			+ Vector2.DOWN.rotated(pente) * travers
		_placer(id, a + p, 30.0, 1.0, 0.0, false, true)
	if taille == GRAND:
		var touffes: Array = HERBES if etage == SURFACE else HERBES_SECHES
		_semer(a, Vector2(longueur * 0.6, 150.0), touffes, _entre(1, 2), true)
		if etage == PROFONDEUR:
			_semer(a, Vector2(longueur * 0.6, 150.0), FISSURES, _entre(0, 1))


# --- Les relations : où va une pièce par rapport à une autre -----------------

## Pose `n` pièces du rôle AU PIED d'une pose : devant et sur les côtés, au ras
## de sa base, jamais derrière — ce qu'on laisse au pied d'une machine se voit.
func _au_pied(cible: Dictionary, role: Array, n: int) -> void:
	if cible.is_empty():
		return
	var f := pied_de(cible)
	for _i in n:
		var id := _dans(role)
		var ang := lerpf(0.2, PI - 0.2, _d())
		var dist: float = f["rx"] + _demi_pied(id) + 4.0
		var sol: Vector2 = f["c"] + Vector2(cos(ang) * dist, sin(ang) * dist * 0.55)
		_placer(id, sol - Vector2(0.0, PIED), 22.0, 1.0, 0.0, false, true)


## Même chose au pied d'une surface plate (le bord bas d'une estrade).
func _au_pied_rect(rect: Rect2, role: Array, n: int) -> void:
	for _i in n:
		var id := _dans(role)
		var sol := Vector2(rect.position.x + _d() * rect.size.x, rect.end.y + 4.0)
		_placer(id, sol - Vector2(0.0, PIED), 22.0, 1.0, 0.0, false, true)


## Une pièce À CÔTÉ d'une autre, sur la même ligne de sol : une torche près de
## sa machine, un brasero près de sa statue. `cote` : -1 à gauche, 1 à droite.
func _a_cote(cible: Dictionary, id: StringName, cote: float) -> Dictionary:
	if cible.is_empty():
		return {}
	var f := pied_de(cible)
	var dx: float = f["rx"] + _demi_pied(id) + 18.0
	var sol: Vector2 = f["c"] + Vector2(cote * dx, 2.0)
	return _placer(id, sol - Vector2(0.0, PIED), 20.0, 1.0, 0.0, cote > 0.0)


## Encadre une pose : la même pièce de chaque côté, en miroir.
func _encadrer(cible: Dictionary, id: StringName) -> void:
	_a_cote(cible, id, -1.0)
	_a_cote(cible, id, 1.0)


## Une paire symétrique autour d'un point : même pièce, en miroir à droite.
func _paire(id: StringName, centre: Vector2, demi_ecart: float) -> void:
	_placer(id, centre + Vector2(-demi_ecart, 0.0), 20.0)
	_placer(id, centre + Vector2(demi_ecart, 0.0), 20.0, 1.0, 0.0, true)


## Pose `n` pièces sur la RIVE d'une surface plate (un bassin) :
## juste hors de son emprise, tout autour.
func _sur_la_rive(nappe: Dictionary, role: Array, n: int) -> void:
	if nappe.is_empty():
		return
	var rect := emprise(nappe)
	var c := rect.get_center()
	var demi := rect.size * 0.5
	for _i in n:
		var id := _dans(role)
		var ang := _d() * TAU
		var t := _demi_pied(id)
		var sol := c + Vector2(cos(ang) * (demi.x + t * 0.9), sin(ang) * (demi.y + t * 0.55))
		_placer(id, sol - Vector2(0.0, PIED), 24.0, 1.0, 0.0, false, true)


## Sème des pièces dans un rectangle autour d'un point, chacune cherchant sa
## place (règles 6 à 8). Pour les marques au sol et le menu décor (herbe,
## fumerolles) : ce qui compte a un rôle. `grappe` : elles peuvent se toucher.
func _semer(a: Vector2, demi: Vector2, role: Array, nombre: int, grappe: bool = false) -> void:
	for _i in nombre:
		var id: StringName = _dans(role)
		var p := Vector2((_d() - 0.5) * demi.x * 2.0, (_d() - 0.5) * demi.y * 2.0)
		_placer(id, a + p, 40.0, 1.0, _quart() if EnferDB.est_plate(id) else 0.0, false, grappe)


# --- Pose et règles ----------------------------------------------------------

func _pose(id: StringName, p: Vector2, e: float = 1.0, r: float = 0.0,
		fh: bool = false, fv: bool = false) -> Dictionary:
	return {"id": id, "p": p, "e": EnferDB.ECHELLE * e, "r": r, "fh": fh, "fv": fv,
		"vieux": false}


## POSE UNE PIÈCE, OU LUI TROUVE UNE PLACE À CÔTÉ. Essaie `voulu`, puis jusqu'à
## huit points autour, de plus en plus loin dans un rayon `rayon`, dans un ordre
## tiré (angle d'or : les essais ne s'alignent pas). Rend la pose retenue, ou un
## dictionnaire vide si la pièce est tombée.
##
## `fh` impose le miroir (paire symétrique) ; sinon il est tiré, sauf pour les
## pièces gravées. `grappe` : la pièce peut TOUCHER ses voisines.
func _placer(id: StringName, voulu: Vector2, rayon: float = 0.0, e: float = 1.0,
		r: float = 0.0, fh: bool = false, grappe: bool = false) -> Dictionary:
	var info := EnferDB.info(id)
	var miroir: bool = fh and not info.get("fixe", false)
	var tirage := _d()
	if not fh and not info.get("fixe", false):
		miroir = tirage < 0.5
	var depart := _d() * TAU
	poses_tentees += 1
	for essai in 9:
		var p := voulu
		if essai > 0:
			if rayon <= 0.0:
				break
			var ang := depart + float(essai) * 2.39996
			var dist := rayon * sqrt(float(essai) / 8.0)
			p = voulu + Vector2(cos(ang), sin(ang) * 0.7) * dist
		var pose := _pose(id, p, e, r, miroir, false)
		if _poser_bloc([pose], false, grappe):
			if essai > 0:
				poses_deplacees += 1
			return pose
	poses_tombees += 1
	return {}


## Pose plusieurs pièces d'un bloc : toutes ou aucune.
func _poser_bloc(poses: Array[Dictionary], joint: bool = false, grappe: bool = false) -> bool:
	var obstacles: Array[Dictionary] = []
	var laves: Array[Rect2] = []
	var pieds: Array[Dictionary] = []
	var marques: Array[Rect2] = []
	var reliefs: Array[Rect2] = []
	var tolerance := TOLERANCE_GRAPPE if grappe else TOLERANCE
	for pose: Dictionary in poses:
		var id: StringName = pose["id"]
		var info := EnferDB.info(id)
		if bloque(pose):
			var o := forme_obstacle(pose)
			if not _obstacle_permis(o, joint, obstacles):
				return false
			obstacles.append(o)
		if pose.has("mur"):
			continue
		if info.get("lave", false):
			var rect := emprise(pose).grow(-6.0)
			if not _lave_permise(rect, pieds):
				return false
			laves.append(rect)
		elif info.has("sol"):
			var rect := emprise(pose)
			if not _zone.encloses(rect):
				return false
			if not _plat_permis(rect):
				return false
			if int(info["sol"]) == EnferDB.SOL_RELIEF:
				# Un plateau ne se pose pas sur ce qui est déjà debout.
				for f: Dictionary in _pieds + pieds:
					if rect.has_point(f["c"]):
						return false
				reliefs.append(rect)
			marques.append(rect)
		else:
			var f := pied_de(pose)
			if not _pied_permis(f, tolerance, pieds, laves, reliefs):
				return false
			pieds.append(f)
	# Les obstacles du bloc face à la lave du bloc (une pièce ne pose jamais les
	# deux, mais un bloc le pourrait).
	for o: Dictionary in obstacles:
		for rect: Rect2 in laves:
			var d := _distance_segment_rect(o["a"], o["b"], rect) - float(o["r"])
			if d > 0.0 and d < ECART_LAVE:
				return false
	_obstacles.append_array(obstacles)
	_laves.append_array(laves)
	_pieds.append_array(pieds)
	_marques.append_array(marques)
	_reliefs.append_array(reliefs)
	for pose: Dictionary in poses:
		_poses.append(pose)
	return true


## Règles 6 à 8 pour une pièce dressée : dans sa parcelle, hors de la lave, sans
## marcher sur le pied d'une autre, ni sur le dessus d'un plateau — une roche
## posée là-haut semblerait flotter au-dessus de la falaise.
func _pied_permis(f: Dictionary, tolerance: float, du_bloc: Array[Dictionary],
		laves_du_bloc: Array[Rect2], reliefs_du_bloc: Array[Rect2]) -> bool:
	var c: Vector2 = f["c"]
	var rx: float = f["rx"]
	var ry: float = f["ry"]
	if not _zone.encloses(Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0)):
		return false
	for rect: Rect2 in _laves + laves_du_bloc:
		if rect.grow_individual(rx * 0.8, ry * 0.8, rx * 0.8, ry * 0.8).has_point(c):
			return false
	for rect: Rect2 in _reliefs + reliefs_du_bloc:
		if rect.grow(-8.0).has_point(c):
			return false
	for autre: Dictionary in _pieds + du_bloc:
		if chevauchent(f, autre, tolerance):
			return false
	return true


## Une pièce plate ne recouvre pas une autre pièce plate, ni la lave.
func _plat_permis(rect: Rect2) -> bool:
	for lave: Rect2 in _laves:
		if lave.intersects(rect.grow(-4.0)):
			return false
	for autre: Rect2 in _marques:
		var inter := autre.intersection(rect)
		if inter.get_area() > 0.15 * minf(autre.get_area(), rect.get_area()):
			return false
	return true


func _obstacle_permis(o: Dictionary, joint: bool, du_bloc: Array[Dictionary]) -> bool:
	var a: Vector2 = o["a"]
	var b: Vector2 = o["b"]
	var r: float = o["r"]
	# Règle 2 : tout l'obstacle dans l'intérieur de sa parcelle.
	var boite := Rect2(a, Vector2.ZERO).expand(b).grow(r)
	if not _interieur.encloses(boite):
		return false
	# Règle 3.
	for x: Vector2 in exclusions:
		if _distance_point_segment(x, a, b) - r < EXCLUSION:
			return false
	# Règle 1 : se toucher (mur) ou laisser l'écart.
	for autre: Dictionary in _obstacles + du_bloc:
		var d := _distance_segments(a, b, autre["a"], autre["b"]) - r - float(autre["r"])
		if joint and d <= 4.0:
			continue
		if d < ECART:
			return false
	# Règle 4.
	for rect: Rect2 in _laves:
		var d := _distance_segment_rect(a, b, rect) - r
		if d > 0.0 and d < ECART_LAVE:
			return false
	return true


## Règles 2 à 4 et 7 pour la lave : dans l'intérieur, loin du départ, à l'écart
## des obstacles, et jamais sous une pièce dressée déjà posée. Deux nappes de
## blocs différents ne se touchent pas non plus.
func _lave_permise(rect: Rect2, pieds_du_bloc: Array[Dictionary]) -> bool:
	if not _interieur.encloses(rect):
		return false
	for x: Vector2 in exclusions:
		if _distance_point_rect(x, rect) < EXCLUSION:
			return false
	for o: Dictionary in _obstacles:
		var d := _distance_segment_rect(o["a"], o["b"], rect) - float(o["r"])
		if d > 0.0 and d < ECART_LAVE:
			return false
	for f: Dictionary in _pieds + pieds_du_bloc:
		if rect.grow_individual(f["rx"], f["ry"], f["rx"], f["ry"]).has_point(f["c"]):
			return false
	for autre: Rect2 in _laves:
		if autre.grow(24.0).intersects(rect):
			return false
	# Ni sur un sceau ou une fissure déjà tracés : la lave les engloutirait.
	for marque: Rect2 in _marques:
		if marque.grow(-4.0).intersects(rect):
			return false
	return true


# --- Géométrie (partagée avec la carte et le test) ---------------------------

## Tailles des images (px de planche), par pièce. Remplies depuis les textures
## par la carte au chargement, et par le test (voir `mesurer`).
static var tailles: Dictionary = {}
## Pied de chaque pièce dressée : Vector2(largeur, décalage du milieu), en px
## d'image — voir `mesurer`.
static var pieds: Dictionary = {}


## Lit dans l'image d'une pièce sa taille et son PIED : largeur des pixels
## opaques de ses dernières rangées (12 % de la hauteur, trois au moins), et
## décalage de leur milieu par rapport au centre — le manche d'une torche n'est
## pas forcément au milieu. C'est l'emprise au sol de la règle 6, et c'est aussi
## sur elle que la carte cale l'ombre de contact.
##
## Une pièce ANIMÉE se mesure sur sa première image : sa planche entière ferait
## une emprise quatre fois trop large.
static func mesurer(id: StringName, texture: Texture2D) -> void:
	var cadre := EnferDB.anim(id)
	var colonnes := maxi(1, cadre.x)
	var rangees_img := maxi(1, cadre.y)
	tailles[id] = Vector2(texture.get_width() / colonnes, texture.get_height() / rangees_img)
	var img := texture.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if colonnes > 1 or rangees_img > 1:
		img = img.get_region(Rect2i(Vector2i.ZERO, Vector2i(tailles[id])))
	var o := img.get_data()
	var l := img.get_width()
	var h := img.get_height()
	var bas := h - 1
	while bas > 0:
		var plein := false
		for x in l:
			if o[(bas * l + x) * 4 + 3] > 128:
				plein = true
				break
		if plein:
			break
		bas -= 1
	var rangees := maxi(3, int(h * 0.12))
	var x0 := l
	var x1 := -1
	for y in range(maxi(0, bas - rangees + 1), bas + 1):
		for x in l:
			if o[(y * l + x) * 4 + 3] > 128:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
	pieds[id] = Vector2(float(l) * 0.6, 0.0) if x1 < x0 \
		else Vector2(float(x1 - x0 + 1), (float(x0 + x1 + 1) - float(l)) * 0.5)


## Le pied d'une pose dressée, au sol : ellipse de centre "c" et de rayons
## "rx", "ry" (le sol est vu en perspective, d'où un ovale).
static func pied_de(pose: Dictionary) -> Dictionary:
	var ech: float = pose["e"]
	var pied: Vector2 = pieds.get(pose["id"], Vector2(40.0, 0.0))
	var dx := pied.y * ech * (-1.0 if pose["fh"] else 1.0)
	var rx := maxf(8.0, pied.x * ech * 0.5)
	return {"c": Vector2(pose["p"]) + Vector2(dx, PIED), "rx": rx, "ry": maxf(6.0, rx * 0.5)}


## Deux pieds se recouvrent-ils ? `tolerance` en part de la somme des rayons.
static func chevauchent(a: Dictionary, b: Dictionary, tolerance: float) -> bool:
	var ca: Vector2 = a["c"]
	var cb: Vector2 = b["c"]
	var dx := (ca.x - cb.x) / (float(a["rx"]) + float(b["rx"]))
	var dy := (ca.y - cb.y) / (float(a["ry"]) + float(b["ry"]))
	return dx * dx + dy * dy < tolerance * tolerance


func _demi_pied(id: StringName) -> float:
	var pied: Vector2 = pieds.get(id, Vector2(40.0, 0.0))
	return maxf(8.0, pied.x * EnferDB.ECHELLE * 0.5)


## Cette pose bloque-t-elle ? Un mur de plusieurs pans porte son obstacle à
## part (clé "mur", sans image) et ses pans n'en ont pas (clé "sans_corps").
static func bloque(pose: Dictionary) -> bool:
	if pose.has("mur"):
		return true
	if pose.get("vieux", false) or pose.get("sans_corps", false):
		return false
	return EnferDB.est_solide(pose["id"])


## L'obstacle d'une pose : segment [a, b] et rayon, en coordonnées du monde.
static func forme_obstacle(pose: Dictionary) -> Dictionary:
	var dims: Vector2 = pose["mur"] if pose.has("mur") else EnferDB.obstacle(pose["id"])
	var p: Vector2 = centre_obstacle(pose)
	var demi := Vector2(dims.x, 0.0).rotated(float(pose["r"]))
	return {"a": p - demi, "b": p + demi, "r": dims.y}


## Centre d'un obstacle. Une pièce dressée bloque sur son PIED, décalé comme
## lui : les objets du pack portent leur ombre vers la droite, et leur base
## n'est pas au milieu de l'image — un obstacle centré sur l'image arrêtait le
## joueur à côté du rocher, sur son ombre. Une pièce plate (un plateau) bloque
## sur toute son image, centrée sur son nœud.
static func centre_obstacle(pose: Dictionary) -> Vector2:
	var p: Vector2 = pose["p"]
	if pose.has("mur") or pose.get("vieux", false) or EnferDB.est_plate(pose["id"]):
		return p
	var pied: Vector2 = pieds.get(pose["id"], Vector2.ZERO)
	return p + Vector2(pied.y * float(pose["e"]) * (-1.0 if pose["fh"] else 1.0), 0.0)


## Emprise d'une pièce plate (centrée), rotation d'un quart de tour comprise.
static func emprise(pose: Dictionary) -> Rect2:
	var taille: Vector2 = tailles.get(pose["id"], Vector2(96.0, 96.0)) * float(pose["e"])
	var quart := absf(sin(float(pose["r"]))) > 0.5
	if quart:
		taille = Vector2(taille.y, taille.x)
	return Rect2(Vector2(pose["p"]) - taille * 0.5, taille)


static func _distance_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _distance_segments(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	return minf(minf(_distance_point_segment(a, c, d), _distance_point_segment(b, c, d)),
		minf(_distance_point_segment(c, a, b), _distance_point_segment(d, a, b)))


static func _distance_point_rect(p: Vector2, r: Rect2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(q)


static func _distance_segment_rect(a: Vector2, b: Vector2, r: Rect2) -> float:
	var d := INF
	for i in 5:
		d = minf(d, _distance_point_rect(a.lerp(b, float(i) / 4.0), r))
	return d


# --- Tirages -----------------------------------------------------------------

func _d() -> float:
	_canal += 1
	return _h(_px, _py, _canal)


func _entre(a: int, b: int) -> int:
	return mini(a + int(_d() * float(b - a + 1)), b)


func _dans(role: Array) -> StringName:
	return role[mini(int(_d() * float(role.size())), role.size() - 1)]


func _signe() -> float:
	return 1.0 if _d() < 0.5 else -1.0


func _quart() -> float:
	return float(_entre(0, 3)) * PI * 0.5


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


## Hachage des coordonnées -> [0, 1[. L'étage entre dans le mélange : une même
## parcelle porte deux lieux sans rapport en surface et en profondeur.
func _h(px: int, py: int, canal: int) -> float:
	var n := (px * 73856093) ^ (py * 19349663) ^ (canal * 83492791) \
		^ (graine * 2654435761) ^ (etage * 961748927)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / 16777216.0
