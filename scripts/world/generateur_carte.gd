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
##     sanctuaires, les geôles et les supplices ; à la vague 11, on descend dans
##     la lave, les cratères et les ossuaires ;
##   - certaines pièces BLOQUENT et d'autres BRÛLENT, et ça impose des règles.
##
## LES RÈGLES DE JOUABILITÉ, garanties par construction et vérifiées par le test :
##   1. Entre deux obstacles, soit ils se touchent (un mur de geôle en trois
##      pièces), soit il reste `ECART` px libres — cinq imps de front. Jamais de
##      goulet où la horde s'aligne pour se faire faucher, jamais de poche.
##   2. Obstacles et lave restent à `BORD` px à l'intérieur de LEUR parcelle.
##      C'est ce qui garantit la règle 1 entre deux parcelles voisines, qui
##      s'engendrent sans se connaître : 2 × 80 = 160.
##   3. Rien de ce qui bloque ou brûle à moins de `EXCLUSION` px du point de
##      départ, ni de l'endroit où l'on se trouve quand on change d'étage.
##   4. La lave laisse `ECART_LAVE` px aux obstacles, ou les touche : pas de
##      couloir étroit entre un mur et une rivière.
##   5. Une rivière est FINIE : elle tient dans sa parcelle, coiffée d'un bassin
##      à chaque bout. Elle ne peut donc jamais enfermer personne.
##
## LES RÈGLES DE COMPOSITION, qui font qu'un lieu a un sens :
##   6. RIEN NE SE CHEVAUCHE. Chaque pièce dressée a une emprise au sol — son
##      PIED, mesuré dans son image — et deux pieds ne se recouvrent pas. Deux
##      marques au sol (sceau, fissure) non plus.
##   7. RIEN NE TOMBE DANS LA LAVE : ni pièce dressée, ni marque au sol.
##   8. RIEN NE DÉBORDE DE SA PARCELLE : deux lieux voisins ne se mêlent pas.
##   9. CHAQUE PIÈCE A UN RÔLE ET UNE PLACE. On encadre ce qu'on vénère de deux
##      braseros, on laisse les restes au pied d'une machine de supplice, on pose
##      les roches refroidies sur la rive des bassins. Une pièce qui gêne cherche
##      une place à côté (`_placer`) avant de renoncer.
##
## Une pose qui enfreindrait une règle n'est pas posée : la pièce « est tombée ».
## Un lieu se lit encore avec un crâne en moins ; sans ce qu'on y vénère, il ne se
## lirait plus, donc le lieu s'arrête là. Une rivière coupée en deux non plus :
## elle se pose d'un bloc ou pas du tout.

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

# --- Le décor d'origine (pack Texture), repris tel quel ----------------------

const DECOR_ECHELLE := 3.0
const DECOR_ECHELLE_PIECE := {
	&"autel": 2.0, &"gravats": 2.0, &"pierre_levee": 2.0, &"tour": 2.0,
}
const DECOR_MIROIR := [&"caillou", &"roche_petite", &"roche", &"dalles", &"rocaille",
	&"gravats", &"touffe", &"buisson_petit", &"buisson", &"urne", &"jarre",
	&"pierre_levee", &"anneau"]
const MODULE := 95.0
const RUINE_MUR := [&"pierre_levee", &"gravats"]
const RUINE_COIN := &"tour"
const RUINE_COEUR := [&"autel", &"anneau"]
const RUINE_SOL := [&"dalles", &"gravats", &"roche_petite"]
const POTERIE := [&"urne", &"jarre"]
const VEGETATION := [&"touffe", &"buisson_petit", &"buisson"]
const ROCHE_TETE := &"rocaille"
const ROCHE_GROS := [&"roche", &"rocaille"]
const ROCHE_MOYEN := [&"roche", &"roche_petite"]
const ROCHE_PETIT := [&"caillou", &"dalles", &"roche_petite"]

# --- Les rôles des pièces de l'enfer -----------------------------------------
#
# Un rôle ne mélange jamais les étages : la surface est l'enfer FROID, rien n'y
# couve ni n'y rougeoie hors des flammes qu'on y a allumées. Les pics de lave,
# les roches incandescentes et les braises sont réservés à la profondeur.

const STATUES := [&"gargouille_a", &"gargouille_b", &"gargouille_c", &"gargouille_d",
	&"gargouille_grande", &"gargouille_assise_a", &"gargouille_assise_b",
	&"gargouille_assise_c", &"gargouille_socle", &"gargouille_penseur",
	&"statue_taureau", &"statue_bouc", &"gardien", &"obelisque_a", &"obelisque_c",
	&"obelisque_e", &"obelisque_g"]
const PETITES_STATUES := [&"gargouille_petite_a", &"gargouille_petite_b",
	&"obelisque_b", &"obelisque_f", &"statue_voilee"]
const STATUETTES := [&"statuette_a", &"statuette_b"]
const CENTRES_SANCTUAIRE := [&"autel_demon", &"autel_squelette", &"autel_squelette_b",
	&"autel_os", &"trone_a", &"trone_b", &"trone_c", &"baphomet", &"buste_demon"]
const SIGLES := [&"pentagramme", &"sceau", &"relief"]
## Sur la roche refroidie d'un autel de braise, seuls les sceaux qui rougeoient :
## le relief de pierre grise y faisait une dalle posée là par erreur.
const SIGLES_BRAISE := [&"pentagramme", &"sceau"]
const COUPES := [&"coupe_feu_a", &"coupe_feu_b", &"coupe_feu_c", &"coupe_feu_d",
	&"coupe_feu_e", &"coupe_feu_f", &"torchere_a", &"torchere_b"]
const CRANES := [&"crane_a", &"crane_b", &"crane_c", &"crane_os", &"crane_bouc"]
const OSSEMENTS := [&"os_a", &"os_b", &"os_c", &"os_d", &"os_e", &"carcasse"]
const RESTES := CRANES + OSSEMENTS
const RUNES := [&"pierre_rune_a", &"pierre_rune_b", &"pierre_rune_c", &"pierre_rune_d",
	&"pierre_rune_e"]
const DALLES_RUNE := [&"dalle_rune_a", &"dalle_rune_b", &"dalle_rune_c", &"dalle_rune_d"]
const STALAGMITES := [&"stalagmite_a", &"stalagmite_b", &"stalagmite_c", &"stalagmite_d",
	&"stalagmites_a", &"stalagmites_b", &"stalagmites_c"]
## Le feu de la surface : un feu de camp qu'on a allumé. Les braises qui couvent
## seules sont de la profondeur.
const FEUX_SURFACE := [&"feu_camp", &"feu_camp_b", &"feu_camp_c"]
const FEUX := [&"feu_camp", &"feu_camp_b", &"feu_camp_c", &"braises", &"tas_braise"]
const SUPPLICES_RONDS := [&"roue_a", &"roue_b", &"chaise_pointes", &"chaise_pointes_b",
	&"trone_pointes", &"trone_rouge_pointes", &"chaise_supplice", &"vierge_fermee",
	&"vierge_ouverte", &"vierge_sang", &"meule", &"cage_grande"]
const SUPPLICES_LONGS := [&"chevalet", &"pilori", &"echelle", &"boite_pointes",
	&"boite_bois", &"guillotine", &"hachoir", &"presse", &"banc_pointes",
	&"lit_pointes", &"lame"]
const CAGES_AMES := [&"cage_ame_a", &"cage_ame_b", &"cage_ame_c", &"cage_ame_d",
	&"pieux_ame"]
const TORCHES := [&"torche_a", &"torche_b", &"torche_c"]
const GEOLE_PORTES := [&"geole_porte_a", &"geole_porte_b"]
const ROCHES_LAVE := [&"roche_lave_a", &"roche_lave_b", &"roche_lave_c", &"roche_lave_d",
	&"roche_braise"]
const ROCHERS := [&"rochers_a", &"rochers_b", &"rochers_c", &"rochers_d", &"rochers_e",
	&"rochers_f", &"eclats", &"eboulis_noir", &"caillou_noir"]
const ECLATS_NOIRS := [&"eclats", &"caillou_noir", &"braise_petite", &"braise_ronde",
	&"eboulis_noir"]
const OBSIDIENNES := [&"obsidienne_a", &"obsidienne_b", &"obsidienne_c", &"obsidienne_d",
	&"obsidienne_e", &"obsidienne_f"]
const FISSURES := [&"fissure_b", &"fissure_c", &"fissure_e", &"fissure_f", &"fissure_g",
	&"fissure_h", &"fissure_i"]
const BASSINS := [&"bassin_trefle", &"bassin_croix"]
const FLAQUES := [&"flaque_a", &"flaque_b", &"flaque_c", &"flaque_d", &"flaque_e",
	&"flaque_f"]
const CRATERES := [&"cratere_a", &"cratere_b", &"cratere_c", &"fosse_a", &"fosse_b",
	&"volcan", &"volcan_actif", &"puits_lave", &"bassin_braise"]
const GOLEMS := [&"golem_a", &"golem_b", &"golem_c", &"golem_d"]
const CENTRES_BRAISE := [&"idole_braise", &"cercle_pics", &"brasier", &"bucher",
	&"chaudron_a", &"chaudron_b", &"chaudron_c", &"bucher_ame"]
const ESTRADES := [&"estrade_defenses", &"estrade_cranes", &"estrade_arc",
	&"estrade_fissures"]
const PONTS := [&"pont_a", &"pont_b"]
const CRISTAUX := [&"cristaux_runes_a", &"cristaux_runes_b"]
const PLANTES_FEU := [&"plante_feu", &"cristal_feu"]
const ROCS_FROIDS := [&"aiguilles", &"aiguilles_b", &"pics_a", &"pics_b"]
const ROCS_BRULANTS := [&"aiguilles", &"aiguilles_b", &"pics_a", &"pics_b", &"pics_lave",
	&"rocher_fendu"]

## Les rivières : longueur (px de planche) et décalage latéral du cours d'un
## bout à l'autre. Mesuré sur les planches : la lave des deux tronçons droits va
## de x 20 à 76, centrée sur 48, EN HAUT COMME EN BAS — ils se raccordent au
## pixel près. Le coude entre centré sur 143,5 et sort centré sur 47,5.
const RIVIERE_LONGUEUR := {&"riviere_droite": 288.0, &"riviere_courte": 192.0,
	&"riviere_coude": 192.0}
const COUDE_ENTREE := 47.5   ## centre de la lave en haut, depuis le centre de l'image
const COUDE_SORTIE := -48.5  ## centre de la lave en bas
## Demi-largeur d'un tronçon droit berges comprises, en px de planche (96 / 2).
const RIVIERE_DEMI_LARGEUR := 48.0
## Les enchaînements permis. Ils tiennent tous dans une parcelle, bassins
## compris (576 px de planche au plus, soit 864 px de monde... moins le bord).
const RIVIERES := [
	[&"riviere_droite"],
	[&"riviere_courte", &"riviere_courte"],
	[&"riviere_courte", &"riviere_coude"],
	[&"riviere_coude", &"riviere_courte"],
]
## Les bassins coiffent les bouts : agrandis pour couvrir les berges du tronçon
## (96 px de planche contre 82 pour un bassin).
const BASSIN_BOUT := 1.25

## Les lieux de chaque étage, et leur poids. L'éboulis domine en surface comme
## avant : c'est du terrain. En profondeur, c'est la lave qui domine.
##
## La SOUFRIÈRE a été retirée : ses plaques de soufre jaune vif se lisaient
## comme des mines d'or (retour de jeu) et juraient avec tout le reste.
enum Lieu { EBOULIS, RUINE, SANCTUAIRE, SUPPLICES, GEOLE, OSSUAIRE, CERCLE,
	CHAMP_LAVE, AUTEL_BRAISE, CRATERE, RIVIERE, EBOULIS_NOIR }
const LIEUX := {
	SURFACE: {Lieu.EBOULIS: 28, Lieu.RUINE: 18, Lieu.SANCTUAIRE: 17, Lieu.SUPPLICES: 15,
		Lieu.GEOLE: 10, Lieu.OSSUAIRE: 6, Lieu.CERCLE: 6},
	PROFONDEUR: {Lieu.CHAMP_LAVE: 26, Lieu.RIVIERE: 18, Lieu.EBOULIS_NOIR: 20,
		Lieu.AUTEL_BRAISE: 15, Lieu.CRATERE: 14, Lieu.OSSUAIRE: 7},
}

## Tolérance de chevauchement des pieds (règle 6), en part de la somme des
## rayons : 1 interdit tout contact, moins laisse des pièces SE TOUCHER. Une
## grappe de roches ou de stalagmites se tient serrée ; une statue et un crâne
## ne se touchent pas.
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
	var coin := Vector2(parcelle) * ZONE_COTE
	var carre := Rect2(coin, Vector2(ZONE_COTE, ZONE_COTE))
	_interieur = carre.grow(-BORD)
	_zone = carre.grow(-MARGE_PARCELLE)

	var lieu: int = _tirer_lieu()
	var taille: int = _tirer_pondere(POIDS_TAILLE)
	# Un lieu qui bloque ou qui brûle reste près du centre de sa parcelle : il
	# doit tenir dans l'intérieur (règle 2). Le décor pur garde plus de jeu,
	# assez pour que la trame de 950 px ne se voie pas — mais il ne déborde plus
	# de sa parcelle (règle 8), ses pièces sont ramenées dedans.
	var jeu := 420.0 if lieu in [Lieu.EBOULIS, Lieu.RUINE, Lieu.OSSUAIRE, Lieu.CERCLE,
			Lieu.EBOULIS_NOIR] \
		else 300.0
	if lieu == Lieu.RIVIERE:
		jeu = 90.0
	var ancre := coin + Vector2(ZONE_COTE, ZONE_COTE) * 0.5 \
		+ Vector2(_d() - 0.5, _d() - 0.5) * jeu
	if _px == 0 and _py == 0:
		ancre = Vector2.RIGHT.rotated(_d() * TAU) * DEPART_DISTANCE

	match lieu:
		Lieu.EBOULIS: _zone_rochers(ancre, taille)
		Lieu.EBOULIS_NOIR: _eboulis_noir(ancre, taille)
		Lieu.RUINE: _zone_ruine(ancre, taille)
		Lieu.SANCTUAIRE: _sanctuaire(ancre, taille)
		Lieu.SUPPLICES: _supplices(ancre, taille)
		Lieu.GEOLE: _geole(ancre, taille)
		Lieu.OSSUAIRE: _ossuaire(ancre, taille)
		Lieu.CERCLE: _cercle(ancre, taille)
		Lieu.CHAMP_LAVE: _champ_lave(ancre, taille)
		Lieu.AUTEL_BRAISE: _autel_braise(ancre, taille)
		Lieu.CRATERE: _cratere(ancre, taille)
		Lieu.RIVIERE: _riviere(ancre, taille)
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


# --- Surface : les lieux de l'enfer froid ------------------------------------

## LE SANCTUAIRE : un parvis dallé, un sceau au sol, et ce qu'on y vénère au
## fond — deux braseros L'ENCADRENT, les offrandes gisent À SES PIEDS. La grande
## version ajoute deux gardiens aux bords du parvis, en miroir, et deux stèles
## qui marquent l'entrée. La petite n'est qu'un oratoire : une statue sur une
## dalle gravée, un brasero à côté.
func _sanctuaire(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		_placer(_dans(DALLES_RUNE), a + Vector2(0.0, PIED + 6.0), 30.0)
		var dressee := _d() < 0.5
		var statue := _placer(_dans(PETITES_STATUES) if dressee else _dans(STATUETTES), a, 40.0)
		if statue.is_empty():
			return
		_a_cote(statue, _dans(COUPES), _signe())
		_au_pied(statue, CRANES, _entre(1, 2))
		return
	var plaque := _placer(&"plaque_dallage", a + Vector2(0.0, 10.0), 0.0,
		0.72 if taille == MOYEN else 0.95)
	_placer(_dans(SIGLES), a + Vector2(0.0, 30.0), 20.0)
	var centre := _placer(_dans(CENTRES_SANCTUAIRE), a + Vector2(0.0, -105.0), 40.0)
	if centre.is_empty():
		return
	_encadrer(centre, _dans(COUPES))
	_au_pied(centre, RESTES, _entre(1, 2))
	if taille < GRAND:
		return
	# Les gardiens tiennent les BORDS du parvis, face à face.
	var demi := 200.0
	if not plaque.is_empty():
		demi = emprise(plaque).size.x * 0.5
	var gardien := _dans(STATUES)
	_paire(gardien, a + Vector2(0.0, 50.0), demi + 30.0)
	_paire(_dans(RUNES), a + Vector2(0.0, 175.0), 150.0)


## LES SUPPLICES : une ou deux machines, chacune avec SA torche plantée à côté
## et ses restes AU PIED. En grand, une cage d'âmes au fond, qu'encadrent deux
## torches. En petit, parfois il ne reste que les restes, autour d'une torche.
func _supplices(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		if _d() < 0.4:
			var machine := _placer(_dans(SUPPLICES_RONDS), a, 40.0)
			_a_cote(machine, _dans(TORCHES), _signe())
			_au_pied(machine, RESTES, _entre(1, 2))
		else:
			var torche := _placer(_dans(TORCHES), a, 30.0)
			_au_pied(torche, RESTES, _entre(2, 3))
		return
	if taille == MOYEN:
		var machine := _placer(_dans(SUPPLICES_RONDS + SUPPLICES_LONGS), a, 40.0)
		if machine.is_empty():
			return
		_encadrer(machine, _dans(TORCHES))
		_au_pied(machine, RESTES, _entre(2, 3))
		return
	var longue := _placer(_dans(SUPPLICES_LONGS), a + Vector2(-190.0, 10.0), 40.0)
	var ronde := _placer(_dans(SUPPLICES_RONDS), a + Vector2(190.0, -10.0), 40.0)
	var cage := _placer(_dans(CAGES_AMES), a + Vector2(0.0, -215.0), 40.0)
	# Chaque machine a sa torche, du côté du dehors : les deux flammes cadrent
	# la scène au lieu de se serrer au milieu.
	_a_cote(longue, _dans(TORCHES), -1.0)
	_a_cote(ronde, _dans(TORCHES), 1.0)
	_au_pied(longue, RESTES, _entre(1, 2))
	_au_pied(ronde, RESTES, _entre(1, 2))
	_encadrer(cage, _dans(TORCHES))
	_au_pied(cage, CRANES, 1)


## LA GEÔLE : un pan de mur de cellules, porte, mur, porte — les pièces se
## touchent et forment UN obstacle. Deux torches aux deux bouts du mur, les os
## des prisonniers au pied des portes, et en grand une cage d'âmes devant.
func _geole(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		var cage := _placer(&"cage_grande", a, 40.0)
		_au_pied(cage, RESTES, _entre(1, 2))
		return
	var pas := 86.0 * EnferDB.ECHELLE - 2.0
	var pieces := [_dans(GEOLE_PORTES), &"geole_mur"]
	if taille == GRAND:
		pieces.append(_dans(GEOLE_PORTES))
	var x0 := -pas * float(pieces.size() - 1) * 0.5
	# UN MUR, UN OBSTACLE. Trois capsules jointives laissaient à chaque jonction
	# une encoche entre leurs bouts arrondis, où un corps restait pris, et deux
	# tangentes contraires qui le renvoyaient de l'une à l'autre : mesuré, pas un
	# imp sur douze ne franchissait un mur de geôle. Les pans sont donc de purs
	# dessins et le mur entier est une seule capsule, convexe.
	var bloc: Array[Dictionary] = []
	var pans: Array[Dictionary] = []
	for i in pieces.size():
		var pan := _pose(pieces[i], a + Vector2(x0 + pas * float(i), -60.0))
		pan["sans_corps"] = true
		bloc.append(pan)
		pans.append(pan)
	var mur := _pose(&"", a + Vector2(0.0, -60.0))
	mur["mur"] = Vector2(-x0 + EnferDB.obstacle(&"geole_mur").x, EnferDB.obstacle(&"geole_mur").y)
	bloc.append(mur)
	if not _poser_bloc(bloc):
		return
	_a_cote(pans[0], _dans(TORCHES), -1.0)
	_a_cote(pans[-1], _dans(TORCHES), 1.0)
	for pan: Dictionary in pans:
		if pan["id"] in GEOLE_PORTES and _d() < 0.7:
			_au_pied(pan, RESTES, 1)
	if taille == GRAND:
		var cage := _placer(_dans(CAGES_AMES), a + Vector2(_signe() * 110.0, 190.0), 50.0)
		_au_pied(cage, RESTES, 1)


## LE CERCLE DE PIERRES : des stèles gravées en rond autour d'un feu de camp.
## Rien n'y bloque, les stèles sont basses ; c'est un repère qu'on voit de loin.
func _cercle(a: Vector2, taille: int) -> void:
	var n: int = [4, 5, 7][taille]
	var rayon: float = [95.0, 125.0, 165.0][taille]
	var phase := _d() * TAU
	if taille == GRAND:
		_placer(_dans(DALLES_RUNE), a + Vector2(0.0, PIED), 0.0)
	_placer(_dans(FEUX_SURFACE), a, 20.0)
	for i in n:
		var ang := phase + TAU * float(i) / float(n)
		_placer(_dans(RUNES), a + Vector2(cos(ang), sin(ang) * 0.7) * rayon, 18.0)


## L'OSSUAIRE, commun aux deux étages : une estrade, les ossements EN TAS dessus
## et autour, parfois une porte d'os au fond avec des crânes à son pied, et un
## rocher dressé en marge.
func _ossuaire(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		var tas := _placer(_dans(OSSEMENTS), a, 40.0)
		_au_pied(tas, CRANES, _entre(1, 2))
		return
	var estrade := _placer(_dans(ESTRADES), a + Vector2(0.0, 20.0), 30.0)
	if estrade.is_empty():
		return
	var dessus := emprise(estrade)
	for _i in _entre(2, 4):
		var p := dessus.position + Vector2(_d(), _d()) * dessus.size
		_placer(_dans(OSSEMENTS), p - Vector2(0.0, PIED), 24.0, 1.0, 0.0, false, true)
	_au_pied_rect(dessus, CRANES, _entre(1, 3))
	if taille == GRAND:
		var porte := _placer(&"porte_os", Vector2(dessus.get_center().x,
			dessus.position.y - 10.0) - Vector2(0.0, PIED), 30.0)
		_au_pied(porte, CRANES, 1)
		var rocs := ROCS_FROIDS if etage == SURFACE else ROCS_BRULANTS
		_placer(_dans(rocs), a + Vector2(_signe() * 270.0, 30.0), 50.0)


# --- Profondeur : la lave ----------------------------------------------------

## LE CHAMP DE LAVE : des bassins cernés de roche refroidie, qui ne se touchent
## pas ; des flaques entre eux ; des blocs encore rouges et de l'obsidienne SUR
## LA RIVE des bassins, pas au milieu du sol. En grand, un volcan le domine.
func _champ_lave(a: Vector2, taille: int) -> void:
	var bassins: Array[Dictionary] = []
	for i in [1, 2, 3][taille]:
		# Le second bassin s'écarte du premier : deux bassins qui se chevauchent
		# se liraient comme une seule tache mal découpée.
		var p := a
		if i > 0:
			p += Vector2.RIGHT.rotated(_d() * TAU) * lerpf(190.0, 260.0, _d())
		var bassin := _placer(_dans(BASSINS), p, 40.0, 1.0, _quart())
		if bassin.is_empty():
			continue
		_placer(&"plaque_lave", bassin["p"], 0.0, lerpf(1.2, 1.5, _d()), _quart())
		bassins.append(bassin)
	for _i in [2, 3, 4][taille]:
		var p := a + Vector2.RIGHT.rotated(_d() * TAU) * lerpf(150.0, 300.0, _d())
		_placer(_dans(FLAQUES), p, 50.0, 1.0, _quart())
	for bassin: Dictionary in bassins:
		_sur_la_rive(bassin, ROCHES_LAVE + OBSIDIENNES, _entre(1, 2))
	_semer(a, Vector2(280.0, 200.0), FISSURES, _entre(1, 3))
	if taille == GRAND:
		var volcan := _placer(_dans([&"volcan", &"volcan_actif"]),
			a + Vector2(_signe() * 250.0, -170.0), 60.0)
		_au_pied(volcan, ECLATS_NOIRS, _entre(1, 2))


## L'AUTEL DE BRAISE : ce qu'on y brûle au centre, sur un sceau ; deux coupes de
## feu l'encadrent. En grand, deux golems de lave gardent les bords, face à face.
func _autel_braise(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		var coupe := _placer(_dans(COUPES), a, 30.0)
		_a_cote(coupe, _dans(RUNES), -1.0)
		_au_pied(coupe, ECLATS_NOIRS, 1)
		return
	_placer(&"plaque_lave", a + Vector2(0.0, 30.0), 0.0, 1.3, _quart())
	_placer(_dans(SIGLES_BRAISE), a + Vector2(0.0, 40.0), 20.0)
	var centre := _placer(_dans(CENTRES_BRAISE), a + Vector2(0.0, -80.0), 40.0)
	if centre.is_empty():
		return
	_encadrer(centre, _dans(COUPES))
	if taille == GRAND:
		_paire(_dans(GOLEMS), a + Vector2(0.0, 20.0), 260.0)
	for _i in _entre(1, 2):
		var p := a + Vector2.RIGHT.rotated(_d() * TAU) * lerpf(220.0, 300.0, _d())
		_placer(_dans(FLAQUES), p, 50.0, 1.0, _quart())


## LE CRATÈRE : une gueule de lave dressée sur une étoile de fissures, des éclats
## à son pied. Le petit n'est qu'un anneau de roches où couvent des braises.
func _cratere(a: Vector2, taille: int) -> void:
	if taille == PETIT:
		# L'anneau est creux : les braises vont DEDANS (voir EnferDB, « creux »).
		_placer(&"anneau_roches", a, 30.0)
		_placer(_dans([&"braises", &"tas_braise"]), a + Vector2(0.0, 6.0), 0.0)
		_semer(a, Vector2(130.0, 90.0), FISSURES, _entre(1, 2))
		return
	_placer(&"etoile_fissure", a + Vector2(0.0, PIED), 0.0, 1.4, _quart())
	var cratere := _placer(_dans(CRATERES), a, 40.0)
	if cratere.is_empty():
		return
	_au_pied(cratere, ECLATS_NOIRS + ROCHES_LAVE, _entre(1, 3))
	_semer(a, Vector2(260.0, 190.0), FISSURES, _entre(1, 2))
	if taille == GRAND:
		var second := _placer(_dans(CRATERES + ROCS_BRULANTS),
			a + Vector2(_signe() * 260.0, 150.0), 60.0)
		_au_pied(second, ECLATS_NOIRS, 1)
		_placer(_dans(FLAQUES), a + Vector2(_signe() * 170.0, -170.0), 50.0, 1.0, _quart())


## LA RIVIÈRE : des tronçons raccordés au pixel, un bassin à chaque bout, un pont
## au milieu. Posée d'un bloc ou pas du tout (voir l'en-tête).
##
## Le cours est construit à la verticale puis, une fois sur deux, couché : la
## lave est vue de dessus, une rotation d'un quart de tour ne se voit pas. Les
## roches se posent sur les BERGES des tronçons droits, calculées tronçon par
## tronçon : la première version les plaçait de part et d'autre de l'axe de
## départ, et le coude, qui déporte le cours, les jetait dans le courant.
func _riviere(a: Vector2, taille: int) -> void:
	var couchee := _d() < 0.5
	var choix := _entre(0, RIVIERES.size() - 1)
	# En petit, un seul tronçon court entre deux bassins : un ruisseau.
	var suite: Array = [&"riviere_courte"] if taille == PETIT else RIVIERES[choix]
	var miroir := _d() < 0.5
	var e := EnferDB.ECHELLE
	var longueur := 0.0
	for id: StringName in suite:
		longueur += RIVIERE_LONGUEUR[id] * e
	# Toutes les poses sont construites dans un repère local (cours vertical,
	# centré sur l'ancre), puis validées ensemble avant d'être retenues.
	var locales: Array[Dictionary] = []
	# Le cours part de l'axe (x = 0) : le coude se pose de sorte que sa lave
	# ENTRE sur l'axe, et décale la suite de ce qu'il déporte.
	var y := -longueur * 0.5
	var x := 0.0
	for i in suite.size():
		var id: StringName = suite[i]
		var l: float = RIVIERE_LONGUEUR[id] * e
		if id == &"riviere_coude":
			var entree := COUDE_ENTREE * e * (-1.0 if miroir else 1.0)
			var sortie := COUDE_SORTIE * e * (-1.0 if miroir else 1.0)
			var cx := x - entree
			locales.append({"id": id, "p": Vector2(cx, y + l * 0.5), "fh": miroir, "fv": false})
			x = cx + sortie
		else:
			# Un tronçon sur deux est retourné : le joint devient un miroir, donc
			# parfait, quel que soit le dessin des bords.
			locales.append({"id": id, "p": Vector2(x, y + l * 0.5), "fh": miroir,
				"fv": i % 2 == 1, "l": l})
		y += l
	# Les bassins aux deux bouts, sur la lave et non sur l'image.
	var bouts := [Vector2(0.0, -longueur * 0.5), Vector2(x, longueur * 0.5)]
	var extras: Array[Dictionary] = []
	for b: Vector2 in bouts:
		extras.append({"id": &"plaque_lave", "p": b, "e": 1.3})
		extras.append({"id": _dans(BASSINS), "p": b, "e": BASSIN_BOUT})
	# Le pont, sur le premier tronçon droit, en travers du cours.
	var pont_local := Vector2.INF
	for pose: Dictionary in locales:
		if pose["id"] != &"riviere_coude":
			pont_local = pose["p"]
			extras.append({"id": _dans(PONTS), "p": pose["p"], "e": 1.0})
			break

	var rot := PI * 0.5 if couchee else 0.0
	var retenues: Array[Dictionary] = []
	for pose: Dictionary in locales + extras:
		var p: Vector2 = pose["p"]
		var r := rot
		# Les bassins tournent librement ; le pont reste en travers du cours.
		if pose["id"] in BASSINS:
			r = _quart()
		retenues.append(_pose(pose["id"], a + p.rotated(rot), pose.get("e", 1.0), r,
			pose.get("fh", false), pose.get("fv", false)))
	if not _poser_bloc(retenues):
		# Pas de place pour la rivière : la parcelle devient un champ de lave.
		_champ_lave(a, MOYEN)
		return
	# Des blocs sur les berges des tronçons droits, jamais devant le pont.
	var berge := RIVIERE_DEMI_LARGEUR * e
	for pose: Dictionary in locales:
		if pose["id"] == &"riviere_coude":
			continue
		for _i in _entre(1, 2):
			var id := _dans(ROCHES_LAVE + ROCHERS + OBSIDIENNES)
			var cote := _signe()
			var le_long := (_d() - 0.5) * float(pose["l"]) * 0.8
			var local := Vector2(pose["p"]) + Vector2(cote * (berge + _demi_pied(id) + 6.0), le_long)
			if pont_local != Vector2.INF and absf(local.y - pont_local.y) < 90.0:
				continue
			# `local` est le point de contact au sol : le nœud est `PIED` au-dessus.
			_placer(id, a + local.rotated(rot) - Vector2(0.0, PIED), 16.0, 1.0, 0.0, false, true)


# --- Le décor d'origine : la ruine et l'éboulis ------------------------------
#
# Repris de `decor_scatter.gd`, qu'ils remplacent : même empreinte, même pente,
# mêmes rôles. Leurs pièces restent dans leur parcelle (règle 8).

func _zone_ruine(ancre: Vector2, taille: int) -> void:
	var axe := _d() * TAU
	if taille == PETIT:
		for i in _entre(1, 2):
			var debout: StringName = _dans(RUINE_MUR)
			_vieux(debout, ancre + Vector2.RIGHT.rotated(axe) * (float(i) * MODULE * 0.85))
		_remplir(ancre, axe, Vector2(70.0, 60.0), RUINE_SOL, _entre(1, 2))
		return
	var mods_x := 2 if taille == MOYEN else _entre(3, 4)
	var mods_y := 2 if taille == MOYEN else _entre(2, 3)
	var erosion := lerpf(0.30, 0.62, _d())
	var demi := Vector2(float(mods_x), float(mods_y)) * MODULE * 0.5
	for iy in mods_y + 1:
		for ix in mods_x + 1:
			if not (ix == 0 or iy == 0 or ix == mods_x or iy == mods_y):
				continue
			var tombe := _d()
			var d_coin := _d()
			var mur: StringName = _dans(RUINE_MUR)
			if tombe < erosion:
				continue
			var coin := (ix == 0 or ix == mods_x) and (iy == 0 or iy == mods_y)
			var id: StringName = RUINE_COIN if coin and d_coin < 0.45 else mur
			var local := Vector2(float(ix), float(iy)) * MODULE - demi
			local += Vector2(_d() - 0.5, _d() - 0.5) * 26.0
			_vieux(id, ancre + local.rotated(axe))
	_remplir(ancre, axe, demi * 1.7, RUINE_SOL, _entre(1, 2))
	if taille < GRAND:
		return
	var coeur := _d()
	var id_coeur: StringName = _dans(RUINE_COEUR)
	if coeur < 0.55:
		_vieux(id_coeur, ancre)
	_remplir(ancre, axe, demi * 1.5, POTERIE, _entre(1, 2))
	_remplir(ancre, axe, demi * 2.1, VEGETATION, _entre(0, 2))


func _remplir(ancre: Vector2, axe: float, demi: Vector2, role: Array, nombre: int) -> void:
	for _i in nombre:
		var id: StringName = _dans(role)
		var p := Vector2((_d() - 0.5) * demi.x * 2.0, (_d() - 0.5) * demi.y * 2.0)
		_vieux(id, ancre + p.rotated(axe))


## L'ÉBOULIS DE LA PROFONDEUR : la même pente que celui de la surface — têtes
## en haut, débris de plus en plus petits et écartés vers le bas — mais en roche
## noire et en obsidienne, sur lesquelles couvent encore des braises. Les pièces
## se serrent sans se chevaucher : trois pierres qui se touchent font une chose.
func _eboulis_noir(a: Vector2, taille: int) -> void:
	var pente := _d() * TAU
	if taille == PETIT:
		var tete := _placer(_dans(OBSIDIENNES), a, 40.0)
		_au_pied(tete, ECLATS_NOIRS, _entre(1, 2))
		return
	var longueur: float = lerpf(220.0, 320.0, _d()) if taille == MOYEN \
		else lerpf(300.0, 430.0, _d())
	for _i in (1 if taille == MOYEN else _entre(1, 2)):
		_placer(_dans(OBSIDIENNES), a + Vector2((_d() - 0.5) * 90.0, (_d() - 0.5) * 70.0),
			40.0, 1.0, 0.0, false, true)
	var nombre: int = _entre(4, 6) if taille == MOYEN else _entre(7, 10)
	for i in nombre:
		var t := (float(i) + _d()) / float(nombre)
		var gros: StringName = _dans(ROCHES_LAVE)
		var moyen: StringName = _dans(ROCHERS)
		var petit: StringName = _dans(ECLATS_NOIRS)
		var id: StringName = gros if t < 0.35 else (moyen if t < 0.7 else petit)
		var travers := (_d() - 0.5) * 2.0 * (45.0 + t * 120.0)
		var p := Vector2.RIGHT.rotated(pente) * (t * longueur) \
			+ Vector2.DOWN.rotated(pente) * travers
		_placer(id, a + p, 30.0, 1.0, 0.0, false, true)
	if taille == GRAND:
		_semer(a, Vector2(longueur * 0.6, 150.0), FISSURES, _entre(1, 2))
		_semer(a, Vector2(longueur * 0.6, 150.0), PLANTES_FEU, _entre(0, 1))
		# Des cristaux runiques dressés au sommet de la pente, en repère.
		_placer(_dans(CRISTAUX), a - Vector2.RIGHT.rotated(pente) * 130.0, 60.0)


func _zone_rochers(ancre: Vector2, taille: int) -> void:
	var pente := _d() * TAU
	if taille == PETIT:
		_vieux(ROCHE_TETE, ancre)
		for _i in _entre(1, 2):
			var id: StringName = _dans(ROCHE_PETIT)
			var p := Vector2.RIGHT.rotated(_d() * TAU) * lerpf(75.0, 140.0, _d())
			_vieux(id, ancre + p)
		return
	var longueur: float = lerpf(220.0, 320.0, _d()) if taille == MOYEN \
		else lerpf(300.0, 430.0, _d())
	var tetes: int = 1 if taille == MOYEN else _entre(1, 2)
	for _i in tetes:
		var t := Vector2((_d() - 0.5) * 90.0, (_d() - 0.5) * 70.0)
		_vieux(ROCHE_TETE, ancre + t)
	var nombre: int = _entre(4, 6) if taille == MOYEN else _entre(7, 10)
	for i in nombre:
		var t := (float(i) + _d()) / float(nombre)
		var gros: StringName = _dans(ROCHE_GROS)
		var moyen: StringName = _dans(ROCHE_MOYEN)
		var petit: StringName = _dans(ROCHE_PETIT)
		var id: StringName = gros if t < 0.35 else (moyen if t < 0.7 else petit)
		var travers := (_d() - 0.5) * 2.0 * (45.0 + t * 120.0)
		var p := Vector2.RIGHT.rotated(pente) * (t * longueur) \
			+ Vector2.DOWN.rotated(pente) * travers
		_vieux(id, ancre + p)
	if taille == GRAND:
		for _i in _entre(0, 2):
			var id: StringName = _dans(VEGETATION)
			var le_long := _d() * longueur
			var cote: float = (1.0 if _d() < 0.5 else -1.0) * lerpf(140.0, 220.0, _d())
			var p := Vector2.RIGHT.rotated(pente) * le_long \
				+ Vector2.DOWN.rotated(pente) * cote
			_vieux(id, ancre + p)


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
## place (règles 6 à 8). Pour les MARQUES au sol : le reste a un rôle.
func _semer(a: Vector2, demi: Vector2, role: Array, nombre: int) -> void:
	for _i in nombre:
		var id: StringName = _dans(role)
		var p := Vector2((_d() - 0.5) * demi.x * 2.0, (_d() - 0.5) * demi.y * 2.0)
		_placer(id, a + p, 40.0, 1.0, _quart() if EnferDB.est_plate(id) else 0.0)


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
			if not _zone.encloses(rect) and int(info["sol"]) != EnferDB.SOL_PLAQUE:
				return false
			if not _plat_permis(id, rect, int(info["sol"])):
				return false
			if int(info["sol"]) != EnferDB.SOL_PLAQUE and id not in PONTS:
				marques.append(rect)
		else:
			var f := pied_de(pose)
			if not _pied_permis(f, tolerance, pieds, laves):
				return false
			if not info.get("creux", false):
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
	for pose: Dictionary in poses:
		_poses.append(pose)
	return true


## Règles 6 à 8 pour une pièce dressée : dans sa parcelle, hors de la lave, sans
## marcher sur le pied d'une autre.
func _pied_permis(f: Dictionary, tolerance: float, du_bloc: Array[Dictionary],
		laves_du_bloc: Array[Rect2]) -> bool:
	var c: Vector2 = f["c"]
	var rx: float = f["rx"]
	var ry: float = f["ry"]
	if not _zone.encloses(Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0)):
		return false
	for rect: Rect2 in _laves + laves_du_bloc:
		if rect.grow_individual(rx * 0.8, ry * 0.8, rx * 0.8, ry * 0.8).has_point(c):
			return false
	for autre: Dictionary in _pieds + du_bloc:
		if chevauchent(f, autre, tolerance):
			return false
	return true


## Une marque au sol ne recouvre pas une autre marque, ni la lave. Une plaque
## (roche refroidie, dallage) peut s'étendre sous tout, sauf le dallage, qui n'a
## rien à faire sous la lave.
func _plat_permis(id: StringName, rect: Rect2, couche: int) -> bool:
	if couche == EnferDB.SOL_PLAQUE:
		if id == &"plaque_lave":
			return true
		for lave: Rect2 in _laves:
			if lave.intersects(rect):
				return false
		return true
	if id in PONTS:
		return true
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
## blocs différents ne se touchent pas non plus (celles d'une même rivière, si).
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


## Pose une pièce du décor d'origine. Elle ne bloque ni ne brûle ; elle reste
## seulement dans sa parcelle (règle 8), et son pied est retenu.
func _vieux(id: StringName, p: Vector2) -> void:
	var ech: float = DECOR_ECHELLE_PIECE.get(id, DECOR_ECHELLE)
	var miroir := DECOR_MIROIR.has(id) and _d() < 0.5
	var pose := {"id": id, "p": p, "e": ech, "r": 0.0, "fh": miroir, "fv": false,
		"vieux": true}
	var f := pied_de(pose)
	var c: Vector2 = f["c"]
	if not _zone.has_point(c):
		return
	_pieds.append(f)
	_poses.append(pose)


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
static func mesurer(id: StringName, texture: Texture2D) -> void:
	tailles[id] = Vector2(texture.get_width(), texture.get_height())
	var img := texture.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
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
## Centré sur le nœud (voir EnferDB, clé "c").
static func forme_obstacle(pose: Dictionary) -> Dictionary:
	var dims: Vector2 = pose["mur"] if pose.has("mur") else EnferDB.obstacle(pose["id"])
	var p: Vector2 = pose["p"]
	var demi := Vector2(dims.x, 0.0).rotated(float(pose["r"]))
	return {"a": p - demi, "b": p + demi, "r": dims.y}


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
