class_name EnferDB
extends Object
## Le catalogue des pièces de la carte : ce que chacune BLOQUE, BRÛLE, ÉCLAIRE,
## et à quelle couche elle se dessine.
##
## Les images sortent du pack Hell Underworld Tileset par
## `tools/extract_enfer.py`, qui en garde les rectangles de découpe. Ici ne vit
## que ce que le jeu doit savoir d'elles — la carte ne lit jamais une image pour
## deviner un rôle, sauf la lave (voir `Carte._masque_lave`).
##
## LES CLÉS D'UNE PIÈCE, toutes facultatives :
##   "c"     obstacle ROND, rayon en pixels du monde. Centré sur le nœud, c'est-à-
##           dire `Carte.PIED` au-dessus de la base dessinée : le même repère que
##           les créatures, dont l'origine est à mi-corps.
##   "k"     obstacle ALLONGÉ (capsule horizontale) : Vector2(demi-longueur,
##           rayon). Pour les pièces larges et peu profondes — un chevalet, un mur
##           de geôle — qu'un cercle rendrait bien trop hautes.
##   "sol"   pièce PLATE : dessinée sous toutes les créatures, sans tri en Y. La
##           valeur est sa couche (voir SOL_*).
##   "lave"  la pièce brûle ce qui marche dessus. La forme brûlante est lue dans
##           l'image elle-même, pixel par pixel : elle suit le dessin exactement.
##   "feu"   pixels incandescents : ils vacillent (shader), rien de plus.
##   "lueur" la pièce ÉCLAIRE : rayon de sa lumière, en pixels du monde. Couleur
##           de lave par défaut ; "flamme" pour la couleur du feu, qui vacille.
##   "braises" des braises s'en élèvent.
##   "fixe"  symétrie interdite : la pièce porte une gravure ou un texte, qu'un
##           miroir trahirait.
##   "creux" la pièce entoure un vide où d'autres peuvent se poser (un anneau de
##           roches autour de ses braises) : son pied ne compte pas.
##
## POURQUOI CES PIÈCES-LÀ BLOQUENT. Le joueur doit pouvoir le deviner d'un coup
## d'œil, donc la règle est une règle de FORME et non de liste : tout ce qui est
## gros et dressé bloque — statues, obélisques, autels, trônes, cratères,
## chaudrons, machines de supplice, cages, murs. Tout ce qui est petit ou à plat
## se traverse — os, pierres, braseros, torches, stèles basses, fissures. Deux
## exceptions assumées, parce qu'on y passe DESSOUS : la potence et le portique,
## des cadres ouverts.

## Échelle d'affichage. Le pack imite un pixel art d'environ 2 px de planche par
## pixel, sans grille régulière (mesuré : aucune phase ne se distingue). À 1,5,
## ce pseudo-pixel mesure 3 px d'écran — la taille du pixel de tout le reste du
## jeu, personnages et décor compris.
const ECHELLE := 1.5

## Couches des pièces plates, du bas vers le haut. Toutes sous les créatures
## (0), sous les zones annoncées et les jauges (-1, -2), au-dessus du sol (-100).
const SOL_PLAQUE := -62   ## plaques de sol fondues
const SOL_MARQUE := -60   ## fissures, dalles, sceaux, estrades
const SOL_OMBRE := -59    ## ombres de contact et ombres portées
const SOL_RIVIERE := -56  ## tronçons de rivière
const SOL_LAVE := -55     ## bassins : ils coiffent les bouts des rivières
const SOL_PONT := -52     ## ponts, posés sur la lave
const BRAISES := -3       ## braises : au-dessus du sol, sous les zones annoncées

const CHEMIN := "res://assets/sprites/enfer/%s.png"

const PIECES := {
	# --- Petits objets : se traversent -------------------------------------
	&"feu_camp": {"feu": true, "lueur": 160.0, "flamme": true},
	&"feu_camp_b": {"feu": true, "lueur": 160.0, "flamme": true},
	&"feu_camp_c": {"feu": true, "lueur": 160.0, "flamme": true},
	&"braises": {"feu": true, "lueur": 70.0},
	&"tas_braise": {"feu": true, "lueur": 70.0},
	&"braise_petite": {"feu": true},
	&"braise_ronde": {"feu": true},
	&"pierre_rune_a": {"fixe": true},
	&"pierre_rune_b": {"fixe": true},
	&"pierre_rune_c": {"fixe": true},
	&"pierre_rune_d": {"fixe": true},
	&"pierre_rune_e": {"fixe": true},
	&"caillou_noir": {},
	&"stalagmites_a": {},
	&"stalagmites_b": {},
	&"stalagmites_c": {},
	&"stalagmite_a": {},
	&"stalagmite_b": {},
	&"stalagmite_c": {},
	&"stalagmite_d": {},
	&"arbre_mort": {},
	&"racines_a": {},
	&"racines_b": {},
	&"racines_c": {},
	&"racines_d": {},
	&"ronces": {},
	&"roche_braise": {"feu": true},
	&"os_a": {},
	&"os_b": {},
	&"os_c": {},
	&"os_d": {},
	&"os_e": {},
	&"carcasse": {},
	&"crane_os": {},
	&"crane_a": {},
	&"crane_b": {},
	&"crane_c": {},
	&"crane_bouc": {},
	&"statuette_a": {},
	&"statuette_b": {},
	&"eboulis_noir": {},
	&"anneau_roches": {"creux": true},
	&"obsidienne_a": {},
	&"obsidienne_b": {},
	&"obsidienne_c": {},
	&"obsidienne_d": {},
	&"obsidienne_e": {},
	&"obsidienne_f": {},
	&"plante_feu": {"feu": true},
	&"cristal_feu": {"feu": true},
	&"coupe_feu_a": {"feu": true, "lueur": 160.0, "flamme": true},
	&"coupe_feu_b": {"feu": true, "lueur": 160.0, "flamme": true},
	&"coupe_feu_c": {"feu": true, "lueur": 160.0, "flamme": true},
	&"coupe_feu_d": {"feu": true, "lueur": 160.0, "flamme": true},
	&"coupe_feu_e": {"feu": true, "lueur": 160.0, "flamme": true},
	&"coupe_feu_f": {"feu": true, "lueur": 160.0, "flamme": true},
	&"coupe_braise": {"feu": true, "lueur": 80.0},
	&"torchere_a": {"feu": true, "lueur": 140.0, "flamme": true},
	&"torchere_b": {"feu": true, "lueur": 140.0, "flamme": true},
	&"torche_a": {"feu": true, "lueur": 140.0, "flamme": true},
	&"torche_b": {"feu": true, "lueur": 140.0, "flamme": true},
	&"torche_c": {"feu": true, "lueur": 140.0, "flamme": true},
	&"roche_lave_a": {"feu": true},
	&"roche_lave_b": {"feu": true},
	&"roche_lave_c": {"feu": true},
	&"roche_lave_d": {"feu": true},
	&"rochers_a": {},
	&"rochers_b": {},
	&"rochers_c": {},
	&"rochers_d": {},
	&"rochers_e": {},
	&"rochers_f": {},
	&"eclats": {},
	&"boule_pointes": {},
	# Cadres ouverts : on passe dessous.
	&"potence": {},
	&"portique": {},
	&"porte_os": {},

	# --- Pièces plates ------------------------------------------------------
	&"plaque_lave": {"sol": SOL_PLAQUE, "feu": true, "lueur": 110.0},
	&"plaque_dallage": {"sol": SOL_PLAQUE, "fixe": true},
	&"etoile_fissure": {"sol": SOL_MARQUE, "feu": true},
	&"fissure_b": {"sol": SOL_MARQUE, "feu": true},
	&"fissure_c": {"sol": SOL_MARQUE, "feu": true},
	&"fissure_e": {"sol": SOL_MARQUE, "feu": true},
	&"fissure_f": {"sol": SOL_MARQUE, "feu": true},
	&"fissure_g": {"sol": SOL_MARQUE, "feu": true},
	&"fissure_h": {"sol": SOL_MARQUE, "feu": true},
	&"fissure_i": {"sol": SOL_MARQUE, "feu": true},
	&"dalle_rune_a": {"sol": SOL_MARQUE, "fixe": true},
	&"dalle_rune_b": {"sol": SOL_MARQUE, "fixe": true},
	&"dalle_rune_c": {"sol": SOL_MARQUE, "fixe": true},
	&"dalle_rune_d": {"sol": SOL_MARQUE, "fixe": true},
	&"pentagramme": {"sol": SOL_MARQUE, "fixe": true, "feu": true},
	&"sceau": {"sol": SOL_MARQUE, "fixe": true, "feu": true},
	&"relief": {"sol": SOL_MARQUE, "fixe": true},
	&"estrade_defenses": {"sol": SOL_MARQUE},
	&"estrade_cranes": {"sol": SOL_MARQUE},
	&"estrade_arc": {"sol": SOL_MARQUE},
	&"estrade_fissures": {"sol": SOL_MARQUE, "feu": true},
	&"bassin_trefle": {"sol": SOL_LAVE, "lave": true, "lueur": 170.0, "braises": true},
	&"bassin_croix": {"sol": SOL_LAVE, "lave": true, "lueur": 170.0, "braises": true},
	&"flaque_a": {"sol": SOL_LAVE, "lave": true, "lueur": 90.0},
	&"flaque_b": {"sol": SOL_LAVE, "lave": true, "lueur": 90.0},
	&"flaque_c": {"sol": SOL_LAVE, "lave": true, "lueur": 90.0},
	&"flaque_d": {"sol": SOL_LAVE, "lave": true, "lueur": 90.0},
	&"flaque_e": {"sol": SOL_LAVE, "lave": true, "lueur": 90.0},
	&"flaque_f": {"sol": SOL_LAVE, "lave": true, "lueur": 90.0},
	&"riviere_droite": {"sol": SOL_RIVIERE, "lave": true, "lueur": 130.0, "braises": true},
	&"riviere_courte": {"sol": SOL_RIVIERE, "lave": true, "lueur": 130.0, "braises": true},
	&"riviere_coude": {"sol": SOL_RIVIERE, "lave": true, "lueur": 150.0, "braises": true},
	&"pont_a": {"sol": SOL_PONT},
	&"pont_b": {"sol": SOL_PONT},

	# --- Monuments : bloquent ------------------------------------------------
	&"gargouille_a": {"c": 17.0},
	&"gargouille_b": {"c": 20.0},
	&"gargouille_c": {"c": 22.0},
	&"gargouille_d": {"c": 22.0},
	&"gargouille_grande": {"c": 28.0},
	&"gargouille_assise_a": {"c": 26.0},
	&"gargouille_assise_b": {"c": 26.0},
	&"gargouille_assise_c": {"c": 30.0},
	&"gargouille_petite_a": {"c": 16.0},
	&"gargouille_petite_b": {"c": 16.0},
	&"gargouille_socle": {"c": 24.0},
	&"gargouille_penseur": {"c": 28.0},
	&"statue_voilee": {"c": 19.0},
	&"statue_taureau": {"c": 22.0},
	&"statue_bouc": {"c": 22.0},
	&"gardien": {"c": 20.0},
	&"buste_demon": {"c": 38.0, "fixe": true},
	&"baphomet": {"c": 28.0},
	&"obelisque_a": {"c": 20.0, "fixe": true},
	&"obelisque_b": {"c": 20.0, "fixe": true},
	&"obelisque_c": {"c": 20.0, "fixe": true},
	&"obelisque_d": {"c": 20.0, "fixe": true},
	&"obelisque_e": {"c": 20.0, "fixe": true},
	&"obelisque_f": {"c": 18.0, "fixe": true},
	&"obelisque_g": {"c": 20.0, "fixe": true},
	&"obelisque_h": {"c": 20.0, "fixe": true},
	&"autel_demon": {"c": 38.0, "fixe": true},
	&"autel_squelette": {"c": 40.0, "fixe": true},
	&"autel_squelette_b": {"c": 40.0, "fixe": true},
	&"autel_os": {"c": 44.0},
	&"trone_a": {"c": 26.0},
	&"trone_b": {"c": 26.0},
	&"trone_c": {"c": 26.0},
	&"idole_braise": {"c": 34.0, "feu": true, "lueur": 150.0},
	&"golem_a": {"c": 32.0, "feu": true, "lueur": 150.0},
	&"golem_b": {"c": 30.0, "feu": true, "lueur": 150.0},
	&"golem_c": {"c": 32.0, "feu": true, "lueur": 150.0},
	&"golem_d": {"c": 30.0, "feu": true, "lueur": 150.0},
	&"volcan": {"c": 40.0, "feu": true, "lueur": 170.0},
	&"volcan_actif": {"c": 40.0, "feu": true, "lueur": 170.0, "braises": true},
	&"cratere_a": {"c": 46.0, "feu": true, "lueur": 160.0, "braises": true},
	&"cratere_b": {"c": 44.0, "feu": true, "lueur": 160.0, "braises": true},
	&"cratere_c": {"c": 46.0, "feu": true, "lueur": 160.0, "braises": true},
	&"fosse_a": {"c": 46.0, "feu": true, "lueur": 160.0, "braises": true},
	&"fosse_b": {"c": 46.0, "feu": true, "lueur": 160.0, "braises": true},
	&"puits_lave": {"c": 40.0, "feu": true, "lueur": 160.0},
	&"cercle_pics": {"c": 44.0, "feu": true, "lueur": 140.0},
	&"foyer": {"c": 34.0, "feu": true, "lueur": 250.0, "flamme": true, "braises": true},
	&"pics_lave": {"c": 30.0, "feu": true, "lueur": 110.0},
	&"rocher_fendu": {"c": 44.0, "feu": true, "lueur": 110.0},
	&"bassin_braise": {"c": 40.0, "feu": true, "lueur": 160.0},
	&"chaudron_a": {"c": 36.0, "feu": true, "lueur": 150.0},
	&"chaudron_b": {"c": 38.0, "feu": true, "lueur": 150.0},
	&"chaudron_c": {"c": 40.0, "feu": true, "lueur": 150.0},
	&"aiguilles": {"c": 44.0},
	&"aiguilles_b": {"c": 40.0},
	&"pics_a": {"c": 24.0},
	&"pics_b": {"c": 24.0},
	&"cristaux_runes_a": {"c": 38.0, "fixe": true},
	&"cristaux_runes_b": {"c": 36.0, "fixe": true},
	&"brasier": {"c": 40.0, "feu": true, "lueur": 250.0, "flamme": true, "braises": true},
	&"bucher": {"c": 36.0, "feu": true, "lueur": 250.0, "flamme": true, "braises": true},
	# Supplices.
	&"chevalet": {"k": Vector2(42.0, 20.0)},
	&"pilori": {"k": Vector2(34.0, 18.0)},
	&"roue_a": {"c": 34.0},
	&"roue_b": {"c": 34.0},
	&"echelle": {"k": Vector2(30.0, 18.0)},
	&"chaise_pointes": {"c": 24.0},
	&"chaise_pointes_b": {"c": 22.0},
	&"trone_pointes": {"c": 24.0},
	&"trone_rouge": {"c": 22.0},
	&"trone_rouge_pointes": {"c": 24.0},
	&"chaise_supplice": {"c": 26.0},
	&"vierge_fermee": {"c": 22.0},
	&"vierge_ouverte": {"c": 22.0},
	&"vierge_sang": {"c": 24.0},
	&"boite_pointes": {"k": Vector2(36.0, 20.0)},
	&"boite_bois": {"k": Vector2(36.0, 20.0)},
	&"guillotine": {"k": Vector2(44.0, 20.0)},
	&"hachoir": {"k": Vector2(42.0, 20.0)},
	&"presse": {"k": Vector2(38.0, 22.0)},
	&"meule": {"c": 26.0},
	&"banc_pointes": {"k": Vector2(44.0, 20.0)},
	&"lit_pointes": {"k": Vector2(44.0, 22.0)},
	&"lame": {"k": Vector2(40.0, 20.0)},
	&"cage_grande": {"c": 28.0},
	&"barreaux_a": {"k": Vector2(36.0, 14.0)},
	&"barreaux_b": {"k": Vector2(48.0, 14.0)},
	&"geole_porte_a": {"k": Vector2(46.0, 18.0), "fixe": true},
	&"geole_mur": {"k": Vector2(46.0, 18.0), "fixe": true},
	&"geole_porte_b": {"k": Vector2(44.0, 18.0), "fixe": true},
	&"cage_ame_a": {"k": Vector2(44.0, 22.0)},
	&"cage_ame_b": {"k": Vector2(44.0, 22.0)},
	&"cage_ame_c": {"k": Vector2(44.0, 22.0)},
	&"cage_ame_d": {"k": Vector2(44.0, 22.0)},
	&"pieux_ame": {"k": Vector2(50.0, 22.0)},
	&"bucher_ame": {"c": 38.0, "feu": true, "lueur": 250.0, "flamme": true, "braises": true},
}


static func chemin(id: StringName) -> String:
	return CHEMIN % id


static func info(id: StringName) -> Dictionary:
	return PIECES.get(id, {})


static func est_plate(id: StringName) -> bool:
	return info(id).has("sol")


static func est_solide(id: StringName) -> bool:
	var i := info(id)
	return i.has("c") or i.has("k")


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
