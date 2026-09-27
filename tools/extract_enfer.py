# -*- coding: utf-8 -*-
"""Decoupe le pack 2DML SET 3 (Szadi art) en pieces pour le generateur de carte.

LE PACK
-------
Un decor volcanique en vrai pixel art, sur une trame de 32 px :
  mainlevbuild.png      les TERRAINS : un bassin de lave borde de falaises, des
                        plateaux rocheux, leurs bords ardents, des sols a
                        carreler, des taches de sol, des fissures ;
  decorative_props.png  les OBJETS : cheminees volcaniques, formations
                        rocheuses, arbres morts, cailloux, herbes, buissons ;
  anim/                 fumerolles et bulles de lave, en planches d'images ;
  other_props.png       des conteneurs metalliques a voyants verts : HORS SUJET
                        dans un enfer, ecartes comme l'etaient les caisses et
                        les panneaux du pack Texture.

Il remplace en 0.9.2 le pack Hell Underworld Tileset, retire parce que son
auteur l'avait produit avec une IA (README, « La carte de l'enfer »).

LES TERRAINS SE COMPOSENT
-------------------------
Le bassin et les plateaux sont des blocs de 8 x 8 tuiles faits pour etre
assembles : coins arrondis, bords, angles rentrants. On ne les decoupe pas tels
quels, on en COMPOSE des pieces de la taille voulue (voir `_composer`) : les
coins du bloc, ses bords repetes, et au milieu la tuile de remplissage — lave
pleine pour un bassin, dessus de roche pour un plateau. Les angles rentrants
(la croix du milieu du bloc) ne servent pas : une piece composee est un
rectangle aux coins arrondis.

L'ARRONDI D'UN COIN DE BASSIN COURT SUR TROIS TUILES, pas deux : seules les
tuiles 3 et 4 de chaque bord sont droites et se repetent. La premiere version
coupait les coins a deux tuiles et tronquait l'arrondi — des bassins en goutte,
des encoches de falaise sur les bords (vu sur planche de controle). Un bassin
fait donc 6 tuiles au moins. Les plateaux aussi, pour la meme raison (coupes
a deux tuiles, ils sortaient en pointe) : ce sont les plus gros obstacles du
jeu, rares.

LE PLATEAU ARDENT (bords de lave sur fond vide) EST ECARTE : son dessus a la
couleur exacte du sol, pose par terre on ne voyait que ses bords, et il se
lisait comme un trou plutot que comme un obstacle.

ILS ONT UNE PERSPECTIVE. La paroi de falaise est dessinee sur le bord HAUT d'un
bassin et sur le bord BAS d'un plateau : une piece tournee d'un quart de tour
mettrait la falaise sur le cote. Les fosses allongees existent donc dans les
deux sens, et le generateur ne les tourne jamais.

LE SOL QUI BORDE UN BASSIN EST FONDU (voir `_fondre_sol`) : le bloc porte une
tuile de sol tout autour de la lave, qui se decouperait en rectangle sur le
carreau du jeu. Elle s'efface selon la distance a la falaise et a la lave.

ISOLER UN OBJET
---------------
Comme pour l'ancien pack, les rectangles ont ete releves en detectant les ilots
de pixels opaques puis identifies sur une planche numerotee. Chaque objet est
MASQUE apres decoupe :
  "c"  on garde le plus grand ilot, plus ceux qui tiennent entierement dans le
       rectangle (une ombre detachee, deux moities de rocher) ;
  "a"  tout le rectangle (gravier, fait de morceaux epars) ;
  "f"  une fissure sur fond de sol : le sol s'efface loin de la fissure.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import decode, encode

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "assets", "packs", "2DML_SET3_v1.0")
OUT = os.path.join(ROOT, "assets", "sprites", "enfer")

SEUIL = 24
T = 32

# (identifiant, planche, x, y, largeur, hauteur, mode)
PIECES = [
    # --- Cheminees volcaniques : bloquent -----------------------------------
    ("cheminee_a",        "deco",   7,   6, 51, 58, "c"),
    ("cheminee_b",        "deco",  78,   0, 39, 52, "c"),
    ("cheminee_c",        "deco", 143,  15, 38, 41, "c"),
    ("cheminee_petite",   "deco", 192,  32, 32, 32, "c"),
    ("cheminees_trio",    "deco", 228,   8, 56, 49, "c"),
    ("cheminees_grappe",  "deco", 290,  15, 62, 67, "c"),
    ("cheminee_haute",    "deco", 365,   3, 39, 59, "c"),
    ("cheminees_paire",   "deco", 417,   1, 62, 63, "c"),
    ("cheminees_duo",     "deco",   7,  70, 51, 52, "c"),
    # --- Roches -------------------------------------------------------------
    ("aiguille",          "deco",  64,  80, 30, 48, "c"),
    ("galet",             "deco", 110,  97, 36, 25, "c"),
    ("rocher_creuse",     "deco", 162,  64, 58, 48, "c"),
    ("bloc_troue",        "deco", 236,  80, 41, 37, "c"),
    ("menhir",            "deco", 299,  96, 42, 57, "c"),
    ("rocher_penche",     "deco", 352,  95, 63, 63, "c"),
    ("falaise",           "deco", 419,  69, 84, 90, "c"),
    ("dome",              "deco", 448, 160, 59, 62, "c"),
    ("colosse",           "deco", 448, 247, 64, 104, "c"),
    # --- Arbres morts ---------------------------------------------------------
    ("arbre_a",           "deco",   7, 163, 42, 61, "c"),
    ("arbre_b",           "deco",  79, 170, 40, 54, "c"),
    ("arbre_c",           "deco", 143, 154, 40, 70, "c"),
    ("arbre_mauve_a",     "deco",   7, 259, 42, 61, "c"),
    ("arbre_mauve_b",     "deco",  79, 266, 40, 54, "c"),
    ("arbre_mauve_c",     "deco", 143, 250, 40, 70, "c"),
    # --- Petits objets : se traversent ----------------------------------------
    ("caillou_a",         "deco", 270, 172, 18, 17, "c"),
    ("caillou_b",         "deco", 353, 174, 16, 16, "c"),
    ("caillou_c",         "deco", 327, 209, 12, 11, "c"),
    ("gravier_a",         "deco", 305, 176, 44, 30, "a"),
    ("gravier_b",         "deco", 324, 207, 48, 30, "a"),
    ("trou_a",            "deco",  41, 350, 31, 19, "c"),
    ("trou_b",            "deco",  41, 389, 31, 21, "c"),
    ("trou_c",            "deco",  76, 382, 26, 16, "c"),
    ("trou_d",            "deco",  78, 365, 20, 14, "c"),
    ("herbe_a",           "deco", 259, 288, 11, 13, "c"),
    ("herbe_b",           "deco", 232, 331, 14, 13, "c"),
    ("herbe_c",           "deco", 357, 325, 14, 15, "c"),
    ("herbe_seche_a",     "deco", 287, 369, 11, 15, "c"),
    ("herbe_seche_b",     "deco", 356, 389, 14, 15, "c"),
    ("herbe_seche_c",     "deco", 231, 395, 14, 13, "c"),
    ("buisson_rouge_a",   "deco",   0, 418, 32, 30, "c"),
    ("buisson_rouge_b",   "deco",  98, 416, 28, 29, "c"),
    ("buisson_rouge_c",   "deco", 132, 422, 25, 20, "c"),
    ("buisson_olive_a",   "deco",   0, 450, 32, 30, "c"),
    ("buisson_olive_b",   "deco",  98, 448, 28, 29, "c"),
    ("buisson_olive_c",   "deco", 132, 454, 25, 20, "c"),
    ("buisson_sombre_a",  "deco",   0, 482, 32, 30, "c"),
    ("buisson_sombre_b",  "deco",  98, 480, 28, 29, "c"),
    ("buisson_sombre_c",  "deco", 132, 486, 25, 20, "c"),
    # --- Fissures ardentes, sur fond de sol qu'on efface ------------------------
    ("fissure_cadre",     "niv",  640, 256, 192, 160, "f"),
    ("fissure_longue",    "niv",  640, 416,  64, 128, "f"),
    ("sol_fendu",         "niv",  640, 160, 160,  64, "f"),
]

# Les TACHES de sol de la planche (colonnes 1184 et 1568) sont ecartees : des
# formes en fleur aux bords reguliers, qui se lisaient comme un tampon pose sur
# le sol plutot que comme un sol. Le carreau a deja ses regions (FloorTiler).

# Terrains composes. Un bloc : (x, y, tuiles de coin, x et y de la tuile de
# remplissage). 
BLOC_BASSIN = (256, 0, 3, 256 + 96, 32)
BLOC_PLATEAU = (0, 512, 3, 96, 512 + 96)
BLOC_PLATEAU_B = (0, 768, 3, 96, 768 + 96)
COMPOSES = [
    ("bassin_6x6",       BLOC_BASSIN, 6, 6),
    ("bassin_7x6",       BLOC_BASSIN, 7, 6),
    ("lac_8x7",          BLOC_BASSIN, 8, 7),
    ("lac_10x8",         BLOC_BASSIN, 10, 8),
    ("fosse_12x6",       BLOC_BASSIN, 12, 6),
    ("fosse_6x12",       BLOC_BASSIN, 6, 12),
    ("plateau_6x6",      BLOC_PLATEAU, 6, 6),
    ("plateau_7x6",      BLOC_PLATEAU, 7, 6),
    ("plateau_b_6x6",    BLOC_PLATEAU_B, 6, 6),
]

# Animations : copiees telles quelles, en planches de 32 x 32. Le nombre
# d'images utiles est dans le catalogue du jeu (EnferDB).
ANIMS = [
    ("fumerolle_a", "rocksmoke1"), ("fumerolle_b", "rocksmoke2"),
    ("fumerolle_c", "rocksmoke3"), ("fumerolle_d", "rocksmoke4"),
    ("bulle_a", "volc_bubble1"), ("bulle_b", "volc_bubble2"),
]

# Carreaux de sol (dossier sol/), mesures sans couture : ecart au joint sous
# le bruit interne (README).
TEXTURES = [
    ("tex_sol", 640, 0, 192, 160),        # le sol que borde le bassin : meme couleur
    ("tex_brun", 832, 416, 128, 96),      # regions de la surface
    ("tex_rouge", 832, 288, 128, 96),     # regions de la profondeur
]

_planches = {}


def _planche(nom):
    if nom not in _planches:
        fichier = {"deco": "decorative_props.png", "niv": "mainlevbuild.png"}[nom]
        _planches[nom] = decode(os.path.join(PACK, fichier))
    return _planches[nom]


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


def _garder_ilots(px, w, h):
    lab, infos = _ilots(px, w, h)
    if len(infos) <= 2:
        return px
    plus_grand = max(range(1, len(infos)), key=lambda i: infos[i][0])
    garder = {plus_grand} | {i for i in range(1, len(infos))
                             if not infos[i][1] and infos[i][0] >= 12}
    out = []
    for i in range(w * h):
        x, y = i % w, i // w
        if lab[i] in garder:
            out.append(px[i])
            continue
        # Un pixel faible qui touche un pixel garde est le bord adouci de la
        # piece, pas un morceau de la voisine.
        if lab[i] == 0 and px[i][3] > 0:
            if any(0 <= x + dx < w and 0 <= y + dy < h and lab[(y + dy) * w + x + dx] in garder
                   for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                out.append(px[i])
                continue
        out.append((0, 0, 0, 0))
    return out


def _lave(p):
    """Critere de couleur de la lave, le meme que `Carte._masque_lave`."""
    r, g, b, a = p
    return a > 128 and r > 160 and g > 50 and b < 110 and r > g * 1.25


def _sol(p):
    """Le sol gris du pack (72/71/75 et ses nuances), ni falaise ni lave."""
    r, g, b, a = p
    return a > 128 and 56 <= r <= 90 and abs(r - g) <= 6 and b >= g - 2 and b - r <= 12


def _distance(w, h, source):
    """Distance de chanfrein (3-4, en px /3) de chaque pixel au plus proche `source`."""
    INF = 10 ** 9
    d = [0 if source[i] else INF for i in range(w * h)]
    for y in range(h):
        for x in range(w):
            i = y * w + x
            for dx, dy, c in ((-1, 0, 3), (0, -1, 3), (-1, -1, 4), (1, -1, 4)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h:
                    d[i] = min(d[i], d[yy * w + xx] + c)
    for y in range(h - 1, -1, -1):
        for x in range(w - 1, -1, -1):
            i = y * w + x
            for dx, dy, c in ((1, 0, 3), (0, 1, 3), (1, 1, 4), (-1, 1, 4)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h:
                    d[i] = min(d[i], d[yy * w + xx] + c)
    return [v / 3.0 for v in d]


def _fondre_sol(w, h, px, plein, fin):
    """Efface le sol gris selon sa distance a ce qui n'est pas du sol : plein
    jusqu'a `plein` px, transparent a `fin`. Ce qui n'est pas du sol reste."""
    source = [px[i][3] > 128 and not _sol(px[i]) for i in range(w * h)]
    d = _distance(w, h, source)
    out = []
    for i in range(w * h):
        r, g, b, a = px[i]
        if source[i] or a == 0:
            out.append(px[i])
            continue
        t = 1.0 - min(1.0, max(0.0, (d[i] - plein) / (fin - plein)))
        out.append((r, g, b, int(a * t)))
    return out


def _decouper(planche, x0, y0, w, h, mode):
    _, _, rows = _planche(planche)
    px = [rows[y0 + y][x0 + x] for y in range(h) for x in range(w)]
    if mode == "c":
        px = _garder_ilots(px, w, h)
    elif mode == "f":
        # Une fissure : on garde les traits rouges et un liseré sombre autour.
        rouge = [p[3] > 128 and p[0] > 120 and p[0] > p[1] * 1.4 for p in px]
        d = _distance(w, h, rouge)
        px = [(p[0], p[1], p[2], int(p[3] * (1.0 - min(1.0, max(0.0, (d[i] - 2.0) / 5.0)))))
              for i, p in enumerate(px)]
    return _rogner(w, h, px)


def _composer(bloc, tw, th):
    """Compose un terrain de tw x th tuiles depuis un bloc de 8 x 8 tuiles."""
    bx, by, coin, fx, fy = bloc
    _, _, rows = _planche("niv")
    w, h = tw * T, th * T
    out = [(0, 0, 0, 0)] * (w * h)

    def source(i, n):
        if i < coin:
            return i
        if i >= n - coin:
            return i - n + 8
        return coin + (i - coin) % (8 - 2 * coin)

    for j in range(th):
        sy = source(j, th)
        for i in range(tw):
            sx = source(i, tw)
            # Le milieu du bloc porte la croix des angles rentrants : dans une
            # piece pleine, c'est du remplissage.
            if 2 <= sx <= 5 and 2 <= sy <= 5:
                ox, oy = fx, fy
            else:
                ox, oy = bx + sx * T, by + sy * T
            for y in range(T):
                for x in range(T):
                    out[(j * T + y) * w + i * T + x] = rows[oy + y][ox + x]
    return w, h, out


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


def attendues():
    return len(PIECES) + len(COMPOSES) + len(ANIMS) + len(TEXTURES)


def extraire():
    """-> (pieces ecrites, attendues), ou (0, attendues) si le pack manque."""
    if not os.path.isdir(PACK):
        return 0, attendues()
    os.makedirs(os.path.join(OUT, "sol"), exist_ok=True)
    faites = 0
    for ident, planche, x, y, w, h, mode in PIECES:
        _ecrire(os.path.join(OUT, ident + ".png"), *_decouper(planche, x, y, w, h, mode))
        faites += 1
    for ident, bloc, tw, th in COMPOSES:
        w, h, px = _composer(bloc, tw, th)
        if bloc == BLOC_BASSIN:
            # Le sol de bordure s'efface : plein au ras de la falaise et de la
            # lave, transparent a une demi-tuile.
            px = _fondre_sol(w, h, px, 4.0, 14.0)
        _ecrire(os.path.join(OUT, ident + ".png"), *_rogner(w, h, px))
        faites += 1
    for ident, fichier in ANIMS:
        w, h, rows = decode(os.path.join(PACK, "anim", fichier + ".png"))
        open(os.path.join(OUT, ident + ".png"), "wb").write(encode(w, h, rows))
        faites += 1
    for ident, x, y, w, h in TEXTURES:
        _, _, rows = _planche("niv")
        px = [rows[y + j][x + i] for j in range(h) for i in range(w)]
        _ecrire(os.path.join(OUT, "sol", ident + ".png"), w, h, px)
        faites += 1
    return faites, attendues()


if __name__ == "__main__":
    faites, total = extraire()
    print("enfer : %d pieces sur %d" % (faites, total))
