# Assets

Un dossier par **entité du jeu**. Tout ce qui appartient à un personnage, un
ennemi ou un boss vit au même endroit : on ajoute une variante, une animation ou
un son sans avoir à chercher où il va.

```
assets/
├── sprites/
│   ├── characters/
│   │   ├── cain/   cain_idle.png  cain_walk.png  (+ cain.png, sprite fait main)
│   │   ├── job/    job_idle.png   job_walk.png
│   │   └── loth/   loth_idle.png  loth_walk.png
│   ├── enemies/
│   │   ├── imp/      imp_idle.png      imp_walk.png
│   │   ├── hound/    hound_idle.png    hound_walk.png
│   │   ├── cultist/  cultist_idle.png  cultist_walk.png
│   │   └── brute/    brute_idle.png    brute_walk.png
│   ├── bosses/
│   │   ├── golgota/  golgota_idle.png  golgota_walk.png
│   │   ├── lilith/   lilith_idle.png   lilith_walk.png
│   │   ├── baal/     baal_idle.png     baal_walk.png
│   │   ├── asmodee/  asmodee_idle.png  asmodee_walk.png
│   │   └── lucifer/  lucifer_idle.png  lucifer_walk.png
│   ├── arena/
│   │   └── floor/    floor.png                     ← dallage répétable
│   ├── ui/           panel · button(×3) · heart · coin · lock · star · gear · close
│   ├── projectiles/  hell_bolt/  cursed_bolt/      (SVG)
│   ├── pickups/      soul/  key/                   (SVG)
│   ├── ui/
│   └── Tiny RPG Character Asset Pack …/            ← packs sources, voir plus bas
├── audio/     mêmes catégories, à remplir
├── vfx/       mêmes catégories, à remplir
└── fonts/
```

## Les packs sources ne sont pas importés

Les deux dossiers `Tiny RPG Character Asset Pack …` sont la **bibliothèque
d'origine**, pas des assets du jeu : 40 personnages, une dizaine de planches
chacun. Ils portent un fichier **`.gdignore`**, qui les rend invisibles au
système de fichiers de Godot.

Ce n'est pas de la coquetterie : sans lui, Godot importe et met en cache près de
800 textures qui ne servent à rien, la première ouverture de l'éditeur devient
interminable et `.godot/imported/` enfle d'autant. Avec, le projet n'importe que
les 24 planches réellement employées.

Pour piocher une nouvelle créature : copier ses planches `…_Idle.png` et
`…_Walk.png` (**version « with shadows »**) dans le dossier de l'entité, pas
besoin de toucher au `.gdignore`.

## Convention de nommage

Le dossier porte l'identité, le fichier porte le rôle :

| Fichier | Rôle |
|---|---|
| `imp_idle.png` | planche au repos — c'est celle que la scène référence |
| `imp_walk.png` | planche de marche |
| `imp_portrait.png` | illustration d'interface (sinon calculée, voir plus bas) |

Pas de préfixe de catégorie dans le nom : le chemin le dit déjà.
`bosses/golgota/golgota_idle.png`, pas `bosses/golgota/boss_golgota_idle.png`.

## Planches d'animation

Une planche est une **bande horizontale d'images carrées** de 100 × 100. Le
nombre d'images n'est écrit nulle part : [`SpriteAnimator`](../scripts/components/sprite_animator.gd)
le déduit de la texture (largeur ÷ hauteur). Ajouter une image à une planche
suffit donc à l'animer — aucun réglage à mettre à jour.

Le composant bascule entre repos et marche d'après le **déplacement réel** du
parent, pas d'après sa vitesse désirée : un ennemi bloqué contre un mur garde une
posture cohérente avec ce qu'on voit. Il ne connaît ni `Player` ni `Enemy`, donc
il se pose tel quel sur n'importe quel corps.

Les packs fournissent aussi `_Attack01`, `_Hurt`, `_Death`. Rien ne les utilise
encore : le jeu signale les coups par un éclair de `modulate` et fait disparaître
les morts. Elles sont disponibles le jour où l'on veut les jouer.

## Format

Deux formats cohabitent, et ce n'est pas un accident :

- **PNG** pour tout le **pixel art** (personnages, ennemis, boss).
- **SVG** pour les formes plates encore en placeholder (projectiles, butin),
  importées en `CompressedTexture2D` sans compression ni mipmaps.

Le fichier `.import` accompagne toujours son image : déplacer l'un sans l'autre
force un ré-import et fait changer l'UID de la ressource.

### Le filtrage doit être « Nearest »

Par défaut Godot **interpole** les textures : un sprite pixel art devient flou dès
qu'il est affiché à une taille autre que 1:1 — et ils le sont tous, puisqu'ils
sont agrandis. Le filtrage n'est pas un réglage d'import mais une propriété de
`CanvasItem`, donc il se pose sur le nœud qui affiche la texture :

| Où | Réglage |
|---|---|
| chaque `Sprite2D` d'entité | `texture_filter = 1` (Nearest) |
| vignette du menu de sélection | `portrait.texture_filter = TEXTURE_FILTER_NEAREST` |

### Échelle et recalage : mesurés, pas devinés

Une planche fait 100 px de côté pour une figure d'une vingtaine de pixels, posée
sur une **ligne de sol** vers y = 56 et non centrée dans son image. Sans
correction, l'entité serait à la fois minuscule et dessinée au-dessus de son
propre cercle de collision.

Les deux réglages se mesurent sur les planches :

- **`scale`** : on vise une hauteur visible d'environ 3,3 × le rayon de collision
  (2,9 × pour les boss, plus massifs). Les trois personnages jouables partagent
  la **même** échelle — ce sont les mêmes humains, ils doivent se ressembler.
- **`offset`** : écart entre le centre de l'image et le centre du **corps**. Le
  corps se mesure sur la version SANS ombre de la planche ; l'ombre, elle, donne
  le centrage horizontal, puisqu'elle est toujours exactement sous le corps
  (c'est pourquoi `offset.x` vaut 0 partout : les packs centrent l'ombre, seule
  l'arme dépasse sur le côté).

| | échelle | offset.y |
|---|---|---|
| personnages | 3,0 | 3,5 (Caïn) · 2,5 (Job, Loth) |
| imp · hound · cultist · brute | 2,0 · 2,5 · 2,0 · 3,0 | 1,5 · 2,0 · 4,5 · 2,5 |
| golgota · lilith · baal · asmodée · lucifer | 5,5 · 4,0 · 5,5 · 5,5 · 5,0 | 7,5 · 5,5 · 6,5 · 3,0 · 7,5 |

Conséquence pour le joueur : il se miroite par **`sprite.scale.x`** et non par
`flip_h`, et le code mémorise la GRANDEUR de l'échelle (`_sprite_scale`). Écrire
`scale.x = -1` retournerait bien le personnage — en le rapetissant à l'échelle 1
au passage. Les ennemis, eux, gardent `flip_h` : leur `offset.x` étant nul, la
faiblesse de `flip_h` (il ignore `offset`) ne les concerne pas.

### Vignettes de personnage

La fiche de sélection ne peut pas afficher la bande entière, ni même sa première
case : ce serait 95 % de vide autour d'une figure illisible. `character_db`
mesure la zone opaque de la première image au chargement et construit un
`AtlasTexture` recadré dessus. Aucun cadrage n'est saisi à la main, donc changer
de sprite ne demande aucun réglage.

## L'interface

`sprites/ui/` contient les pièces extraites de **PixelUIKit** (panneau sombre,
liseré doré). Le kit complet reste dans `sprites/PixelUIKit/` avec un `.gdignore`
— même raison que pour les packs de personnages : on n'importe que ce qu'on
utilise.

Tout est assemblé dans un **thème unique**, [`assets/ui/theme.tres`](ui/theme.tres),
déclaré en `gui/theme/custom`. Aucun écran ne style ses panneaux ni ses boutons :
ils héritent. Changer le liseré, c'est une valeur dans un fichier.

### Les boutons ont dû être reconstruits

Ceux du kit portent un « OK » **gravé dans l'image**. En 9-tranches, c'est
inutilisable : la zone centrale est celle qu'on étire, donc le texte se serait
déformé avec la largeur du bouton.

Mais leur dégradé est uniforme horizontalement — 21 colonnes identiques de chaque
côté du texte. On reconstruit donc un bouton de 8 px : deux colonnes de bordure,
quatre colonnes de dégradé pur, deux de bordure. Les 9 tranches tombent dessus
proprement et le bouton s'étire à n'importe quelle taille.

Les marges verticales (haut 4, bas 8) sont choisies pour que l'étirement mange la
bande claire et laisse le biseau sombre intact : un bouton de 44 px reste un
bouton biseauté, pas un dégradé délavé.

### Deux variations de thème

| Variation | Pour quoi | Pourquoi pas le style par défaut |
|---|---|---|
| *(défaut)* | boutons d'action, panneaux d'écran | — |
| `CardButton` | cartes de personnage, cartes de pacte | sur le doré plein, les noms colorés (rouge de Caïn, violet des pactes) sont illisibles ; la variation est un panneau sombre à liseré doré |

### Les barres : le remplissage porte son propre retrait

Le kit ne fournit qu'une barre **pleine**, d'un seul tenant. Une `ProgressBar` en
veut deux : un rail vide et un remplissage. Les deux sont donc dérivés de
`bar_hp.png` — le rail en remplaçant le rouge par du sombre, le remplissage en
gardant le rouge.

Le piège est dans le dessin : Godot trace le remplissage sur **toute la hauteur
du contrôle**, sans tenir compte des marges du fond. Un remplissage plein
recouvrirait donc le cadre du rail. C'est le remplissage qui porte son retrait,
en **pixels transparents** — 2 px sur les quatre côtés — et les 9 tranches
tombent exactement dessus. À 0 %, seules les extrémités transparentes sont
tracées : rien ne reste à l'écran.

La barre de boss réutilise les deux mêmes images, éclaircies par
`modulate_color`. Un seul jeu de pièces, deux barres.

### Filtrage

`default_texture_filter` est passé à **Nearest** dans les réglages du projet :
c'est le bon réglage pour tout le pixel art, et l'interface en hérite sans avoir
à le poser écran par écran. Le sol de l'arène, seule texture non pixel art,
repasse explicitement en linéaire (`texture_filter = 2` sur son nœud).

### Icônes

Le kit n'a pas d'icône de clé. Les clés utilisent donc `lock` — c'est ce qu'elles
ouvrent, et la Forge Éternelle est littéralement un arbre de verrous.

| Icône | Usage |
|---|---|
| `heart` | barre de vie |
| `coin` | âmes |
| `lock` | clés |
| `star` · `gear` · `close` | disponibles, pas encore employées |

## Le sol

`arena/floor/floor.png` est un **carreau répétable** de 420 × 420 découpé dans une
carte d'arène. Deux précautions, sans lesquelles la répétition saute aux yeux :

- **La découpe tombe sur un joint de dalle.** Le dallage a un pas de 30 px ; le
  carreau fait exactement 14 dalles, et son bord gauche est le milieu d'un joint.
  Bout à bout, deux demi-joints en refont un entier et la grille ne se brise pas.
- **L'éclairage est aplati.** La carte d'origine s'assombrit vers ses bords ; sans
  correction, ce dégradé se répéterait en damier clair/sombre. Le carreau est donc
  divisé par une version très floue de lui-même (flou cyclique, rayon 45) : la
  lumière basse fréquence part, le détail des dalles reste.

Il est répété par [`floor_tiler.gd`](../scripts/components/floor_tiler.gd) — un
seul `Sprite2D` en `texture_repeat`, recalé chaque image sur un multiple de la
taille du carreau pour que le motif reste accroché au MONDE et non à l'écran.

La teinte `modulate = (0.66, 0.52, 0.50)` du nœud `Floor` assombrit et réchauffe
le dallage : brut, il est gris-brun et l'armure de Caïn s'y fond. Mettre du blanc
rend l'image d'origine telle quelle.

## Ajouter une entité

1. Créer `assets/sprites/<catégorie>/<nom>/` et y déposer `<nom>_idle.png` et
   `<nom>_walk.png`.
2. Ouvrir Godot une fois pour que l'import se fasse.
3. Dans la scène : régler `texture_filter`, `scale` et `offset` du `Sprite2D`
   (mesures ci-dessus), puis ajouter un nœud `SpriteAnimator` avec les deux
   planches.

Pour un personnage jouable, les chemins se déclarent dans
[`character_db.gd`](../scripts/characters/character_db.gd) (clés `sprite`,
`sprite_walk`, `sprite_offset`, `sprite_scale`) ; si un fichier est absent, le
catalogue le laisse simplement vide.
