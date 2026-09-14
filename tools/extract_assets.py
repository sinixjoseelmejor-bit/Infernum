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
1. Recuperer les trois packs et les deposer dans assets/sprites/ :
       PixelUIKit/
       Tiny RPG Character Asset Pack v1.03 -Full 20 Characters/
       Tiny RPG Character Asset Pack 02 -Full 20 Characters/
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

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
KIT = os.path.join(SPR, "PixelUIKit")
P13 = os.path.join(SPR, "Tiny RPG Character Asset Pack v1.03 -Full 20 Characters",
                   "Characters(100x100)")
P02 = os.path.join(SPR, "Tiny RPG Character Asset Pack 02 -Full 20 Characters",
                   "Characters(100x100 split)")

# (categorie, entite, pack, nom d'origine, separateur, nom de la planche de marche)
ENTITIES = [
    ("characters", "cain",    P13, "Armored Axeman", "-", "Walk"),
    ("characters", "job",     P13, "Knight Templar", "-", "Walk01"),
    ("characters", "loth",    P13, "Archer",         "-", "Walk"),
    ("enemies",    "imp",     P02, "Demon_A",        "_", "Walk"),
    ("enemies",    "hound",   P02, "Hellhound",      "_", "Walk"),
    ("enemies",    "cultist", P02, "Warlock",        "_", "Walk"),
    ("enemies",    "brute",   P02, "Minotaur",       "_", "Walk"),
    ("bosses",     "golgota", P02, "Flame Golem",    "_", "Walk"),
    ("bosses",     "lilith",  P02, "Demoness_A",     "_", "Walk"),
    ("bosses",     "baal",    P02, "Demon_C",        "_", "Walk"),
    ("bosses",     "asmodee", P02, "Demon_E",        "_", "Walk"),
    ("bosses",     "lucifer", P02, "Black Knight_C", "_", "Walk"),
]

ICONS = ["heart", "coin", "lock", "star", "gear", "close"]
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
    for cat, ent, pack, src, sep, walk in ENTITIES:
        folder = os.path.join(pack, src, src + " with shadows")
        dst = os.path.join(SPR, cat, ent)
        ok = copy(os.path.join(folder, src + sep + "Idle.png"),
                  os.path.join(dst, ent + "_idle.png"))
        ok = copy(os.path.join(folder, src + sep + walk + ".png"),
                  os.path.join(dst, ent + "_walk.png")) and ok
        done += 1 if ok else 0
    return done


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
    ui()
    icon()
    if missing:
        print("\n%d fichier(s) source introuvable(s) :" % len(missing))
        for m in missing[:10]:
            print("   ", m)
        if len(missing) > 10:
            print("    ... et %d autres" % (len(missing) - 10))
        print("\nDeposez les trois packs dans assets/sprites/ (voir l'entete de"
              " ce fichier), puis relancez.")
        sys.exit(1)
    print("  %d entites : planches repos + marche" % count)
    print("  interface : panneau, 3 boutons, 2 barres, %d icones" % len(ICONS))
    print("  application : icon.png + icon.ico")
    print("\nOuvrez le projet dans Godot une fois pour lancer l'import.")
