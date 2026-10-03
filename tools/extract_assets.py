# -*- coding: utf-8 -*-
"""Regenere les assets derives des packs tiers.

POURQUOI CE SCRIPT EXISTE
-------------------------
Les licences des trois packs autorisent leur usage dans un jeu mais interdisent
de les redistribuer ou de les re-televerser, modifies ou non. Un depot public
etant precisement un televersement, ni les packs ni les planches qu'on en tire
ne sont versionnes. Le depot porte donc le code, les scenes et les reglages ;
ce script reconstruit tout le reste a l'identique.

INSTALLATION
------------
1. Recuperer les six packs et les deposer dans assets/packs/ :
       PixelUIKit/
       Tiny RPG Character Asset Pack v1.03 -Full 20 Characters/
       Tiny RPG Character Asset Pack 02 -Full 20 Characters/
       ItemIconPack/
       2DML_SET3_v1.0/               (la carte : voir extract_enfer.py)
       Touches/touches_clavier.png   (les touches affichees par l'interface)
2. python tools/extract_assets.py
3. Ouvrir le projet dans Godot une fois, pour l'import.

Le script est idempotent : le relancer ecrase ses sorties sans rien casser.
"""
import math
import os
import shutil
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import decode, encode
import extract_enfer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
PACKS = os.path.join(ROOT, "assets", "packs")
KIT = os.path.join(PACKS, "PixelUIKit")
ICONS_PACK = os.path.join(PACKS, "ItemIconPack")
P13 = os.path.join(PACKS, "Tiny RPG Character Asset Pack v1.03 -Full 20 Characters",
                   "Characters(100x100)")
P02 = os.path.join(PACKS, "Tiny RPG Character Asset Pack 02 -Full 20 Characters",
                   "Characters(100x100 split)")
TOUCHES_PACK = os.path.join(PACKS, "Touches", "touches_clavier.png")

# (categorie, entite, pack, nom d'origine, separateur, nom de la planche de marche)
ENTITIES = [
    ("characters", "cain",    P13, "Armored Axeman", "-", "Walk"),
    ("characters", "job",     P13, "Knight Templar", "-", "Walk01"),
    ("characters", "loth",    P13, "Archer",         "-", "Walk"),
    ("enemies",    "imp",     P02, "Demon_A",        "_", "Walk"),
    ("enemies",    "hound",   P02, "Hellhound",      "_", "Walk"),
    ("enemies",    "cultist", P02, "Warlock",        "_", "Walk"),
    ("enemies",    "brute",   P02, "Minotaur",       "_", "Walk"),
    ("enemies",    "oeil",    P02, "Eyeball Monster","_", "Walk"),
    # 0.9.2. Les deux volants n'ont pas de planche de repos : ils volent tout
    # le temps, le vol sert aux deux (septieme champ).
    ("enemies",    "chauve_souris", P02, "Hellbat",   "_", "Flying", "Flying"),
    ("enemies",    "feu_follet",    P02, "Ghostfire", "_", "Flying", "Flying"),
    ("enemies",    "slime_lave",    P02, "Lava Slime","_", "Walk"),
    ("enemies",    "invocatrice",   P02, "Demoness_B","_", "Walk"),
    ("bosses",     "golgota", P02, "Flame Golem",    "_", "Walk"),
    ("bosses",     "lilith",  P02, "Demoness_A",     "_", "Walk"),
    ("bosses",     "baal",    P02, "Demon_C",        "_", "Walk"),
    ("bosses",     "asmodee", P02, "Demon_E",        "_", "Walk"),
    ("bosses",     "lucifer", P02, "Black Knight_C", "_", "Walk"),
    # Cinematiques : la femme de Loth, changee en sel. Teintee en jeu, pas ici.
    ("story",      "femme_sel", P13, "Priest",       "-", "Walk"),
]

ICONS = ["heart", "coin", "lock", "star", "gear", "close"]

# Les icones d'objets. Le pack en compte 1244, nommees itemN.png sans aucune
# indication de contenu : ces correspondances ont ete etablies a l'oeil sur des
# planches de contact, et n'ont aucune chance d'etre redecouvertes autrement.
# C'est la partie de ce script qu'il ne faut PAS perdre.
ITEM_ICONS = {
    "ember": 723,            # torche allumee
    "ash_soles": 262,        # bottes
    "rusty_striker": 933,    # engrenage rouille
    "tanned_hide": 232,      # veste de cuir
    "chipped_fang": 1187,    # croc
    "soul_magnet": 921,      # aimant en fer a cheval
    "demon_bile": 919,       # flacon vert
    "infernal_breech": 934,  # engrenage d'acier
    "basalt_scales": 239,    # armure sombre
    "hunter_eye": 1169,      # oeil
    "leech": 1222,           # ver rouge
    "spectral_drift": 689,   # volute spectrale
    "trifid_shard": 542,     # eclats de cristal
    "forge_heart": 688,      # coeur rouge
    "blood_pact": 1179,      # organe sanglant
    "predator_crown": 874,   # couronne d or
    "longinus_lance": 124,   # lance
    "guardian_seal": 199,    # bouclier
    "eternal_ember": 721,    # brasier
    "damned_clock": 765,     # cadran
    "reaper_claw": 1240,     # griffe
    "thorn_mantle": 891,     # cape verte
    "phoenix_down": 1178,    # plume rouge
    "void_siphon": 1195,     # orbe noire
    "whetstone":             562,  # pierre grise en barre
    "bandages":              669,  # linge blanc
    "executioner_glove":     294,  # gant de cuir
    "knuckle_rosary":        1164, # os
    "clotted_blood":         1189, # goutte de sang
    "giant_bane":            61,   # marteau rouge
    "brazen_serpent":        679,  # serpent d or enroule
    "moloch_chain":          597,  # maillons de chaine
    "penitent_cuirass":      224,  # plastron d acier
    "moloch_horn":           1182, # corne
    "solomon_seal":          169,  # medaille d or
    "reliquary":             718,  # coffret de bois
    # 0.9.2
    "sulfur":              1121, # soufre jaune en mottes
    "tartarus_chains":     779,  # chaine de fer
    "david_sling":         1113, # laniere enroulee
    "samson_jaw":          1185, # molaire
    "greek_fire":          902,  # fiole de feu
    "sodom_salt":          552,  # cristaux blancs
    "golgotha_nail":       924,  # pointe de fer
    "salamander_skin":     1045, # salamandre rouge
    "thirty_pieces":       1158, # piece d argent
    "censer":              937,  # encensoir d or
    "moses_staff":         841,  # baton de bois
    "jericho_trumpet":     844,  # cor d or
}

# Le butin (0.10.1) : ame, cle, soin, et la Cle des Abysses, tires du meme pack
# a la place des SVG plats d'origine. Aucune de ces icones ne sert a un objet :
# un butin ne doit pas ressembler a ce qu'on achete (le coeur 688 est celui du
# Coeur de forge, d'ou la fiole pour le soin). Sortie : pickups/<nom>.png.
PICKUP_ICONS = {
    "soul": 598,         # orbe pale lumineux (teinte cyan en jeu)
    "key": 691,          # cle doree
    "abyss_key": 693,    # cle d'argent (teinte violette en jeu)
    "heal": 903,         # fiole rouge
}

UI = os.path.join(SPR, "ui")
MASTER = 1024
ICON_SIZES = [256, 128, 64, 48, 32, 24, 16]

missing = []


def need(path):
    if not os.path.exists(path):
        missing.append(os.path.relpath(path, ROOT))
        return False
    return True


def copy(src, dst):
    if not need(src):
        return False
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)
    return True


def entities():
    """Version « with shadows » : l'ombre pose la creature au sol, indispensable
    en vue de dessus. Les recalages verticaux des scenes sont mesures dessus."""
    done = 0
    for cat, ent, pack, src, sep, walk, *repos in ENTITIES:
        idle = repos[0] if repos else "Idle"
        folder = os.path.join(pack, src, src + " with shadows")
        dst = os.path.join(SPR, cat, ent)
        ok = copy(os.path.join(folder, src + sep + idle + ".png"),
                  os.path.join(dst, ent + "_idle.png"))
        ok = copy(os.path.join(folder, src + sep + walk + ".png"),
                  os.path.join(dst, ent + "_walk.png")) and ok
        done += 1 if ok else 0
    return done


# Les gestes des boss (0.10.1) : chaque planche du pack a ses attaques, son
# coup encaisse et sa mort, qui ne servaient pas. Le boss joue la planche
# d'attaque pendant l'annonce de son coup : on voit QUI frappe, et le geste
# arrive en meme temps que la zone. Sortie : <boss>_<geste>.png.
GESTES_BOSS = [("Attack01", "attaque1"), ("Attack02", "attaque2"),
               ("Attack03", "attaque3"), ("Hurt", "touche"), ("Death", "mort")]


def gestes_boss():
    faits = 0
    for cat, ent, pack, src, sep, *_ in ENTITIES:
        if cat != "bosses":
            continue
        folder = os.path.join(pack, src, src + " with shadows")
        for nom_pack, nom in GESTES_BOSS:
            chemin = os.path.join(folder, src + sep + nom_pack + ".png")
            # Baal n'a que deux attaques : le geste manquant n'est pas une erreur.
            if os.path.exists(chemin):
                faits += 1 if copy(chemin, os.path.join(SPR, cat, ent, ent + "_" + nom + ".png")) else 0
    return faits


def ui():
    copy(os.path.join(KIT, "pieces", "panel_plain.png"), os.path.join(UI, "panel.png"))
    for name in ICONS:
        copy(os.path.join(KIT, "icons_32", name + ".png"), os.path.join(UI, name + ".png"))

    # Les boutons du kit portent un « OK » grave : en 9-tranches, le centre est
    # justement ce qu'on etire, le texte se deformerait. Le degrade etant
    # uniforme horizontalement, on rebatit un bouton de 8 px a partir d'une
    # colonne pure : deux colonnes de bord, quatre de degrade, deux de bord.
    for src, dst in [("button_normal", "button"), ("button_hover", "button_hover"),
                     ("button_pressed", "button_pressed")]:
        path = os.path.join(KIT, "pieces", src + ".png")
        if not need(path):
            continue
        w, h, px = decode(path)
        cols = [0, 1, 10, 10, 10, 10, w - 2, w - 1]
        rows = [[px[y][c] for c in cols] for y in range(h)]
        open(os.path.join(UI, dst + ".png"), "wb").write(encode(8, h, rows))

    # Le kit ne fournit qu'une barre PLEINE ; une ProgressBar veut un rail et un
    # remplissage. Godot trace le remplissage sur toute la hauteur du controle
    # sans respecter les marges du fond : c'est donc le remplissage qui porte son
    # retrait, en pixels transparents.
    path = os.path.join(KIT, "pieces", "bar_hp.png")
    if need(path):
        w, h, px = decode(path)
        cols = [0, 1, 60, 60, 60, 60, w - 2, w - 1]
        clear, dark = (0, 0, 0, 0), (26, 22, 32, 255)
        track, fill = [], []
        for y in range(h):
            tr, fi = [], []
            for i, c in enumerate(cols):
                p = px[y][c]
                inside = 2 <= i <= 5 and 2 <= y <= h - 3
                tr.append(dark if inside else p)
                fi.append(p if inside else clear)
            track.append(tr)
            fill.append(fi)
        open(os.path.join(UI, "bar_track.png"), "wb").write(encode(8, h, track))
        open(os.path.join(UI, "bar_fill.png"), "wb").write(encode(8, h, fill))


def _teinte_braise(p, danger=False, neutre=False):
    """Repeint un pixel du kit (violet et or) dans la palette de l'enfer.

    Le kit est un kit de fantasy generique : panneaux violet sombre, liseres
    dores. Tel quel, il donnait des menus qu'on a deja vus partout. Les gris
    violaces deviennent un charbon rouge, l'or devient braise, le vert du
    curseur devient feu. La VALEUR de chaque pixel est gardee : le relief du
    pixel art (biseaux, reflets) survit au changement de teinte.
    """
    import colorsys
    r, g, b, a = p
    if a == 0:
        return p
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    deg = h * 360.0
    if 180.0 <= deg <= 320.0:            # violets et gris violaces
        h2, s2 = (356.0 if danger else 6.0) / 360.0, min(1.0, s * (1.9 if danger else 1.35))
        v2 = v * (0.95 if danger else 0.88)
    elif 25.0 <= deg <= 65.0 and neutre:  # ors en gris, pour etre teints par le code
        h2, s2, v2 = 0.0, 0.0, v
    elif 25.0 <= deg <= 65.0:            # ors
        h2, s2, v2 = ((4.0 if danger else 20.0) / 360.0, min(1.0, s * 1.08), v)
    elif 70.0 <= deg <= 160.0:           # verts (curseurs, interrupteurs)
        h2, s2, v2 = 14.0 / 360.0, min(1.0, s * 1.25), min(1.0, v * 1.35)
    else:
        return p
    r2, g2, b2 = colorsys.hsv_to_rgb(h2, s2, v2)
    return (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)


def _agrandir(w, h, px, n):
    """Agrandissement entier, au plus proche : le pixel art reste net."""
    return w * n, h * n, [[px[y // n][x // n] for x in range(w * n)] for y in range(h * n)]


def ui_enfer():
    """Les pieces d'interface de la refonte des menus (0.10.1), dans
    assets/sprites/ui/enfer/ : repeintes en braise, agrandies x2 (cadres,
    cases, boutons) ou x3 (fleches). A x1, le biseau d'un cadre ne faisait
    que 2 px sur un ecran de 1080 : les panneaux semblaient dessines au trait.
    """
    sortie = os.path.join(UI, "enfer")
    os.makedirs(sortie, exist_ok=True)

    def piece(src, dst, n, danger=False, colonnes=None, neutre=False):
        path = os.path.join(KIT, "pieces", src + ".png")
        if not need(path):
            return
        w, h, px = decode(path)
        if colonnes is not None:
            px = [[row[c] for c in colonnes(w)] for row in px]
            w = len(px[0])
        px = [[_teinte_braise(p, danger, neutre) for p in row] for row in px]
        w, h, px = _agrandir(w, h, px, n)
        open(os.path.join(sortie, dst + ".png"), "wb").write(encode(w, h, px))

    piece("panel_plain", "cadre", 2)
    # Liseré gris : la carte d'objet le teint de la couleur de sa rareté.
    piece("panel_plain", "cadre_neutre", 2, neutre=True)
    piece("slot", "case", 2)
    piece("slot_selected", "case_active", 2)
    piece("slot", "case_danger", 2, danger=True)
    piece("slot_selected", "case_danger_active", 2, danger=True)
    # Meme reconstruction que les boutons d'origine (voir ui()) : le « OK »
    # grave du kit ne doit pas s'etirer.
    huit = lambda w: [0, 1, 10, 10, 10, 10, w - 2, w - 1]
    for src, dst in [("button_normal", "bouton"), ("button_hover", "bouton_survol"),
                     ("button_pressed", "bouton_appui")]:
        piece(src, dst, 2, colonnes=huit)
    piece("arrow_right", "fleche", 3)
    piece("arrow_left", "fleche_gauche", 3)
    piece("toggle_on", "interrupteur_oui", 2)
    piece("toggle_off", "interrupteur_non", 2)
    piece("checkbox_on", "coche_oui", 2)
    piece("checkbox_off", "coche_non", 2)


def touches():
    """La planche des touches clavier, et une touche VIERGE qu'on etire.

    La planche a les lettres, les fleches et F1 a F12, en 16 px, normales
    (rangees 0 a 6) et enfoncees (7 a 13) — mais ni Espace, ni Tab, ni Echap,
    les touches que le jeu utilise le plus. On en tire donc une touche vierge
    en effacant l'apostrophe de la sienne (la plus petite inscription de la
    planche) : son etiquette prend la couleur de la face. Les colonnes 5 a 9
    d'une touche sont identiques d'une rangee a l'autre, l'interface les etire
    pour ecrire n'importe quel nom dessus. Sortie : 32 x 16, normale a gauche,
    enfoncee a droite.
    """
    if not copy(TOUCHES_PACK, os.path.join(UI, "touches.png")):
        return False
    w, h, px = decode(TOUCHES_PACK)
    face, face_enfoncee = (57, 64, 70), (40, 40, 40)
    rows = []
    for y in range(16):
        row = []
        for x in range(16):
            p = px[6 * 16 + y][x]
            row.append(face + (255,) if p[:3] == (255, 255, 255) and p[3] > 0 else p)
        for x in range(16):
            p = px[13 * 16 + y][x]
            row.append(face_enfoncee + (255,) if p[:3] == (161, 201, 255) and p[3] > 0 else p)
        rows.append(row)
    open(os.path.join(UI, "touche_vide.png"), "wb").write(encode(32, 16, rows))
    return True


def item_icons():
    """Une icone 16x16 par objet du catalogue, nommee par son identifiant.

    Le jeu les charge PAR CONVENTION (assets/sprites/items/<id>.png) : aucun
    chemin n est ecrit dans le catalogue, ajouter un objet revient a deposer un
    fichier au bon nom."""
    done = 0
    for name, index in sorted(ITEM_ICONS.items()):
        if copy(os.path.join(ICONS_PACK, "item%d.png" % index),
                os.path.join(SPR, "items", name + ".png")):
            done += 1
    return done


def pickup_icons():
    """Le butin : une icone 16x16 par sorte, dans pickups/<nom>.png."""
    done = 0
    for name, index in sorted(PICKUP_ICONS.items()):
        if copy(os.path.join(ICONS_PACK, "item%d.png" % index),
                os.path.join(SPR, "pickups", name + ".png")):
            done += 1
    return done


def icon():
    """Golgota, image 3 de sa planche de repos, version SANS ombre."""
    path = os.path.join(P02, "Flame Golem", "Flame Golem", "Flame Golem_Idle.png")
    if not need(path):
        return
    _, side, px = decode(path)
    img = [[px[y][3 * side + x] for x in range(side)] for y in range(side)]
    xs = [x for y in range(side) for x in range(side) if img[y][x][3] > 12]
    ys = [y for y in range(side) for x in range(side) if img[y][x][3] > 12]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
    sw, sh = x1 - x0 + 1, y1 - y0 + 1

    # Agrandir a une echelle ENTIERE, une seule fois et tres grand : un pixel art
    # agrandi a un facteur fractionnaire a des pixels de tailles inegales.
    scale = int(MASTER * 0.80 / max(sw, sh))
    dw, dh = sw * scale, sh * scale
    ox, oy = (MASTER - dw) // 2, (MASTER - dh) // 2

    master = []
    c = (MASTER - 1) / 2.0
    for y in range(MASTER):
        row = []
        for x in range(MASTER):
            d = math.hypot(x - c, (y - c) * 1.05) / (MASTER * 0.60)
            g = max(0.0, 1.0 - d * d) ** 2
            row.append((int(20 + 118 * g), int(10 + 30 * g), int(14 + 18 * g), 255))
        master.append(row)
    for y in range(dh):
        for x in range(dw):
            p = img[y0 + y // scale][x0 + x // scale]
            if p[3] < 12:
                continue
            a = p[3] / 255.0
            b = master[oy + y][ox + x]
            master[oy + y][ox + x] = (int(p[0] * a + b[0] * (1 - a)),
                                      int(p[1] * a + b[1] * (1 - a)),
                                      int(p[2] * a + b[2] * (1 - a)), 255)

    # Puis reduire par moyenne de zone : c'est cet ordre qui donne des petites
    # tailles nettes. Rendre directement en 16 px donne de la bouillie.
    def shrink(n):
        k = MASTER // n
        out = []
        for y in range(n):
            row = []
            for x in range(n):
                acc = [0, 0, 0]
                for dy in range(k):
                    for dx in range(k):
                        q = master[y * k + dy][x * k + dx]
                        acc[0] += q[0]
                        acc[1] += q[1]
                        acc[2] += q[2]
                t = k * k
                row.append((acc[0] // t, acc[1] // t, acc[2] // t, 255))
            out.append(row)
        e = 1 if n <= 32 else 2
        for i in range(n):
            for j in list(range(e)) + list(range(n - e, n)):
                out[i][j] = (12, 6, 9, 255)
                out[j][i] = (12, 6, 9, 255)
        return out

    imgs = {n: shrink(n) for n in ICON_SIZES}
    open(os.path.join(ROOT, "icon.png"), "wb").write(encode(256, 256, imgs[256]))

    def dib_bytes(n, rows):
        # BMP 32 bits dans un ICO : entete double en hauteur, pixels BGRA de bas
        # en haut, puis un masque AND que Windows exige meme sans transparence.
        head = struct.pack("<IiiHHIIiiII", 40, n, n * 2, 1, 32, 0, n * n * 4, 0, 0, 0, 0)
        body = bytearray()
        for y in range(n - 1, -1, -1):
            for p in rows[y]:
                body += bytes((p[2], p[1], p[0], 255))
        stride = ((n + 31) // 32) * 4
        return head + bytes(body) + b"\x00" * (stride * n)

    entries = [(n, encode(n, n, imgs[n]) if n == 256 else dib_bytes(n, imgs[n]))
               for n in ICON_SIZES]
    offset = 6 + 16 * len(entries)
    head, dirs, blobs = struct.pack("<HHH", 0, 1, len(entries)), b"", b""
    for n, data in entries:
        dirs += struct.pack("<BBBBHHII", n & 0xFF, n & 0xFF, 0, 0, 1, 32, len(data), offset)
        blobs += data
        offset += len(data)
    open(os.path.join(ROOT, "icon.ico"), "wb").write(head + dirs + blobs)


if __name__ == "__main__":
    print("Extraction vers", os.path.relpath(SPR, ROOT))
    count = entities()
    gestes = gestes_boss()
    ui()
    ui_enfer()
    items = item_icons()
    butin = pickup_icons()
    clavier = touches()
    enfer, enfer_attendues = extract_enfer.extraire()
    icon()
    if missing:
        print("\n%d fichier(s) source introuvable(s) :" % len(missing))
        for m in missing[:10]:
            print("   ", m)
        if len(missing) > 10:
            print("    ... et %d autres" % (len(missing) - 10))
        print("\nDeposez les six packs dans assets/packs/ (voir l'entete de"
              " ce fichier), puis relancez.")
        sys.exit(1)
    print("  %d entites : planches repos + marche" % count)
    print("  boss : %d planches de gestes (attaques, coup, mort)" % gestes)
    print("  interface : panneau, 3 boutons, 2 barres, %d icones%s"
          % (len(ICONS), ", touches clavier" if clavier else ""))
    print("  objets : %d icones sur %d attendues" % (items, len(ITEM_ICONS)))
    print("  butin : %d icones sur %d attendues" % (butin, len(PICKUP_ICONS)))
    print("  carte de l'enfer : %d pieces sur %d attendues" % (enfer, enfer_attendues))
    print("  application : icon.png + icon.ico")
    print("\nOuvrez le projet dans Godot une fois pour lancer l'import.")
