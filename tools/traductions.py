# -*- coding: utf-8 -*-
"""Releve les textes du jeu et verifie la traduction anglaise.

LE FRANCAIS EST LA LANGUE SOURCE
--------------------------------
Le jeu est ecrit en francais et le reste : chaque texte affiche est sa propre
cle de traduction (msgid). `locale/en.po` porte l'anglais en face. Aucune table
de cles abstraites (MENU_JOUER...) : on lit le code tel qu'il s'affiche, et un
texte sans traduction retombe sur le francais au lieu d'afficher une cle.

CE QUE LE SCRIPT RELEVE
-----------------------
1. Les appels `tr("...")`, `tr("...", "contexte")` et
   `TranslationServer.translate("...")` de tous les scripts, sauf le panneau
   de developpement (jamais livre aux joueurs, reste en francais). Et les
   textes poses TELS QUELS dans un controle (`label.text = "PAUSE"`,
   `add_item("...")`) : le controle les traduit lui-meme, et les retraduit si
   la langue change a l'ecran. Un texte compose (`"Vague %d" % n`) doit passer
   par tr() AVANT le formatage : c'est le gabarit qui se traduit.
2. Les proprietes `text`, `tooltip_text` et `placeholder_text` des scenes.
3. Les DONNEES : les catalogues ecrits en constantes (objets, personnages,
   Forge, maledictions, pactes, histoire...). Une constante ne peut pas appeler
   `tr()` : c'est l'affichage qui traduit, et c'est la table `DONNEES`
   ci-dessous qui dit quelles cles y sont du texte.

USAGE
-----
    python tools/traductions.py            verifie : code de sortie 1 s'il manque
                                           une traduction
    python tools/traductions.py --manque   ajoute les textes manquants a en.po,
                                           msgstr vide, a remplir
    python tools/traductions.py --suspects liste les chaines qui ressemblent a du
                                           francais sans passer par tr() : les
                                           oublis probables

A relancer apres toute retouche d'un texte. Un texte modifie en francais perd
sa traduction (sa cle a change) : le script le signale comme manquant, et
l'ancienne entree comme obsolete.
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PO = os.path.join(ROOT, "locale", "en.po")

# Jamais livres aux joueurs : pas de traduction.
EXCLUS = {
    "scripts/ui/dev_screen.gd",
}

# fichier -> ce qui y est du texte :
#   "cles"     : valeur des cles de dictionnaire nommees (chaine, ou tableau de
#                chaines comme "titre")
#   "valeurs"  : toutes les valeurs chaines des dictionnaires constants nommes
#   "premiers" : premier element de chaque ligne des tableaux constants nommes
DONNEES = {
    "scripts/items/item_database.gd": {"cles": ["name", "desc"]},
    "scripts/items/item_data.gd": {"valeurs": ["RARITY_NAMES"]},
    "scripts/characters/character_db.gd": {
        "cles": ["name", "title", "archetype", "desc", "passive_name", "passive_desc"]},
    "scripts/story/story_db.gd": {"cles": ["texte", "titre"], "premiers": ["LOCUTEURS"]},
    "scripts/meta/forge_tree.gd": {"cles": ["name", "desc", "branch"]},
    "scripts/systems/curse_system.gd": {"cles": ["name", "desc", "penalty"]},
    "scripts/systems/wave_modifiers.gd": {"cles": ["name", "desc"]},
    "scripts/core/settings.gd": {"valeurs": ["JOYSTICK_LABELS"]},
    "scripts/ui/stats_screen.gd": {"premiers": ["ROWS"]},
    "scripts/ui/item_card.gd": {"valeurs": ["LABELS"]},
    "scripts/ui/hud.gd": {"cles": ["nom"]},
    "scripts/ui/touche.gd": {"valeurs": ["NOMS"]},
}

PROPRIETES_SCENE = ("text", "tooltip_text", "placeholder_text", "boss_name", "subtitle")


# --- Lecture du GDScript ----------------------------------------------------

class Chaine:
    __slots__ = ("valeur", "ligne", "debut", "fin", "prefixe")

    def __init__(self, valeur, ligne, debut, fin, prefixe):
        self.valeur = valeur
        self.ligne = ligne
        self.debut = debut
        self.fin = fin
        self.prefixe = prefixe


ECHAPPEMENTS = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\",
                "a": "\a", "b": "\b", "f": "\f", "v": "\v", "0": "\0"}


def _desechapper(brut):
    sortie = []
    i = 0
    while i < len(brut):
        c = brut[i]
        if c == "\\" and i + 1 < len(brut):
            n = brut[i + 1]
            if n == "u" and i + 6 <= len(brut):
                sortie.append(chr(int(brut[i + 2:i + 6], 16)))
                i += 6
                continue
            if n == "\n":
                i += 2
                continue
            sortie.append(ECHAPPEMENTS.get(n, "\\" + n))
            i += 2
            continue
        sortie.append(c)
        i += 1
    return "".join(sortie)


def lexer(source):
    """Les litteraux chaine d'un script, commentaires ignores.

    Des litteraux separes seulement par `+`, des blancs, des retours a la ligne
    ou une continuation `\\` sont fusionnes : c'est ainsi que le code coupe une
    longue phrase, et c'est la phrase entiere qui s'affiche.
    """
    chaines = []
    i = 0
    ligne = 1
    n = len(source)
    while i < n:
        c = source[i]
        if c == "\n":
            ligne += 1
            i += 1
            continue
        if c == "#":
            while i < n and source[i] != "\n":
                i += 1
            continue
        if c in "\"'":
            prefixe = ""
            if i > 0 and source[i - 1] in "&^r" and (i < 2 or not (source[i - 2].isalnum() or source[i - 2] == "_")):
                prefixe = source[i - 1]
            debut = i - len(prefixe)
            triple = source[i:i + 3] in ('"""', "'''")
            fermeture = source[i:i + 3] if triple else c
            j = i + len(fermeture)
            brut = []
            ligne_debut = ligne
            while j < n:
                if source[j] == "\\" and prefixe != "r":
                    brut.append(source[j:j + 2])
                    if source[j + 1:j + 2] == "\n":
                        ligne += 1
                    j += 2
                    continue
                if source.startswith(fermeture, j):
                    break
                if source[j] == "\n":
                    ligne += 1
                brut.append(source[j])
                j += 1
            texte = "".join(brut)
            valeur = texte if prefixe == "r" else _desechapper(texte)
            chaines.append(Chaine(valeur, ligne_debut, debut, j + len(fermeture), prefixe))
            i = j + len(fermeture)
            continue
        i += 1
    return _fusionner(source, chaines)


CONCAT = re.compile(r"^(?:\s|\\\n)*\+(?:\s|\\\n)*$")


def _fusionner(source, chaines):
    sortie = []
    for ch in chaines:
        if sortie and ch.prefixe == "" and sortie[-1].prefixe == "" \
                and CONCAT.match(source[sortie[-1].fin:ch.debut]):
            prec = sortie[-1]
            sortie[-1] = Chaine(prec.valeur + ch.valeur, prec.ligne, prec.debut, ch.fin, "")
            continue
        sortie.append(ch)
    return sortie


APPEL_TR = re.compile(r"(?:\btr|\bTranslationServer\.translate|\batr)\(\s*$")
# Un texte posé tel quel dans un contrôle : le contrôle le traduit lui-même, et
# le retraduit si la langue change pendant qu'il est affiché.
DANS_CONTROLE = re.compile(r"(?:\b(?:text|tooltip_text|placeholder_text)\s*=|\badd_item\()\s*$")


def _contexte_tr(source, chaines, k):
    """(cle, contexte) si la chaine k est le premier argument d'un tr()."""
    ch = chaines[k]
    avant = source[max(0, ch.debut - 60):ch.debut]
    if not APPEL_TR.search(avant):
        return None
    contexte = ""
    if k + 1 < len(chaines):
        suivante = chaines[k + 1]
        if re.match(r"^\s*,\s*$", source[ch.fin:suivante.debut]):
            contexte = suivante.valeur
    return ch.valeur, contexte


def _bloc_constant(source, nom):
    """(debut, fin) du texte de la constante `nom` : de son `=` a la fin de la
    parenthese, du crochet ou de l'accolade qui l'ouvre."""
    m = re.search(r"^\s*const\s+" + re.escape(nom) + r"\b[^=]*=\s*", source, re.M)
    if not m:
        return None
    i = m.end()
    ouvrants = {"[": "]", "{": "}", "(": ")"}
    if source[i] not in ouvrants:
        return None
    pile = [ouvrants[source[i]]]
    j = i + 1
    en_chaine = None
    while j < len(source) and pile:
        c = source[j]
        if en_chaine:
            if c == "\\":
                j += 2
                continue
            if c == en_chaine:
                en_chaine = None
        elif c in "\"'":
            en_chaine = c
        elif c == "#":
            while j < len(source) and source[j] != "\n":
                j += 1
            continue
        elif c in ouvrants:
            pile.append(ouvrants[c])
        elif c == pile[-1]:
            pile.pop()
        j += 1
    return i, j


def releve_script(chemin_rel, source):
    """Liste de (cle, contexte, lieu)."""
    chaines = lexer(source)
    trouves = []
    for k, ch in enumerate(chaines):
        if ch.prefixe:
            continue
        tr = _contexte_tr(source, chaines, k)
        if tr is not None:
            trouves.append((tr[0], tr[1], "%s:%d" % (chemin_rel, ch.ligne)))
        elif DANS_CONTROLE.search(source[max(0, ch.debut - 40):ch.debut]) \
                and not re.match(r"^\s*%", source[ch.fin:ch.fin + 4]):
            trouves.append((ch.valeur, "", "%s:%d" % (chemin_rel, ch.ligne)))

    spec = DONNEES.get(chemin_rel, {})
    for cle in spec.get("cles", []):
        motif = re.compile(r'"' + re.escape(cle) + r'"\s*:\s*$')
        for k, ch in enumerate(chaines):
            if ch.prefixe or not motif.search(source[max(0, ch.debut - 40):ch.debut]):
                continue
            # Une valeur chaine, ou un tableau de chaines ("titre": ["A", "B"]).
            trouves.append((ch.valeur, "", "%s:%d" % (chemin_rel, ch.ligne)))
        motif_tab = re.compile(r'"' + re.escape(cle) + r'"\s*:\s*\[')
        for m in motif_tab.finditer(source):
            fin = source.index("]", m.end())
            for ch in chaines:
                if not ch.prefixe and m.end() <= ch.debut < fin:
                    trouves.append((ch.valeur, "", "%s:%d" % (chemin_rel, ch.ligne)))
    for nom in spec.get("valeurs", []):
        bloc = _bloc_constant(source, nom)
        if bloc is None:
            continue
        for ch in chaines:
            if ch.prefixe or not (bloc[0] <= ch.debut < bloc[1]):
                continue
            # Valeur, pas cle : suivie d'une virgule, d'une fin de ligne ou de
            # l'accolade, jamais de deux-points.
            if re.match(r"^\s*:", source[ch.fin:ch.fin + 3]):
                continue
            trouves.append((ch.valeur, "", "%s:%d" % (chemin_rel, ch.ligne)))
    for nom in spec.get("premiers", []):
        bloc = _bloc_constant(source, nom)
        if bloc is None:
            continue
        for ch in chaines:
            if ch.prefixe or not (bloc[0] <= ch.debut < bloc[1]):
                continue
            avant = source[bloc[0]:ch.debut].rstrip()
            # Premier element d'une ligne : juste apres un `[`, ou apres le
            # `[` d'une valeur de dictionnaire (`&"cle": [`).
            if avant.endswith("["):
                trouves.append((ch.valeur, "", "%s:%d" % (chemin_rel, ch.ligne)))
    return trouves


# --- Lecture des scenes -----------------------------------------------------

PROPRIETE = re.compile(r'^(%s) = "((?:[^"\\]|\\.)*)"' % "|".join(PROPRIETES_SCENE), re.M | re.S)


def releve_scene(chemin_rel, source):
    trouves = []
    for m in PROPRIETE.finditer(source):
        valeur = _desechapper(m.group(2))
        if valeur.strip():
            ligne = source.count("\n", 0, m.start()) + 1
            trouves.append((valeur, "", "%s:%d" % (chemin_rel, ligne)))
    return trouves


# --- Releve complet ---------------------------------------------------------

def fichiers(extension, dossiers=("scripts", "scenes")):
    for dossier in dossiers:
        for racine, _dirs, noms in os.walk(os.path.join(ROOT, dossier)):
            for nom in sorted(noms):
                if nom.endswith(extension):
                    chemin = os.path.join(racine, nom)
                    yield os.path.relpath(chemin, ROOT).replace("\\", "/"), chemin


def lire(chemin):
    return io.open(chemin, encoding="utf-8").read()


def releve():
    """{(cle, contexte): [lieux]} dans l'ordre de premiere apparition."""
    entrees = {}
    for rel, chemin in fichiers(".gd"):
        if rel in EXCLUS:
            continue
        for cle, ctx, lieu in releve_script(rel, lire(chemin)):
            if cle.strip():
                entrees.setdefault((cle, ctx), []).append(lieu)
    for rel, chemin in fichiers(".tscn"):
        for cle, ctx, lieu in releve_scene(rel, lire(chemin)):
            entrees.setdefault((cle, ctx), []).append(lieu)
    return entrees


# --- Le fichier PO ----------------------------------------------------------

def _po_chaine(texte):
    texte = texte.replace("\\", "\\\\").replace('"', '\\"').replace("\t", "\\t")
    if "\n" not in texte:
        return '"%s"' % texte
    morceaux = texte.split("\n")
    lignes = ['""']
    for i, morceau in enumerate(morceaux):
        fin = "\\n" if i < len(morceaux) - 1 else ""
        if morceau or fin:
            lignes.append('"%s%s"' % (morceau, fin))
    return "\n".join(lignes)


def _po_lire_chaine(lignes):
    return _desechapper("".join(re.match(r'^\s*"(.*)"\s*$', l).group(1) for l in lignes))


def lire_po(chemin=PO):
    """Liste ordonnee de dicts {ctx, id, str, lieux, obsolete}, en-tete compris."""
    if not os.path.exists(chemin):
        return []
    entrees = []
    courante = {"ctx": "", "id": None, "str": "", "lieux": [], "commentaires": []}
    champ = None
    tampon = []

    def vider():
        nonlocal champ, tampon
        if champ:
            courante[champ] = _po_lire_chaine(tampon)
        champ, tampon = None, []

    for brute in io.open(chemin, encoding="utf-8").read().split("\n") + [""]:
        ligne = brute.rstrip("\r")
        if not ligne.strip():
            vider()
            if courante["id"] is not None:
                entrees.append(courante)
            courante = {"ctx": "", "id": None, "str": "", "lieux": [], "commentaires": []}
            continue
        if ligne.startswith("#:"):
            courante["lieux"].extend(ligne[2:].split())
            continue
        if ligne.startswith("#"):
            courante["commentaires"].append(ligne)
            continue
        m = re.match(r'^(msgctxt|msgid|msgstr)\s+(".*")\s*$', ligne)
        if m:
            vider()
            champ = {"msgctxt": "ctx", "msgid": "id", "msgstr": "str"}[m.group(1)]
            tampon = [m.group(2)]
            continue
        tampon.append(ligne)
    return entrees


ENTETE = '''msgid ""
msgstr ""
"Project-Id-Version: Infernum\\n"
"Language: en\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
'''


def ecrire_po(entrees, chemin=PO):
    blocs = [ENTETE]
    for e in entrees:
        if e["id"] == "":
            continue
        lignes = list(e.get("commentaires", []))
        if e.get("lieux"):
            lignes.append("#: " + " ".join(e["lieux"][:4]))
        if e["ctx"]:
            lignes.append("msgctxt " + _po_chaine(e["ctx"]))
        lignes.append("msgid " + _po_chaine(e["id"]))
        lignes.append("msgstr " + _po_chaine(e["str"]))
        blocs.append("\n".join(lignes) + "\n")
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    io.open(chemin, "w", encoding="utf-8", newline="\n").write("\n".join(blocs))


# --- Les oublis probables ---------------------------------------------------

FRANCAIS = re.compile(r"[àâçéèêëîïôûùüÿœæÀÂÇÉÈÊËÎÏÔÛÙÜŒ]|\b(?:le|la|les|des|du|une?|et|de|vous|pour|sans|avec|est)\b", re.I)


def suspects():
    for rel, chemin in fichiers(".gd"):
        if rel in EXCLUS:
            continue
        source = lire(chemin)
        chaines = lexer(source)
        retenus = {(c, ctx) for c, ctx, _l in releve_script(rel, source)}
        cles = {c for c, _ctx in retenus}
        for k, ch in enumerate(chaines):
            if ch.prefixe or ch.valeur in cles:
                continue
            v = ch.valeur
            if "res://" in v or "user://" in v or not re.search(r"[A-Za-zÀ-ÿ]{2}", v):
                continue
            ligne_code = source[source.rfind("\n", 0, ch.debut) + 1:source.find("\n", ch.debut)]
            if re.search(r"\b(print|push_warning|push_error|printerr|assert)\(|@export_", ligne_code):
                continue
            if "shader_type" in v or re.match(r"^[a-z0-9_./%:-]*$", v):
                continue
            if FRANCAIS.search(v) or re.search(r"[A-ZÀ-Ý]", v) or " " in v.strip():
                print("%s:%d  %r" % (rel, ch.ligne, v))


# --- Programme --------------------------------------------------------------

def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if "--suspects" in sys.argv:
        suspects()
        return 0
    trouves = releve()
    po = lire_po()
    connus = {(e["ctx"], e["id"]): e for e in po if e["id"]}
    manquants = []
    for (cle, ctx), lieux in trouves.items():
        e = connus.get((ctx, cle))
        if e is None or not e["str"]:
            manquants.append((cle, ctx, lieux))
    obsoletes = [e for k, e in connus.items() if (k[1], k[0]) not in trouves]
    # Un gabarit dont la traduction perd ou ajoute un `%d` fait échouer le
    # formatage EN JEU (texte vide et erreur), et seulement dans cette langue.
    gabarits = [e for e in connus.values() if e["str"] and _jetons(e["id"]) != _jetons(e["str"])]

    if "--manque" in sys.argv:
        nouvelles = [e for e in po if e["id"]]
        for e in nouvelles:
            e["lieux"] = trouves.get((e["id"], e["ctx"]), e["lieux"])
        for cle, ctx, lieux in manquants:
            if (ctx, cle) not in connus:
                nouvelles.append({"ctx": ctx, "id": cle, "str": "", "lieux": lieux})
        ecrire_po(nouvelles)
        print("%d textes, %d ajoutes a traduire" % (len(trouves),
              len([m for m in manquants if (m[1], m[0]) not in connus])))
        return 0

    for cle, ctx, lieux in manquants:
        print("MANQUE  %s  %r%s" % (lieux[0], cle, ("  [%s]" % ctx) if ctx else ""))
    for e in obsoletes:
        print("OBSOLETE  %r" % e["id"])
    for e in gabarits:
        print("GABARIT  %r -> %r" % (e["id"], e["str"]))
    print("%d textes, %d traduits, %d manquants, %d obsoletes, %d gabarits faux"
          % (len(trouves), len(trouves) - len(manquants), len(manquants), len(obsoletes),
             len(gabarits)))
    return 1 if manquants or gabarits else 0


def _jetons(texte):
    """Les emplacements de formatage, dans l'ordre : `%d`, `%+.1f`, `%%`,
    `{sceaux}`. L'ordre compte : `%` les remplit par position."""
    return re.findall(r"%[-+0#]*\d*(?:\.\d+)?[a-zA-Z%]|\{\w+\}", texte)


if __name__ == "__main__":
    sys.exit(main())
