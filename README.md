# Infernum

Roguelite d'action top-down (Brotato / Hades / Risk of Rain 2), ambiance enfer & démons.
**Godot 4.6** — testé sur 4.6.2 stable.

## Lancer

Ouvrir le dossier dans Godot, puis F5. Scène de départ :
`scenes/ui/main_menu.tscn`. L'arène est `scenes/main/main.tscn`.

> **Après un clone, il manque les images.** Les sprites des personnages, des
> ennemis, des boss et de l'interface viennent de packs tiers dont la licence
> interdit la redistribution : ils ne sont pas dans le dépôt. Déposer les trois
> packs dans `assets/sprites/` puis lancer
> ```bash
> python tools/extract_assets.py
> ```
> Le script n'a aucune dépendance et reconstruit tout à l'identique : les 12
> planches d'entité, les pièces d'interface, et l'icône de l'application. Les
> noms de packs attendus sont en tête du fichier, les licences dans
> [`CREDITS.md`](CREDITS.md).

| Action | Clavier | Manette | Mobile |
|---|---|---|---|
| Déplacement | ZQSD/WASD + flèches | stick gauche | joystick virtuel |
| Tir | automatique | automatique | automatique |
| **Pause** | `Échap` | `B` | — |
| Recommencer | `R` | — | bouton de l'écran de fin |

Le joystick virtuel est masqué sur desktop. Pour le tester à la souris, passer
l'option **Joystick virtuel** sur « Toujours affiché ».

## Boucle de jeu

Le jeu s'ouvre sur un **menu principal** — Jouer, Profils, Options, Quitter.
« Jouer » mène au choix du personnage (et à la Forge Éternelle). Puis, au
lancement d'une run, un écran propose des **malédictions** — entièrement
facultatives. Puis s'enchaînent des vagues de durée croissante. À la fin de chaque
vague le jeu se met en pause et la **boutique** s'ouvre : le joueur y dépense ses
**âmes** pour acheter des objets parmi 4 propositions (relance payante), et peut
accepter un **pacte de vague** pour la vague suivante — facultatif lui aussi.

La run se termine à la mort du joueur : les âmes non dépensées sont perdues, les
**clés** récoltées sont capitalisées et servent à alimenter la **Forge Éternelle**
(arbre de méta-progression permanent) et à débloquer des objets.

Le HUD affiche en permanence : vie, **numéro de vague**, **minuteur de la vague**,
âmes, clés, éliminations.

## Systèmes

### Vagues — [wave_manager.gd](scripts/systems/wave_manager.gd)

| Courbe | Formule | Note |
|---|---|---|
| Durée | `20 s + 2 s × (vague-1)`, max 45 s | |
| Densité | `0.8 + 0.22 × (vague-1)` spawn/s, max 6 | |
| PV ennemis | `× (1 + 0.14 × (vague-1))` | **additif**, pas composé |
| Dégâts ennemis | `× (1 + 0.11 × (vague-1))` | la seule courbe qui rend la fin de run dangereuse |
| Vitesse ennemis | `× (1 + 0.015 × (vague-1))`, max ×1.35 | |
| Élites | à partir de la vague 4, jusqu'à 18 % (31,5 % avec options) | PV ×4, âmes ×2, 2 % de clé, 8 % de soin |
| Boss | PV `× (1 + 0.09 × (vague − 5))` | sinon ils tombaient en 4 s en fin de run |

Les i-frames du joueur (0,4 s) bornent les dégâts entrants à **2,5 coups par
seconde** : le nombre d'ennemis ne fait donc presque rien au danger réel, seuls
les dégâts **par coup** comptent. C'est pourquoi la courbe de dégâts ennemis est
la plus raide après celle des PV — et pourquoi les options qui ajoutent de la
densité paient peu (voir Malédictions et Pactes).

La difficulté monte **linéairement**. C'est délibéré : à la vague 20 un imp a ×3.66 PV,
pas ×13.7 comme le donnerait un `×1.14` composé par vague. La puissance du joueur
étant elle-même plafonnée, les deux courbes restent comparables.

Les ennemis survivants sont dissipés en fin de vague, sans récompense — sinon la fin
de vague devient un distributeur d'âmes gratuit.

**Les tirs et les zones en cours sont dissipés aussi**, et c'est moins évident. La
boutique met l'arbre en pause : un trait de cultiste ou une zone de boss encore
en l'air quand la vague tombe y reste figé, puis repart à la fermeture de la
boutique — sur un joueur qui regardait l'interface et n'a aucun moyen de
l'anticiper. La durée de vie des projectiles ne l'en sauve pas : son minuteur est
gelé lui aussi, donc ils attendent aussi longtemps que la boutique reste ouverte.

Mesuré avant correction : six traits en vol, 3 s de boutique, **10 dégâts
encaissés à la réouverture sans que le joueur ait rien fait**. Après : zéro.
Le conteneur ne porte que des projectiles et des télégraphes ; les âmes non
ramassées sont enfants du conteneur d'ennemis et survivent, comme il se doit.

### Le soin

Deux sources, aucune autre. Il n'y avait rien auparavant : la moindre erreur se
payait jusqu'à la fin de la run, et une partie pouvait être condamnée dès la
vague 6 sans l'être vraiment — le joueur traînait quinze vagues avec 12 PV.

- **5 PV par vague franchie.** Un plancher de confort, pas une régénération :
  5 PV ne rattrapent pas une vague mal jouée.
- **25 % des PV max en plus à la mort d'un boss.** Un boss se gagne rarement
  intact ; sans cela, le survivre revenait à entamer la suite avec les restes, et
  la punition dépassait de loin la récompense. Vérifié : 20 → 46 PV sur 85 max,
  soit les 5 PV de vague plus 21 du boss.
- **Les élites laissent un soin dans 8 % des cas**, rendant 10 % des PV **max**
  (plancher à 8 PV). En pourcentage et non en plat, parce que les objets de vie
  peuvent doubler le maximum : un soin fixe deviendrait dérisoire là où il sert.

#### Le plafond est la pièce importante

Le nombre d'élites par vague passe de 2 à la vague 5 à **86 à la vague 25** : une
simple probabilité par élite ferait du soin une ressource quarante fois plus
abondante en fin de partie qu'au début, précisément là où le jeu doit mordre.
D'où un plafond de **2 soins par vague**. Mesuré :

| Vague | Élites | Soins/vague | PV rendus | + régen | Total |
|---|---|---|---|---|---|
| 2 | 0 | 0 | 0 % | 5 | **5 %** |
| 5 | 1,9 | 0,16 | 1,6 % | 5 | **6,6 %** |
| 10 | 14,8 | 1,08 | 10,8 % | 5 | **15,8 %** |
| 15 | 41,9 | 1,84 | 18,4 % | 5 | **23,4 %** |
| 25 | 86,2 | 1,99 | 19,9 % | 5 | **24,9 %** |

Sans le plafond, la même courbe donnait **56 % des PV max par vague à la
vague 20** et 69 % à la vague 25 — le joueur se serait soigné plus vite qu'il ne
pouvait être touché.

Avec le plafond, la courbe monte puis se stabilise à un quart des PV max par
vague. À la vague 20 un brute frappe pour 49 : un quart des PV max, c'est **une
demi-touche de brute par vague**. De quoi absorber une erreur, pas une mauvaise
passe.

#### Ce qui n'a délibérément pas été branché

Le soin n'est **pas** multiplié par les malédictions ni par les pactes,
contrairement aux clés. Ces systèmes sont déjà les canaux de puissance du jeu ;
y brancher la survie en ouvrirait un cinquième, et celui-là annulerait
directement la difficulté qu'ils sont censés ajouter.

Le surplus est perdu : ramasser un soin à pleins PV ne met rien en réserve.
C'est ce qui empêche de thésauriser les soins au sol pour les prendre au moment
idéal — ils sont d'ailleurs aspirés en fin de vague comme le reste du butin.

### L'aspiration de fin de vague

La boutique n'ouvre pas à la seconde où la vague tombe. Entre les deux, un état
`COLLECTING` : **tout le butin encore au sol fonce vers le joueur**, et la
boutique attend la carte vide.

Les âmes au sol n'étaient pas perdues pour autant — vérifié, elles survivent au
nettoyage de fin de vague et à la vague suivante, elles n'ont aucune durée de
vie. Le problème était qu'elles n'étaient pas **dépensables** à la boutique qui
venait de s'ouvrir : elles attendaient que le joueur repasse dessus pendant la
vague suivante et ne comptaient qu'à la boutique d'après. Il fallait donc
arbitrer entre finir sa tournée de ramassage et se battre — ce qui punissait
surtout les fins de vague chargées, celles où il y a le plus à ramasser.

L'aspiration force l'accroche quel que soit le rayon et pousse la poursuite à
1 400 px/s. Mesuré, joueur immobile, trente âmes semées de 80 à 1 500 px :
**30 sur 30 récupérées, boutique ouverte 1,37 s après la fin de vague**.

Deux détails qui comptent :

- L'ordre de nettoyage. Ennemis et projectiles sont dissipés **avant** la
  collecte, pas après : le joueur traverse cette seconde et demie sans pouvoir
  être touché.
- Un garde-fou de 3 s. Au-delà, ce qui reste est encaissé d'office. Une boutique
  qui ne s'ouvre jamais à cause d'une âme injoignable serait bien pire qu'une âme
  ramassée à distance.

L'appel est répété à chaque image et non passé une fois : un ennemi mort au même
instant dépose ses âmes en différé, elles doivent être rattrapées aussi.

### Ennemis — 4 comportements

| Type | Script | Comportement | Vague |
|---|---|---|---|
| **Imp** | `enemy.gd` | corps-à-corps, poursuite directe | 1 |
| **Limier** | `dasher_enemy.gd` | rapide : approche → armement télégraphié → charge → récupération | 2 |
| **Cultiste** | `ranged_enemy.gd` | distance : garde ~320 px, recule si on l'approche, tire | 3 |
| **Brute** | `enemy.gd` | tanky : lent, 90 PV, résistant au recul, gros dégâts de contact | 4 |

Âmes par ennemi : imp 3, limier 3, cultiste 5, brute 6 — soit environ 0,1 âme par
point de PV pour tout le monde. La brute était réglée sur une propriété morte
(`xp_value`, qui n'existe pas sur `Enemy`) et retombait donc sur 3 âmes pour
90 PV : l'ennemi le plus coûteux à tuer était aussi le moins rentable, et c'est
son poids d'apparition qui croît le plus vite.

Le limier s'immobilise pendant son armement : la menace vient de la pression au sol,
pas d'un coup inévitable. Les projectiles ennemis n'ont **ni tir à l'avance ni
auto-correction** — l'aide à la visée est un confort réservé au joueur.

### Objets — 21 objets, 4 raretés

6 communes · 6 rares · 6 épiques · 3 légendaires, plus **3 objets à débloquer aux clés**.
Tout est déclaré en données dans [item_database.gd](scripts/items/item_database.gd) :
ajouter un objet purement statistique ne demande aucune ligne de code.

Prix de base : 25 / 45 / 75 / 100 âmes, ajustés par vague et par richesse (voir
Économie). Poids de rareté à la vague 1 :
60 / 27 / 10 / 3, dérivant vers le haut avec un plafond dur (max 25 % épique, 10 % légendaire).

## Équilibrage

Les valeurs ci-dessous ont été mesurées par un banc d'essai qui instanciait les
vraies classes du jeu (`PlayerStats`, `Weapon`, `ItemDB`, `WaveManager`), pas une
ré-implémentation. Métrique : `puissance = √(ratio DPS × ratio PV effectifs)`,
évaluée en valeur **marginale** sur une build de milieu de partie, rapportée au
coût en âmes.

### Les neuf règles anti-scaling

**1. Additif, jamais multiplicatif entre objets.** Deux objets à +25 % de dégâts
donnent +50 %, pas ×1.5625. Sans cette règle, 10 objets à +25 % donneraient ×9.3
au lieu de ×3.5. [`PlayerStats`](scripts/core/player_stats.gd) additionne des
*pools* et n'applique le total qu'une fois.

**2. Chaque pool est plafonné.**

| Stat | Plafond |
|---|---|
| Dégâts | +200 % |
| Cadence | +150 % |
| Ennemis traversés | +3 |
| Projectiles | +4 |
| Chance critique | 60 % |
| Dégâts critiques | ×3.5 max (×3.2 réellement atteignable) |
| Vitesse | +60 % |
| Vol de vie | 8 %, **et** 1,5 % des PV max soignés par seconde |
| Armure | `armure / (armure + 100)`, armure plafonnée à 160 → 61,5 % max |
| Gain d'âmes | +75 % |
| Chance (raretés) | +3 |

L'armure et la chance étaient les deux seuls axes **sans plafond**. L'armure
montait à 236 (70 % de réduction) et les trois objets les plus rentables du jeu
étaient défensifs ; la chance n'était bornée qu'en aval, par les limites de poids
de rareté.

**3. Le multishot est taxé globalement** : `1 / (1 + 0.35 × extra)`. 2 projectiles
= ×1.48 de DPS, 5 = ×2.08. Sous-linéaire quel que soit l'objet qui ajoute le
projectile, donc un futur objet multishot ne peut pas casser l'économie.

**4. Aucun objet ne cumule deux axes multiplicatifs sans contrepartie.** Dégâts %,
cadence % et projectiles se multiplient entre eux : tout objet qui en touche deux
paie sur le troisième.

**5. Les bonus plats restent petits.** Un bonus en pourcentage se dilue dans le
pool additif à mesure que la build grandit ; un bonus plat, non. Un « +3 dégâts »
sur une arme à 12 vaut +25 % de DPS pour toujours — plus que le meilleur objet
rare, au prix d'une commune.

**6. Aucun objet ne sature un plafond à lui seul.** Si `mods[axe] × max_stacks`
atteint le plafond, celui-ci cesse d'être une incitation à diversifier et devient
« achetez quatre fois le même objet ». *Sceau du gardien* (×5 = ×6.12 de PV
effectifs), *Couronne du prédateur* (×5 = les deux plafonds de critique) et
*Écailles de basalte* ont vu leur nombre de piles réduit pour cette raison.

**7. La récompense suit le risque MESURÉ, pas le risque apparent.** Les i-frames
du joueur bornent les dégâts entrants à 2,5 coups/seconde : ajouter des ennemis
ne coûte presque rien et multiplie le revenu en âmes. Les options de **densité**
paient donc peu (Horde +15 %, Marée montante +5 %), celles qui augmentent les
dégâts **par coup** paient le plus (Fureur +35 %, Rituel de sang +32 %).

**8. Le prix des objets croît de façon quadratique avec l'inventaire.** Plus de
puissance = plus de kills = plus d'âmes = plus de puissance : c'est une boucle de
rétroaction, et une courbe de prix linéaire ne la rattrape jamais. Le facteur de
richesse est `1 + 0.06 n + 0.0035 n²`, ce qui ne mord vraiment que sur les runs
qui s'emballent.

**9. Aucun effet « par kill » non plafonné.** *Griffe du moissonneur* est borné à
+40 % de dégâts. *Braise éternelle* fait exploser les cadavres mais **les
explosions ne s'enchaînent pas**, et son explosion suit les dégâts d'UN projectile
(donc taxée par le multishot, et indifférente à la cadence) : elle ne scale pas
seule.

### Dispersion mesurée du pool

Efficacité par âme dépensée, objets purement statistiques :

Puissance gagnée pour 100 âmes dépensées, objets purement statistiques :

| Rareté | Médiane | Min | Max | Écart |
|---|---|---|---|---|
| Commune | 17.8 | 10.4 (Croc ébréché) | 20.5 (Cuir tanné) | ×2.0 |
| Rare | 15.5 | 7.7 (Œil du chasseur) | 17.1 (Écailles de basalte) | ×2.2 |
| Épique | 12.2 | 6.8 (Duvet de phénix) | 16.0 (Sceau du gardien) | ×2.3 |
| Légendaire | 15.4 | — | — | — |

Les huit meilleurs objets du catalogue tiennent maintenant dans un intervalle de
×1.33 (20.5 → 15.4) et **mélangent tous les axes** : défense (Cuir tanné,
Écailles), cadence (Percuteur), dégâts (Fiel de démon), polyvalent (Sceau du
gardien), plat (Braise ardente), légendaire (Horloge damnée). Avant cette passe,
les trois premiers étaient défensifs et creusaient un écart de ×2 sur la médiane.

La métrique ne chiffre ni la portée (*Œil du chasseur*), ni le vol de vie
(*Sangsue*), ni l'explosion (*Braise éternelle*), ni le gain d'âmes (*Aimant*,
*Siphon*), ni la vitesse (*Semelles*) : ces objets valent plus que leur ligne.

### Archétypes, ~10 objets sur Caïn

| Build | DPS | PV effectifs | Puissance | Coût |
|---|---|---|---|---|
| Multishot | ×3.28 | ×1.24 | **2.01** | 617 |
| Mix générique | ×2.75 | ×1.43 | **1.99** | 501 |
| Tank / soin | ×0.64 | ×3.83 | **1.57** | 556 |
| Critique | ×1.76 | ×1.24 | **1.47** | 565 |
| Gros coups | ×2.60 | ×0.81 | **1.45** | 629 |
| Cadence | ×1.65 | ×1.12 | **1.36** | 596 |
| Mobilité | ×1.48 | ×1.12 | **1.29** | 432 |

Deux têtes quasi à égalité (2.01 / 1.99) et, rapporté au coût, c'est le **mix
générique** qui gagne (0.40 de puissance pour 100 âmes contre 0.33 au multishot).
C'est le résultat recherché : chaque axe étant plafonné, se diversifier bat la
sur-spécialisation.

Les deux derniers le sont pour des raisons différentes, et assumées :

- **Cadence** dépasse son propre plafond (+179 % achetés pour +150 % autorisés) et
  paie en plus les malus de dégâts de *Culasse* et *Horloge* — c'est exactement la
  pression anti-monobuild que les plafonds doivent exercer ;
- **Mobilité** vaut surtout ce que la métrique ne mesure pas : les coups évités.

**Gros coups** (×0.81 de PV effectifs) n'est réellement jouable que sur Job : deux
*Pactes de sang* coûtent 36 PV, soit 42 % de la vie de Caïn contre 28 % de celle
de Job. **Tank pur** reste non viable seul (×0.64 de DPS) : il survit à la vague
mais ne tue plus assez pour financer la suite.

### Économie

Le revenu en âmes croît beaucoup plus vite que la difficulté, et surtout il
**s'auto-alimente** : plus de puissance = plus de kills = plus d'âmes. Le prix
des objets suit donc trois termes : `base × (1 + 0.15 × vague) × (1 + 0.06 n +
0.0035 n²)`, où `n` est le nombre d'objets déjà possédés.

Le terme **quadratique** est le frein de la boucle. Une courbe linéaire ne la
rattrape jamais : une run qui cumulait Forge complète, six malédictions et un
pacte de densité à chaque vague finissait avec 56 objets à la vague 12 — c'est-à-
dire **tout le catalogue achetable**, tous les plafonds saturés, et plus aucune
décision à prendre pendant les huit dernières vagues.

Simulation d'achat gloutonne sur les vraies classes, Caïn, marge = DPS du joueur
divisé par le DPS nécessaire pour tuer *tout* ce qui apparaît :

| Configuration | Objets v20 | Puissance v20 | Marge v15 | Marge v20 |
|---|---|---|---|---|
| Référence, aucune option | 33 | ×5.96 | ×0.47 | ×0.44 |
| Forge complète | 34 | ×7.34 | ×0.62 | ×0.54 |
| Forge + pacte Carapace à chaque vague | 35 | ×9.33 | ×0.50 | ×0.53 |
| Forge + 6 malédictions | 44 | ×13.70 | ×0.81 | ×0.82 |
| Forge + 6 malédictions + pacte Élites | 45 | ×12.85 | ×0.75 | ×0.73 |

**Avant cette passe, la run maudite était la run facile** : marge ×2.23 à la
vague 10 contre ×0.73 pour la run de référence, c'est-à-dire que le mode « plus
difficile » était le seul à tenir la cadence. Le revenu montait ×6 pendant que la
difficulté montait ×1.6. Elle reste la plus puissante — c'est sa raison d'être —
mais elle ne dispense plus d'esquiver.

### Relancer la boutique

Le coût repart de zéro à chaque ouverture, et monte vite :

| Relance | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Coût | 1 | 2 | 10 | 20 | 40 | 80 | 160 | 320 |
| Cumul | 1 | 3 | 13 | 33 | 73 | 153 | 313 | 633 |

Les deux premières sont presque offertes : elles servent à ne pas rester bloqué
sur une offre entièrement hors sujet, ce qui est du gâchis de tour et non un
choix. La troisième change de registre, et au-delà le doublement rend le
défilement du catalogue hors de prix.

**Ce n'est pas un robinet à puissance.** Une relance ne rapporte aucune âme,
donc aucun objet supplémentaire : le nombre d'achats par vague reste tenu par le
prix des objets ci-dessus, que ceci ne touche pas. Ce qu'on achète ici, c'est de
la précision de build — et ça se mesure : sur 2 000 runs simulées, un objet
épique donné apparaît pour la première fois **vague 9,5 sans relance, vague 4,4
avec deux relances par boutique**.

### Durée de run visée

Le DPS nécessaire pour tuer *tout* ce qui apparaît passe de 21 (vague 1) à 1 627
(vague 20), soit ×77, alors que la puissance réaliste du joueur plafonne vers ×6-9
sans options, ×13-15 en cumulant tout.
La run est donc **conçue pour se terminer**, vers la vague 15-20 pour un bon joueur
(le DPS requis est une borne haute : on peut esquiver au lieu de tout tuer).
Pour allonger ou raccourcir les runs, les leviers sont
`spawns_per_second_growth` (0.22) et `health_growth` (0.14) dans `wave_manager.gd`.

## Menu et options

Le menu principal est un hub à quatre entrées :

| Bouton | Écran |
|---|---|
| **JOUER** | choix du personnage → **Forge Éternelle** ou **Commencer** |
| **PROFILS** | les trois emplacements de sauvegarde |
| **OPTIONS** | affichage, entrée, confort |
| **QUITTER** | sauvegarde puis rend la main au bureau |

Chaque écran est une surcouche `CanvasLayer` sur le menu, pas un changement de
scène : le retour est instantané.

### Options

Six réglages, tous **réellement branchés** — aucun contrôle décoratif. Ils
sont écrits à chaque modification dans `user://infernum_settings.cfg`, hors
profil (ce sont des préférences, pas de la progression).

| Réglage | Effet |
|---|---|
| **Plein écran** | bascule la fenêtre (`DisplayServer`) |
| **Musique** | 0 à 100 % — agit sur le bus `Musique` |
| **Effets** | 0 à 100 % — agit sur le bus `Effets` |
| **Joystick virtuel** | Automatique (tactile uniquement) · Toujours affiché · Masqué |
| **Tremblement de caméra** | 0 à 150 % — à 0, plus aucune secousse (confort visuel) |
| **Déplacement 8 directions** | quantifie stick et joystick sur 8 axes, ou déplacement libre |

Vérifié par mesure : à 0 %, une secousse de force 20 laisse le traumatisme de la
caméra à 0.00 ; à 100 %, il monte à 1.00.

## Interface — un thème, zéro style local

L'habillage vient de **PixelUIKit** (panneau sombre, liseré doré) et passe
entièrement par [`assets/ui/theme.tres`](assets/ui/theme.tres), déclaré en
`gui/theme/custom`. Plus aucun écran ne définit son propre `StyleBoxFlat` de
panneau : les sept écrans ont perdu le leur et héritent. Changer l'apparence de
tous les boutons du jeu, c'est une valeur dans un fichier.

Deux choses ont demandé du travail plutôt qu'une copie :

- **Les boutons du kit portent un « OK » gravé** — inutilisable en 9-tranches,
  puisque c'est justement la zone centrale qu'on étire. Leur dégradé étant
  uniforme horizontalement, on en reconstruit un de 8 px de large à partir d'une
  colonne pure. Détail dans [`assets/README.md`](assets/README.md).
- **Les cartes ne peuvent pas être des boutons dorés** : sur le doré plein, le
  rouge de Caïn et le violet des pactes sont illisibles. Elles passent par une
  variation de thème `CardButton` — panneau sombre à liseré doré, qui s'allume
  à la sélection.

Le HUD gagne trois icônes : cœur, pièce, cadenas. Le kit n'a pas de clé ; le
cadenas est ce qu'elles ouvrent.

La barre de vie et la barre de boss viennent du kit elles aussi. Le kit ne
fournit qu'une barre *pleine* là où une `ProgressBar` veut un rail et un
remplissage — et Godot trace le remplissage sur toute la hauteur du contrôle,
sans respecter les marges du fond. C'est donc le remplissage qui porte son
retrait, en pixels transparents. Vérifié à 100, 62, 28, 6 et 0 % : le cadre reste
intact et rien ne subsiste à vide.

`default_texture_filter` passe à **Nearest** pour tout le projet — c'est le bon
réglage pour du pixel art, et l'interface en hérite sans réglage par écran. Le
sol de l'arène, seule texture non pixel art, repasse en linéaire sur son nœud.

## Menu de pause — qui possède la pause

`Échap` / `B` ouvre le menu de pause : reprendre, options, abandonner la run.
Il met l'arbre en pause et réutilise l'écran d'options tel quel, sans le
dupliquer.

La seule difficulté est de savoir **à qui appartient la touche**. Boutique,
malédictions et fin de run mettent déjà l'arbre en pause pendant qu'ils sont
ouverts : un menu de pause qui s'ouvrirait par-dessus la boutique relancerait la
partie en se refermant, boutique toujours affichée.

Le test tient en une ligne — `get_tree().paused`. Si l'arbre est en pause et que
le menu n'est pas visible, c'est qu'un autre écran la détient, et `Échap` lui
appartient. Aucune référence croisée entre écrans, rien à mettre à jour en
ajoutant un écran qui met en pause.

L'écran d'options est le seul cas inverse : il s'ouvre *par-dessus* le menu de
pause, donc c'est lui qui doit consommer `Échap` en premier. Il est placé après
le menu dans l'arbre (l'entrée non gérée remonte les frères à l'envers) et le
menu s'efface tant que les options sont visibles. En les refermant, le menu
**reprend le focus** : sans ça il restait visible mais sans rien à quoi la
manette puisse s'accrocher.

Vérifié, entrées simulées : ouverture et fermeture par `Échap`, options
par-dessus puis refermées sans fermer le menu, et `Échap` avec la boutique
ouverte qui ferme bien la boutique sans ouvrir le menu.

## Le focus doit survivre à une reconstruction

La Forge et l'écran de fin de run se reconstruisent sur signal : débloquer un
nœud émet `keys_changed`, puis `node_unlocked`, et chaque signal relançait un
`refresh()` complet. Trois conséquences, toutes mesurées :

- l'écran était reconstruit **trois fois par clic** ;
- le bouton qu'on venait de presser était **détruit pendant l'exécution de son
  propre signal** ;
- le porteur du focus partait avec lui, donc **plus rien n'avait le focus**.

À la souris ça ne se voit pas. À la manette, l'écran devenait un cul-de-sac : la
navigation directionnelle n'a plus de point de départ, et il fallait reprendre la
souris pour en sortir. C'est exactement le symptôme remonté.

Deux corrections :

1. **Reconstruction différée et dédoublonnée.** Un drapeau et un
   `call_deferred` : une seule reconstruction, à la fin de la frame, donc plus
   jamais pendant le signal qui l'a déclenchée.
2. **Le focus est capturé puis rendu.** `UIUtils.capture_focus` retient le NOM du
   contrôle focalisé et son RANG parmi les contrôles atteignables ;
   `restore_focus` rend le focus au même nom, sinon au voisin de même rang,
   sinon au bouton de repli. Les boutons portent donc un nom stable
   (`noeud_<id>`, `objet_<id>`).

Au passage, un bouton désactivé passe en `FOCUS_NONE` : sans ça, traverser la
Forge au stick obligeait à parcourir les douze nœuds verrouillés pour atteindre
le seul qu'on pouvait ouvrir.

Vérifié : après déblocage d'un nœud puis d'un objet, le focus atterrit sur un
bouton voisin encore actionnable, et il reste au moins un contrôle atteignable
même lorsque tout est déjà débloqué.

## Mise en page des écrans

Tous les panneaux suivent la même règle, et elle vaut d'être écrite parce que
c'est exactement là où ça avait dérapé :

> Un `PanelContainer` en `SHRINK` prend sa taille **minimale**. Un
> `ScrollContainer` a une taille minimale de zéro. Mettre les deux ensemble donne
> un panneau réduit à la hauteur qu'on a écrite en dur dans le scroll — 140 ou
> 150 px — quel que soit le contenu.

C'est ce qui rendait la boutique illisible : les cartes d'objet font 214 px de
haut et disposaient de 140 px, donc elles étaient coupées en deux et il fallait
scroller dans une fente. Même défaut sur Options (335 px de contenu pour 150),
Profils (266 pour 140) et les cartes de personnage.

La règle appliquée maintenant : **chaque `custom_minimum_size` de scroll est
réglé sur le besoin réel mesuré**, et le panneau se dimensionne dessus. Le
viewport fait au minimum 1920×1080 en unités logiques (`canvas_items` / `expand`,
donc la hauteur logique ne descend jamais sous 1080 quelle que soit la fenêtre) :
**plus aucune barre de défilement n'apparaît en usage normal.**

Ces minima sont à remesurer dès qu'on touche à l'habillage. L'arrivée du thème
PixelUIKit a ajouté des marges de panneau et de carte, et quatre listes se sont
remises à défiler sans que rien d'autre ne change — d'où les valeurs ci-dessous,
relevées écran par écran après coup.

| Écran | Panneau | Contenu / place |
|---|---|---|
| Boutique | 880 × 656 | 422 à 445 / 480 |
| Malédictions | 760 × 668 | 380 / **396** |
| Choix du personnage | 860 × 599 | 288 / 300 |
| Forge Éternelle | 940 × 946 | 538 / **552**  ·  127 / **142** |
| Options | 820 × 493 | 335 / 340 |
| Profils | 820 × 478 | 266 / 270 |
| Fin de run | 700 × 451 | 127 / **148** |

Deux listes se mesurent au **pire cas**, pas à ce qu'on voit à l'écran par
défaut : les objets à débloquer de la Forge et de la fin de run n'affichent que
ce qui reste verrouillé. Sur un profil qui a tout ouvert, elles sont vides et ne
prouvent rien — il faut les remplir des trois objets à clé pour les dimensionner.
La boutique, elle, varie avec la longueur des descriptions tirées : la place est
réglée sur le plus long des tirages observés, pas sur un tirage moyen.

Deux détails qui comptent :

- l'offre et les pactes de la boutique sont des `HFlowContainer` : sur un écran
  étroit les cartes **passent à la ligne** au lieu de défiler horizontalement ;
- `ItemCard` est en `MOUSE_FILTER_PASS`, sinon survoler une carte bloque la
  molette — la boutique n'a plus qu'une seule zone scrollable, elle doit répondre
  partout.

Un `Label` en `autowrap` a une hauteur minimale d'**une ligne** : une carte dont
le texte est en `EXPAND_FILL` absorbe l'espace libre mais n'en réclame pas. La
hauteur du texte doit donc être portée par la carte elle-même
(`CARD_MIN_SIZE`), pas espérée du conteneur.

## Profils

Trois emplacements de sauvegarde indépendants, gérés depuis le menu (bouton
**Profils**). Chacun a ses propres clés, sa Forge, son meilleur score et son
dernier personnage joué.

C'est le seul moyen de **recommencer une partie** : les clés sont irréversibles
au sein d'un profil, donc on repart de zéro en activant un emplacement vide ou en
effaçant celui en cours (effacement à double clic, confirmation explicite). Les
profils se renomment directement dans la liste.

Fichiers : `user://infernum_profile_N.cfg` par profil, plus
`user://infernum_profiles.cfg` qui retient l'emplacement actif.

## Personnages jouables

Trois damnés, trois marchés différents avec l'enfer. Les identités prolongent la
ligne biblique des boss. Le choix se fait au menu et se mémorise entre les runs.

| | **Caïn** *Le Premier Sang* | **Job** *L'Éprouvé* | **Loth** *Le Fuyard* |
|---|---|---|---|
| Archétype | Dégâts | Survie | Mobilité |
| Figure | le premier meurtrier, marqué pour ne jamais mourir ni être en paix | on lui a tout pris pour voir s'il plierait ; il n'a pas plié | il a quitté la ville en flammes sans se retourner — contrairement à sa femme |
| PV | 85 | 130 (+12 armure) | 80 |
| Vitesse | 215 | 218 | **288** |
| Arme | 19 dégâts / 2.9 par s | 10.5 / 3.5 | 9 / **5.2** |
| Portée | 340 | 355 | 300 |
| Passif | **La Marque** : +1 % de dégâts par élimination dans la vague, plafonné à **+25 %**, remis à zéro à chaque vague | **La Patience** : 0.9 PV/s, mais seulement après **4 s sans être touché** | **Ne pas se retourner** : **+20 % de cadence** tant qu'il se déplace |

### Équilibrage

Un personnage change les **valeurs de base**, pas les règles. Ses éventuels
modificateurs de départ (l'armure de Job, le ramassage de Loth) tombent dans les
mêmes pools plafonnés que les objets : un personnage ne peut pas dépasser les
limites, il choisit seulement d'où l'on part. Les trois passifs sont bornés et
passent par `RunState.character_bonus`, donc aucun ne crée de canal de scaling
parallèle.

Mesuré sur les vraies classes, **passifs exclus** (référence neutre = 1.000) :

| | DPS de base | DPS passif actif | PV effectifs | Puissance |
|---|---|---|---|---|
| Caïn | 59.5 | 74.4 | 85 | **1.000** (référence) |
| Job | 44.1 | 44.1 | 146 | **1.009** |
| Loth | 49.1 | 59.0 | 80 | **0.864** + mobilité |

Job démarrait à 38.6 DPS, soit **−48 % face à Caïn**, et son avantage portait sur
le seul axe que les i-frames rendaient déjà trivial. Il passe à 12.0 de dégâts
d'arme (44.1 DPS) et sa Patience à **1,4 PV/s après 3 s** au lieu de 0,9 après 4 s :
c'est son moteur, il doit être lisible.

Loth ferme la marche sur la métrique, mais elle ne mesure pas ce qui fait son
intérêt : 288 de vitesse contre 215, c'est-à-dire les coups qu'il ne prend pas.

**Honnêteté sur les passifs** : celui de Loth (+20 % de cadence *tant qu'il se
déplace*) et celui de Caïn (+25 % de dégâts *à partir de 25 éliminations dans la
vague*) sont conditionnels sur le papier et **quasi permanents en pratique** — on
bouge en permanence dans un twin-stick, et 25 éliminations tombent dans les
quinze premières secondes de n'importe quelle vague. Ils sont donc évalués, et
équilibrés, comme des bonus permanents.

## Démarche procédurale

Le joueur a une marche animée **sans aucune image d'animation** :
[`waddle.gd`](scripts/components/waddle.gd) superpose deux oscillations sur le
sprite — jamais sur le corps physique, la collision reste rigide.

```
inclinaison = sin(phase)        → le corps penche d'un côté puis de l'autre
rebond      = abs(sin(phase))   → le corps se soulève
```

Tout tient dans le `abs()` : `sin` a une période de `TAU`, `abs(sin)` une période
de `PI`. Le rebond va donc **deux fois plus vite** que l'inclinaison, soit un
soulèvement par penché — **un rebond par pas**. C'est ce rapport de fréquence qui
fait lire « il marche » plutôt que « il se balance ».

| Réglage | Valeur | Effet |
|---|---|---|
| `cadence` | 4.2 pas/s | vitesse de la démarche à pleine course |
| `max_tilt_deg` | 9° | amplitude du penché |
| `bounce_height` | 2.5 px | hauteur du soulèvement |
| `pivot_y` | 27 px | hauteur du pivot sous l'origine |

**Le pivot est aux pieds, pas au centre.** C'est le point qui fait toute la
différence : une rotation autour du centre du corps envoie les pieds sur les
côtés, ce qui donne un personnage qui glisse au lieu de marcher. Mesuré sur un
cycle complet : **0,00 px** de déplacement horizontal aux pieds contre **16,9 px**
à la tête. Le pivot est obtenu sans toucher à la hiérarchie de la scène, par
`position += P - P.tourné(angle)`.

La cadence suit la **vitesse réelle** et non la consigne : poussé par un recul ou
bloqué contre un mur, le pas ralentit avec le personnage au lieu de pédaler.

À l'arrêt, la phase repart de zéro (`sin(0) = 0`, donc aucun saut visuel à la
remise en route) et le sprite revient au neutre par interpolation.

Contrepartie assumée : faire tourner du pixel art l'échantillonne en biais et
crénèle légèrement les contours. À 9° ça reste propre ; au-delà, ça se voit.

### La perforation — mesurée, pas estimée

**Lance de Longin** (épique, 2 piles) fait traverser les corps aux projectiles :
au lieu de s'arrêter au premier ennemi, le trait continue et frappe les suivants.

C'est un multiplicateur de DPS, comme le multishot, et dans un jeu de horde les
cibles s'alignent en permanence. Il est donc **plafonné** (3 corps traversés) et
**taxé** : chaque corps traversé encaisse 35 % de moins que le précédent —
100 %, 65 %, 42 %, 27 %. Sans cette décote, un seul objet vaudrait plus que
n'importe quel autre du catalogue, gratuitement.

Mesuré en vague 12, build et densité identiques, 60 s de jeu :

| Perforation | Dégâts infligés | Gain | Impacts | Ennemis touchés |
|---|---|---|---|---|
| 0 | 3 180 | — | 331 | — |
| 1 | 4 264 | **+34 %** | 501 | ×1,51 |
| 2 | 4 777 | **+50 %** | 611 | ×1,85 |
| 3 | 4 622 | +45 % | 648 | ×1,96 |

Deux choses se lisent là-dedans. Le nombre d'ennemis touchés monte bien à ×1,96 —
l'objet fait ce qu'il promet, il frappe plus de monde à la fois. Mais le gain en
dégâts sature vers +50 % : la décote fait que le troisième et le quatrième corps
ne rapportent presque plus rien.

Avec son malus de −8 % de cadence par pile, l'objet vaut ~+23 % net à une pile et
~+26 % à deux. Il se range donc juste à côté de Cœur de forge (+38 % de dégâts,
−10 % de cadence) au lieu de l'écraser — et empiler la seconde pile rapporte
visiblement moins que la première, ce qui est exactement le comportement
recherché.

#### Le trait cherche le corps suivant

Un trait perforant continuait tout droit. Sur des ennemis **dispersés**, il ne
rencontrait donc presque jamais de deuxième corps : mesuré, huit ennemis semés au
hasard, le trait en touchait **0,63 par tir quel que soit le niveau de
perforation** — l'objet ne faisait littéralement rien tant que la mêlée ne
s'alignait pas d'elle-même.

Après chaque corps traversé, le trait se braque donc sur l'ennemi le plus proche
dans un rayon de 520 px. Même semis des deux côtés :

| Perforation | Sans braquage | Avec braquage |
|---|---|---|
| 1 | 0,63 | **1,08** (+73 %) |
| 2 | 0,63 | **1,67** (+167 %) |
| 3 | 0,63 | **2,17** (+247 %) |

Ces chiffres sont le **pire cas** : les ennemis y sont éparpillés exprès. Dans
une horde dense, les corps s'alignent d'eux-mêmes et l'écart se réduit — c'est
pourquoi la mesure en combat réel plus haut donne +34 à +50 % de dégâts et non
+250 %. La décote de 35 % par corps s'applique toujours : le braquage fait
atteindre les cibles, il n'augmente pas ce que chacune encaisse.

Deux détails qui décident du fonctionnement :

- **Les corps déjà traversés sont exclus de la recherche.** `_hit` empêche déjà
  de blesser deux fois le même ennemi, mais sans cette exclusion le trait se
  rebraquait sur celui qu'il venait de traverser et restait collé dedans : il
  dépensait ses perforations sans toucher personne d'autre.
- **Le braquage est sec, pas progressif.** À 720 px/s, un virage doux laisse le
  trait quitter la mêlée avant d'avoir tourné.

Le braquage ne s'applique qu'après avoir traversé un **ennemi** : sans cette
condition, un projectile ennemi perforant partirait chasser les ennemis.

## Boss — un palier toutes les 5 vagues

Cinq boss, dans l'ordre. Une vague de boss **ne se termine pas au chronomètre** :
elle se termine quand le boss tombe. Les ennemis normaux continuent d'arriver,
mais au quart de la cadence. Au-delà du cinquième, le cycle reboucle avec +45 %
de PV et +20 % de dégâts par tour.

### Les renforts volaient le combat

Les PV des boss sont calibrés en supposant que **tout** le DPS du joueur leur
tombe dessus. C'était faux : l'auto-visée classe les cibles par DISTANCE, et
c'est structurellement défavorable aux boss — ils sont lents et massifs, les
renforts foncent sur le joueur, donc les renforts sont presque toujours plus
près. Mesuré sur Golgota à la vague 5 : il ne recevait que **55 à 61 %** des
tirs, le combat durait **47 à 52 s** au lieu des 17,6 visées, et le joueur —
85 PV à ce stade, sans armure ni objet défensif — se voyait présenter 27 attaques
au sol. Il fallait en esquiver **80 %** pour survivre.

Le mal était indirect : les renforts ne tuaient pas (87 % des dégâts venaient des
écrasements télégraphiés), ils allongeaient le combat, et le combat allongé
multipliait les écrasements.

Trois réglages, mesurés :

| | avant | après |
|---|---|---|
| `TargetingSystem.boss_bonus` | — | **0,20** |
| `boss_add_spawn_ratio` | 0,35 | **0,25** |
| Golgota `slam_damage` | 20 | **17** |
| *Golgota est la cible* | 55–61 % | **84–90 %** |
| *Durée du combat* | 47–52 s | **~33 s** |
| *Dégâts présentés* | ~435 | **~240** |
| *Esquive nécessaire* | 80 % | **~63 %** |

Le biais de ciblage reste modéré à dessein : à 0,50 le joueur ne nettoie plus
rien, se fait submerger, et les dégâts encaissés **remontent**. Golgota est par
ailleurs le seul boss rencontré sans build — d'où les 17 de dégâts d'écrasement,
six coups au lieu de quatre sur un réservoir de 85 PV. Les suivants gardent les
leurs : à la vague 10 le joueur a déjà des PV et de l'armure.

Leurs PV **suivent la vague** (`× (1 + 0.09 × (vague − 5))`, dégâts `× (1 + 0.04 × …)`).
Sans cela, ils étaient figés pendant que le DPS du joueur était multiplié par 22
entre les vagues 5 et 20 : Asmodée tombait en **4,3 s** et Lucifer en **4,0 s**,
donc ni l'un ni l'autre n'atteignait jamais sa phase 2 (déclenchée à 50 % de PV),
et la jauge de pression se déclenchait au plus une fois. Tout le travail de
pattern était invisible.

| Boss | Vague | PV | Temps de mise à mort |
|---|---|---|---|
| Golgota | 5 | 2 200 | 17,6 s |
| Lilith | 10 | 5 220 | 20,7 s |
| Baal | 15 | 9 880 | ~21 s |
| Asmodée | 20 | 16 450 | ~18 s |
| Lucifer | 25 | 26 600 | ~20 s |

Les cinq combats tiennent maintenant dans une fourchette de 17 à 21 s : les deux
phases et plusieurs décharges de la jauge de pression sont garanties. L'enragement
à 100 s reste ce qu'il doit être — un filet contre le joueur qui traîne, pas une
phase attendue.

| Vague | Boss | Identité | Phases | Anti-immobilisation |
|---|---|---|---|---|
| 5 | **Golgota** — *Le Mont du Crâne* | le Golgotha n'est pas un démon mais un lieu : le mont où l'on dressait les croix. Colosse d'ossements, lent, écrasant | Pierre → Fracture (crânes en anneaux) | **Le Calvaire** : sept croix jaillissent en couronne serrée autour du joueur |
| 10 | **Lilith** — *La Première Nuit* | première femme d'Adam, partie plutôt que se soumettre, mère des lilim | Séduction (orbite, invocations) → Nuit (semi-invisible, téléportations) | **L'Appel** : elle se téléporte sur le joueur et fait surgir quatre lilim autour de lui |
| 15 | **Baal** — *Le Seigneur de l'Orage* | divinité cananéenne de l'orage, culte par le feu | Orage (foudre télégraphiée) → Fournaise (sillage de braise, anneaux) | **Le Déluge** : huit éclairs tombent d'un coup en couronne |
| 20 | **Asmodée** — *Les Trois Têtes* | roi des démons du Livre de Tobie, trois têtes : taureau, homme, bélier | Deux têtes → Trois têtes | **La Chaîne de Salomon** : le lien se referme et *tire le joueur vers lui* |
| 25 | **Lucifer** — *L'Étoile du Matin* | *lucifer*, « porteur de lumière », nom de l'étoile du matin devenu celui de l'ange déchu | Porteur de lumière → La Chute → L'Abîme | **L'Aube brûlante** : la couronne de feu s'embrase *à la distance où se tient le joueur* |

### La mécanique anti-immobilisation

Le problème est structurel : dans un jeu à tir automatique, un boss qui poursuit
bêtement se bat tout seul. Le joueur recule en cercle, l'auto-aim fait le travail,
et le combat devient une formalité sans aucune prise de risque.

Les cinq boss partagent donc une **jauge de pression**
([boss.gd](scripts/bosses/boss.gd)) :

- elle monte quand le joueur reste au-delà de `engage_distance`, et **d'autant
  plus vite qu'il est loin** (accélération bornée, sinon la sanction se
  déclencherait en boucle à très grande distance) ;
- elle monte **aussi** quand le boss n'a rien subi depuis 3 s : tourner en rond
  sans tirer ne marche pas non plus ;
- elle ne redescend qu'au corps-à-corps, sous le feu ;
- à saturation elle déclenche `_release_pressure()`, que chaque boss exprime à sa
  façon — croix, téléportation, foudre, chaîne, couronne de feu.

**Le kiting n'est pas interdit, il est facturé.** Le joueur doit revenir prendre
des risques régulièrement, ce qui est exactement l'intention.

Second garde-fou, l'**enragement** : passé 100 s, le boss gagne +60 % de dégâts et
la pression monte deux fois plus vite. Un combat ne peut pas s'éterniser.

Mesuré en test, joueur fuyant en permanence à pleine vitesse : Golgota 8
sanctions, Baal 6, Lucifer 7, Asmodée 3, Lilith 1 — Lilith étant celle dont la
mobilité suffit à rattraper le joueur, sa jauge sature rarement.

### Lisibilité

Aucun boss ne touche le joueur sans préavis : toutes les frappes au sol passent
par [`Telegraph`](scripts/combat/telegraph.gd), un disque qui se remplit avant de
détoner. La difficulté vient du nombre et du placement des zones, jamais d'un coup
impossible à lire. Les charges (Asmodée, Lucifer) sont annoncées par une zone au
point d'arrivée, et le boss s'immobilise pendant l'armement.

## Forge Éternelle — méta-progression permanente

Arbre de **15 nœuds** en 3 branches, débloqués avec des clés et conservés entre les
runs. Accessible depuis l'écran de fin de run.

| Branche | Nœuds | Effets |
|---|---|---|
| **Fer** | Braise de forge → Trempe / Mécanisme huilé → Fil rasoir → Acier noir | +12 % dégâts, +5 % cadence, +4 % crit |
| **Chair** | Cuir cousu → Plaques rivetées / Souffle lent → Carcasse épaisse → Écaille de forge | +18 PV, +16 armure, +0.3 PV/s |
| **Cendre** | Braises tièdes → Pas léger / Appel des âmes → Augure → Coffre de forge | +8 % âmes, +4 % vitesse, +40 % ramassage, +1 chance, 60 âmes au départ |

Chaque nœud a des prérequis ; **42 clés** au total, soit ~8 à 10 runs.

### Pourquoi ça ne trivialise pas le début de partie

Impact de l'arbre **complet**, mesuré sur la vraie arme :

| | Sans Forge | Forge complète | Ratio |
|---|---|---|---|
| DPS | 50.4 | 61.5 | ×1.22 |
| PV effectifs | 100 | 146 | ×1.46 |
| **Puissance** | — | — | **×1.335 (+34 %)** |

Soit l'équivalent d'environ **7,5 objets communs**, ou 1,5 à 2 vagues d'avance.
Confirmé en simulation de run complète : à la vague 20, puissance ×7.34 avec
l'arbre complet contre ×5.96 sans, soit **+23 %** une fois dilué dans une build
de 34 objets. Trois raisons pour lesquelles ça reste modéré :

1. **Les bonus alimentent les mêmes pools plafonnés que les objets.** Un joueur
   avec +12 % de dégâts de Forge démarre à 12 % des 200 % autorisés : la Forge
   avance le curseur, elle ne déplace pas le plafond.
2. **Le début de partie est déjà confortable sans elle** (DPS de base 50 pour 21
   requis en vague 1) : la Forge ne change rien au ressenti des vagues 1-3, elle
   déplace le mur de difficulté d'environ deux vagues.
3. **Aucun nœud ne touche deux axes multiplicatifs à la fois**, même règle que
   pour les objets.

## Malédictions — difficulté volontaire, facultative

Proposées **au lancement de la run**, sur un écran dont le bouton par défaut est
« Commencer sans malédiction ». Aucune n'est cochée d'office : la run sans
malédiction est exactement celle sur laquelle l'équilibrage a été mesuré.

| Malédiction | Coût | Récompense | Danger |
|---|---|---|---|
| Meute affamée | Ennemis +30 % vitesse | +20 % d'âmes | 2 |
| Chair durcie | Ennemis +50 % PV | +25 % d'âmes | 3 |
| Marée montante | +35 % d'ennemis | +5 % d'âmes, +15 % de chance de clé | 3 |
| Fragilité mortelle | −30 PV max | +1 chance, +15 % d'âmes | 3 |
| Rituel de sang | Ennemis +45 % dégâts | +1,5 chance, +32 % d'âmes | 4 |
| Œil du vide | Élites dès la vague 1, ×2 | +8 % d'âmes, +25 % de chance de clé | 4 |

Les pénalités **s'additionnent** (1 + somme), elles ne se composent pas : les 6
malédictions donnent ennemis ×1.50 PV / ×1.30 vitesse / ×1.45 dégâts / ×1.35
densité, pas un produit qui explose. Les récompenses en âmes tombent dans
`soul_gain_pct`, **plafonné à +75 %** : tout empiler donne +105 %, donc le
plafond mord.

**Ce qui a changé, et pourquoi.** Les récompenses étaient calibrées sur le danger
*apparent*. Or les i-frames du joueur bornent les dégâts entrants à 2,5 coups par
seconde : ajouter des ennemis ou des élites ne coûte presque rien, mais multiplie
le revenu en âmes — et les élites valaient alors ×4 âmes et portaient 6 % de
chance de clé chacune. Résultat mesuré : les six malédictions **doublaient le
revenu tout en n'augmentant la difficulté que de 60 %**, et la run maudite était
la plus confortable du jeu. Les pénalités de PV et de dégâts ont donc été durcies,
les récompenses des options de densité coupées, et les élites ramenées à ×2 âmes
et 2 % de clé.

## Pactes de vague — risque à court terme, facultatif

Deux pactes sont proposés en boutique entre chaque vague ; le joueur en prend
**un** ou aucun. Un pacte ne dure **qu'une vague** et re-cliquer dessus l'annule.
Les pactes de danger ≥ 4 n'apparaissent pas avant la vague 3.

| Pacte | Règle | Récompense |
|---|---|---|
| Chairs volatiles | Les ennemis explosent à leur mort (mèche de 0,55 s) | +25 % d'âmes |
| Célérité damnée | Ennemis +35 % vitesse | +30 % d'âmes |
| Horde | +45 % d'ennemis | +15 % d'âmes |
| Carapace | Ennemis +65 % PV | +30 % d'âmes |
| Fureur | Ennemis +60 % dégâts | +1 chance, +35 % d'âmes |
| Nuée d'élites | Trois fois plus d'élites | +8 % d'âmes, +35 % de chance de clé |
| Brouillard de cendre | Votre portée de ciblage −30 % | +35 % d'âmes |
| Frénésie | Ennemis +25 % vitesse et +30 % PV | +22 % d'âmes, +0,5 chance |

Même correction que pour les malédictions : *Chairs volatiles* payait +40 %
d'âmes alors que les i-frames absorbent les détonations groupées — c'est-à-dire
précisément dans les vagues denses où les morts se concentrent. *Horde* et *Nuée
d'élites* étaient les deux pactes les plus rentables du jeu pour un risque réel
quasi nul.

Les explosions des chairs volatiles ont une **mèche de 0,55 s** : elles sont
esquivables, ce n'est pas un coût forfaitaire imposé.

### Les quatre sources de bonus ne créent aucun canal de scaling parallèle

Forge (permanent), malédictions (toute la run), pacte (une vague) et objets
écrivent **tous** dans les mêmes pools additifs plafonnés de `PlayerStats`, via
`RunState.recompute_stats()` qui repart de zéro à chaque changement. Côté
difficulté, les multiplicateurs optionnels s'appliquent **par-dessus** la courbe
de vague sans la modifier : une run sans malédiction ni pacte reste bit pour bit
la run de référence analysée plus haut.

## Monnaies

| | Source | Usage | Persistance |
|---|---|---|---|
| **Âmes** | tous les ennemis (orbes attirées par le joueur) | acheter des objets, relancer la boutique | perdues à la mort |
| **Clés** | élites (2 %) + 1 garantie toutes les 5 vagues + 1 à 3 par boss | Forge Éternelle + déblocage d'objets | **conservées entre les runs** |

Les bonus de chance de clé des malédictions et des pactes **s'additionnent** au
lieu de se composer. Avec l'ancien produit et 6 % par élite, une run allant à la
vague 20 rapportait **40 clés** — presque les 42 que coûte l'arbre entier — et
jusqu'à **270** en cumulant *Œil du vide*, *Marée montante* et *Nuée d'élites*,
soit six fois toute la méta-progression en une seule partie.

| Configuration | Clés à la vague 15 | Forge complète en |
|---|---|---|
| Référence | 11 | ~4,7 runs |
| Œil du vide | 16 | ~3,4 runs |
| Œil du vide + Marée montante + Nuée d'élites | 21 | ~2,6 runs |

L'écart entre la meilleure configuration de farm et la run normale passe ainsi de
×8 à ×1,9 : accepter des malédictions accélère toujours la Forge, mais ne la
saute plus.

Les âmes ne sont volontairement pas capitalisées : une épargne inter-runs
trivialiserait les premières vagues de la partie suivante.

## Manette

Le jeu se joue intégralement à la manette, menus compris.

| Commande | Manette | Clavier |
|---|---|---|
| Se déplacer | stick gauche · croix directionnelle | ZQSD / WASD · flèches |
| **Viser** | **stick droit** | — (visée automatique) |
| Valider | **A** | Entrée · Espace |
| Retour | **B** | Échap |
| Onglet suivant / précédent | L1 · R1 | Tab · Maj+Tab |

Trois manques bloquaient réellement le jeu à la manette, et aucun ne se voyait
sans tester :

1. **`ui_accept` et `ui_cancel` n'avaient aucune liaison manette.** Les défauts
   de Godot ne sont pas repris dès qu'un projet définit ses propres actions : A
   et B ne faisaient rien, donc aucun menu n'était utilisable.
2. **Aucun écran ne gérait `ui_cancel`.** Même avec la liaison, un écran ouvert
   était un cul-de-sac — sans souris, impossible d'en sortir. Boutique, Forge,
   Options, Profils et choix du personnage se ferment maintenant avec **B**.
3. **La croix directionnelle n'était pas liée au déplacement**, seulement les
   axes du stick gauche.

### Le stick droit vise

C'est ce qui rend le jeu réellement twin-stick. L'auto-visée ne change pas : le
stick droit alimente l'`aim_hint` que
[`TargetingSystem`](scripts/combat/targeting_system.gd) utilisait déjà pour
pondérer le choix de cible. Poussé, il dit où regarder ; relâché, on retombe sur
la direction de course — donc rien ne change au clavier ni au tactile.

Concrètement, on peut fuir vers la gauche en tirant vers la droite.

### Ce qui n'est volontairement pas lié

`restart` (relance instantanée) reste sur **R au clavier uniquement**. Sur une
touche de façade, une pression accidentelle détruisait une run sans confirmation.

L'action `dash` est déclarée dans la table d'entrées (Espace / bouton A) mais
**n'est implémentée nulle part** : c'est une liaison morte, sans effet.

## Auto-aim (`scripts/combat/targeting_system.gd`)

Chaque cible dans le rayon reçoit un score (0 = idéal), le plus petit gagne :

```
score = (distance / portée) × (1 - aim_weight)
      + min(angle / tolérance, 1) × aim_weight     [si une direction est visée]
      - sticky_bonus                               [si c'est déjà la cible]
```

Réglages mobile par défaut : `aim_tolerance_deg = 110°`, `aim_weight = 0.35`,
`sticky_bonus = 0.18`, `sticky_grace = 0.35 s`, `range_radius = 340 px`.

La pénalité d'angle **sature** au-delà de la tolérance : le joueur ne se retrouve jamais
sans tirer parce qu'il vise mal, il privilégie simplement ce qui est devant lui. Trois
filets en plus : tir anticipé sur la position future, auto-correction du projectile en
vol (90 °/s), et un enum `target_priority` (`NEAREST`, `AIM_ASSISTED`, `LOWEST_HEALTH`,
`HIGHEST_HEALTH`).

## Arborescence

```
scenes/
  main/main.tscn              arène, câble les systèmes entre eux
  player/player.tscn          joueur + Targeting + Weapons + Camera
  enemies/                    imp · hound · cultist · brute
  projectiles/                hell_bolt (joueur) · cursed_bolt (ennemi)
  pickups/                    soul · key · heal
  bosses/                     golgota · lilith · baal · asmodee · lucifer
  combat/                     telegraph
  ui/                         main_menu · character_select · options · profiles
                              hud · shop · game_over · forge · curse_select
                              pause
scripts/
  core/       game_events.gd (autoload)   bus de signaux global
              player_input.gd (autoload)  clavier/manette + tactile
              settings.gd (autoload)      préférences (affichage, son, confort)
              audio.gd (autoload)         bus, banque de voix, musique
              run_state.gd (autoload)     vague, monnaies, inventaire, stats
              save_manager.gd (autoload)  clés et déblocages persistants
              player_stats.gd             agrégation + PLAFONDS d'équilibrage
              collision_layers.gd, groups.gd
  items/      item_data.gd                définition d'un objet
              item_database.gd (autoload) catalogue + tirage par rareté
  components/ health.gd                   PV réutilisable
  player/     player.gd
  combat/     targeting_system.gd · weapon.gd · projectile.gd · telegraph.gd
  enemies/    enemy.gd · ranged_enemy.gd · dasher_enemy.gd
  bosses/     boss.gd                     socle : phases + anti-kite
              golgota.gd · lilith.gd · baal.gd · asmodee.gd · lucifer.gd
  systems/    wave_manager.gd · drop_system.gd (autoload) · item_effects.gd
              curse_system.gd (autoload)   malédictions de run
              wave_modifiers.gd (autoload) pactes de vague
              character_effects.gd        passifs des personnages
  camera/     game_camera.gd
  pickups/    pickup.gd
  characters/ character_data.gd           définition d'un personnage
              character_db.gd (autoload)  catalogue + sélection
  meta/       forge_tree.gd (autoload)    arbre de méta-progression
  ui/         hud.gd · shop.gd · item_card.gd · game_over.gd
              forge_screen.gd · profiles_screen.gd · curse_select.gd
              pause_menu.gd · virtual_joystick.gd · ui_utils.gd
  main.gd
assets/
  sprites/    un dossier par entité : characters/cain, enemies/imp,
              bosses/lucifer, projectiles/hell_bolt, pickups/soul...
              chaque entité porte deux planches : <nom>_idle.png, <nom>_walk.png
              les packs sources portent un .gdignore (non importés)
  audio/      SoundEffects/ 2 musiques + 5 effets (OGG Vorbis)
  vfx/        Effect_pushAndStars/ planche d'explosion (domaine public)
  fonts/
  README.md   planches, échelles, recalages, procédure d'ajout
default_bus_layout.tres       bus Master · Musique · Effets
```

## Effets visuels

### L'explosion de Braise éternelle

Une planche de 840 × 654, sept colonnes sur six lignes de 120 × 109. Le nom du
fichier donne la taille des cellules, pas le reste : le contenu réel a été
**mesuré sur la couverture alpha de chaque cellule**, et il réserve deux
surprises.

- **L'animation est continue**, lue de gauche à droite puis ligne par ligne. Ce
  ne sont pas six variantes de sept images : la couverture monte de 0 à 32 %
  puis retombe à 0 sur l'ensemble de la planche.
- **13 cellules sur 42 sont vides** — une au début, douze à la fin. Les jouer
  ferait vivre le nœud un cinquième de seconde de plus sans rien afficher.
  [`sprite_effect.gd`](scripts/vfx/sprite_effect.gd) joue donc une **plage**,
  ici les images 1 à 29, à 60 images/s — soit 0,48 s.

La boîte englobante du dessin fait 111 × 105 px dans une cellule de 120 × 109,
centrée à un pixel près. L'échelle n'est donc pas choisie à l'œil : elle vaut
`rayon × 2 / 111`, ce qui donne 2,43 pour le rayon de 135 px de l'explosion.
**Le dessin fait exactement la taille de la zone qui blesse** — le joueur voit la
portée au lieu de la deviner, et changer `explosion_radius` change le dessin.

L'effet vit dans le conteneur des projectiles : c'est le seau des objets de monde
éphémères, et la fin de vague le vide. Un effet en cours y disparaît, ce qui est
le comportement voulu. Il n'a aucun effet de jeu — il ne blesse rien, ne bloque
rien, et peut être retiré à tout moment.

Vérifié en jeu : l'ennemi meurt, l'effet apparaît à sa position, 270 px de
diamètre affichés pour 135 px de rayon de dégâts, et disparaît après 29 images.

## Sprites et animation

Personnages, ennemis et boss sont des **planches d'images**, animées sans le
moindre fichier d'animation : une bande horizontale d'images carrées, et
[`SpriteAnimator`](scripts/components/sprite_animator.gd) qui en déduit le nombre
d'images (largeur ÷ hauteur) et fait défiler `Sprite2D.frame`.

Il bascule entre repos et marche d'après le **déplacement réel** du parent, pas
d'après sa vitesse désirée : un ennemi bloqué contre un mur garde une posture
cohérente avec ce qu'on voit. Il ne référence ni `Player` ni `Enemy`, donc il se
pose tel quel sur n'importe quel corps — le joueur, un ennemi, un boss.

| | Sprite | | Sprite |
|---|---|---|---|
| **Caïn** | guerrier en armure à la hache | **imp** | petit démon à l'épée |
| **Job** | templier au bouclier | **hound** | chien des enfers |
| **Loth** | archer | **cultist** | sorcier au bâton |
| **Golgota** | golem de pierre et de braise | **brute** | minotaure |
| **Lilith** | démone à la faux | **Asmodée** | démon à deux lames |
| **Baal** | démon ailé au trident | **Lucifer** | chevalier noir |

Deux choses se mesurent sur la planche au lieu de se régler à l'œil :
l'**échelle** (les figures font 20 px dans une image de 100) et le **recalage**
vertical (elles sont posées sur une ligne de sol, pas centrées). Le corps se
mesure sur la version sans ombre ; l'ombre donne le centrage horizontal,
puisqu'elle est toujours exactement sous le corps. Valeurs et justification dans
[`assets/README.md`](assets/README.md).

Le joueur se miroite par le SIGNE de `sprite.scale.x`, en mémorisant la grandeur
de l'échelle : `scale.x = -1` retournerait bien le personnage, en le rapetissant
à l'échelle 1 au passage. Les ennemis gardent `flip_h`, sans risque : leur
`offset.x` est nul.

Les planches d'attaque, de blessure et de mort existent dans les packs et ne sont
pas encore jouées — le jeu signale les coups par un éclair de `modulate`.

### Le sol

L'arène n'a pas de bord : le sol ne peut donc pas être une image posée une fois.
C'est un carreau de 420 × 420 répété à l'infini par
[`floor_tiler.gd`](scripts/components/floor_tiler.gd) — un seul `Sprite2D` en
`texture_repeat`, sans TileMap ni grille de nœuds.

Le seul piège est le recalage : si le sprite suivait la caméra au pixel près, le
sol paraîtrait immobile et le joueur donnerait l'impression de courir sur place.
Il est donc recalé sur un **multiple exact de la taille du carreau** — le saut est
invisible (un carreau en vaut un autre) et le dallage reste accroché au monde.

Le carreau lui-même est découpé sur un joint de dalle et son éclairage aplati,
faute de quoi la répétition se verrait ; le détail est dans
[`assets/README.md`](assets/README.md).

## Son

Sept fichiers OGG Vorbis, dans `assets/audio/SoundEffects/`. L'OGG est le seul
format qui reboucle sans trou : le MP3 porte dans sa définition un silence
d'encodeur en tête et en queue, qui s'entendrait à chaque reprise de la musique.

Contrairement aux sprites, ces fichiers **sont versionnés** : leur licence
n'interdit la mise à disposition que sous forme de banque de sons ou de pack
autonome (voir [`CREDITS.md`](CREDITS.md)). Un clone suffit donc pour avoir le
son. S'ils venaient à manquer, le jeu démarre quand même, muet, avec un
avertissement par fichier et aucune erreur.

### Deux bus, deux curseurs

`Musique` et `Effets` partent l'un et l'autre dans `Master`
([`default_bus_layout.tres`](default_bus_layout.tres)). Les deux curseurs des
options écrivent directement sur ces bus, donc aucun `AudioStreamPlayer` n'a à
connaître le réglage : un son choisit son bus à la création, et c'est tout. À
0 %, le bus est **coupé** plutôt que mis à −∞ dB — un gain infiniment petit reste
un calcul de mixage à chaque image.

Les volumes sont écrits par `Settings`, pas par l'autoload `Audio` : les
réglages se chargent avant lui, et un bus coupé doit l'être dès la première
image. `AudioServer`, lui, est disponible immédiatement.

### La banque de voix

Un `AudioStreamPlayer` ne joue qu'un son à la fois. [`audio.gd`](scripts/core/audio.gd)
en garde seize et les distribue ; quand tout est occupé, il vole la plus
ancienne. Couper un son déjà bien entamé s'entend infiniment moins que d'ignorer
le tir qui vient de partir.

Chaque son déclare aussi son propre garde-fou : un intervalle minimal entre deux
déclenchements, et un nombre maximal d'exemplaires simultanés. Mesuré : **40
morts dans la même image ne produisent qu'un seul rugissement**, ce qui est le
comportement voulu — quarante copies décalées de quelques millisecondes ne font
pas quarante rugissements, elles font un peigne métallique.

### Le tir a dû être coupé

`Fireball.ogg` dure 8,04 s, et la mesure du débit instantané montre de l'énergie
sur **toute** la durée : ce n'est pas une détonation, c'est une nappe. L'arme
tire jusqu'à 6,2 coups par seconde une fois la cadence améliorée ; jouer le
fichier entier empilerait une vingtaine de voix et noierait tout le reste.

Le son est donc coupé à **0,5 s**, avec une descente de 0,12 s pour ne pas
remplacer le problème par un clic.

Mesuré sur 10 s de tir continu à 6,2 coups/s, quota de voix compris :

| Coupure | Quota | Voix moyennes | Empilement | Tirs coupés en plein vol |
|---|---|---|---|---|
| 0,45 s | 4 | 2,80 | +4,5 dB | 0 % |
| **0,5 s** | **4** | **3,10** | **+4,9 dB** | **0 %** |
| 1,0 s | 4 | 3,84 | +5,8 dB | **93 %** |
| 1,0 s | 8 | 5,84 | +7,7 dB | 0 % |

La ligne à 1,0 s avec le quota d'origine est le piège : le son déborde ses
quatre voix et 93 % des tirs en reprennent une qui joue encore. Un vol de voix
est brutal — il claque. Allonger le tir demande donc de monter le quota **et**
de baisser le volume de 3 dB pour compenser l'empilement ; les trois valeurs
sont dans le commentaire de [`audio.gd`](scripts/core/audio.gd).

À 1 s le tir mobilise 7 des 16 voix en permanence et cesse d'être un évènement :
six copies d'une nappe qui se recouvrent en continu font un bourdon. À 0,5 s
chaque coup s'articule encore. D'où le choix.

### Les boutons sonnent sans être câblés

L'interface fabrique ses boutons à la volée : boutique, Forge, sélection de
personnage. Les connecter un par un demanderait de repasser sur chaque script,
et d'y penser à chaque ajout. `Audio` écoute donc `node_added` sur l'arbre et
branche tout `BaseButton` qui apparaît.

Un bouton qui veut un autre son que le clic par défaut le dit lui-même :

```gdscript
button.set_meta(&"sfx", &"objet")
```

Ce branchement passe par `node_added`, donc **chaque** nœud du jeu — projectile,
ennemi, âme — traverse un appel de plus. Mesuré sur 4 000 nœuds : 13,39 ms avec
le hook contre 11,71 ms sans, soit **0,4 µs par nœud**. Une vague chargée en crée
quelques dizaines par image : le coût est sous la microseconde par image, contre
un budget de 16,7 ms.

### Pourquoi l'audio tourne en pause

`PROCESS_MODE_ALWAYS`. Le menu de pause, la boutique et l'écran de malédictions
mettent l'arbre en pause, et leurs boutons doivent quand même cliquer — sans ça
l'interface devient muette dès qu'un écran s'ouvre, c'est-à-dire presque tout le
temps.

### Les fichiers

| Fichier | Durée | Rôle |
|---|---|---|
| `MusicGameplay.ogg` | 4 min 26 | musique d'arène, en boucle |
| `MenuSoundMusic.ogg` | 15,5 s | musique des menus, en boucle |
| `Fireball.ogg` | 8,04 s | tir du joueur, coupé à 0,5 s |
| `BigRoar.ogg` | 5,09 s | apparition d'un boss |
| `chooseUpgradeSound.ogg` | 1,37 s | objet obtenu, nœud de Forge débloqué |
| `smallRoar1sec.ogg` | 0,84 s | mort d'un ennemi |
| `StoneSoundForButtonMenuSelect.ogg` | 0,47 s | clic d'interface |

Deux évènements n'ont pas encore de son faute de fichier : **le joueur qui
encaisse un coup** et **l'âme ramassée**. Ce sont les deux premiers à ajouter.

## Livrer une version

Les modèles d'export de Godot 4.6.2 sont installés (Windows, Linux, macOS, Web,
Android, iOS), et [`export_presets.cfg`](export_presets.cfg) déclare deux
préréglages prêts à l'emploi.

```bash
godot --headless --export-release "Windows Desktop" build/windows/Infernum.exe
godot --headless --export-release "Web" build/web/index.html
```

Le préréglage Windows **embarque le `.pck` dans l'exécutable** : un seul fichier,
rien à installer. Poids : 100 Mo, dont **0,3 Mo de jeu** — le reste est le moteur.
Compressé, l'archive tombe à 35 Mo.

Deux réglages conditionnent une version jouable ailleurs que sur la machine de
développement :

- **`window_width_override` / `height_override` à 1280 × 720.** Le viewport reste
  à 1920 × 1080 en unités logiques (toute la mise en page en dépend, voir plus
  haut), mais la FENÊTRE s'ouvre plus petit. Sans ça, le jeu s'ouvre à 1920 de
  large et déborde de l'écran sur un portable.
- **Les `.gdignore` des packs sources.** Ils ne servent pas qu'à accélérer
  l'éditeur : ce qu'ils masquent n'est pas exporté. La version livrée contient les
  24 planches et les 10 pièces d'interface réellement utilisées, pas les 800
  fichiers des packs — ce que leurs licences demandent explicitement.

### Avant une diffusion publique

- **Licences.** Récapitulées dans [`CREDITS.md`](CREDITS.md). Les trois packs
  autorisent l'usage commercial dans un jeu et interdisent la redistribution des
  assets. **Distribuer le jeu exporté est conforme** — c'est le cas d'usage
  explicitement prévu.
- **Dépôt public.** C'est l'autre face de la même clause : « ni redistribution ni
  ré-upload, modifiés ou non ». Ni les packs ni les planches qu'on en tire ne
  sont donc versionnés — seuls le sont le code, les scènes, les réglages, et
  l'art propre au projet (le carreau de sol, le sprite de Caïn fait main). Tout
  le reste se régénère par [`tools/extract_assets.py`](tools/extract_assets.py).
  Le prix à payer est une étape d'installation. Le dépôt est par ailleurs passé
  en **privé**, ce qui ferme aussi les anciens commits — un fichier poussé puis
  retiré reste sinon accessible par le SHA de son commit.
- **Signature.** L'exécutable n'est pas signé ; Windows SmartScreen affichera un
  avertissement au premier lancement. Normal pour une première version, mais
  autant le dire dans la page de téléchargement.

### L'icône

`icon.png` (fenêtre, éditeur) et `icon.ico` (exécutable Windows) sont **générés
depuis un sprite du jeu** — Golgota, image 3 de sa planche de repos, version sans
ombre, sur une lueur de braise.

Deux choses décident du résultat, et elles vont dans cet ordre précis :

1. **Agrandir à une échelle entière, une seule fois, très grand** (×25 dans un
   maître de 1024). Un pixel art agrandi à un facteur fractionnaire a des pixels
   de tailles inégales.
2. **Réduire par moyenne de zone** vers chaque taille demandée. Réduire depuis un
   maître propre donne des petites tailles nettes ; agrandir directement en 16 px
   donne de la bouillie.

L'`.ico` embarque 256, 128, 64, 48, 32, 24 et 16 px — la grande en PNG compressé,
les autres en DIB 32 bits (entête doublé en hauteur et masque AND, que Windows
exige même sans transparence). Vérifié : six des sept tailles se retrouvent dans
l'exécutable exporté, Godot ignorant l'entrée 24 px, qui n'est pas une taille
standard.

Le choix du sprite n'est pas arbitraire : l'imp a été essayé et rejeté, son épée
pâle occupe la moitié de la masse et brouille la silhouette à 32 px. Golgota n'a
qu'un accent de couleur, et il survit à la réduction.
- **Version.** `config/version` est à `0.1.0`, repris dans les métadonnées de
  l'exécutable. À incrémenter à chaque livraison.

## Étendre

- **Un objet statistique** : une entrée dans `ITEMS` de `item_database.gd`. Les clés de
  `mods` sont celles de `PlayerStats.add_mod()`. Respecter la règle 4 ci-dessus.
- **Un objet à effet** : ajouter un `special` et le gérer dans `item_effects.gd` —
  et lui donner une borne explicite.
- **Une arme** : dupliquer le nœud `Weapon` sous `Player/Weapons`, changer
  `projectile_scene`. Le `TargetingSystem` et les stats sont injectés automatiquement.
- **Un ennemi** : sous-classer `enemy.gd` et surcharger `_update_movement()` pour un
  nouveau comportement (ou juste une scène avec d'autres exports pour une variante de
  stats), puis l'ajouter à `WaveManager.enemy_scenes` avec sa vague d'apparition et
  son poids.
- **Un personnage** : une entrée dans `Characters.CHARACTERS`. Le menu et les
  cartes se construisent tout seuls. Pour un passif, ajouter un `special` et le
  gérer dans `character_effects.gd` — en le plafonnant, et en n'appelant
  `RunState.set_character_bonus()` que sur transition, jamais chaque frame.
- **Un boss** : sous-classer `boss.gd`, surcharger `_run_phase()`,
  `_on_phase_entered()` et surtout `_release_pressure()` — la sanction anti-kite
  n'est pas optionnelle, c'est ce qui rend le combat non trivial. Les primitives
  (`fire_ring`, `fire_spread`, `telegraph_at`, `telegraph_ring`, `dash_toward`,
  `strafe_around`, `spawn_add`) sont dans la classe de base. Puis ajouter la
  scène à `WaveManager.boss_scenes`.
- **Un nœud de Forge** : une entrée dans `Forge.NODES` (`cost`, `requires`, `mods`).
  L'écran se reconstruit tout seul, aucune retouche d'UI.
- **Une malédiction / un pacte** : une entrée dans `Curses.CURSES` ou
  `WaveMods.MODIFIERS`. Les clés de pénalité (`enemy_health`, `enemy_speed`,
  `spawn_rate`, `elite_mult`…) sont lues par le WaveManager, les `rewards` vont
  dans les pools de `PlayerStats`. Garder le principe : additif et plafonné.
- **Réagir aux évènements** (XP, succès, audio, VFX) : écouter `GameEvents`
  (`enemy_died`, `damage_dealt`, `wave_started`, `player_damage_dealt`…) ou `RunState`.
  Aucun système n'en référence un autre en dur.

### Calques de physique

| # | Nom | Valeur |
|---|---|---|
| 1 | world | 1 |
| 2 | player | 2 |
| 3 | enemy | 4 |
| 4 | player_projectile | 8 |
| 5 | enemy_projectile | 16 |
| 6 | pickup | 32 |

## Notes

- Rendu en `gl_compatibility` (mobile / web friendly), étirement `canvas_items`.
- **Mise en page** : tous les panneaux modaux sont bornés par un `MarginContainer`
  plein écran, et leurs listes sont dans des `ScrollContainer` élastiques
  (`size_flags_vertical = 3`) plutôt qu'à hauteur fixe. Vérifié : chaque panneau
  tient en 1920×1080, 1280×720 et 1024×600. En ajouter un : ne jamais donner à
  une liste une hauteur minimale qui suppose un grand écran — c'est ce qui
  faisait déborder la Forge (793 px de minimum, contre 482 aujourd'hui).
- Les sauvegardes vivent dans `user://infernum_profile_N.cfg` (voir Profils).
- Les personnages, ennemis et boss sont des planches PNG animées ; les
  projectiles et le butin sont encore des SVG plats. Remplacer un sprite
  n'implique aucun changement de code, mais bien trois réglages mesurés sur la
  planche (`scale`, `offset`, filtrage Nearest) — la marche à suivre est dans
  [`assets/README.md`](assets/README.md).
