# -*- coding: utf-8 -*-
"""Decoupe le pack Hell Underworld Tileset en pieces pour le generateur de carte.

LE PACK N'EST PAS UN TILESET AU SENS STRICT
-------------------------------------------
Cinq planches de 768 x 768, sans aucune tuile de transition entre terrains :
des objets poses ou ils tiennent (monuments, supplices, laves, damnes), plus
quelques carres de sol opaques. Rien dans le pack ne dit ou est quoi. Les
rectangles ci-dessous ont ete releves en detectant les ilots de pixels opaques,
puis identifies sur des agrandissements quadrilles — comme les icones d'objets,
c'est la partie de ce fichier qu'il ne faut PAS perdre.

CE N'EST PAS DU PIXEL ART PROPRE
--------------------------------
Mesure : deux pixels voisins ont presque toujours des couleurs differentes, et
aucune phase de grille (2, 3 ou 4 px) ne se distingue des autres. Le dessin imite
un pixel art d'environ 2 px de planche par pixel, mais sans grille reguliere.
On NE le reduit donc PAS de moitie (ca le brouillerait) : les pieces sont
extraites telles quelles et affichees a 1,5, ce qui met ce pseudo-pixel a 3 px
d'ecran — la taille du pixel de tout le reste du jeu.

ISOLER UNE PIECE
----------------
Les planches sont serrees : le rectangle d'une piece deborde souvent sur le bord
adouci de sa voisine. Chaque piece est donc MASQUEE apres decoupe :
  "c"  le rectangle est la boite exacte d'un ilot : on ne garde que cet ilot ;
  "r"  rectangle releve a la main : on garde le plus grand ilot, plus tous ceux
       qui tiennent entierement dans le rectangle (une cage a plusieurs pieces,
       deux moities de rocher). Ce qui touche le bord appartient au voisin ;
  "a"  tout le rectangle (fissures fines, faites de morceaux epars) ;
  "o"  carre de sol opaque, copie tel quel (textures et dalles) ;
  "f"  carre de sol opaque dont on FOND LES BORDS (voir `PLAQUES`) ;
  "l"  troncon de riviere : la berge est fondue selon la distance a la lave
       (voir `_rive`) ; "lr" fait d'abord le tri des ilots de "r".
Les pixels a demi transparents qui bordent un ilot garde sont conserves : c'est
l'anticrenelage du dessin, sans lui la piece aurait un contour en escalier.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import decode, encode

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "assets", "packs", "Hell Underworld Tileset")
OUT = os.path.join(ROOT, "assets", "sprites", "enfer")

# Seuil d'opacite d'un ilot. En dessous, c'est de l'anticrenelage : il suit
# l'ilot qu'il borde, il n'en fait pas un a lui seul.
SEUIL = 24

# (identifiant, planche, x, y, largeur, hauteur, mode)
PIECES = [
    # --- B-01 : terrains, petits objets ---------------------------------------
    ("feu_camp",        1, 584,  13, 32, 31, "c"),
    ("pierre_rune_a",   1, 632,   4, 31, 40, "c"),
    ("braise_petite",   1, 683,  14, 27, 23, "c"),
    ("caillou_noir",    1, 734,  15, 21, 22, "c"),
    ("braises",         1, 582,  65, 36, 24, "c"),
    ("stalagmites_a",   1, 628,  49, 40, 46, "c"),
    ("stalagmite_a",    1, 683,  50, 26, 46, "c"),
    ("stalagmite_b",    1, 729,  56, 29, 35, "c"),
    ("stalagmite_c",    1, 682, 104, 28, 40, "c"),
    ("arbre_mort",      1, 731,  98, 26, 46, "c"),
    ("racines_a",       1, 724, 147, 41, 44, "c"),
    ("os_a",            1, 724, 198, 38, 38, "c"),
    ("os_b",            1, 725, 250, 39, 32, "c"),
    ("racines_b",       1, 677, 292, 39, 43, "c"),
    ("racines_c",       1, 725, 290, 39, 46, "c"),
    ("racines_d",       1, 676, 338, 40, 46, "c"),
    ("roche_braise",    1, 724, 348, 40, 34, "c"),
    ("tas_braise",      1, 680, 400, 33, 23, "c"),
    ("os_c",            1, 672, 434, 48, 48, "r"),
    ("feu_camp_b",      1, 721, 428, 47, 52, "r"),
    ("carcasse",        1, 675, 486, 42, 37, "c"),
    ("os_d",            1, 673, 529, 47, 48, "c"),
    ("pierre_rune_b",   1, 295, 675, 34, 42, "c"),
    ("pierre_rune_c",   1, 247, 724, 36, 44, "c"),
    ("pierre_rune_d",   1, 295, 721, 34, 47, "c"),
    ("pierre_rune_e",   1, 242, 674, 44, 46, "r"),
    ("stalagmites_b",   1, 341, 674, 38, 45, "c"),
    ("stalagmite_d",    1, 395, 674, 27, 46, "c"),
    ("ronces",          1, 436, 674, 41, 46, "c"),
    ("os_e",            1, 481, 677, 46, 42, "c"),
    ("feu_camp_c",      1, 528, 678, 48, 42, "c"),
    ("stalagmites_c",   1, 345, 726, 29, 40, "c"),
    # Dalles gravees : des carreaux de sol, poses a plat.
    ("dalle_rune_a",    1, 576,  96, 48, 48, "o"),
    ("dalle_rune_b",    1, 624,  96, 48, 48, "o"),
    ("dalle_rune_c",    1, 576, 144, 48, 48, "o"),
    ("dalle_rune_d",    1, 624, 144, 48, 48, "o"),
    # Le soufre (planche B-01 en (384, 384) et (480, 192)) n'est pas repris :
    # jaune vif, il se lisait comme des mines d'or.
    # Plaques de sol, fondues au bord : la lave refroidie qui cerne un bassin,
    # l'etoile de fissures, les dalles d'un sanctuaire (le motif de 96 px est
    # repete 3 x 3 avant d'etre fondu, voir `PLAQUES`).
    ("plaque_lave",     1,   0, 158, 144, 128, "f"),
    ("etoile_fissure",  4, 479,   0,  98,  97, "f"),
    ("plaque_dallage",  1, 384, 192,  96,  96, "f"),

    # --- B-04 : la lave -------------------------------------------------------
    ("volcan",          4, 392,  13, 80, 81, "c"),
    ("anneau_roches",   4, 583,  29, 82, 60, "c"),
    ("volcan_actif",    4, 582, 124, 84, 65, "c"),
    ("bassin_trefle",   4, 391, 296, 82, 80, "c"),
    ("bassin_croix",    4, 486, 295, 83, 84, "c"),
    ("flaque_a",        4, 583, 296, 35, 31, "c"),
    ("flaque_b",        4, 631, 298, 34, 31, "c"),
    ("flaque_c",        4, 583, 346, 32, 34, "c"),
    ("flaque_d",        4, 632, 344, 34, 32, "c"),
    ("flaque_e",        4, 391, 488, 33, 33, "c"),
    ("flaque_f",        4, 439, 536, 33, 33, "c"),
    ("obsidienne_a",    4, 678,   2, 36, 46, "c"),
    ("plante_feu",      4, 682,  51, 28, 43, "c"),
    ("cristal_feu",     4, 725,  51, 39, 43, "c"),
    ("coupe_feu_a",     4, 680,  99, 32, 45, "c"),
    ("coupe_feu_b",     4, 724,  98, 40, 45, "c"),
    ("coupe_braise",    4, 677, 165, 38, 25, "c"),
    ("coupe_feu_c",     4, 728, 152, 32, 40, "c"),
    ("roche_lave_a",    4, 675, 200, 42, 37, "c"),
    ("roche_lave_b",    4, 723, 194, 42, 45, "c"),
    ("roche_lave_c",    4, 674, 247, 44, 39, "c"),
    ("roche_lave_d",    4, 723, 243, 42, 43, "c"),
    ("obsidienne_b",    4, 677, 290, 36, 44, "c"),
    ("eclats",          4, 722, 292, 35, 27, "c"),
    ("rochers_a",       4, 579, 440, 42, 36, "c"),
    ("rochers_b",       4, 628, 437, 40, 41, "c"),
    ("rochers_c",       4, 580, 484, 40, 42, "c"),
    ("rochers_d",       4, 631, 482, 37, 44, "c"),
    ("coupe_feu_d",     4, 725, 485, 39, 41, "c"),
    ("rochers_e",       4, 579, 536, 42, 32, "c"),
    ("rochers_f",       4, 628, 532, 42, 42, "c"),
    ("coupe_feu_e",     4, 677, 532, 37, 42, "c"),
    ("coupe_feu_f",     4, 725, 538, 38, 36, "c"),
    ("obsidienne_c",    4, 578, 582, 44, 39, "c"),
    ("obsidienne_d",    4, 631, 579, 34, 43, "c"),
    ("torchere_a",      4, 489, 676, 31, 43, "c"),
    ("torchere_b",      4, 537, 678, 31, 41, "c"),
    ("braise_ronde",    4, 395, 734, 26, 23, "c"),
    ("obsidienne_e",    4, 484, 723, 40, 44, "c"),
    ("obsidienne_f",    4, 533, 725, 38, 42, "c"),
    # Fissures : dessinees sur un carre de sol opaque, donc fondues au bord.
    ("fissure_b",       4, 240, 432, 48, 48, "f"),
    ("fissure_c",       4, 288, 432, 48, 48, "f"),
    ("fissure_e",       4, 192, 480, 48, 48, "f"),
    ("fissure_f",       4, 240, 480, 48, 48, "f"),
    ("fissure_g",       4, 288, 480, 48, 48, "f"),
    ("fissure_h",       4, 336, 480, 48, 48, "f"),
    ("fissure_i",       4, 384, 624, 48, 48, "f"),
    # Rivieres : bords coupes net, a coiffer d'un bassin a chaque bout.
    ("riviere_droite",  4,  96, 192, 96, 288, "l"),
    ("riviere_courte",  4, 288,   0, 96, 192, "l"),
    ("riviere_coude",   4,   0,   0, 192, 192, "lr"),
    ("riviere_lacet",   4,   0, 480, 144, 288, "r"),

    # --- B-05 : monuments -----------------------------------------------------
    ("gargouille_a",    5,   8,   2, 32, 93, "c"),
    ("gargouille_b",    5,  49,   2, 46, 93, "c"),
    ("statuette_a",     5, 105,   3, 30, 44, "c"),
    ("statuette_b",     5,  97,  52, 46, 43, "c"),
    ("statue_voilee",   5, 146,   3, 44, 92, "c"),
    ("gargouille_c",    5, 193,   2, 46, 93, "c"),
    ("gargouille_d",    5, 241,   2, 45, 93, "c"),
    ("gargouille_grande", 5, 294, 3, 84, 92, "c"),
    ("buste_demon",     5, 391,   2, 82, 93, "c"),
    ("idole_braise",    5, 483,   4, 90, 91, "c"),
    ("obelisque_a",     5, 581,   4, 41, 91, "c"),
    ("obelisque_b",     5, 626,  15, 41, 80, "c"),
    ("baphomet",        5, 688,   5, 65, 90, "c"),
    ("gardien",         5,   2,  99, 45, 92, "c"),
    ("crane_os",        5,  49,  98, 46, 43, "c"),
    ("crane_a",         5,  58, 154, 28, 27, "c"),
    ("statue_taureau",  5, 116,  99, 60, 92, "c"),
    ("autel_demon",     5, 202,  99, 76, 91, "c"),
    ("autel_squelette", 5, 295,  99, 82, 91, "c"),
    ("cercle_pics",     5, 388,  98, 89, 93, "c"),
    ("foyer",           5, 490, 110, 76, 81, "r"),
    ("puits_lave",      5, 579, 106, 90, 82, "c"),
    ("aiguilles",       5, 674,  98, 92, 92, "c"),
    ("gargouille_assise_a", 5, 13, 195, 71, 91, "c"),
    ("gargouille_assise_b", 5, 104, 194, 80, 92, "c"),
    ("autel_os",        5, 193, 194, 94, 92, "c"),
    ("relief",          5, 290, 194, 92, 92, "c"),
    ("golem_a",         5, 387, 195, 90, 91, "r"),
    ("obelisque_c",     5, 486, 195, 40, 91, "c"),
    ("obelisque_d",     5, 530, 195, 40, 91, "c"),
    ("golem_b",         5, 581, 197, 86, 89, "c"),
    ("bassin_braise",   5, 675, 231, 91, 55, "c"),
    ("gargouille_petite_a", 5, 7, 304, 34, 78, "c"),
    ("gargouille_petite_b", 5, 53, 307, 36, 75, "c"),
    ("gargouille_socle", 5, 109, 291, 70, 91, "c"),
    ("autel_squelette_b", 5, 200, 291, 81, 90, "c"),
    ("gargouille_penseur", 5, 302, 290, 68, 92, "c"),
    ("golem_c",         5, 387, 290, 90, 92, "r"),
    ("golem_d",         5, 485, 290, 86, 92, "c"),
    ("obelisque_e",     5, 584, 291, 40, 91, "c"),
    ("obelisque_f",     5, 628, 306, 36, 77, "c"),
    ("cratere_a",       5, 674, 290, 93, 93, "c"),
    ("aiguilles_b",     5,   6, 386, 84, 93, "c"),
    ("statue_bouc",     5, 117, 395, 54, 83, "c"),
    ("obelisque_g",     5, 197, 386, 41, 92, "c"),
    ("obelisque_h",     5, 241, 386, 41, 93, "c"),
    ("chaudron_a",      5, 295, 406, 81, 69, "c"),
    ("chaudron_b",      5, 386, 404, 92, 75, "c"),
    ("chaudron_c",      5, 482, 395, 93, 80, "c"),
    ("fosse_a",         5, 578, 388, 92, 91, "c"),
    ("fosse_b",         5, 674, 394, 93, 85, "c"),
    ("pics_a",          5,   1, 500, 46, 75, "c"),
    ("pics_b",          5,  48, 482, 46, 57, "c"),
    ("eboulis_noir",    5,  48, 541, 47, 34, "c"),
    ("estrade_defenses", 5, 97, 486, 94, 90, "c"),
    ("porte_os",        5, 193, 484, 94, 88, "c"),
    ("estrade_cranes",  5, 289, 488, 94, 88, "c"),
    ("estrade_arc",     5, 385, 484, 94, 87, "c"),
    ("estrade_fissures", 5, 481, 484, 94, 90, "c"),
    ("pont_a",          5, 577, 508, 94, 48, "c"),
    ("pont_b",          5, 673, 500, 95, 56, "c"),
    ("cristaux_runes_a", 5, 5, 578, 85, 93, "c"),
    ("cristaux_runes_b", 5, 107, 579, 74, 92, "c"),
    ("brasier",         5, 196, 583, 87, 88, "c"),
    ("bucher",          5, 294, 585, 84, 86, "r"),
    ("cratere_b",       5, 386, 578, 92, 93, "c"),
    ("pics_lave",       5, 482, 585, 92, 79, "c"),
    ("rocher_fendu",    5, 576, 576, 96, 96, "r"),
    ("cratere_c",       5, 673, 578, 95, 92, "r"),
    ("gargouille_assise_c", 5, 1, 676, 94, 92, "c"),
    ("pentagramme",     5, 103, 681, 82, 83, "c"),
    ("sceau",           5, 198, 675, 84, 92, "c"),
    ("trone_a",         5, 303, 674, 66, 94, "c"),
    ("trone_b",         5, 401, 673, 62, 95, "c"),
    ("trone_c",         5, 496, 673, 64, 95, "c"),
    ("crane_b",         5, 602, 739, 20, 23, "c"),
    ("crane_c",         5, 626, 739, 20, 23, "c"),
    ("crane_bouc",      5, 684, 734, 29, 32, "c"),

    # --- B-03 : supplices -----------------------------------------------------
    ("chevalet",        3,   2,  31, 92, 63, "c"),
    ("pilori",          3,  98,  41, 92, 53, "c"),
    ("potence",         3, 194,   8, 92, 88, "c"),
    ("roue_a",          3, 292,   0, 87, 96, "c"),
    ("roue_b",          3, 388,   2, 88, 94, "c"),
    ("echelle",         3, 495,   5, 67, 91, "c"),
    ("chaise_pointes",  3, 592,   1, 64, 95, "c"),
    ("trone_pointes",   3, 689,   4, 62, 92, "c"),
    ("vierge_fermee",   3,   0, 192, 48, 96, "r"),
    ("vierge_ouverte",  3,  49, 194, 46, 95, "c"),
    ("boite_pointes",   3, 100, 200, 88, 88, "r"),
    ("boite_bois",      3, 202, 219, 76, 70, "c"),
    ("cage_petite",     3, 100, 288, 88, 96, "r"),
    ("cage_grande",     3, 210, 289, 60, 95, "c"),
    ("barreaux_a",      3, 300, 289, 73, 95, "c"),
    ("barreaux_b",      3, 387, 289, 90, 95, "c"),
    ("geole_porte_a",   3, 485, 289, 86, 95, "c"),
    ("geole_mur",       3, 582, 289, 84, 95, "c"),
    ("geole_porte_b",   3, 680, 289, 80, 95, "c"),
    ("torche_a",        3,  11, 386, 33, 94, "c"),
    ("torche_b",        3,  54, 386, 31, 94, "c"),
    ("torche_c",        3,  98, 386, 29, 94, "c"),
    ("guillotine",      3, 578, 390, 92, 86, "c"),
    ("hachoir",         3, 486, 386, 86, 93, "c"),
    ("presse",          3,   2, 482, 91, 94, "c"),
    ("meule",           3, 385, 485, 86, 88, "c"),
    ("banc_pointes",    3, 576, 488, 96, 82, "c"),
    ("portique",        3, 682, 483, 76, 93, "c"),
    ("chaise_supplice", 3, 113, 577, 61, 95, "c"),
    ("trone_rouge",     3, 596, 578, 56, 94, "c"),
    ("trone_rouge_pointes", 3, 692, 580, 56, 92, "c"),
    ("vierge_sang",     3, 407, 674, 50, 94, "c"),
    ("lit_pointes",     3, 292, 680, 88, 88, "c"),
    ("lame",            3, 484, 674, 88, 94, "c"),
    ("chaise_pointes_b", 3, 595, 674, 58, 94, "c"),

    # --- B-02 : les damnes, seulement ENFERMES --------------------------------
    # Un damne libre, dresse au milieu du sol, se lit comme un ennemi : on n'en
    # garde que ceux qu'une cage, des pieux ou un bucher retiennent. Les
    # fantomes et les demons de la planche sont ecartes pour la meme raison.
    ("cage_ame_a",      2, 578,   0, 92, 97, "c"),
    ("cage_ame_b",      2, 386, 192, 92, 96, "c"),
    ("cage_ame_c",      2, 482, 192, 92, 97, "c"),
    ("cage_ame_d",      2, 578, 480, 92, 97, "c"),
    ("boule_pointes",   2, 491, 109, 74, 68, "c"),
    ("pieux_ame",       2, 576, 114, 96, 79, "c"),
    ("bucher_ame",      2, 480, 576, 96, 96, "r"),
]

# Les textures de sol, repetees a l'infini par le shader du sol (regions). Un
# carreau repete doit se raccorder a lui-meme : ces recadrages sont ceux qui
# ramenent l'ecart aux joints SOUS le bruit interne du carreau, trouves en
# essayant toutes les positions (voir le README, « La carte »).
#
#   pave sombre, carre de 192 brut   joints 6,5 / 5,5 pour un bruit de 3,9
#   pave sombre, (424, 2) en 144     joints 2,4 / 2,2          -> invisible
#   dallage de temple, 96 brut       joints 3,1 / 2,7, bruit 7,7 -> invisible
#   lave craquelee, (2, 158) en 96   joints 5,6 / 6,0, bruit 13,4 -> invisible
TEXTURES = [
    ("tex_pave_sombre",     1, 424,   2, 144, 144),
    ("tex_dallage",         1, 384, 192,  96,  96),
    ("tex_lave_refroidie",  1,   2, 158,  96,  96),
]

# Plaques fondues : (repetitions en x, en y) du motif avant le fondu. Par
# defaut 1 x 1. Le fondu suit une ellipse dont le bord est bruite : une plaque
# carree se lirait comme un carrelage colle sur le sol.
PLAQUES = {
    "plaque_dallage": (3, 3),
}

_planches = {}


def _planche(n):
    if n not in _planches:
        _planches[n] = decode(os.path.join(PACK, "tile-B-%02d.png" % n))
    return _planches[n]


def _ilots(px, w, h):
    """Etiquette les ilots opaques (4-connexite) -> (etiquettes, [(taille, touche_bord)])."""
    lab = [0] * (w * h)
    infos = [None]
    for i in range(w * h):
        if lab[i] or px[i][3] <= SEUIL:
            continue
        n = len(infos)
        lab[i] = n
        pile = [i]
        taille = 0
        bord = False
        while pile:
            j = pile.pop()
            x, y = j % w, j // w
            taille += 1
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                bord = True
            for k, ok in ((j - 1, x > 0), (j + 1, x < w - 1), (j - w, y > 0), (j + w, y < h - 1)):
                if ok and not lab[k] and px[k][3] > SEUIL:
                    lab[k] = n
                    pile.append(k)
        infos.append((taille, bord))
    return lab, infos


def _bruit(x, y, graine):
    """Bruit de valeur lisse dans [0, 1], deux octaves."""
    def h(ix, iy):
        n = (ix * 73856093) ^ (iy * 19349663) ^ (graine * 83492791)
        n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0

    def v(x, y):
        ix, iy = int(x // 1), int(y // 1)
        fx, fy = x - ix, y - iy
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a, b = h(ix, iy), h(ix + 1, iy)
        c, d = h(ix, iy + 1), h(ix + 1, iy + 1)
        return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy

    return v(x, y) * 0.65 + v(x * 2.3, y * 2.3) * 0.35


def _fondre(w, h, px, graine):
    """Fond les bords d'un carre opaque : ellipse au contour bruite."""
    out = []
    for i in range(w * h):
        x, y = i % w, i // w
        u = (x + 0.5) / w * 2.0 - 1.0
        v = (y + 0.5) / h * 2.0 - 1.0
        e = 1.0 - (u * u + v * v) ** 0.5
        e += (_bruit(x / 14.0, y / 14.0, graine) - 0.5) * 0.45
        t = max(0.0, min(1.0, e / 0.28))
        t = t * t * (3 - 2 * t)
        p = px[i]
        out.append((p[0], p[1], p[2], int(p[3] * t)))
    return out


def _lave(p):
    """Critere de couleur de la lave, le meme que `Carte._masque_lave`."""
    r, g, b, a = p
    return a > 128 and r > 160 and g > 50 and b < 110 and r > g * 1.25


# La berge gardee autour de la lave, en pixels de planche : pleine jusqu'a
# RIVE_PLEINE, effacee a RIVE_FIN.
RIVE_PLEINE = 7.0
RIVE_FIN = 17.0


def _rive(w, h, px, graine):
    """Fond la berge d'un troncon de riviere.

    Les troncons sont des rectangles opaques : leur berge grise se decoupait en
    bords droits sur le sol de l'arene, et chaque raccord dessinait un carre
    (vu en capture). On ne garde qu'une bordure de roche autour de la lave,
    effacee en fondu selon la distance a la lave — distance de chanfrein 3-4 —
    avec un bruit pour que le bord ne soit pas un trait parallele au courant.
    """
    inf = 10 ** 6
    d = [0 if _lave(px[i]) else inf for i in range(w * h)]
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if x > 0:
                d[i] = min(d[i], d[i - 1] + 3)
            if y > 0:
                d[i] = min(d[i], d[i - w] + 3)
                if x > 0:
                    d[i] = min(d[i], d[i - w - 1] + 4)
                if x < w - 1:
                    d[i] = min(d[i], d[i - w + 1] + 4)
    for y in range(h - 1, -1, -1):
        for x in range(w - 1, -1, -1):
            i = y * w + x
            if x < w - 1:
                d[i] = min(d[i], d[i + 1] + 3)
            if y < h - 1:
                d[i] = min(d[i], d[i + w] + 3)
                if x < w - 1:
                    d[i] = min(d[i], d[i + w + 1] + 4)
                if x > 0:
                    d[i] = min(d[i], d[i + w - 1] + 4)
    out = []
    for i in range(w * h):
        x, y = i % w, i // w
        dist = d[i] / 3.0 + (_bruit(x / 9.0, y / 9.0, graine) - 0.5) * 6.0
        t = max(0.0, min(1.0, (RIVE_FIN - dist) / (RIVE_FIN - RIVE_PLEINE)))
        p = px[i]
        out.append((p[0], p[1], p[2], int(p[3] * t)))
    return out


def _decouper(n, x0, y0, w, h, mode, ident=""):
    _, _, rows = _planche(n)
    if mode.startswith("l"):
        w2, h2, px = _decouper(n, x0, y0, w, h, "r" if mode == "lr" else "o", ident)
        return w2, h2, _rive(w2, h2, px, 7)
    px = [rows[y0 + y][x0 + x] for y in range(h) for x in range(w)]
    if mode == "f":
        rx, ry = PLAQUES.get(ident, (1, 1))
        if rx > 1 or ry > 1:
            px = [px[(y % h) * w + (x % w)] for y in range(h * ry) for x in range(w * rx)]
            w, h = w * rx, h * ry
        return _rogner(w, h, _fondre(w, h, px, sum(map(ord, ident))))
    if mode in ("o", "a"):
        return w, h, px
    lab, infos = _ilots(px, w, h)
    if len(infos) == 1:
        return w, h, px
    plus_grand = max(range(1, len(infos)), key=lambda i: infos[i][0])
    garder = {plus_grand}
    if mode == "r":
        garder |= {i for i in range(1, len(infos)) if not infos[i][1] and infos[i][0] >= 12}
    # Un pixel faible est garde s'il touche un pixel garde : c'est le bord
    # adouci de la piece, pas un morceau de la voisine.
    out = []
    for i in range(w * h):
        x, y = i % w, i // w
        if lab[i] in garder:
            out.append(px[i])
            continue
        if lab[i] == 0 and px[i][3] > 0:
            voisin = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and lab[yy * w + xx] in garder:
                    voisin = True
                    break
            if voisin:
                out.append(px[i])
                continue
        out.append((0, 0, 0, 0))
    return _rogner(w, h, out)


def _rogner(w, h, px):
    xs = [i % w for i in range(w * h) if px[i][3] > 0]
    ys = [i // w for i in range(w * h) if px[i][3] > 0]
    if not xs:
        return w, h, px
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    nw, nh = x1 - x0 + 1, y1 - y0 + 1
    return nw, nh, [px[(y0 + y) * w + x0 + x] for y in range(nh) for x in range(nw)]


def _ecrire(chemin, w, h, px):
    rows = [px[y * w:(y + 1) * w] for y in range(h)]
    open(chemin, "wb").write(encode(w, h, rows))


def extraire():
    """-> (pieces ecrites, attendues), ou (0, attendues) si le pack manque."""
    if not os.path.isdir(PACK):
        return 0, len(PIECES) + len(TEXTURES)
    os.makedirs(os.path.join(OUT, "sol"), exist_ok=True)
    faites = 0
    for ident, n, x, y, w, h, mode in PIECES:
        pw, ph, px = _decouper(n, x, y, w, h, mode, ident)
        _ecrire(os.path.join(OUT, ident + ".png"), pw, ph, px)
        faites += 1
    for ident, n, x, y, w, h in TEXTURES:
        pw, ph, px = _decouper(n, x, y, w, h, "o")
        _ecrire(os.path.join(OUT, "sol", ident + ".png"), pw, ph, px)
        faites += 1
    return faites, len(PIECES) + len(TEXTURES)


if __name__ == "__main__":
    faites, attendues = extraire()
    print("enfer : %d pieces sur %d" % (faites, attendues))
