class_name EnferDB
extends Object
## Le catalogue des pièces de la carte : ce que chacune BLOQUE, BRÛLE, ÉCLAIRE,
## et à quelle couche elle se dessine.
##
## Les images sortent du pack 2DML SET 3 (Szadi art) par
## `tools/extract_enfer.py`, qui en garde les rectangles de découpe et compose
## les terrains. Ici ne vit que ce que le jeu doit savoir d'elles — la carte ne
## lit jamais une image pour deviner un rôle, sauf la lave (voir
## `Carte._masque_lave`).
##
## LES CLÉS D'UNE PIÈCE, toutes facultatives :
##   "c"     obstacle ROND, rayon en pixels du monde. Centré sur le PIED mesuré
##           dans l'image (voir `GenerateurCarte.forme_obstacle`) : les objets
##           du pack portent leur ombre vers la droite, leur base n'est pas au
##           milieu de l'image.
##   "k"     obstacle ALLONGÉ (capsule horizontale) : Vector2(demi-longueur,
##           rayon). Pour les pièces larges et peu profondes.
##   "sol"   pièce PLATE : dessinée sous toutes les créatures, sans tri en Y. La
##           valeur est sa couche (voir SOL_*). Un plateau est plat ET bloque :
##           on ne peut jamais se tenir derrière lui, donc rien n'a à passer
##           dessous ; son obstacle est centré sur l'image.
##   "lave"  la pièce brûle ce qui marche dessus. La forme brûlante est lue dans
##           l'image elle-même, pixel par pixel : elle suit le dessin exactement.
##   "feu"   pixels incandescents : ils vacillent (shader), rien de plus.
##   "lueur" la pièce ÉCLAIRE : rayon de sa lumière, en pixels du monde. Couleur
##           de lave par défaut ; "flamme" pour la couleur du feu, qui vacille.
##   "braises" des braises s'en élèvent.
##   "anim"  planche d'images de 32 px : Vector3i(colonnes, rangées, images
##           utiles), jouée à `ANIM_IPS` images par seconde.
##
## LES OMBRES SONT DANS LES PLANCHES. Chaque objet du pack porte la sienne,
## dessinée vers la droite : la carte n'ajoute plus d'ombre de contact, qui
## ferait double emploi.
##
## POURQUOI CES PIÈCES-LÀ BLOQUENT. Le joueur doit pouvoir le deviner d'un coup
## d'œil, donc la règle est une règle de FORME et non de liste : tout ce qui est
## dressé et plus haut que lui bloque — cheminées, formations rocheuses, arbres
## morts, plateaux. Tout ce qui est bas ou à plat se traverse — cailloux, trous,
## herbes, buissons, fissures, la petite cheminée qui lui arrive à la taille.

## Échelle d'affichage. Le pack est du VRAI pixel art, sur une grille nette (à
## la différence de l'ancien, qui n'en imitait que l'apparence) : un facteur
## entier, 2, met une cheminée à 104 px et un arbre mort à 140, pour un joueur
## de 84.
const ECHELLE := 2.0

## Couches des pièces plates, du bas vers le haut. Toutes sous les créatures
## (0), sous les zones annoncées et les jauges (-1, -2), au-dessus du sol (-100).
const SOL_MARQUE := -60   ## fissures
const SOL_OMBRE := -59    ## ombres de contact (plus utilisées par ce pack)
const SOL_LAVE := -56     ## bassins, lacs, fosses
const SOL_BULLE := -55    ## bulles, posées sur la lave
const SOL_RELIEF := -52   ## plateaux : au-dessus de tout le sol
const BRAISES := -3       ## braises : au-dessus du sol, sous les zones annoncées

## LA TEINTE DE CHAQUE ÉTAGE, la même pour le carreau de sol et pour TOUTES les
## pièces du pack : ils ont été peints ensemble, les teinter différemment
## casserait leur accord — et la bordure de sol d'un bassin se découperait sur
## le carreau voisin. La lave, elle, garde sa couleur (voir `Carte.SHADER_FEU`).
## Réglée pour retrouver à l'écran la teinte des étages d'avant : pierre froide
## en surface, rouge en profondeur (README, « On part de la pierre froide »).
const TEINTE_SURFACE := Color(0.61, 0.67, 0.68)
const TEINTE_PROFONDEUR := Color(0.84, 0.63, 0.53)

## Images par seconde des pièces animées.
const ANIM_IPS := 7.0

const CHEMIN := "res://assets/sprites/enfer/%s.png"

const PIECES := {
	# --- Cheminées volcaniques ------------------------------------------------
	&"cheminee_a": {"c": 26.0},
	&"cheminee_b": {"c": 22.0},
	&"cheminee_c": {"c": 17.0},
	&"cheminees_trio": {"c": 40.0},
	&"cheminees_grappe": {"c": 34.0},
	&"cheminee_haute": {"c": 25.0},
	&"cheminees_paire": {"c": 43.0},
	&"cheminees_duo": {"c": 24.0},
	# Elle arrive à la taille du joueur : on la contourne des yeux, pas du corps.
	&"cheminee_petite": {},
	# --- Formations rocheuses -------------------------------------------------
	&"aiguille": {"c": 20.0},
	&"rocher_creuse": {"c": 33.0},
	&"bloc_troue": {"c": 22.0},
	&"menhir": {"c": 25.0},
	&"rocher_penche": {"c": 27.0},
	&"falaise": {"k": Vector2(26.0, 38.0)},
	&"dome": {"c": 38.0},
	&"colosse": {"c": 43.0},
	&"galet": {},
	# --- Arbres morts : bloquent au tronc -------------------------------------
	&"arbre_a": {"c": 14.0},
	&"arbre_b": {"c": 14.0},
	&"arbre_c": {"c": 14.0},
	&"arbre_mauve_a": {"c": 14.0},
	&"arbre_mauve_b": {"c": 14.0},
	&"arbre_mauve_c": {"c": 14.0},
	# --- Petits objets : se traversent ----------------------------------------
	&"caillou_a": {},
	&"caillou_b": {},
	&"caillou_c": {},
	&"gravier_a": {},
	&"gravier_b": {},
	&"trou_a": {},
	&"trou_b": {},
	&"trou_c": {},
	&"trou_d": {},
	&"herbe_a": {},
	&"herbe_b": {},
	&"herbe_c": {},
	&"herbe_seche_a": {},
	&"herbe_seche_b": {},
	&"herbe_seche_c": {},
	&"buisson_rouge_a": {},
	&"buisson_rouge_b": {},
	&"buisson_rouge_c": {},
	&"buisson_olive_a": {},
	&"buisson_olive_b": {},
	&"buisson_olive_c": {},
	&"buisson_sombre_a": {},
	&"buisson_sombre_b": {},
	&"buisson_sombre_c": {},
	# Des cratères qui fument : six images, la dernière rangée à moitié vide.
	&"fumerolle_a": {"anim": Vector3i(4, 2, 6)},
	&"fumerolle_b": {"anim": Vector3i(4, 2, 6)},
	&"fumerolle_c": {"anim": Vector3i(4, 2, 6)},
	&"fumerolle_d": {"anim": Vector3i(4, 2, 6)},

	# --- Pièces plates --------------------------------------------------------
	&"fissure_cadre": {"sol": SOL_MARQUE, "feu": true, "lueur": 150.0},
	&"fissure_longue": {"sol": SOL_MARQUE, "feu": true, "lueur": 90.0},
	&"sol_fendu": {"sol": SOL_MARQUE, "feu": true},
	&"bassin_6x6": {"sol": SOL_LAVE, "lave": true, "lueur": 230.0, "braises": true},
	&"bassin_7x6": {"sol": SOL_LAVE, "lave": true, "lueur": 250.0, "braises": true},
	&"lac_8x7": {"sol": SOL_LAVE, "lave": true, "lueur": 260.0, "braises": true},
	&"lac_10x8": {"sol": SOL_LAVE, "lave": true, "lueur": 280.0, "braises": true},
	&"fosse_12x6": {"sol": SOL_LAVE, "lave": true, "lueur": 230.0, "braises": true},
	&"fosse_6x12": {"sol": SOL_LAVE, "lave": true, "lueur": 230.0, "braises": true},
	&"bulle_a": {"sol": SOL_BULLE, "anim": Vector3i(4, 4, 9)},
	&"bulle_b": {"sol": SOL_BULLE, "anim": Vector3i(4, 4, 9)},
	&"plateau_6x6": {"sol": SOL_RELIEF, "c": 140.0},
	&"plateau_7x6": {"sol": SOL_RELIEF, "k": Vector2(30.0, 140.0)},
	&"plateau_b_6x6": {"sol": SOL_RELIEF, "c": 140.0},
}


static func teinte(profond: bool) -> Color:
	return TEINTE_PROFONDEUR if profond else TEINTE_SURFACE


static func chemin(id: StringName) -> String:
	return CHEMIN % id


static func info(id: StringName) -> Dictionary:
	return PIECES.get(id, {})


static func est_plate(id: StringName) -> bool:
	return info(id).has("sol")


static func est_solide(id: StringName) -> bool:
	var i := info(id)
	return i.has("c") or i.has("k")


## Planche animée : Vector3i(colonnes, rangées, images), ou Vector3i.ZERO.
static func anim(id: StringName) -> Vector3i:
	return info(id).get("anim", Vector3i.ZERO)


## Demi-étendue d'un obstacle (capsule horizontale) : Vector2(demi-longueur,
## rayon). Un cercle a une demi-longueur nulle. Vector2.ZERO si la pièce se
## traverse.
static func obstacle(id: StringName) -> Vector2:
	var i := info(id)
	if i.has("k"):
		return i["k"]
	if i.has("c"):
		return Vector2(0.0, float(i["c"]))
	return Vector2.ZERO
