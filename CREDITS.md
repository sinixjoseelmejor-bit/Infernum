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
leur texte gravé, les barres découpées en rail + remplissage.

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
| Golgota | Flame Golem |
| Lilith | Demoness_A |
| Baal | Demon_C |
| Asmodée | Demon_E |
| Lucifer | Black Knight_C |

L'icône du jeu (`icon.png`, `icon.ico`) est dérivée du sprite du Flame Golem.

### Texture — décor de l'arène

`assets/packs/Texture/` — deux atlas de 512 × 512, `LICENCE` fourni avec le pack.

- Usage **libre, personnel et commercial**.
- Modification autorisée.
- **Redistribution et revente interdites** — d'où l'exclusion du dépôt.
- Crédit apprécié mais non exigé (d'où cette page) ; le fichier de licence ne
  nomme pas son auteur.

15 pièces en sont tirées, découpées et renommées : pierres, gravats, dalles,
autel, urnes, jarre, anneau, pierre levée, tour, et trois buissons reteintés en
cendre. Quatre pièces de cimetière ont été découpées puis retirées, le décor ne
composant que des ruines et des éboulis. Les rectangles de découpe sont dans `DECOR`, au sein de
[`tools/extract_assets.py`](tools/extract_assets.py) ; les atlas n'ont aucune
grille, ces relevés ne se retrouveraient pas autrement. Le reste du pack — caisses,
tonneaux, portes, banc, panneaux gravés, tuiles d'herbe — n'est pas employé.

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

Deux musiques (menus, arène) et cinq effets : tir, mort d'un ennemi, apparition
d'un boss, objet obtenu, clic d'interface.

### Effet d'explosion

`assets/vfx/Effect_pushAndStars/` — planche « Puff and Stars » de **@CodeManuPro**.
`LICENSE.txt` fourni avec l'asset : **domaine public**, usage personnel et
commercial, aucun crédit exigé. C'est la licence la plus permissive du projet —
elle n'impose rien, la mention est ici parce que l'auteur la dit appréciée.

Utilisée pour l'explosion de *Braise éternelle*.

### Icônes d'objets

`assets/packs/ItemIconPack/` — 1244 icônes 16×16, `LICENSE.txt` fourni avec le
pack.

- Usage **libre, personnel et commercial**.
- Modification de n'importe quelle partie autorisée.
- **Redistribution et revente interdites** — d'où l'exclusion du dépôt.
- Crédit vivement apprécié (d'où cette page) ; le fichier de licence ne nomme
  pas son auteur.

24 icônes en sont tirées, une par objet du catalogue. La table de correspondance
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

## Moteur

[Godot Engine](https://godotengine.org) 4.6.2, licence MIT.
