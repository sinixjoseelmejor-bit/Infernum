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

### Sol de l'arène

`assets/sprites/arena/floor/floor.png` — carreau de 420 × 420 découpé dans une
carte d'arène fournie par l'auteur du projet.

## Moteur

[Godot Engine](https://godotengine.org) 4.6.2, licence MIT.
