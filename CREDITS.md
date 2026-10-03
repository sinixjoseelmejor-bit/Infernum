# Crédits

## Code et conception

Tout le code, l'équilibrage et les scènes du dépôt.

## Assets tiers

Aucun pack d'**image** n'est versionné ici (voir [`.gitignore`](.gitignore)) :
leurs licences interdisent de rendre les assets téléchargeables ou extractibles
en dehors du projet fini. L'audio fait exception, sa licence étant plus étroite
sur ce point. Seules les pièces
réellement employées, recadrées et adaptées, vivent dans les dossiers d'entité.

### PixelUIKit — interface

Panneau, boutons, barres et icônes. `LICENSE.txt` fourni avec le pack.

- Usage personnel et **commercial** illimité, y compris dans un jeu vendu.
- Modification, recadrage et recolorisation autorisés.
- Aucune attribution exigée (mais appréciée — d'où cette page).
- Redistribution des assets **interdite**, originaux comme modifiés.

Utilisé ici : `panel`, `button` (3 états), `bar_hp`, et les icônes `heart`,
`coin`, `lock`, `star`, `gear`, `close`. Les boutons ont été reconstruits sans
leur texte gravé, les barres découpées en rail + remplissage. Depuis la 0.10.1,
les menus utilisent aussi `slot`, `slot_selected`, `arrow_left/right`,
`toggle_on/off` et `checkbox_on/off`, **recolorisés** (violet et or → charbon et
braise) et agrandis ×2 ou ×3 par `tools/extract_assets.py` — la licence permet
la recolorisation, et ces dérivés restent hors du dépôt comme les originaux.

### Tiny RPG Character Asset Pack (v1.03 et 02) — personnages, ennemis, boss

Licence publiée sur la page de téléchargement du pack :

- Usage **personnel et commercial** dans des projets de jeu vidéo.
- Modification et adaptation autorisées.
- Redistribution, revente ou **ré-upload interdits**, modifiés comme non modifiés.
- Usage interdit pour l'**entraînement d'IA** et les projets **NFT**.
- Crédit apprécié mais non exigé (d'où cette page).

Utilisé ici, planches de repos et de marche uniquement :

| Dans le jeu | Sprite d'origine |
|---|---|
| Caïn | Armored Axeman |
| Job | Knight Templar |
| Loth | Archer |
| imp | Demon_A |
| hound | Hellhound |
| cultist | Warlock |
| brute | Minotaur |
| œil | Eyeball Monster |
| Golgota | Flame Golem |
| Lilith | Demoness_A |
| Baal | Demon_C |
| Asmodée | Demon_E |
| Lucifer | Black Knight_C |
| chauve-souris (0.9.2) | Hellbat (vol, repos compris) |
| feu follet (0.9.2) | Ghostfire (vol, repos compris) |
| slime de lave (0.9.2) | Lava Slime |
| invocatrice (0.9.2) | Demoness_B |

L'icône du jeu (`icon.png`, `icon.ico`) est dérivée du sprite du Flame Golem.

### Texture — retiré en 0.9.2

Le pack du décor d'origine de l'arène (ruines, éboulis, urnes, buissons passés
à la cendre). **Sorti du projet en 0.9.2** : sa pierre beige, peinte et
lissée, jurait à côté du pixel art net du pack de la carte, et plus rien ne
l'employait. Ses 15 pièces extraites et leur code d'extraction ont été
supprimés.

### 2DML SET 3 — la carte de l'enfer (0.9.2)

`assets/packs/2DML_SET3_v1.0/` — trois planches (terrains, décor, petits
objets), six planches d'animation et leurs sources PSD, `public-license.txt`
fourni avec le pack. Art de **Szadi art**.

- Usage **personnel et commercial**, y compris dans un jeu vendu.
- Modification, découpe et adaptation autorisées.
- **Revente interdite**, originale ou modifiée — d'où l'exclusion du dépôt,
  comme les autres packs d'images.
- Emploi interdit dans un logo, une marque ou une marque de service.
- Crédit non exigé mais apprécié : **Szadi art**, d'où cette page.

[`tools/extract_enfer.py`](tools/extract_enfer.py) en tire 71 fichiers :
cheminées volcaniques, formations rocheuses, arbres morts, cailloux, herbes,
buissons, fissures, fumerolles et bulles animées, trois carreaux de sol, et
des bassins, lacs, fosses et plateaux **composés** à partir des blocs de tuiles
du pack. Ne sont pas employés : les conteneurs métalliques à voyants verts
(`other_props.png`), hors sujet dans un enfer ; les taches de sol en fleur ; le
plateau aux bords de lave, dont le dessus a la couleur du sol.

### Hell Underworld Tileset — retiré en 0.9.2

Le pack de la carte de la 0.9.1. **Retiré parce que son vendeur l'avait produit
avec une IA.** Toutes les images qui en étaient tirées (210 pièces, 3 textures)
ont été supprimées ; rien du jeu n'y renvoie plus. Les builds et la
bande-annonce de la 0.9.1 le montrent encore.

### Touches clavier — l'affichage des touches (0.9.1)

`assets/packs/Touches/touches_clavier.png` — une planche de 128 × 224 : les
touches du clavier en 16 px (flèches, F1 à F12, A à Z, quelques signes), en
versions normale et enfoncée. Déposée sans nom de pack ni fichier de licence :
**la source et la licence sont à consigner ici avant une diffusion publique.**
Comme les autres images tierces, elle reste hors du dépôt ; `extract_assets.py`
la copie et en tire une touche vierge.

### Effets sonores et musiques

`assets/audio/SoundEffects/` — `LICENSE.txt` fourni avec les fichiers. C'est le
seul lot d'assets tiers **versionné ici**, parce que sa licence l'autorise :

- Licence non exclusive, mondiale, libre de droits, projets **personnels et
  commerciaux**.
- Découpe, modification et mixage autorisés — le tir du joueur est d'ailleurs
  coupé à 0,5 s.
- Mise à disposition interdite **uniquement** sous forme de banque de sons, de
  pack d'échantillons ou de tout autre format autonome ; les sons doivent être
  intégrés à un projet global et ne pas en être le produit principal.
- Attribution appréciée mais non exigée (d'où cette page). Le fichier de licence
  ne nomme pas son auteur — la mention est restée à l'état de gabarit —, on ne
  peut donc créditer personne nommément.

Trois musiques (menus, arène ×2) et cinq effets : tir, mort d'un ennemi,
apparition d'un boss, objet obtenu, clic d'interface.

**`MusicGameplay2.ogg` est à rattacher.** La seconde musique d'arène a été
déposée dans le même dossier que les autres, mais on ne sait pas si elle vient
du même lot — donc si le `LICENSE.txt` ci-dessus la couvre. À confirmer avant
toute diffusion publique, au même titre que `menu.jpg`. Si
elle vient d'ailleurs, sa licence peut être plus étroite que celle qui autorise
le versionnement de ce dossier.

### Musiques d'arène ajoutées — dossier `Music/`

Six fichiers déposés dans `assets/audio/Music/`, dont quatre employés comme
musiques d'arène. **Aucun fichier de licence ne les accompagne** : ils ont été
téléchargés comme libres de droits et libres de licence, et c'est cette mention
faite au téléchargement qui fonde leur emploi ici. Si le point devait être
retracé, c'est la page de téléchargement qui fait foi.

Les noms de fichiers sont **gardés tels quels**, avec le pseudonyme de l'auteur
et l'identifiant du morceau. Ils sont laids dans le code et c'est le prix : ce
sont eux qui portent l'attribution, faute de fichier de licence.

| Fichier | Auteur annoncé | Durée | Emploi |
|---|---|---|---|
| `alex-morgan-thrash-metal-591343.ogg` | alex-morgan | 3 min 02 | arène |
| `wolfdudedodi-cyber-wolf-529967.ogg` | wolfdudedodi | 3 min 24 | arène |
| `strawberry_candy-powerful-heavy-metal-heavy-force-572627.ogg` | strawberry_candy | 2 min 07 | arène |
| `mrclaps-this-heavy-metal-492569.ogg` | mrclaps | 2 min 09 | arène |
| `43084433-hard-rock-logo-intro-335297.ogg` | — | 13,8 s | aucun |
| `freesound_community-rock-destroy-6409.ogg` | freesound_community | 2,9 s | écrasement de Golgota (0.9.1) |

### Effets sonores ajoutés — dossier `Sfx/` (0.9.1)

36 fichiers déposés comme **libres de droits**, sans fichier de licence joint :
comme pour les musiques ci-dessus, c'est la mention faite au téléchargement qui
fonde leur emploi, et la page d'origine qui fait foi. **Les sources restent à
consigner ici** (lien et licence par fichier) avant une diffusion publique.

Ils ont été renommés en entrant dans le projet — leurs noms d'origine étaient des
descriptions, pas des attributions. Correspondance, pour les retrouver :

| Dans le projet | Nom déposé |
|---|---|
| `ame.ogg` | ramasser ame (remplace « ame ramassé », devenu le son des clés) |
| `ambiance_donjon.ogg` | dungeon ambient sound |
| `ambiance_lave.ogg` | ambient lava |
| `chaine.ogg` | chain |
| `cle.ogg` | Ramasser clé (l'ancien « ame ramassé ») |
| `foudre.ogg` | thunder |
| `meuglement.ogg` | cow muh |
| `teleportation.ogg` | teleport |
| `tir_ennemi.ogg` | tir culturiste |
| `vie_basse.ogg` | low hp |
| `baiser.ogg` | kiss |
| `cle_abysses.ogg` | abyss key |
| `consecration.ogg` | eart magic |
| `coup_encaisse.ogg` | Coup encaissé joueur |
| `explosion.ogg` | explosion sound |
| `forge.ogg` | anvil noise |
| `glitch_1.ogg` à `glitch_4.ogg` | Glitch 1 à Glitch 4 |
| `impact.ogg` | impact ennemi |
| `jugement.ogg` | jugement job |
| `lance.ogg` | lance tir |
| `mort_boss.ogg` | Boss explosion die |
| `mort_joueur.ogg` | dying man |
| `parade.ogg` | parade Job |
| `parade_ratee.ogg` | parade ratée |
| `prix_du_sang.ogg` | Blood Cain |
| `ruee.ogg` | Dash loh |
| `seconde_chance.ogg` | resurrection sounf |
| `soin.ogg` | soin ramassé |
| `texte.ogg` | text |
| `texte_ligne.ogg` | Text 2 |
| `voile_brise.ogg` | Glass clack |

(Ceux du premier lot portaient le suffixe « -converted ». Le gong a été retiré.)

## Art propre au projet

Versionné, contrairement aux planches tirées des packs : il n'appartient à
personne d'autre.

| Fichier | Rôle |
|---|---|
| `assets/sprites/arena/floor/` | les deux carreaux de sol |
| `assets/sprites/characters/cain/` | le sprite de Caïn, fait main |
| `assets/sprites/bosses/Morts/MortAll.png` | l'animation de mort, commune aux cinq ennemis |
| `assets/sprites/LogoStudio.png` | le logo **RootStudio**, affiché au lancement |

### Effet d'explosion

`assets/vfx/Effect_pushAndStars/` — planche « Puff and Stars » de **@CodeManuPro**.
`LICENSE.txt` fourni avec l'asset : **domaine public**, usage personnel et
commercial, aucun crédit exigé. C'est la licence la plus permissive du projet —
elle n'impose rien, la mention est ici parce que l'auteur la dit appréciée.

Utilisée pour l'explosion de *Braise éternelle*.

### Impacts au sol des boss

`assets/sprites/bosses/vfx-Sheet.png` — cinq effets d'impact sur une grille de
17 × 5 cellules de 96 px, achetés. **Aucun fichier de licence n'accompagne la
planche** : l'auteur précise à l'achat qu'elle est d'usage libre, et c'est sur
cette mention que repose son emploi ici. Si ce point devait être retracé, c'est
la page d'achat qui fait foi, faute de `LICENSE.txt`.

Utilisée pour les zones annoncées de Golgota, Baal, Asmodée et Lucifer.

### L'éclair de Baal (0.10.1)

`assets/sprites/bosses/Eclaire.png` — planche de foudre (3 variantes de
5 images), déposée par l'auteur du projet pour les zones de foudre de Baal.
**Source et licence à consigner ici** avant une diffusion publique.

### Icônes d'objets

`assets/packs/ItemIconPack/` — 1244 icônes 16×16, `LICENSE.txt` fourni avec le
pack.

- Usage **libre, personnel et commercial**.
- Modification de n'importe quelle partie autorisée.
- **Redistribution et revente interdites** — d'où l'exclusion du dépôt.
- Crédit vivement apprécié (d'où cette page) ; le fichier de licence ne nomme
  pas son auteur.

48 icônes en sont tirées, une par objet du catalogue, plus quatre pour le
butin (âme, clé, soin, Clé des Abysses) depuis la 0.10.1. La table de correspondance
est dans [`tools/extract_assets.py`](tools/extract_assets.py).

### Sol de l'arène

Deux carreaux, tous deux de l'art fourni par l'auteur du projet, et les seules
images versionnées ici avec les effets sonores.

- `floor.png` — 348 × 362, découpé dans une carte d'arène. Le découpage d'origine
  (420 × 420) portait une couture visible une fois répété ; il a été recadré en
  (68, 52) pour que le carreau se raccorde à lui-même.
- `floor2.png` — 528 × 576, le second étage, tiré d'un rendu de 1408 × 768 par
  mesure du pas des dalles et suppression du vignettage. Le rendu source
  (`floor/source/Floor2.jpg`) est conservé, masqué à Godot par un `.gdignore` :
  il ne part pas dans l'export. L'outil qui en tire le carreau est
  [`tools/floor_tile.gd`](tools/floor_tile.gd). **Si ce rendu venait d'un pack
  tiers et non du projet, il faut le déplacer sous `assets/packs/` comme les
  autres** : la clause de non-redistribution s'appliquerait à lui aussi.

Le procédé des deux découpes, et la mesure qui les justifie, sont détaillés dans
[`README.md`](README.md).

### Police de l'interface — Jersey 10

`assets/fonts/Jersey10-Regular.ttf`, pour le logo INFERNUM, les titres d'écran
et tous les boutons. **SIL Open Font License 1.1**, texte complet dans
[`assets/fonts/Jersey10-OFL.txt`](assets/fonts/Jersey10-OFL.txt).

> Copyright 2023 The Soft Type Project Authors
> (https://github.com/scfried/soft-type-jersey)

Téléchargée depuis le dépôt officiel Google Fonts (`ofl/jersey10`). L'OFL
autorise l'usage commercial et l'embarquement dans un exécutable ; elle impose
de livrer la licence avec la police et interdit seulement de **vendre la police
seule**. Elle remplace **Alagard**, retirée du projet en 0.8.6 faute de licence
vérifiable — sa table `name` ne portait qu'un crédit, « Pix3M », sans chaîne de
licence ni URL.

### Illustration du menu titre

`assets/sprites/menu/menu.jpg`, 1588 × 656 — le gouffre en flammes du menu
principal. Art fourni par l'auteur du projet, comme les carreaux de sol, et
versionné pour la même raison.

**Si cette illustration venait d'un pack tiers et non du projet, il faut la
déplacer sous `assets/packs/` comme les autres** : la clause de
non-redistribution s'appliquerait à elle aussi. Elle a d'ailleurs été déposée
d'abord dans `assets/sprites/ui/`, un dossier tenu hors de git précisément
parce qu'il reçoit les extractions de PixelUIKit — elle y aurait été invisible
au dépôt sans que rien ne le signale.

Le fichier est resté en JPEG : la mesure montre qu'il est déjà à sa résolution
native, donc le convertir n'aurait rien enlevé aux artefacts et aurait doublé son
poids. Le raisonnement et les chiffres sont dans [`README.md`](README.md).

## Moteur

[Godot Engine](https://godotengine.org) 4.6.2, licence MIT.
