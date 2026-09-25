# Infernum

Roguelite d'action top-down (Brotato / Hades / Risk of Rain 2), ambiance enfer & démons.
**Godot 4.6** — testé sur 4.6.2 stable.

## Lancer

Ouvrir le dossier dans Godot, puis F5. Scène de départ :
`scenes/ui/main_menu.tscn`. L'arène est `scenes/main/main.tscn`.

> **Après un clone, il manque les images.** Les sprites des personnages, des
> ennemis, des boss, de l'interface et du décor viennent de packs tiers dont la
> licence interdit la redistribution : ils ne sont pas dans le dépôt. Déposer les
> cinq packs dans `assets/packs/` puis lancer
> ```bash
> python tools/extract_assets.py
> ```
> Le script n'a aucune dépendance et reconstruit tout à l'identique : les 12
> planches d'entité, les pièces d'interface, les 24 icônes d'objets, les 19
> pièces de décor et l'icône de l'application. Les noms de packs attendus sont en
> tête du fichier, les licences dans [`CREDITS.md`](CREDITS.md).

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

Le `WaveManager` n'orchestre plus que le cycle d'une vague (combat, aspiration,
boutique). Les chiffres vivent dans des classes à part, sous
[`scripts/systems/waves/`](scripts/systems/waves/) :

| Classe | Rôle |
|---|---|
| `DifficultyCurve` | PV, dégâts, vitesse, densité et élites de la piétaille, plus les deux constantes du Déchaînement |
| `BossCurve` | mise à l'échelle des boss et renforcement de la boucle |
| `EnemyRoster` / `EnemySpawnEntry` | types d'ennemis, vague d'entrée, poids et dérive — réglés dans [`scenes/main/enemy_roster.tres`](scenes/main/enemy_roster.tres) |
| `LeftoverHarvest` | ce que rendent les survivants en fin de vague |

Les courbes sont des **fonctions pures** : elles ne lisent aucun autoload, le
Déchaînement et les multiplicateurs d'options arrivent en argument. C'est ce qui
permet de les tester sans lancer de partie — voir « Tests des vagues » plus bas.
Les commentaires du code gardent la règle et le chiffre clé, et renvoient ici
pour les mesures.

| Courbe | Formule | Note |
|---|---|---|
| Durée | `20 s + 2 s × (vague-1)`, max 45 s | |
| Densité | `0.8 + 0.19 × (vague-1)` spawn/s, max 6 (9 avec options) | |
| PV ennemis | `× (1 + 0.10 × (vague-1))`, **+0.09/vague de plus à partir de la 16** (pente totale 0,19) | additif ; la seconde pente fait retomber la marge en fin de run |
| Dégâts ennemis | `× (1 + 0.095 × (vague-1))` | la seule courbe qui rend la fin de run dangereuse |
| Vitesse ennemis | `× (1 + 0.015 × (vague-1))`, max ×1.35 | |
| Élites | à partir de la vague 4, jusqu'à 18 % (31,5 % avec options) | PV ×4, **dégâts ×1,35**, âmes ×2, 2 % de clé, 8 % de soin |
| Boss | PV `× (1 + 0.09 × (vague − 5))` | sinon ils tombaient en 4 s en fin de run |

Les i-frames du joueur (0,4 s) bornent les dégâts entrants à **2,5 coups par
seconde** : le nombre d'ennemis ne fait donc presque rien au danger réel, seuls
les dégâts **par coup** comptent. C'est pourquoi la courbe de dégâts ennemis est
la plus raide après celle des PV — et pourquoi les options qui ajoutent de la
densité paient peu (voir Malédictions et Pactes).

La pente de dégâts a été réglée par le haut : à **11 %**, une brute élite
frappait pour **79 à la vague 20**, soit un joueur mort en une touche et demie
quel que soit son équipement. À 9,5 %, la courbe mord sans supprimer le droit à
l'erreur.

#### Une option doit toujours coûter

Relevé en écrivant les tests des vagues. La densité et les élites n'avaient
qu'**un seul** plafond, appliqué **après** les malédictions et les pactes — celui
censé borner les options. La vague normale l'atteignait donc d'elle-même : sans
aucune option, les élites passaient 18 % dès la **vague 13** et touchaient 31,5 %
à la **19**. À partir de là, « Nuée d'élites » (élites ×3, danger 4) et « Œil du
vide » (élites ×2) **ne coûtaient plus rien** et continuaient de verser leur
chance de clé : une récompense sans risque. Même chose, plus tard, pour
« Horde » et « Marée montante » une fois la cadence à 9/s (vague 44, donc en
Déchaînement).

Il y a désormais **deux plafonds, dans cet ordre** : la courbe de base s'arrête à
18 % d'élites et 6 apparitions/s, **puis** les options multiplient, jusqu'à
31,5 % et 9/s. C'est ce que le tableau ci-dessus annonçait depuis le début.

Le changement n'est pas neutre sans option, et il a été fait **avant** la
calibration pour qu'elle en mesure l'effet. À la vague 20, élites 31,5 % → 18 % :

| Par apparition, vague 20 | Avant | Après | Écart |
|---|---|---|---|
| PV (élite ×4) | ×1,945 | ×1,54 | **−21 %** |
| Âmes (élite ×2) | ×1,315 | ×1,18 | −10 % |
| Chance de clé (élite 2 %) | 0,63 % | 0,36 % | **−43 %** |

La difficulté monte **linéairement**. C'est délibéré : à la vague 20 un imp a ×3,35 PV
(seconde pente comprise), pas ×6,1 comme le donnerait un `×1.10` composé par vague. La puissance du joueur
étant elle-même plafonnée, les deux courbes restent comparables.

Les ennemis survivants sont dissipés en fin de vague. Ils rendent une part de
ce qu'on leur a pris, jamais le prix plein — voir « Les survivants rendent ce
qu'on leur a pris ».

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

#### Tests des vagues

```bash
godot --headless --path . res://tools/test_waves.tscn
```

[`tools/test_waves.gd`](tools/test_waves.gd) vérifie les courbes, la mise à
l'échelle des cinq boss (vagues 5, 10, 30 et 55), le roster et la moisson. Code
de sortie 0 si tout passe. Les valeurs attendues ont été **mesurées par banc
sur l'ancien `WaveManager`** avant sa restructuration : un échec est un
changement d'équilibrage, à reporter ici s'il est voulu. Contrôlé dans l'autre
sens : les tests échouent si l'on déplace `repeat_damage_growth` de 0,20 à 0,21.

Le test tourne dans une **scène** et non en `-s` : les scènes d'ennemis
référencent des autoloads, que le mode script ne charge pas. Exclu des paquets
joueurs avec le reste de `tools/`.

### Le soin

Deux sources, aucune autre. Il n'y avait rien auparavant : la moindre erreur se
payait jusqu'à la fin de la run, et une partie pouvait être condamnée dès la
vague 6 sans l'être vraiment — le joueur traînait quinze vagues avec 12 PV.

Tout le soin est libellé en **coups encaissables**, jamais en points de vie —
voir « Le soin ne se compte pas en PV » plus bas, c'est la décision structurante.

- **0,5 coup par vague franchie.**
- **1,5 coup en plus à la mort d'un boss.** Un boss se gagne rarement intact ;
  sans cela, le survivre revenait à entamer la suite avec les restes.
- **Les élites laissent un soin dans 8 % des cas**, valant 0,35 coup, plafonné à
  deux par vague.

#### Le soin ne se compte pas en PV

C'est la décision structurante, et elle vient d'une mesure. L'ancienne valeur —
5 PV fixes par vague, plus 10 % des PV max par soin d'élite — **valait 6,2 coups
encaissables à la vague 3 et 0,7 à la vague 20**. Neuf fois moins, précisément là
où le joueur en a besoin.

La cause est structurelle : les dégâts ennemis montent de 9,5 % par vague, les PV
du joueur non. Un soin libellé en points de vie, ou même en fraction des PV max,
va donc mécaniquement à contresens de la difficulté — généreux quand le jeu est
facile, dérisoire quand il mord.

Tout le soin est donc exprimé en **coups encaissables** : `coups × dégâts de
référence × multiplicateur de vague`. Résultat mesuré, joueur équipé comme il le
serait à cette vague :

| Vague | Coups rendus, avant | Coups rendus, après |
|---|---|---|
| 3 | 6,2 | 3,1 |
| 10 | 1,0 | 1,7 |
| 15 | 0,8 | 1,4 |
| 20 | 0,7 | 1,4 |

L'écart entre le début et la fin passe de ×9 à ×2,4. Le soin garde sa valeur là
où il compte.

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

### Ennemis — 5 comportements

| Type | Script | Comportement | Vague |
|---|---|---|---|
| **Imp** | `enemy.gd` | corps-à-corps, poursuite directe | 1 |
| **Limier** | `dasher_enemy.gd` | rapide : approche → armement télégraphié → charge → récupération | 2 |
| **Cultiste** | `ranged_enemy.gd` | distance : garde ~320 px, recule si on l'approche, tire | 3 |
| **Brute** | `enemy.gd` | tanky : lent, 90 PV, résistant au recul, gros dégâts de contact | 4 |
| **Œil** | `beam_enemy.gd` | rayon : vise, verrouille, frappe en ligne droite | 11 |

Âmes par ennemi : imp 3, limier 3, cultiste 5, brute 6, œil 8 — soit environ 0,1 âme par
point de PV pour tout le monde. La brute était réglée sur une propriété morte
(`xp_value`, qui n'existe pas sur `Enemy`) et retombait donc sur 3 âmes pour
90 PV : l'ennemi le plus coûteux à tuer était aussi le moins rentable, et c'est
son poids d'apparition qui croît le plus vite.

Le limier s'immobilise pendant son armement : la menace vient de la pression au sol,
pas d'un coup inévitable. Les projectiles ennemis n'ont **ni tir à l'avance ni
auto-correction** — l'aide à la visée est un confort réservé au joueur.

### La fiche de run montre d'OÙ viennent les chiffres

`TAB` ouvre la fiche. Chaque statistique y est décomposée par source, et lue en
VALEUR ABSOLUE aux deux bouts :

| | Personnage | Forge | Sacrés | Objets | Pactes | = Total |
|---|---|---|---|---|---|---|
| Dégâts | 9,0 | +4 % | −5 % | — | — | **10,4 /tir** |
| dont dégâts plats | — | — | — | +1,5 | — | **+1,5** |
| PV maximum | 80 | +10 | +10 | — | — | **100** |
| Armure | — | — | +10 | +16 | — | **26  (−21 %)** |
| Gain d'âmes | +10 % | +8 % | +45 % | — | +20 % | **+75 %** PLAFOND |

La première version n'affichait que des modificateurs. Elle disait « PV maximum
+30 » sans jamais dire que la base est 80, ni que l'arme tape à 9 et tire 5,2
fois par seconde : **un pourcentage sans son point d'appui ne se compare à
rien.** La colonne Personnage porte donc la valeur du personnage SEUL, et le
total la valeur effective.

**Les objets sacrés ont leur propre colonne.** Ce sont ceux qu'on ouvre avec des
**clés**, dans la Forge — le Manteau d'épines, le Duvet de phénix, le Siphon du
vide. Les mêler aux objets de boutique effacerait la seule chose qui les
distingue : ils se paient en runs précédentes, pas en âmes. Les voir à part, c'est
voir ce que les clés ont acheté.

Cinq décisions valent d'être retenues.

**Les colonnes de source sont BRUTES, le total est PLAFONNÉ.** Un plafond
s'applique au total, jamais à une source prise à part. Quand les colonnes
additionnées dépassent le total, la différence est exactement ce que le joueur a
acheté pour rien, et c'est là que la mention PLAFOND s'allume. C'est le genre de
chose qu'une fiche doit montrer plutôt que laisser deviner.

**Un tiret, pas un zéro,** quand une source n'apporte rien. Quatorze lignes de
« +0 % » répétées cinq fois seraient un mur de zéros où le regard ne trouverait
plus les chiffres qui comptent. Même raison pour la ligne « dont dégâts plats »,
qui **disparaît** quand aucune source n'en donne : seule la Braise ardente en
donne, et la plupart des runs ne l'auront pas.

**Un malus s'écrit en rouge.** Le Siphon du vide coûte des dégâts, une
malédiction coûte du confort : un malus en vert se lirait comme un gain.

**Le total est lu sur les NŒUDS VIVANTS**, l'arme et le joueur, et non recalculé
par la fiche. C'est le seul moyen d'être sûr qu'elle dise la même chose que le
jeu : une formule recopiée se désynchroniserait au premier changement
d'équilibrage, et une fiche qui ment est pire qu'une fiche absente.

Les statistiques sans base — armure, régénération, vol de vie, chance,
projectiles supplémentaires — gardent l'écriture de bonus dans la colonne
Personnage : leur base EST zéro, et écrire « 0 » serait plus bavard qu'un tiret.

Les **dégâts plats** sont la seule statistique qui ne se lise pas dans la même
unité que sa ligne, d'où la sous-ligne. Ils s'ajoutent **avant** le pourcentage,
donc ils sont multipliés par lui : +1,5 plat sur une arme à +50 % vaut +2,25 de
dégâts réels. Sans cette ligne, la Braise ardente affichait un tiret partout
tout en augmentant les dégâts — exactement la fiche qui ment contre laquelle
tout le reste a été écrit.

### Trois effets de jeu ne se voyaient pas du tout

Un effet qui déplace le joueur, lui retire des PV ou lui SAUVE la vie sans rien
afficher n'est pas un effet difficile : c'est un effet injuste. Trois en étaient
là.

**La chaîne d'Asmodée** tirait le joueur vers le boss, lui infligeait des dégâts
et secouait la caméra — et **rien n'était dessiné entre les deux**. C'est le seul
effet du jeu à modifier la position du joueur, et c'était le seul à ne montrer
aucune image. Elle est maintenant dessinée par
[`chain_lash.gd`](scripts/combat/chain_lash.gd) : elle part en arc, se tend, et
suit ses deux extrémités image par image — les deux bougent, le boss dérive et le
joueur est tiré.

Dessinée par code et non par une planche d'images, pour trois raisons mesurables
plutôt que par goût : sa longueur va de 170 à plus de 900 px selon la distance,
le nombre de maillons doit suivre, et ses deux bouts se déplacent pendant
l'animation. Un sprite étiré donnerait des maillons ovales, un sprite répété
demanderait exactement la logique qui est ici.

Deux essais ont été jetés en route. Des maillons **espacés** de 5 px lisaient
comme un pointillé, pas comme une chaîne — ils sont contigus, et l'entrelacement
se lit au contraste entre un maillon de face et un maillon de profil. Un maillon
sur deux en **brun sombre** se confondait avec le sol : il est resté clair, et
c'est un cerne noir sous toute la chaîne qui la détache du fond, y compris quand
elle traverse un rocher — ce qu'elle fait forcément.

**Le pacte des Chairs volatiles** annonçait sa mèche *dans un commentaire*, et
par rien d'autre : le code attendait 0,55 seconde en silence puis frappait dans
un rayon de 110 px. Le joueur ne pouvait pas sortir du rayon puisque rien ne lui
disait où il était. C'est maintenant une vraie zone annoncée, la même brique que
les boss, et elle emporte l'effet d'explosion — sans quoi un ennemi qui détone au
milieu d'une mêlée ne se distingue pas d'un ennemi qui meurt.

La planche d'explosion **existait déjà** et servait à la Braise éternelle. Ce
n'était pas un asset qui manquait, c'était un appel.

#### La seconde chance ressemblait à un coup encaissé

Le nœud de Forge **Seconde chance** intercepte le coup fatal, relève le joueur à
mi-vie et le rend intouchable 1,5 seconde. Le seul événement du jeu qui **annule
une mort** rejouait l'éclair ROUGE de n'importe quel coup encaissé, avec une
secousse deux fois plus forte, et rien d'autre. Il se lisait donc comme un gros
dégât, c'est-à-dire exactement comme son contraire — et surtout, rien ne disait
au joueur qu'il disposait d'une fenêtre pour s'extraire de ce qui venait de le
tuer. C'est la partie qui coûte des runs : la protection existait, elle était
invisible.

[`revive_burst.gd`](scripts/vfx/revive_burst.gd) la dessine en **deux temps**, et
c'est le second qui porte l'information :

| Temps | Ce que ça dit |
|---|---|
| **Éclat**, 0,45 s | une onde dorée part du corps, des rais s'en échappent : il vient de se passer quelque chose, et ce n'est pas un dégât |
| **Compte**, 1,5 s | un anneau se vide comme un cadran autour des pieds, et disparaît **exactement** quand l'invulnérabilité s'arrête |

L'anneau n'est pas une décoration qui dure à peu près aussi longtemps : c'est la
**mesure** de la protection restante. `Player.REVIVE_INVULNERABILITE` sert à la
fois à `Health.revive` et à la durée de l'anneau — deux valeurs séparées
auraient dérivé au premier réglage, et un anneau qui ment sur la protection est
pire qu'un anneau absent. Vérifié : à 1,20 s l'anneau est là et
`is_invulnerable()` répond vrai ; à 1,75 s les deux sont tombés ensemble.

Trois détails viennent de la capture d'écran et pas du code :

- **L'anneau était à 34 px, il est à 56.** À 34 il tombait SUR le personnage et
  l'arc restant se lisait comme une rayure au-dessus de sa tête. Il reste
  néanmoins sous la taille d'une zone de boss (78 à 135 px), qu'il ne doit jamais
  imiter : celles-là annoncent un dégât.
- **Il fallait une piste sous l'arc.** Un arc seul ne dit pas sur quelle course
  il se vide, donc il ne dit pas combien il reste — seulement qu'il rétrécit.
- **Il est posé aux pieds**, 34 px sous l'origine du nœud. Les planches sont des
  images de 100 px où le dessin flotte au milieu : un cercle au sol centré sur
  l'origine coupe le personnage en deux.

Le son est celui des objets obtenus, `chooseUpgradeSound` — celui de la banque
qui dit « quelque chose vient de vous être donné », ce qui est littéralement le
cas. Aucun fichier à ajouter.

### Les objets achetés tournent autour du joueur

L'inventaire n'existait qu'à l'écran de pause : en pleine vague, le joueur ne
voyait rien de ce qu'il avait acheté. Une run se construit pourtant objet par
objet, et ne rien montrer de cette construction pendant qu'elle a lieu revient à
cacher le sujet du jeu.

**Une icône par objet DISTINCT, jamais par exemplaire.** La Braise ardente se
cumule cinq fois : cinq braises identiques sur le même cercle seraient un bruit
qui n'apprend rien, et rempliraient l'orbite avant que le joueur ait fait le tour
du catalogue. Le nombre d'exemplaires se lit dans la fiche, qui est faite pour ça.

Un anneau régulier a été écarté : N icônes équidistantes tournant d'un bloc lit
comme un engrenage. Chaque icône a donc son rayon, sa vitesse et son balancement,
tirés **de son identifiant** et non au hasard — un grain retiré à chaque image
ferait vibrer les icônes sur place, et un grain tiré de l'indice déplacerait tous
les objets dès qu'un nouveau s'ajoute. Mesuré en jeu : sur quatre icônes, entre
2,7 et 4,5 px de déplacement en une demi-seconde, donc aucune ne suit sa voisine.

L'orbite est **aplatie de moitié** en vertical, comme tout le reste du jeu : un
cercle vu de dessus en vue 3/4 est une ellipse, et un cercle parfait flotterait à
la verticale du joueur. Chaque icône passe **derrière** lui sur la moitié arrière
de sa course, sans quoi elle glisserait sur lui sans profondeur.

Aucun effet de jeu : les icônes ne blessent pas, ne bloquent pas, ne ramassent
rien.

**Le vidage de l'inventaire s'écoute, il ne se suppose pas.** Recharger la scène
au moment de rejouer reconstruit bien le joueur, mais `_ready()` d'un ENFANT
tourne AVANT celui de son parent : l'orbite se construisait sur l'inventaire de
la run précédente, que `main.gd` vidait juste après, en silence. Les objets de
la partie d'avant restaient à tourner jusqu'au prochain achat, qui remettait
tout d'aplomb — ce qui rendait le défaut d'autant plus déroutant. `item_gained`
n'annonçait que les ajouts ; `RunState` émet maintenant `run_reset`.

#### L'Œil sanctionne l'immobilité

C'est ce qu'aucun des quatre autres ne faisait. Le cultiste tire des traits : ils
se lisent un par un et s'esquivent en marchant. L'Œil, lui, transforme une
position sûre en la seule où il ne faut pas être. Dans une arène où l'on tourne
en rond en tirant automatiquement, c'est la première chose qui punit le fait de
se poser.

Son rayon a **trois temps**, et c'est le deuxième qui porte tout le sens :

| Temps | Durée | Ce que ça dit |
|---|---|---|
| Visée | 0,70 s | un fil sombre suit le joueur : un coup se prépare |
| Verrouillage | 0,38 s | la direction se fige et la ligne s'allume : **bougez** |
| Tir | 0,16 s | le trait s'épaissit et frappe une fois |

La ligne suit le joueur pendant la visée, donc reculer ne sert à rien : seul le
pas de côté après le verrouillage esquive. Le rayon est un **segment**, pas une
demi-droite infinie — passer derrière l'Œil est une esquive valable, et il serait
faux de la refuser.

Sa faiblesse est son immobilité : il se fige pendant toute la charge, plus d'une
seconde d'arrêt complet, et il ne recule jamais quand on l'approche. Un Œil qu'on
laisse tranquille tire toutes les 3,4 s ; un Œil qu'on charge meurt sans avoir
fini de viser.

Il entre à la **vague 11**, juste après Lilith, et c'est un seuil de jeu et non
d'équilibrage : l'introduire plus tôt punirait un joueur qui n'a pas encore de
quoi choisir où se placer. Son poids monte doucement — deux ou trois Yeux
suffisent à interdire de se poser, dix en feraient un jeu de couloirs.

Comme les zones de boss, le rayon est **entièrement dessiné par code**, sans
asset ni collision : au moment du tir on mesure la distance du joueur au segment.
C'est un test exact, là où une zone de collision allongée demanderait un corps et
une couche de physique.

##### Tuer l'Œil annule le rayon — il ne l'annulait pas

Le rayon vit dans le conteneur des projectiles et non sous l'Œil : il lui
**survivait** donc, et frappait au nom d'un mort. C'était faux deux fois.

Faux pour le jeu d'abord. Toute la faiblesse de l'Œil est son immobilité pendant
la charge — c'est la phrase du paragraphe précédent, « un Œil qu'on charge meurt
sans avoir fini de viser ». Si le trait part quand même, la récompense de l'avoir
vu venir n'existe plus, et la seule contrepartie du seul ennemi qui sanctionne
l'immobilité disparaît.

Faux pour le code ensuite, et de façon instructive : `_tirer` passait `source` à
`apply_damage` **sans vérifier sa validité**. Une fois l'Œil libéré, l'appel
entier échouait sur une erreur de type. Le rayon ne blessait donc personne — le
bon résultat, **obtenu par accident**, avec une erreur en console et sans que
rien ne disparaisse à l'écran : le joueur voyait le trait le traverser sans
effet. Le garde-fou existait déjà dans
[`projectile.gd`](scripts/combat/projectile.gd), il manquait ici.

`is_queued_for_deletion()` compte autant que `is_instance_valid()` : `queue_free`
ne libère qu'en fin d'image, donc sans ce test le rayon tirerait encore une fois
au nom d'un Œil déjà mort.

Vérifié en posant un Œil face à un joueur immobile, donc sur la ligne de visée,
et en attendant l'apparition réelle du rayon plutôt qu'un délai supposé — le
premier tir arrive entre 1,0 et 1,7 s selon le déphasage aléatoire, et une
première mesure à 0,5 s n'avait rien prouvé du tout :

| | Rayons en vol | Dégâts au joueur |
|---|---|---|
| Œil vivant | 1, puis le tir part | **15** |
| Œil tué pendant la charge | 1 → **0** en moins de 0,05 s | **0** |

### Objets — 36 objets, 4 raretés

9 communes · 9 rares · 9 épiques · 5 légendaires, plus **4 objets à débloquer aux clés**.
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

### La passe d'équilibrage de la 0.5.0

Une simulation de run sur les vraies classes — vrais ennemis, vraies courbes,
vrais prix de boutique — a mesuré la **marge** du joueur : les dégâts qu'il peut
produire divisés par ceux qu'il faudrait pour tuer tout ce qui apparaît. Au-dessus
de 1 il nettoie, en dessous les ennemis s'accumulent.

**Une run ne suffit pas.** Deux exécutions de la même configuration ont donné 1,22
puis 0,42 à la vague 15 : le tirage d'objets domine tout le reste. Tout ce qui
suit est moyenné sur **huit runs**.

| Vague | 3 | 5 | 8 | 10 | 13 | 16 | 19 | 22 |
|---|---|---|---|---|---|---|---|---|
| Avant | 1,86 | 1,06 | 0,83 | 0,82 | 0,97 | 0,91 | 0,98 | — |
| **Après** | 2,24 | 1,44 | 1,04 | 0,94 | 1,18 | 1,10 | 0,87 | 1,00 |

Le problème n'était pas que le jeu soit dur, c'est qu'il était **plat** : de la
vague 6 à la 21, la marge restait collée à 0,90, sans escalade ni récompense —
quinze vagues de tapis roulant — pendant que 10 % de chaque vague survivait et
s'accumulait jusqu'à saturer l'arène. La courbe a maintenant une forme : large au
début, serrée au milieu, et une seconde pente de PV à partir de la vague 16 pour
qu'une run finisse par se conclure.

#### Ce que le joueur encaisse

| Vague | PV max | Coup moyen / pire | Morts en (moy / pire) |
|---|---|---|---|
| 5 | 85 | 11 / 22 | 8,1 / 3,8 |
| 10 | 135 | 16 / 40 | 8,6 / 3,4 |
| 15 | 147 | 21 / 50 | 6,8 / 2,9 |
| 22 | 177 | 30 / 65 | 5,9 / 2,7 |

Le « pire » est un brute élite. Avant la passe il frappait pour **79 à la
vague 20** — une mort en une touche et demie quel que soit l'équipement. Les
élites doivent être une menace, pas une sentence : leur multiplicateur de dégâts
descend de ×1,6 à ×1,35, et la courbe générale de 11 % à 9,5 % par vague.

#### Ce qui reste ouvert

La boutique finit encore une run de 22 vagues avec 56 piles pour 23 objets
distincts : **tout le catalogue, au maximum d'empilement**. Le renchérissement a
été relevé (`0.06 → 0.062` linéaire, `0.0035 → 0.0045` quadratique) mais pas assez
pour rendre les dernières vagues décisionnelles. Le monter davantage coûtait plus
de puissance que la baisse de PV n'en rendait — les deux courbes se combattent, et
c'est la marge qui perdait. À reprendre séparément.

### Dispersion mesurée du pool

Efficacité par âme dépensée, objets purement statistiques :

Puissance gagnée pour 100 âmes dépensées, objets purement statistiques *(avant la
passe de la 0.8.6, qui a remonté le Croc et l'Œil — voir plus bas)* :

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

### La passe d'équilibrage de la 0.8.6 — objets et Forge

Un banc temporaire a rejoué l'économie d'une run sur les vraies classes :
courbes et roster réels, prix de boutique réels, tirage d'offres par `ItemDB`,
portes de boss lues sur les scènes (PV, enragement, clés), nœuds de Forge réels,
et un acheteur glouton au meilleur rapport puissance / prix. 32 runs par
configuration.

**Le banc a d'abord été validé contre les mesures déjà écrites ici**, avant de
servir à quoi que ce soit : il retrouve *Écailles de basalte* à 17,1 (17,1
publié), *Œil du chasseur* à 7,7 (7,7), *Sceau du gardien* à 16,6 (16,0), *Cuir
tanné* à 19 en milieu de partie (20,5). La métrique par objet est donc fiable.
L'économie simulée l'est moins, et c'est dit plus bas.

#### Trois objets remontés dans leur fourchette

Puissance marginale pour 100 âmes de prix de base, sur les builds réelles de
l'acheteur à la vague 6 :

| Objet | Avant | Après | Changement | Médiane de sa rareté |
|---|---|---|---|---|
| *Croc ébréché* (commune) | 10,4 | **14,8** | critique 6 % → 9 % | ~14,5 |
| *Œil du chasseur* (rare) | 7,7 | **10,0** | critique 8 % → 11 % | ~12 |
| *Manteau d'épines* (rare, 2 clés) | 9,9 | **13,9** | armure 10 → 14 | ~12 |

Le Croc était structurellement faible : avec un multiplicateur critique de ×2,
+6 % de critique ne vaut que +6 % de DPS, quand le *Percuteur* en donne +10 % au
même prix. Aucun des deux critiques ne sature le plafond à lui seul (5 piles :
45 % et 55 % pour 60 %). Le *Manteau* se paie en clés : il ne pouvait pas valoir
moins qu'une rare ordinaire. L'*Œil* reste sous la médiane, et c'est voulu — sa
portée, que la métrique ne voit pas, fait le reste.

Laissés tels quels, et pourquoi : *Éclat trifide* vaut ×2 la médiane des épiques
en début de partie puis retombe à 12 à la vague 12, c'est l'exception multishot
assumée ; *Horloge damnée* et *Culasse infernale* s'effondrent quand la cadence
sature son plafond, c'est la pression anti-monobuild voulue ; *Duvet de phénix*
est le dernier des épiques sur la métrique mais rend **2,2 coups par vague** à la
vague 12, quatre fois le soin de fin de vague.

À la pièce, les épiques valent 8 à 13 % de puissance contre 2 à 5 % aux
communes. Comme chaque pièce renchérit toutes les suivantes (terme quadratique
du prix), acheter moins d'objets plus forts reste rentable : la rareté paie.

#### La Forge fait ce qu'elle promet

Forge complète, personnage nu :

| | DPS | PV effectifs | Puissance | Tronc seul |
|---|---|---|---|---|
| Caïn | ×1,96 | ×1,55 | **×1,75** | ×1,69 |
| Job | ×2,51 | ×1,62 | **×2,01** | ×1,63 |
| Loth | ×2,36 | ×1,58 | **×1,93** | ×1,72 |

C'est exactement le « ≈ ×2 de DPS » sur lequel les boss sont calibrés (voir « Les
boss sont des contrôles de build »), **sans compter** les nœuds d'effet (âmes de
départ, remise, étal, seconde chance…), que la métrique ne voit pas. Job et Loth
gagnent davantage par leur branche, et c'est le but : le DPS forgé de Job (≈ 110)
rejoint celui de Caïn (≈ 118) alors qu'il part de 44 contre 60. **Aucune valeur
de Forge n'a été changée.**

En runs simulées, la Forge complète franchit Lucifer et le Golgota de la boucle
32 fois sur 32 pour les trois personnages ; sans Forge, Caïn et Loth butent
surtout sur Lilith. Le tronc commun seul suffit presque (29 à 31 runs sur 32
pour Caïn et Loth) : la branche propre ne change pas le boss atteint, elle
change la façon d'y arriver.

#### Douze objets de plus, et pourquoi douze

Le défaut ouvert depuis la 0.5.0 : une run complète finissait avec **tout le
catalogue**, et les dernières boutiques n'étaient plus des décisions. Pour qu'une
bonne run ne possède plus que 60 à 70 % des objets, il fallait environ
35 objets. Au-delà, la dilution rend les builds aléatoires : un épique donné
apparaîtrait pour la première fois vers la vague 19 sans relance, contre 9,5
aujourd'hui. Douze ajouts, dans les proportions existantes :

| Objet | Rareté | Effet | Le trou qu'il comble |
|---|---|---|---|
| Pierre à aiguiser | commune | +4 % crit, +15 % dégâts crit | les dégâts critiques n'existaient qu'en épique |
| Bandelettes | commune | +0,3 PV/s, 3 piles | aucun soin accessible tôt |
| Gant du bourreau | commune | +8 % dégâts | aucune commune en pourcentage de dégâts |
| Chapelet de phalanges | rare | +8 % crit, +30 % dégâts crit, −3 % cadence | une build critique avant les épiques |
| Sang caillé | rare | +1 % vol de vie, +8 PV, 2 piles | vol de vie et PV réunis |
| Fléau des géants | rare | +30 % aux boss et élites, −10 % aux autres | les boss sont des portes de DPS, rien ne s'y préparait |
| Serpent d'airain | épique | pouvoir 30 % plus rapide ; Caïn garde 30 % de sa Marque | aucun objet ne touchait aux verbes |
| Chaîne de Moloch | épique | les critiques traversent un corps de plus, +5 % crit | un multiplicateur propre aux builds critiques |
| Cuirasse du pénitent | épique | +22 armure, +8 % vitesse, 2 piles | un tank mobile |
| Corne de Moloch | légendaire | élites ×1,5 plus fréquentes, ×2 d'âmes | une build économique qui se paie en risque |
| Sceau de Salomon | légendaire | +1 projectile, −25 % de portée | un second multishot, payé en portée |
| Reliquaire | rare, 3 clés | première relance de chaque boutique offerte | un objet de précision de build |

**La Chaîne de Moloch devait faire rebondir tous les tirs.** C'était inutile :
la perforation se rebraque déjà sur l'ennemi suivant, elle aurait doublé la
*Lance de Longin*. Réservée aux critiques, elle réutilise la même mécanique et
la même décote, mais n'a de valeur que dans une build critique.

**Le Serpent d'airain ne pouvait pas raccourcir le Prix du sang** : ce pouvoir ne
se recharge pas avec le temps mais avec la Marque. Il en garde donc 30 % après
usage, ce qui revient au même raccourcissement.

**Deux règles d'équilibrage sont enfreintes, sciemment.** La *Pierre à aiguiser*
touche deux axes multiplicatifs (chance et dégâts critiques) sans malus : en
commune, et à 4 % de chance, l'ensemble reste sous la médiane de sa rareté. Le
*Sceau de Salomon* ajoute un projectile hors de l'*Éclat trifide*, que la règle
E réservait à lui seul ; la taxe multishot globale le borne de la même façon, et
il paie en portée.

Les six effets ont été **déclenchés à la main**, comme les nœuds de Forge :

| Sonde | Attendu | Mesuré |
|---|---|---|
| Fléau, trait de 100 sur un commun | 90 | **90** |
| Fléau, trait de 100 sur une élite | 130 | **130** |
| Chaîne, tir critique | un corps de plus | **+1** *(0 sur un tir normal)* |
| Serpent, ruée / parade | 1,54 s / 2,8 s | **1,54 s / 2,8 s** |
| Corne, élites à la vague 8 | ×1,5 | **×1,5**, plafond des options tenu |
| Reliquaire, cinq relances | 0, 1, 2, 10, 20 | **0, 1, 2, 10, 20** |
| Serpent sur Caïn, 20 éliminations dépensées | 6 gardées | **6** |

**Mesuré en banc, 96 runs par configuration, ancien catalogue contre nouveau :**

| | Distincts en fin de run | Lucifer battu, tronc seul (Job) | Clés par run, Forge complète |
|---|---|---|---|
| 24 objets | 15,5 à 16,6 sur 24 **(65-69 %)** | 88 / 96 | 33,4 à 34,7 |
| 36 objets | 18,4 à 19,5 sur 36 **(51-54 %)** | 83 / 96 | 32,9 à 33,9 |

Le catalogue ne sature plus, et rien d'autre ne bouge : sans Forge, les trois
personnages font aussi bien ou légèrement mieux ; avec la Forge complète, 94 à
96 runs sur 96 vont au bout dans les deux cas. La seule baisse porte sur le
**Golgota de la boucle**, après Lucifer, pour une Forge incomplète — le combat de
fin de partie durci, pas la progression.

**Trois nouveaux objets ont été relevés après la première mesure** : la *Pierre à
aiguiser* (2,2 → 10,6 à vide — des dégâts critiques seuls ne valent rien à 8 %
de chance), le *Chapelet* (4,2 → 9,2, son malus de cadence mangeait tout) et la
*Cuirasse* (armure 18 → 22). Trop faibles, ils diluaient la boutique : Job
n'atteignait plus la vague 30 qu'une fois sur trois avec le tronc de Forge.

Le *Fléau*, le *Serpent*, la *Corne* et le *Reliquaire* ne se chiffrent pas avec
la métrique : ils changent la porte de boss, l'esquive, le risque ou la boutique.
À juger en jeu.

#### Ce que le banc ne sait pas, et ce qui reste à vérifier en jeu

- **Il n'esquive pas et ne meurt qu'à l'enragement d'un boss.** Les clés et les
  boss franchis sont donc une **borne haute** : un profil neuf y complète sa
  Forge en 5 à 8 runs, là où la conception vise une douzaine — un vrai joueur,
  qui meurt aussi sous les coups, sera plus lent. À confirmer sur des profils
  réels avant de toucher au rythme des clés.
- **Job ne franchit Golgota avant l'enragement que 14 fois sur 32 sans Forge.**
  Cohérent avec la mesure déjà écrite (80 à 100 s contre 60 s d'enragement).
  Pour Job, la porte est un seuil d'endurance et non de mort : il est bâti pour
  tenir un boss enragé. Rien n'a été changé ; c'est **le premier point à
  vérifier en jeu**, manette en main.
- Les nœuds et objets d'effet — seconde chance, soin après boss, vol de vie,
  vitesse, portée, gain d'âmes — ne se chiffrent pas avec cette métrique.

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
des objets suit donc trois termes : `base × (1 + 0.15 × vague) × (1 + 0.062 n +
0.0045 n²)`, où `n` est le nombre d'objets déjà possédés.

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

### La spirale de la build enfermée, et les deux sorties

Les âmes ne tombaient que des **éliminations**. Un joueur qui ne tue plus assez
vite ne gagne donc plus d'âmes, donc n'achète plus les objets qui font les
dégâts, donc tue encore moins vite. La boucle se referme et la run est condamnée
sans être finie.

Ce n'est pas un problème de courbe de fin de partie — les PV ennemis montent de
façon additive (×3,4 à la vague 20, ×4,9 à la vague 40) contre un plafond de
dégâts joueur à ×39. Une build complète n'est jamais rattrapée. Ce qui se fait
rattraper, c'est une build **moyenne ou défensive**, parce qu'au milieu de partie
les deux courbes sont à parité. Il fallait donc un filet pour une build mal
partie, et surtout **pas** une nouvelle source de revenu : elle serait devenue le
canal dominant en fin de partie.

#### 1. Les survivants rendent ce qu'on leur a pris

À la fin d'une vague, les ennemis encore debout étaient effacés **sans rien
lâcher** : on pouvait enlever 90 % des points de vie de quarante ennemis et
rentrer avec zéro. Ils rendent désormais leur valeur en âmes au prorata des
dégâts encaissés, **à moitié prix** (`leftover_soul_ratio`).

La qualité de la mesure est de **ne rien changer quand tout va bien** — et c'est
vérifié, pas supposé :

| Build | v1 | v2 | v3 | v4 | v5 | v6 | v7 | v8 |
|---|---|---|---|---|---|---|---|---|
| Écrasante *(+3000 % dégâts)* | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 6 |
| De base, aucun objet | 0 | 0 | 3 | 12 | 7 | 19 | 10 | 10 |

Un joueur qui tue tout n'a aucun survivant, donc ne touche pas une âme de plus :
aucun recalibrage de l'économie, aucun canal de puissance nouveau. La récolte
grandit avec la taille de l'échec, ce qui est exactement la forme voulue — et
elle pèse 10 à 25 % du revenu d'une vague dans le cas le plus défavorable.

#### Le taux dépend du personnage : Job 50 %, Caïn et Loth 25 %

La première version payait tout le monde au même taux, et la mesure a montré
qu'elle allait au mauvais endroit. Build de base, aucun achat, joueur
invincible, même trajectoire — la seule variable est le personnage :

| | À taux uniforme (0,5) | Taux séparés (Job 0,5 / autres 0,25) |
|---|---|---|
| **Job** | 78 âmes | **82** *(66 à 133 sur 6 runs)* |
| Loth | 100 | 63 |
| Caïn | 87 | 48 |

À taux uniforme, **c'est Loth qui moissonnait le plus et Job le moins** — soit
exactement l'inverse de ce pour quoi le filet avait été écrit. L'intuition
inverse était la mienne, sur une run unique, et elle était fausse : la récolte
paie les dégâts **répartis sur des cibles qui survivent**, donc elle va à qui
arrose, pas à qui encaisse. Loth tire vite et l'auto-visée change de cible sans
arrêt.

Le taux est donc porté par le personnage (`CharacterData.leftover_ratio`) et
non par le `WaveManager`, qui ne garde qu'une échelle globale pour désactiver la
mécanique d'un coup. Job est à taux plein parce qu'**user une foule sans
l'achever est littéralement son registre** ; les deux autres à moitié, ce qui
leur laisse une sortie de secours sans en faire un revenu.

La variance est grande — 66 à 133 âmes sur 6 runs pour Job — parce que le
nombre de survivants dépend de la composition de la vague. Les médianes se
comparent, les runs individuelles non.

Aucun des deux taux n'est le plein tarif, et c'est voulu : à 100 %, grignoter
quarante ennemis rapporterait autant que les tuer et achever ses cibles n'aurait
plus d'intérêt.
Vérifié sur des valeurs connues — dix ennemis intacts rendent **0**, dix ennemis
à moitié entamés **7**, dix ennemis à 10 % de leurs PV **13**. Le reliquat est
cumulé d'un ennemi au suivant avant d'être versé, sinon l'arrondi mangerait
tout : un imp vaut 3 âmes, donc 0,75 âme à moitié entamé, donc zéro — quarante
fois zéro.

#### 2. La boutique rachète

Le second cas de build enfermée n'est pas un manque de revenu mais un revenu
**mal dépensé** : trois objets défensifs achetés tôt, et plus assez de dégâts
pour gagner les âmes du quatrième. La boutique rachète donc un exemplaire pour
**la moitié de son prix de base**.

La moitié du prix **de base**, jamais du prix payé. Le prix payé vaut au moins le
prix de base et monte avec la vague et la richesse : à la vague 1 sans aucun
objet, un percuteur s'achète 25 âmes et se revend 12. Revendre est donc toujours
une perte sèche, et aucun aller-retour ne rapporte, à aucun moment de la run.
C'est une sortie de secours, pas un robinet.

La vente retire un exemplaire, recalcule tout depuis l'inventaire — donc vendre
le dernier exemplaire d'un objet à effet scripté retire bien son effet — et
prévient l'orbite, qui sinon continuerait d'afficher un objet vendu.

##### L'inventaire est une colonne à part, à côté de la boutique

La revente vivait au FOND du corps de la boutique, sous l'offre et sous les
pactes, donc dans la même zone de défilement qu'eux. Au-delà de quelques objets
elle passait sous le bord, et il fallait faire défiler pour SAVOIR ce qu'on
possédait. Or ce n'est pas la même question que « qu'est-ce que j'achète » :
l'une se lit d'un coup d'œil, et elle sert à décider de l'autre. Deux questions
dans le même défilement, c'est une question qu'on ne se pose plus.

Elle a donc sa **colonne**, à gauche, avec son propre défilement. Quatre
décisions valent d'être retenues :

- **Une liste verticale, pas un flux.** Dans une colonne de 330 px, un
  `HFlowContainer` se replie sur une ou deux cases par ligne — c'est-à-dire une
  liste, mais irrégulière. Les boutons prennent toute la largeur, sinon le bord
  droit part en dents de scie.
- **Les icônes, les mêmes que sur les cartes de l'offre.** Une liste de noms
  demande de LIRE pour retrouver un objet ; avec son icône elle se parcourt des
  yeux, ce qui est exactement ce qu'on fait quand on cherche quoi revendre. Et
  c'est la même image que celle qu'on a vue en l'achetant.
- **32 px, et il a fallu DEUX réglages.** Un `Button` dessine son icône à sa
  taille native, soit 16 px — deux fois trop petite, et `icon_max_width` seul ne
  fait que réduire. Il faut `expand_icon` pour qu'elle grandisse ET
  `icon_max_width` pour qu'elle s'arrête à 32, facteur **entier** sur une source
  de 16 comme partout ailleurs dans le jeu.
- **Le panneau entier disparaît quand on ne possède rien**, et pas seulement son
  contenu : une colonne vide de 330 px à gauche de la boutique décentrerait
  l'écran de la première vague sans rien apprendre à personne.

La colonne prend la **hauteur de la boutique** et pas celle de l'écran. Essayée
en pleine hauteur : elle touchait les deux bords, la boutique restait centrée et
plus courte, et l'écran penchait à gauche. Elle défile dès une dizaine d'objets,
et c'est assumé — une run complète en possède une vingtaine de distincts, aucune
colonne ne les montrera tous.

**Le corps de la boutique a dû être remesuré**, et c'est la règle du projet :
ces minima se reprennent dès qu'on touche à l'habillage. En perdant la section
de revente il est passé de 480 à 560 px de place — non pas parce qu'il a grandi,
mais parce qu'il défilait déjà avant : mesuré de 445 à 514 px selon le tirage,
contre 480 disponibles. Les pactes étaient rognés en bas de la boutique depuis
un moment, sous la section de revente qui cachait le problème.

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
`spawns_per_second_growth` et `health_growth` dans
[`difficulty_curve.gd`](scripts/systems/waves/difficulty_curve.gd) *(0.22 et 0.14 à
l'époque de cette mesure, 0.19 et 0.10 aujourd'hui)*.

## Le logo du studio, au lancement

La **première** scène du jeu n'est plus le menu : `run/main_scene` pointe sur
[`splash.tscn`](scenes/ui/splash.tscn), qui montre le logo **RootStudio** sur
fond noir, puis passe la main. Trois temps — 0,45 s d'apparition, 1,10 s de
tenue, 0,70 s de fondu — et la tenue est ce qui donne au logo le temps d'être
LU : à 0,6 s il passe pour un défaut d'affichage, au-delà de 2 s il se fait
attendre.

**Pourquoi pas l'écran de démarrage de Godot** (`boot_splash`), qui existe déjà :
il affiche une image fixe pendant le chargement du moteur, sans fondu, sans
durée réglable et sans moyen de la passer. Une scène coûte trois nœuds et donne
les trois.

**Elle se passe**, et ce n'est pas un détail : n'importe quelle touche, n'importe
quel bouton de manette, n'importe quel clic l'abrège. Au deuxième lancement de
la journée c'est la seule chose qu'on demande à un logo — sans ça, ce qui
accueille le joueur devient ce qui le retarde. Seules les PRESSIONS comptent :
sans ce test, la touche qui a lancé le jeu depuis un terminal passerait le logo
avant qu'il ne s'affiche.

Le logo est mesuré avant d'être posé, comme le reste : son fond est un noir
**opaque** (0, 0, 0, 255) jusque dans les coins, donc il se fond dans l'écran
sans qu'on ait à le découper. Et il n'a **aucune grille de pixels** — 93,5 % de
blocs uniformes au pas 2, en baisse ensuite, contre 100 % pour une vraie planche
de pixel art. C'est une image redimensionnée, pas du pixel art : elle se met à
l'échelle librement, en filtrage **linéaire**, là où tout le reste du jeu est au
plus proche.

Rien n'y est préchargé : le menu est chargé au changement de scène et non
pendant le fondu. Le jeu pèse 0,3 Mo de contenu et s'ouvre instantanément ; un
préchargement n'achèterait rien et masquerait le vrai coût s'il augmentait un
jour.

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

### L'illustration du titre, et pourquoi elle reste un JPEG

Le menu porte une illustration plein écran, `menu.jpg` — un gouffre en flammes
vu de dessus — et le titre est composé en **Jersey 10**, une police pixel sous
licence OFL (Alagard jusqu'à la 0.8.6, retirée faute de licence vérifiable).

**Le JPEG a d'abord été suspecté, puis mesuré, puis gardé.** Le réflexe, sur du
pixel art, est de convertir : le JPEG code par blocs de 8×8 en fréquence, donc il
pose un halo autour de chaque arête franche, et une image en aplats n'a que des
arêtes franches. Le même réflexe avait été le bon pour `floor2.png`, tiré d'un
rendu JPEG par mesure du pas des dalles.

Ici, la mesure dit l'inverse. Le pas a été cherché de 2 à 12 en comparant le
contraste **sur** les frontières multiples du pas au contraste **ailleurs** : sur
une image agrandie n fois, tout le contraste se reporte sur les frontières, donc
le rapport explose au bon pas. Il est resté entre 0,97 et 1,08 pour tous les pas
essayés — **aucune grille**. L'illustration est déjà à sa résolution native,
1588 × 656. Il n'y a donc rien à ramener : les artefacts JPEG sont **déjà cuits
dans l'image**, et réécrire en PNG les aurait conservés à l'identique en doublant
le poids du fichier (1 302 Ko contre 658). Godot ré-encode de toute façon à
l'import, en sans perte (`compress/mode=0`).

Ce qui reste du JPEG est mesurable et négligeable : un écart-type de 5,8 sur la
somme RVB dans une zone d'aplat sombre, soit moins de deux niveaux par canal.
Invisible à l'écran, et l'outil de conversion a été supprimé plutôt que gardé
« au cas où » — un outil qui ne sert pas est un outil qui ment sur le procédé.

L'illustration est en **2,42 de rapport**, bien plus large que le 16/9 du jeu.
Elle est posée en `KEEP_ASPECT_COVERED` : à l'écran large elle tient presque
entière, en 16/9 elle perd 13 % de chaque bord. La composition étant centrée et
symétrique, ce sont les coins de dallage qui partent, jamais le gouffre.

Un **voile en dégradé** passe par-dessus, de 12 % d'opacité en haut à 66 % en
bas. Il ne sert pas à assombrir l'image mais à la faire reculer : les boutons ont
leur propre fond opaque, et les libellés ont reçu un contour, donc la lisibilité
était déjà acquise. Le voile est monté à 66 % en bas parce que c'est là que la
lave est la plus vive et que s'affiche la ligne de profil, la plus petite de
l'écran.

Le titre est en **160 px**, un multiple de 10 : Jersey 10 est dessinée sur une
grille de 10, et une taille non multiple ferait tomber ses traits entre deux
pixels — d'où des titres en 50 ou 60, et des boutons en 30 (20 dans les cases de
la Forge). Elle paraît plus petite qu'une police vectorielle à taille égale :
toutes les tailles de bouton ont été remontées d'environ un tiers. Pour la même
raison, son import coupe le **lissage**, le **hinting** et le **positionnement
sous-pixel** — trois réglages faits pour les polices vectorielles, et qui ne
savent qu'abîmer une police pixel.

**Une police pour les titres et les boutons, pas pour les paragraphes.** Les
descriptions longues restent dans la police par défaut : un paragraphe entier en
pixel fatigue l'œil. La police vit dans le thème (`Button`, `CheckButton`,
`OptionButton`, et la variation `TitleLabel` pour les titres) : aucun écran ne
la charge lui-même.

Trois candidates ont été comparées sur le fond du menu, avec les vrais textes :
Alagard, **Jacquard 24** (une vraie gothique, superbe en logo mais illisible
en petites capitales — « OPTIONS » ne se lisait plus) et **Jersey 10**, retenue
pour sa lisibilité à toutes les tailles.

Les quatre sous-écrans posent leur propre voile à **80 %** (92 % avant la 0.8.6,
qui effaçait l'illustration). À 80 % le titre et les boutons du hub
transparaissaient autour des panneaux les plus courts — des blocs rouges
au-dessus de Profils. Le hub **s'efface donc tant qu'un sous-écran est ouvert** ;
l'illustration et les braises restent.

Des **braises** montent du gouffre (`CPUParticles2D`, 70 carrés de 2 à 5 px,
7 s de vie), entre le voile et les boutons : peu nombreuses et lentes, elles se
remarquent au second regard sans disputer la lecture.

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

### Trois boutons, trois rôles

Jusqu'à la 0.8.6, tous les boutons du jeu étaient le même rectangle doré :
Commencer, Retour, les onze malédictions, les nœuds de Forge — et **Effacer**,
en doré plein sur le profil actif. L'action la plus destructrice de l'interface
était la plus visible. Trois variations de thème, désormais :

| Variation | Aspect | Usage |
|---|---|---|
| `Button` | doré plein | l'action principale de l'écran, une seule si possible |
| `SecondaryButton` | sombre, liseré doré qui s'allume au survol | Retour, Forge Éternelle, Valeurs par défaut, nœuds acquis |
| `DangerButton` | rouge sombre, jamais mis en avant | Effacer un profil, Abandonner la run |

Appliqué partout, écrans de jeu compris : à la fin de run, « Nouvelle run » est
le seul bouton doré (Forge et Menu passent en secondaire) ; à la pause,
« Reprendre » est doré, « Options » secondaire, « Abandonner la run » en danger.

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
| Boutique | 1120 × ~620 | **mesurée sur son contenu**, entre 360 et 780 |
| Objets (colonne de gauche) | 330 × 706 | 642 pour 9 objets / 632 — elle défile, et c'est normal |
| Malédictions | 1240 × ~620 | **mesurée sur son contenu**, grille de 3 × 2 cartes |
| Choix du personnage | 1320 × ~700 | cartes 400 × **480** (texte coupé à 288) |
| Forge Éternelle | 1560 × ~1000 | **mesurée sur son contenu** (voir ci-dessous) |
| Options | 820 × 493 | 335 / 340 |
| Profils | 820 × 478 | 266 / 270 |
| Fin de run | 700 × 451 | 127 / **148** |

**La boutique aussi se mesure sur son contenu depuis la 0.8.6**, et la mesure a
eu un piège. Les noms d'objets en Jersey ont gagné une ligne : à 880 px de large,
« Chapelet de phalanges » en prenait trois et les pactes passaient sous le bord.
Le panneau passe à 1120 px. Mesurée tout de suite après la reconstruction, la
zone prenait pourtant son plafond, avec un grand vide sous les pactes : les
textes à retour à la ligne n'avaient **pas encore leur largeur** et réclamaient
une ligne par mot. On mesure donc après **une image de mise en page** — même garde
sur les malédictions.

**La pièce rare de l'offre est mise en valeur** : liseré doublé, fond teinté de sa
rareté, mention « PIÈCE RARE ». Seulement si elle est épique ou légendaire, et
strictement plus rare que les trois autres — un marqueur qui s'allumerait à
chaque boutique ne signalerait plus rien.

**Le HUD n'avait aucun contour**, d'où une vague peu lisible sur le sol sombre de
l'arène. Vague (50 px), chronomètre, âmes, clés, éliminations, nom de boss et
annonces passent en Jersey avec un contour sombre de 5 à 12 px selon la taille.

**Les malédictions sont des cartes depuis la 0.8.6.** L'ancienne liste empilait
onze barres dorées identiques, la récompense en petit texte cyan dessous : on
lisait mal ce qu'on gagnait, et plus mal encore ce qui était coché. Chaque
malédiction est une carte à cocher — nom, danger, description, **prix** en rouge
en face du **gain** en cyan — et la carte cochée s'allume comme celle du
personnage choisi. La grille se mesure sur son contenu, comme la Forge.

**La Forge se mesure elle-même depuis la 0.8.6.** Réglée à la main, sa zone
coupait l'arbre dès qu'un nœud gagnait une ligne, et le défaut est revenu à
chaque retouche d'habillage. Après chaque reconstruction, l'arbre prend
exactement sa hauteur minimale, et la liste des objets la sienne, bornée à
180 px. C'est aussi devenu un **vrai arbre** : chaque nœud est rangé à sa
profondeur (un de plus que son prérequis le plus profond), des traits relient
prérequis et nœuds — dorés quand le chemin est ouvert —, trois états se lisent
sans lire un mot (acquis, achetable, verrouillé), et une barre de détail donne la
description entière du nœud survolé ou sélectionné. Les cases tronquent leur
texte avec des points de suspension au lieu de le couper.

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
| Archétype | Dégâts | **Paladin** (0.9.0) | Mobilité |
| Figure | le premier meurtrier, marqué pour ne jamais mourir ni être en paix | on lui a tout pris pour voir s'il plierait ; il n'a pas plié | il a quitté la ville en flammes sans se retourner — contrairement à sa femme |
| PV | 85 | 130 (+12 armure) | 80 |
| Vitesse | 215 | 218 | **288** |
| Arme | 19 dégâts / 2.9 par s | **Lance du Juste** : 19 / 2.2, traverse un ennemi | 9 / **5.2** |
| Portée | 340 | 355 | 300 |
| Passif | **La Marque** : +1 % de dégâts par élimination dans la vague, plafonné à **+25 %**, remis à zéro à chaque vague — et le **PRIX DU SANG** (Espace / A), qui la dépense d'un coup autour de lui | **La Consécration** : immobile 0,5 s, il consacre le sol (160 px) — ce qui y entre brûle, il s'y soigne — et le **REFUS DE PLIER** (Espace / A), dont trois réussites chargent le **JUGEMENT** | **Ne pas se retourner** : **+20 % de cadence** tant qu'il se déplace, et la **RUÉE** (Espace / A) — 240 px à travers les corps, toutes les 2,2 s |

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

### La ruée de Loth — un verbe, pas un pourcentage

C'est la conséquence directe du paragraphe ci-dessus. Si les passifs sont des
bonus plats déguisés, alors les trois personnages se jouent **avec les mêmes
mains** : mêmes touches, même arme, mêmes déplacements, et seuls les chiffres
changent. Loth était un Caïn plus rapide. Il **traverse** désormais, ce qu'aucun
autre ne sait faire — et un verbe de plus vaut dix pourcents de plus.

L'action `dash` était **déclarée dans la table d'entrées depuis le début** (Espace
/ bouton A) et n'était implémentée nulle part. Ce README la listait lui-même
comme une liaison morte. Elle ne l'est plus, et elle n'appartient qu'à Loth.

| | Valeur | Pourquoi celle-là |
|---|---|---|
| Distance | **240 px** | les zones annoncées font 78 à 135 px de rayon, et la couronne du Calvaire est posée à 155 px : 240 sort de n'importe laquelle. À 137 px — la première valeur essayée — la ruée ne quittait même pas un écrasement de Golgota |
| Durée | **0,22 s** | au-delà d'un quart de seconde on ne tire plus et on ne corrige plus sa trajectoire : ce n'est plus une esquive, c'est un déplacement |
| Recharge | **2,2 s** | le vrai bouton d'équilibrage — une quinzaine de ruées par vague de 35 s, assez pour un outil, trop peu pour traverser en permanence |

#### Elle traverse les corps, et rien d'autre

**Aucune invulnérabilité.** Zones annoncées, projectiles et rayons touchent
pendant la ruée comme avant. Deux raisons, et aucune n'est une précaution de
principe :

1. Toute la difficulté du jeu est dans le **placement** — « la difficulté vient
   du nombre et du placement des zones, jamais d'un coup impossible à lire ».
   Une ruée invulnérable effacerait la lecture qu'elle est censée récompenser :
   on ne sortirait plus d'une zone, on la traverserait.
2. Les 0,4 s d'i-frames du joueur sont **déjà** la borne des dégâts entrants, à
   2,5 coups par seconde. Une seconde source d'invulnérabilité serait un canal
   parallèle, c'est-à-dire ce que tout le reste de l'équilibrage s'interdit.

La ruée sert à être **ailleurs**, pas à être intouchable.

Traverser demande **deux** garde-fous et non un. Le joueur retire la couche des
ennemis de son masque le temps du trajet, ce qui l'empêche d'être bloqué — mais
l'ennemi, lui, continue de le voir : sa collision à lui déclenche toujours les
dégâts de contact. Sans le second test, dans `enemy.gd`, traverser une mêlée
coûterait un coup à chaque fois et la ruée cesserait d'être une sortie.

#### Sondes

Chaque promesse est vérifiée en déclenchant la **vraie action d'entrée**, pas la
fonction qu'elle appelle : c'est la liaison qu'on veut prouver vivante.

| Sonde | Attendu | Mesuré |
|---|---|---|
| Distance d'une ruée | ~240 px | **236 px** |
| Durée | 0,22 s | **0,22 s** (1 083 px/s) |
| Ruée redemandée aussitôt | refusée | 0 px |
| Ruée après 2,4 s | acceptée | 268 px |
| Mur de 8 imps en travers | traversé, 0 dégât de contact | **traversé, 0 dégât** |
| Dégât hors contact pendant la ruée | encaissé | **50 encaissés**, `is_invulnerable` = faux |
| Ruée sur Caïn et sur Job | refusée | 0 px |

**Le banc s'est trompé une fois de plus sur le temps**, et la leçon mérite
d'être gardée : cumuler `+0,01` à chaque tour d'un `create_timer(0.01)` donnait
**0,13 s pour une ruée de 0,22**. À 170 images par seconde, un minuteur de 10 ms
en consomme 17, donc la boucle tourne bien moins souvent qu'elle ne le croit.
C'est exactement l'erreur que la règle « attendre sur le temps, jamais sur des
frames » interdit — déguisée en minuteur. La durée se lit sur l'horloge, dans un
banc lancé en fenêtré où le temps du jeu vaut le temps réel.

#### Deux images, parce qu'un déplacement de 240 px en 0,22 s ne se voit pas

À 60 images par seconde, le personnage n'est dessiné que sur treize images le
long d'un trajet plus long que l'écran n'est haut : sans rémanence il ne se
déplace pas, il **disparaît d'un endroit et réapparaît à un autre**. Six copies
sont donc laissées en route ([`dash_trail.gd`](scripts/vfx/dash_trail.gd)), dans
le conteneur des projectiles et non sous le joueur — enfants de lui, elles le
suivraient, c'est-à-dire exactement ce qu'elles doivent ne pas faire.

**La teinte de la traînée a dû passer au-dessus de 1, et c'est la capture qui l'a
montré.** `modulate` MULTIPLIE la couleur du sprite : un bleu froid à
(0,72 · 0,88 · 1,0) **assombrit** une planche déjà sombre, et les copies
disparaissaient dans la pierre de l'arène. Seule la plus récente se voyait, donc
la ruée lisait encore comme un saut. À (1,30 · 1,70 · 2,20) elles s'en détachent.

La recharge a sa propre jauge ([`dash_gauge.gd`](scripts/vfx/dash_gauge.gd)) :
une ruée qui répond une fois sur trois sans rien afficher n'est pas difficile,
elle est illisible. Elle ne se montre que **pendant** la recharge et disparaît
dès que la ruée est disponible — l'état par défaut du jeu ne doit rien afficher.
Trois différences délibérées avec l'anneau de la seconde chance, sans quoi deux
jauges au même endroit se confondraient :

| | Seconde chance | Ruée |
|---|---|---|
| Sens | se **vide** | se **remplit** |
| Rayon | 56 px | 26 px |
| Teinte | doré | bleu froid |

Elle n'a pas de son : la banque en compte sept, aucun ne dit « traverser », et en
détourner un dirait autre chose. C'est le premier à ajouter avec le coup encaissé
et l'âme ramassée.

### Le Prix du sang — Caïn dépense sa Marque

Même raisonnement que pour la ruée, appliqué au personnage suivant : il fallait
un **verbe**, et il ne fallait pas inventer une ressource pour l'alimenter.

La Marque en était déjà une, gâchée. Elle monte jusqu'à +25 % en tuant, puis
**retombe à zéro à chaque vague**, et le joueur n'avait jamais rien pu en faire :
elle se remplit toute seule et se vide toute seule. Le pouvoir en fait une
décision — **garder ses 25 % pour le boss qui arrive, ou les brûler maintenant
pour sortir d'un encerclement**.

| | Valeur | Pourquoi celle-là |
|---|---|---|
| Rayon | **200 px** | l'explosion de Braise éternelle porte à 135 px et part à chaque élimination ; celui-ci coûte une vague de Marque et ne part qu'une fois. À 200 px il prend une mêlée entière autour du joueur sans devenir une frappe d'écran |
| Dégâts | **3 × l'arme × la charge** | ils suivent l'arme principale, comme l'explosion : ils profitent des objets de dégâts, mais pas de la cadence ni du multishot — c'est ce qui les empêche de scaler seuls |
| Minimum | **25 % de la Marque** | en dessous, rien ne part du tout. Sans ce test, un appui réflexe à trois éliminations grille la vague entière pour un coup qui ne tue rien |
| Recul | **260** | le coup sert aussi à ouvrir un passage, pas seulement à tuer |

**Le plafond du coup est celui de la Marque**, pas un chiffre à part : la branche
de Forge de Caïn, qui monte déjà le plafond à +45 %, monte le coup avec lui, et
aucun canal de scaling nouveau ne s'ouvre.

#### Le marché, chiffré

La Marque pleine vaut **11,9 DPS** pour Caïn (59,5 de base, dont 25 % viennent
d'elle). La garder rapporte donc, selon ce qu'il reste de vague :

| Reste de vague | Valeur de la Marque gardée | Le coup la dépasse à partir de |
|---|---|---|
| 10 s | 119 | **2 ennemis** |
| 20 s | 238 | **4 ennemis** |
| 30 s | 357 | **6 ennemis** |

Le coup vaut **71,3 par cible** à Marque pleine, arme nue. C'est la forme de
décision recherchée : **un outil de foule, jamais une réponse à un boss**. Seul
face à Golgota, dépenser la Marque rapporte 71 là où la garder en rapporte 238.

**Le coup profite deux fois de la Marque**, et c'est mesuré : 71,3 au lieu de
57,0, parce que les dégâts d'arme qu'il lit portent encore le +25 % au moment où
il part. C'est assumé — la Marque est sur lui quand il frappe — et ça reste borné
par le même plafond.

#### L'échelle de l'explosion était fausse, et pas seulement ici

Le dessin se met à l'échelle du rayon, comme tout le reste. Pris sur la largeur
en usage — 111 px, l'**union** des 29 images — le résultat mesuré en jeu donnait
**278 px dessinés pour une zone de 400**. L'union compte les étoiles projetées au
loin à l'image 9 ; l'**image de pointe** n'en fait que 82.

C'est exactement l'erreur corrigée sur les impacts de boss en 0.8.1, restée ici
parce que ce correctif-là n'avait touché que la planche des boss. La constante
passe donc à 82 px **pour les deux** : le Prix du sang dessine désormais 377 px
sur 400, et **l'explosion de Braise éternelle grandit du même tiers** sans que
sa portée change d'un pixel.

#### Une troisième jauge, et il fallait qu'elle se distingue

La Marque n'était affichée **nulle part**. Un pouvoir dont on ignore la charge
n'est pas un choix, c'est une loterie — et le choix est tout ce qu'il apporte.

|  | Seconde chance | Ruée | Marque |
|---|---|---|---|
| Sens | se vide | se remplit | se remplit |
| Rayon | 56 px | 26 px | 26 px |
| Teinte | doré | bleu froid | **rouge sang** |
| Visible | pendant le compte | pendant la recharge | dès qu'il y a de la Marque |

Le rayon est celui de la ruée, volontairement : les deux appartiennent à des
personnages différents et ne peuvent pas être à l'écran en même temps. L'arc
reste **terne sous le minimum** et s'éclaire au franchissement — l'instant où le
pouvoir devient utilisable est le seul que le joueur ne doit pas manquer.

#### Sondes

Comme pour la ruée, la promesse est vérifiée en déclenchant la **vraie action
d'entrée**, pas la fonction qu'elle appelle.

| Sonde | Attendu | Mesuré |
|---|---|---|
| Marque pleine, brute à 120 px | dégâts, Marque vidée | **71,3**, 25 % → 0 % |
| Même coup, cible à 190 px | identique | **71,3** |
| Marque à moitié (13 %) | environ la moitié | **33,5**, 25 % → 0 % |
| Marque à 5 % | rien, et Marque gardée | **0 dégât**, 5 % → 5 % |
| Cible à 199 px | touchée | **71,3** |
| Cible à 201 px | épargnée | **0** |
| Touche Espace pour de vrai | le coup part | **71,3**, 25 % → 0 % |
| Jauges montées sur Caïn | Marque oui, ruée non | **oui / non** |
| Job et Loth | aucun pouvoir, aucune jauge | **0 dégât, aucune jauge** |

Il n'a **pas de son**, comme la ruée : la banque en compte sept, aucun ne dit
« dépenser ». C'est le troisième à ajouter, avec le coup encaissé et l'âme
ramassée.

### Le Refus de plier — la parade de Job

Troisième et dernier verbe. Job était le personnage le plus **passif** des
trois : il encaisse, il régénère, il attend. Ses 146 PV effectifs et ses 90 %
de réduction possible en font déjà le plus solide — lui donner un bouclier
n'aurait pas changé sa façon de jouer, ça l'aurait confirmée.

**Et un bouclier était interdit.** Les 0,4 s d'i-frames sont la seule borne des
dégâts entrants du jeu ; une immunité temporaire serait une seconde source
d'invulnérabilité, c'est-à-dire un canal parallèle. La parade, elle, **annule un
coup et un seul**, et se mérite.

| | Valeur | Pourquoi celle-là |
|---|---|---|
| Amorce | **0,15 s** | sans elle, à 170 images par seconde, la parade serait une réaction pure : triviale ou illisible. Avec, c'est une **prédiction** — et le jeu est fait pour ça, chaque attaque de boss étant annoncée par un disque qui se remplit |
| Fenêtre | **0,25 s** | assez pour couvrir l'arrivée d'un coup lu à l'avance, trop peu pour couvrir une hésitation |
| Sanction | **0,5 s cloué** | ratée, il reste planté dans la mêlée. À 2,5 coups/s au maximum, ça coûte environ un coup : de quoi hésiter, pas de quoi condamner |
| Recharge | **4 s** | le bouton d'équilibrage, comme les 2,2 s de la ruée |
| Contre | **2,5 × l'arme**, 150 px, recul 420 | il repousse tout ce qui est au contact : c'est la réponse à ce que Job ne sait pas faire, se dégager |

#### Ce qu'elle ne pare pas, et pourquoi c'est la règle la plus importante

**Les zones annoncées ne se parent pas.** Toute la difficulté du jeu est le
placement ; une parade qui marche sur les zones remplacerait « lis le sol et
bouge » par un bouton, et effacerait la lecture qu'elle prétend récompenser —
exactement l'argument qui interdit déjà une ruée invulnérable.

La distinction est **structurelle et non une liste de cas** : une zone qui
détone appelle `apply_damage` **sans auteur** (`source = null`), là où le
contact, un projectile et un rayon en passent toujours un. La parade ne teste
donc rien de particulier — elle ne s'arme que s'il y a quelqu'un en face.

**Un coup paré n'ouvre pas les i-frames**, puisqu'on sort avant `take_damage`.
Parer dans une mêlée laisse donc exposé 0,4 s plus tôt que d'encaisser : la
parade n'est pas gratuite, même réussie. C'est mesuré — le coup suivant passe
immédiatement.

**Le contre fait des dégâts FIXES**, un multiple des dégâts d'arme, et surtout
pas une fraction de ce qui a été paré : au Déchaînement les dégâts ennemis
montent en exponentielle, donc un contre proportionnel exploserait exactement là
où le mode cherche la limite.

#### Trois états, parce qu'une recharge ne suffisait pas

La ruée pouvait se contenter d'une jauge de recharge : elle part à l'instant où
on la demande. Pas celle-ci. Un joueur qui ne voit pas **quand** la fenêtre est
ouverte ne peut pas apprendre à la placer — il croit que le jeu répond mal alors
qu'il appuie trop tôt.

| État | Dessin |
|---|---|
| Amorce | un anneau large qui se **resserre** vers le corps |
| Fenêtre | un anneau **serré et vif**, plus un point central |
| Recharge | un arc qui se remplit, comme la ruée |
| Réussite | un éclat blanc, et l'onde du contre part jusqu'à 150 px |

Le bleu est celui de Job et ressemble à celui de la ruée : ça ne pose pas de
problème, les deux appartiennent à des personnages différents et ne peuvent pas
être à l'écran en même temps.

#### Sondes

| Sonde | Attendu | Mesuré |
|---|---|---|
| Coup de 40 dans la fenêtre | annulé | **140 → 140 PV** |
| Contre sur une brute à 100 px | dégâts | **42,3** (2,5 × 16,92) |
| **Zone annoncée** dans la fenêtre | **encaissée** | **140 → 118,6 PV** |
| Coup suivant immédiat | il passe | **140 → 111,4 PV** |
| Parade ratée | cloué, puis libre | **0 px** pendant 0,5 s, **79 px** ensuite |
| Nouvelle parade après réussite | refusée | **fenêtre fermée** |
| Cible à 149 px | touchée | **42,3** |
| Cible à 151 px | épargnée | **0** |
| Caïn et Loth | aucune parade | **coup encaissé, 85 → 65 et 80 → 60** |

**Le banc s'est trompé une fois, et la cause mérite d'être gardée** : le contre
mesurait 59,2 au lieu de 42,3, soit exactement le contre **plus une balle de
Job** (16,92). Son arme porte à 355 px, donc toute cible à portée du contre
l'est aussi, et un tir parti dans la même image entrait dans la mesure. Coupée
l'arme, le chiffre tombe pile sur l'attendu. Une mesure de dégâts sur un
personnage qui tire tout seul doit d'abord le faire taire.

Elle n'a **pas de son**, comme la ruée et le Prix du sang.

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
mais au quart de la cadence. Au-delà du cinquième, le cycle reboucle en
renforçant les boss — voir « La boucle repartait du boss le plus faible ».

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

Leurs PV **suivent la vague** (`× (1 + 0.09 × (vague − 5))`, dégâts : voir « Les
attaques des boss suivent la vague » ci-dessous).
Sans cela, ils étaient figés pendant que le DPS du joueur était multiplié par 22
entre les vagues 5 et 20 : Asmodée tombait en **4,3 s** et Lucifer en **4,0 s**,
donc ni l'un ni l'autre n'atteignait jamais sa phase 2 (déclenchée à 50 % de PV),
et la jauge de pression se déclenchait au plus une fois. Tout le travail de
pattern était invisible.

| Boss | Vague | PV de scène | PV à sa vague | Temps de mise à mort |
|---|---|---|---|---|
| Golgota | 5 | 3 800 | 3 800 | 17,6 s |
| Lilith | 10 | 5 600 | 8 120 | 20,7 s |
| Baal | 15 | 7 900 | 15 010 | ~21 s |
| Asmodée | 20 | 8 900 | 20 915 | ~18 s |
| Lucifer | 25 | 10 000 | 28 000 | ~20 s |

Les cinq combats tiennent maintenant dans une fourchette de 17 à 21 s : les deux
phases et plusieurs décharges de la jauge de pression sont garanties. L'enragement
à 100 s reste ce qu'il doit être — un filet contre le joueur qui traîne, pas une
phase attendue.

#### Les attaques des boss suivent la vague

Seul le dégât de **contact** montait, et deux fois moins vite que la piétaille
(4 % contre 9,5 % par vague). Les dégâts d'**attaque** — foudre, braise, salves,
tout ce qui blesse réellement le joueur — ne montaient pas du tout : une attaque
de Lucifer à la vague 25 valait **0,55 coup** quand un marteau de Golgota à la
vague 5 en valait **1,7**. Le boss le plus tardif était le moins dangereux du jeu.

Contact et attaques suivent maintenant la pente de dégâts de la piétaille,
ramenée à la vague 5 sur laquelle les valeurs de chaque boss sont écrites
(`BossCurve.threat_multiplier`).

#### Les boss sont des contrôles de build

Chaque scène fixe ses PV et son `enrage_time` pour qu'un DPS insuffisant fasse
durer le combat jusqu'à l'enragement — et c'est là que la run se termine. Seuils
visés, en multiples du DPS de départ (≈ 60) : Golgota ×1,25, Lilith ×3, Baal ×5,
Asmodée ×7, Lucifer ×9. Sans Forge, une bonne build franchit Lilith et bute sur
Baal ; la Forge complète (≈ ×2 de DPS) porte jusqu'à Lucifer.

Mesuré en partie réelle avant ce réglage, build faible et mort neutralisée :
**116 s** pour Baal et **542 s** pour Lucifer. C'est précisément ce que
l'enragement transforme désormais en mort.

*(Les temps datent de ce calibrage, mesurés sur une build qui progresse
normalement. La colonne « PV de scène » est relue sur les scènes : c'est elle qui
fait foi, et c'est son écart de ×2,6 entre Golgota et Lucifer qui a cassé la
boucle — voir ci-dessous.)*

| Vague | Boss | Identité | Phases | Anti-immobilisation |
|---|---|---|---|---|
| 5 | **Golgota** — *Le Mont du Crâne* | le Golgotha n'est pas un démon mais un lieu : le mont où l'on dressait les croix. Colosse d'ossements, lent, écrasant | Pierre → Fracture (crânes en anneaux) | **Le Calvaire** : sept croix jaillissent en couronne serrée autour du joueur |
| 10 | **Lilith** — *La Première Nuit* | première femme d'Adam, partie plutôt que se soumettre, mère des lilim | Séduction (orbite, invocations) → Nuit (semi-invisible, téléportations) | **L'Appel** : elle se téléporte sur le joueur et fait surgir quatre lilim autour de lui |
| 15 | **Baal** — *Le Seigneur de l'Orage* | divinité cananéenne de l'orage, culte par le feu | Orage (foudre télégraphiée) → Fournaise (sillage de braise, anneaux) | **Le Déluge** : huit éclairs tombent d'un coup en couronne |
| 20 | **Asmodée** — *Les Trois Têtes* | roi des démons du Livre de Tobie, trois têtes : taureau, homme, bélier | Deux têtes → Trois têtes | **La Chaîne de Salomon** : le lien se referme et *tire le joueur vers lui* |
| 25 | **Lucifer** — *L'Étoile du Matin* | *lucifer*, « porteur de lumière », nom de l'étoile du matin devenu celui de l'ange déchu | Porteur de lumière → La Chute → L'Abîme | **L'Aube brûlante** : la couronne de feu s'embrase *à la distance où se tient le joueur* |

### La boucle repartait du boss le plus faible

Passé Lucifer, le cycle reprend à Golgota. Le renforcement de boucle — +45 % de
PV et +20 % de dégâts par tour — s'appliquait aux PV **propres** de chaque boss,
or le roster va de 3 800 à 10 000 : un écart de **×2,6** que +45 % ne rattrape
pas. Chaque tour rejouait donc la dent de scie **depuis son point le plus bas**,
et le boss qui suivait Lucifer était le plus faible du jeu depuis quinze vagues.

Mesuré sur les vraies classes, Caïn, catalogue complet au maximum de piles
(77 exemplaires, 169 PV) — la build qu'une run qui atteint la vague 25 possède
déjà. Le joueur orbite le boss à 320 px, quatre répétitions par palier, et il est
rendu increvable pour que la mesure porte sur ses dégâts et non sur son esquive.
« Morts » = dégâts présentés rapportés à ses points de vie.

| Vague | Boss | PV avant | Mise à mort avant | Morts avant |
|---|---|---|---|---|
| 25 | Lucifer | 28 000 | 9,1 s | 0,52 |
| 30 | Golgota | 17 908 | **5,9 s** | **0,31** |
| 35 | Lilith | 30 044 | 10,5 s | 0,74 |
| 40 | Baal | 47 538 | 18,9 s | 2,84 |
| 45 | Asmodée | 59 363 | 22,0 s | 2,08 |
| 50 | Lucifer | 73 225 | 26,3 s | 3,60 |
| 55 | Golgota | 39 710 | **14,5 s** | **0,92** |

Les deux lignes en gras sont le défaut : le boss d'après Lucifer tombait en
**5,9 secondes**, contre 9,1 pour le Lucifer qu'on venait de battre, et il
présentait **0,31 mort** contre 0,52. Un tour plus loin, Golgota retombait à
0,92 mort après un Lucifer à 3,60 — **divisé par quatre**, et cet écart
s'aggravait à chaque tour puisque le terme de vague dilue le +45 %.

#### Un plancher, pas un remplacement — et la première version s'est trompée

La correction évidente était de faire suivre à tous les boss rebouclés la courbe
du **dernier** du roster. Elle supprimait bien la dent de scie… en **abaissant**
la moitié de la boucle, les bases propres de Baal, Asmodée et Lucifer étant
supérieures à ce qu'elle imposait :

| | PV | Mise à mort |
|---|---|---|
| Baal vague 40 | 47 538 → 41 500 | 18,9 → 13,3 s |
| Lucifer vague 50 | 73 225 → 50 500 | 26,3 → 17,9 s |

Un durcissement qui rendait la moitié du contenu plus facile. C'est un
**plancher** qu'il fallait : en boucle, aucun boss ne descend sous le réservoir
du dernier du roster, et ceux qui sont déjà au-dessus gardent le leur. Le +45 %
par tour s'applique ensuite, inchangé.

Le plancher est **lu sur la scène** du dernier boss, jamais écrit en dur :
réordonner `boss_scenes` ou en ajouter un sixième suffit, sans qu'un nombre
recopié parte à la dérive en silence.

#### Les PV allongent le combat, ils ne le rendent pas plus dur

D'où le second levier : les rencontres répétées **frappent plus souvent**.
`Boss.attack_speed_multiplier` accélère le temps que voit la boucle de phase, ce
qui resserre les intervalles entre deux frappes — **sans toucher au préavis des
zones annoncées ni aux dégâts par coup**. Un boss ne touche toujours pas sans
préavis.

Le plafond est **calculé, pas choisi**. Les 0,4 s d'invulnérabilité du joueur
bornent les dégâts entrants à 2,5 coups par seconde, et Baal — le boss le plus
dense — produit déjà 1,94 zone par seconde. À ×1,30 il passait à 2,52 et le
combat cessait d'être esquivable ; le plafond est donc à **×1,25** (2,43), et la
montée est de +15 % par tour.

Vérifié, et c'est la mesure qui compte : **le joueur ne prend jamais plus de
0,83 coup par seconde** sur toute la boucle, pour un plafond d'i-frames à 2,5.
La pression à se déplacer augmente ; le mur de dégâts inévitables, non.

#### Ce que ça donne

| Vague | Boss | PV après | Mise à mort | Morts | Coups/s |
|---|---|---|---|---|---|
| 25 | Lucifer | 28 000 | 9,1 s | 0,46 | 0,44 |
| 30 | Golgota | **47 125** | **16,0 s** | 0,55 | 0,24 |
| 35 | Lilith | 53 650 | 18,6 s | 0,89 | 0,31 |
| 40 | Baal | 60 175 | 19,7 s | 3,09 | 0,76 |
| 45 | Asmodée | 66 700 | 24,5 s | 2,98 | 0,59 |
| 50 | Lucifer | 73 225 | 29,7 s | 5,43 | 0,83 |
| 55 | Golgota | **104 500** | **58,3 s** | 7,36 | 0,46 |

La suite est **monotone** : plus aucune rencontre n'est plus courte que la
précédente, à aucun tour. Le premier boss d'après Lucifer passe de 5,9 à 16,0
secondes, et Golgota au deuxième tour de 14,5 à 58,3 — assez pour que
l'enragement (60 s) commence à mordre, ce qui est exactement son rôle : la run
est conçue pour se terminer.

**Rien n'a été abaissé.** Les vagues 1 à 25 ne sont pas touchées du tout : le
chemin `loops == 0` est inchangé, ligne pour ligne, et la mesure le confirme
(Lucifer vague 25, 28 000 PV, 9,1 s avant comme après).

#### Ce que le banc a appris sur lui-même

Deux fausses mesures avant la bonne, et les deux valent d'être écrites.

**Un joueur aux PV gonflés ne reste pas increvable.** `Player.apply_stats`
ramène `max_health` à la valeur du personnage, et la Marque de Caïn déclenche un
recalcul à chaque palier d'éliminations : le joueur reprenait ses 169 PV en
pleine vague de boss, mourait, et l'écran de fin mettait l'arbre en pause. Le
combat se figeait sans que rien ne le dise — quatre boss « survivaient » 240
secondes. Il faut regonfler à **chaque** `stats_recomputed`. Le drapeau
`invincible` de `Health` ne convient pas non plus : il fait sortir `take_damage`
avant l'émission de `damaged`, donc il efface la mesure des dégâts présentés.

**La boutique s'ouvre entre deux mesures** et met l'arbre en pause, avec le même
symptôme silencieux. Un banc qui saute de vague en vague doit la refermer
d'office.

Et une leçon de méthode déjà connue, re-vérifiée : **un cercle fixe dans le monde
ne mesure rien**. La jauge de pression se lit sur la distance au boss ; un joueur
qui tourne autour de l'origine pendant que le boss apparaît n'importe où donnait
±20 % d'écart entre deux exécutions identiques. En orbitant **le boss**, quatre
répétitions tiennent dans ±3 %.

#### Le Déchaînement s'applique aussi aux boss — il ne s'appliquait pas

Les boss ont leur propre courbe de PV et ne passent **jamais** par
`DifficultyCurve.health_multiplier()`. C'est voulu : leur difficulté est celle de leur
palier, pas celle de la vague. Mais l'exponentielle du Déchaînement n'est pas un
palier — c'est la réponse de l'enfer à un joueur sans plafond — et les boss en
étaient exemptés **par accident**. Leurs PV montaient linéairement pendant que
ceux d'une brute étaient multipliés par 1,15 à chaque vague.

Mesuré en comparant le boss à **une seule brute** de la même vague :

| Vague | Boss | PV du boss | PV d'une brute | Le boss vaut |
|---|---|---|---|---|
| 30 | Golgota | 47 125 | 31 285 | 1,5 brute |
| 40 | Baal | 60 175 | 172 370 | **0,35 brute** |
| 55 | Golgota | 104 500 | 1 961 660 | **0,05 brute** |

À partir de la trentaine, le boss était **la chose la moins solide de l'écran**,
dans le mode dont c'est précisément le terrain de jeu. Le Déchaînement est un
défi de classement : on y pousse aussi loin qu'on peut, plus rien n'est plafonné
côté joueur, et une vague de boss y était devenue un repos.

Le facteur appliqué est **exactement celui de la piétaille**, et ce n'est pas une
valeur choisie : multiplier les deux par la même chose laisse le rapport
boss/piétaille **identique à ce qu'il est en régime normal**, à chaque vague. Un
chiffre propre aux boss aurait redessiné ce rapport sans que personne ne l'ait
décidé. Vérifié en mesurant les deux régimes, colonne pour colonne :

| Vague | Le boss vaut, régime normal | … en Déchaînement |
|---|---|---|
| 30 | 99,7 brutes | **99,7** |
| 35 | 96,1 | **96,1** |
| 40 | 93,5 | **93,5** |
| 45 | 91,5 | **91,5** |
| 50 | 89,9 | **89,9** |
| 55 | 116,1 | **116,1** |

Les dégâts suivent la même règle, par `DEGATS_DECHAINES` : sans cela un boss aux
PV rattrapés serait devenu un sac à frapper de plusieurs millions de points de
vie qui ne menace rien — l'ennui, pas la difficulté. À la vague 30 son coup vaut
723 contre 605 à une brute ; à la vague 55, 9 428 contre 6 759. Le boss frappe
plus fort que la piétaille, comme il doit, et pas d'un ordre de grandeur.

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

### Baal était le seul à se laisser jouer sans regarder l'écran

Sa phase 1 posait **une** zone toutes les 1,5 seconde, annoncée 0,8 seconde à
l'avance, large de 95 px. Le joueur se déplace à 288 px/s : il en couvrait 230
pendant le préavis, donc il sortait du cercle en marchant, sans le regarder. Et
rien d'autre n'occupait l'espace — pas un projectile entre deux frappes. Le
combat n'avait pas d'autre difficulté que sa longueur.

Pire, la seule zone était posée à la position **anticipée** du joueur, ce qui
récompensait paradoxalement l'immobilité : sans vitesse, la prédiction retombe
sur la position courante et il suffisait d'un pas au dernier moment.

Ce qui a changé est de la **densité** et de la **lecture**, jamais du dégât par
coup ni du préavis. La règle du jeu est qu'un boss ne touche pas sans préavis :
durcir Baal en raccourcissant sa mèche l'aurait cassée.

| | Avant | Après |
|---|---|---|
| Zones par frappe | 1 | **2** (doublet) ou **3** (saccade) |
| Intervalle, phase 1 | 1,5 s | 1,2 s |
| Préavis | 0,8 s | 0,62 s |
| Projectiles, phase 1 | aucun | anneau de 8 toutes les 4,5 s |
| Anneaux, phase 2 | 1 | **2 contrarotatifs** |
| Déluge | 8 zones, quelle que soit la distance | **9 à 16**, selon la distance |

Le **doublet** pose une zone là où le joueur va et une là où il est : rester
immobile est puni par la seconde, courir tout droit par la première. Il faut
changer de direction, ce qui n'était pas demandé avant.

La **saccade**, une frappe sur trois, aligne trois zones sur son axe de course
avec 0,14 s d'écart entre elles, et ferme la fuite en ligne droite. S'il est
immobile, elle part vers le boss : elle ferme la retraite au lieu de tomber trois
fois au même endroit.

Le **Déluge** compte ses zones selon la distance, comme l'Aube brûlante de
Lucifer. La couronne était de huit zones quoi qu'il arrive, donc elle s'espaçait
à mesure que le joueur reculait : la sanction anti-kite s'affaiblissait
précisément quand on kitait le plus. Mesuré : **9 zones à 300 px, 16 à 700**.

**Le plafond des i-frames n'est pas franchi**, et c'est ce qui rend le
durcissement honnête. Les 0,4 s d'invulnérabilité du joueur bornent les dégâts
entrants à 2,5 coups par seconde. Baal produisait 0,67 zone par seconde : le
plafond n'était jamais atteint, les zones étaient la seule limite. Il en produit
maintenant 1,94 en moyenne — toujours **sous** le plafond. La pression à se
déplacer augmente ; le mur de dégâts inévitables, non.

### Lucifer était le plus petit des cinq

Mesuré sur la boîte du contenu de chaque planche de repos, multiplié par
l'échelle du sprite dans la scène :

| Boss | Échelle | À l'écran |
|---|---|---|
| Asmodée | ×5,5 | 253 × 137 px |
| Golgota | ×5,5 | 176 × 170 px |
| Baal | ×5,5 | 170 × 154 px |
| Lilith | ×4,0 | 136 × 116 px |
| **Lucifer** | ×5,0 → **×6,0** | 195 × 155 → **234 × 186 px** |

Lucifer est le dernier boss, celui qu'on affronte à la vague 25 au bout d'une
demi-heure, et il était le **seul des quatre gros sous ×5,5**. Il passe à ×6,0 :
il domine désormais les quatre autres au lieu d'arriver en dessous.

**Sa boîte de collision ne bouge pas** (rayon 50). Ce n'est pas un oubli :
l'agrandir le rendrait plus facile à toucher ET plus dangereux au contact, deux
changements d'équilibrage pour une demande d'apparence. Le décalage entre son
dessin et sa boîte existait déjà — Asmodée mesure 253 px de large pour un rayon
de 52 — parce que la boîte représente le corps, pas l'envergure.

## Le Déchaînement — la récompense d'avoir tué Lucifer

**À QUOI SERT CE MODE**, parce que ça décide de tout le reste : c'est un **défi
de classement**. On y pousse aussi loin qu'on peut, **plus rien n'est plafonné**
côté joueur, et la question n'est plus « est-ce que je gagne » mais « jusqu'où
je tiens ». C'est le sens de la Clé des Abysses. Deux conséquences directes :
tout ce qui borne le joueur saute (voir plus bas — sauf une seule borne, qui
plafonne le temps de jeu et non la puissance), et **tout ce qui lui résiste doit
suivre la même courbe**, boss compris. Un mode où l'on mesure une limite ne peut
pas comporter une vague où l'on se repose.

Lucifer ne déverrouille rien en mourant : il **laisse tomber la Clé des
Abysses**, et il faut aller la prendre. La différence n'est pas décorative — un
déverrouillage accordé dans le noir pendant l'écran de fin de run ne se fête
pas, le joueur lit une ligne de texte après coup s'il la lit. Un objet qui tombe
du corps du boss, qu'on voit traverser l'arène et qu'on ramasse, est la
récompense elle-même.

La clé **ne tombe qu'une fois** : rejouer Lucifer dans la boucle rapporte ses
clés normales, pas une seconde clé sans objet. Elle est aussi **impossible à
rater** — son rayon d'accroche est celui de l'arène entière. Mesuré : lâchée à
762 px du joueur, elle le rejoint en 1,16 seconde.

### Elle s'arme à la Forge, personnage par personnage

Une fois la clé ramassée, un panneau apparaît à la Forge — l'écran où l'on
décide ce que devient un personnage sur la durée, et le seul qui soit déjà
propre à chacun. Armé une fois, le Déchaînement vaut pour toutes les runs
suivantes de CE personnage : Caïn peut être déchaîné pendant que Job reste bridé.

Le panneau est **caché** tant que la clé n'a pas été prise, pas grisé : un bouton
désactivé qu'on ne peut pas expliquer sans divulgâcher la fin du jeu vaut mieux
ne pas exister. Et la sélection de personnage porte un **témoin** juste au-dessus
du bouton qui lance la partie — c'est le dernier moment pour s'apercevoir qu'on
part en déchaîné sans l'avoir voulu.

### « Enlever les plafonds » ne voulait pas dire ce qu'on croyait

C'est la mesure qui a dicté le contenu du mode. En additionnant **tout** le
catalogue au maximum de piles plus les 21 nœuds de Forge, **sept plafonds sur
treize restent hors d'atteinte** :

| Pool | Maximum atteignable | Plafond | Effet de sa levée |
|---|---|---|---|
| Cadence de tir | +153 % | +150 % | **aucun** |
| Projectiles | +4 | +4 | **aucun** |
| Perforation | +3 | +3 | **aucun** |
| Armure | 106 | 160 | **aucun** |
| Vol de vie | +4 % | +8 % | **aucun** |
| Chance | +1,0 | +3,0 | **aucun** |
| Dégâts critiques | +1,20 | +1,50 | **aucun** |
| Chance de critique | +120 % | +60 % | ×2 |
| Dégâts | +352 % | +200 % | ×1,76 |
| Gain d'âmes | +113 % | +75 % | ×1,51 |
| Vitesse | +86 % | +60 % | ×1,43 |
| Portée | +100 % | +80 % | ×1,25 |

*(Mesuré sur le tronc commun des 21 nœuds. Les branches propres ajoutées depuis
valent 20 à 45 % sur un ou deux axes selon le personnage — assez pour dépasser
le plafond de cadence, pas pour rapprocher les sept autres.)*

Lever les seuls plafonds aurait donné **environ ×1,5 de dégâts** — une
augmentation, pas une build cassée. Ce qui bride vraiment, ce ne sont pas les
plafonds : ce sont les **deux taxes** (multishot et perforation), le **budget de
soin** du vol de vie, et le **nombre de piles**. Le mode les emporte donc tous,
sinon il ne tiendrait pas sa promesse.

### Ce que ça donne, mesuré

| Objets possédés | DPS normal | DPS déchaîné |
|---|---|---|
| 20 | ×6,1 | ×8,3 |
| 40 | ×18,7 | ×31,8 |
| 80 | ×35,8 *(plafonné)* | **×190** |
| 160 | ×35,8 | **×1 256** |
| 299 | ×35,8 | **×11 166** |

Les deux régimes sont presque identiques jusqu'à 40 objets, et c'est exactement
la forme voulue : le mode ne trivialise pas le début de run, il enlève le
plafond là où le régime normal s'arrête de monter.

### Une seule borne survit, et ce n'est pas un oubli

La **réduction de dégâts de l'armure** reste bornée à 90 % (contre 61,5 % en
temps normal). La formule tend vers 100 % sans jamais l'atteindre, donc elle ne
plafonne pas la puissance : elle plafonne le TEMPS DE JEU. À 99 % de réduction
le joueur n'est pas cassé, il est immortel, et une run immortelle ne finit
jamais — plus de fin, plus de score, plus rien à raconter. Casser le jeu doit
rester quelque chose qu'on regarde, pas un écran qu'on abandonne.

Pour la même raison, les objets à **effet scripté** restent uniques même
déchaînés : ils sont écrits pour un exemplaire, et les empiler ne les
renforcerait pas — ça déclencherait le même effet plusieurs fois sur le même
événement.

### L'enfer répond : les ennemis passent en exponentielle

Casser le jeu n'est amusant que s'il reste quelque chose à casser. En régime
normal les PV montent de 10 % par vague — linéaire, et largement dépassé par un
×1 256. En déchaîné, ils sont multipliés par **1,15 par vague** et les dégâts
par **1,08**.

| Vague | PV ennemis | Dégâts ennemis | DPS joueur estimé |
|---|---|---|---|
| 10 | ×8 | ×4 | ×25 |
| 20 | ×49 | ×13 | ×150 |
| 30 | ×324 | ×38 | ×450 |
| 40 | ×1 819 | ×102 | ×950 |

Le joueur domine largement jusqu'à la trentaine, puis la courbe le rattrape vers
la vague 36-38. **Premier réglage**, à bouger après avoir joué : `PUISSANCE_DECHAINEE`
et `DEGATS_DECHAINES` dans [`difficulty_curve.gd`](scripts/systems/waves/difficulty_curve.gd)
sont les deux seuls chiffres à toucher pour allonger ou raccourcir la course.

Les dégâts montent aussi, et pas seulement les PV : des ennemis à ×1 800 de PV
qui ne tuent pas ne font pas une run difficile, ils font une run qu'on abandonne
d'ennui.

### Le débit de projectiles a été mesuré, et il ne pose pas de problème

C'était le risque annoncé : 299 objets déchaînés donnent 17 projectiles par tir
à 6,9 tirs par seconde, soit **608 projectiles lancés par seconde** et ~670
vivants en permanence. Vsync coupée, le coût par image passe de **0,93 ms à
1,48 ms** — 676 images par seconde, pour un budget de 16,7 ms à 60 fps. Le
risque n'existe pas ; il fallait le vérifier plutôt que borner à l'aveugle.

La clé est **revérifiée à chaque lecture** du réglage : un profil dont le fichier
serait modifié à la main pour armer le Déchaînement sans posséder la clé se
retrouve bridé quand même. Effacer le réglage ne suffirait pas, la condition est
la clé.

## Forge Éternelle — méta-progression permanente

Arbre de **26 nœuds par personnage** — 21 communs sur trois branches de 7, plus
une quatrième branche qui n'existe que pour lui. Débloqués avec des clés et
conservés entre les runs. Accessible depuis l'écran de fin de run et depuis la
sélection de personnage.

| Branche | Nœuds | Effets |
|---|---|---|
| **Fer** | Braise de forge → Trempe / Mécanisme huilé → Fil rasoir → Acier noir → Fer qui traverse → Colère | +27 % dégâts, +6 % cadence, +5 % crit, +1 perforation |
| **Chair** | Cuir cousu → Plaques rivetées / Souffle lent → Carcasse épaisse → Écaille de forge / Repos du vainqueur → Seconde chance | +25 PV, +20 armure, +0,4 PV/s, +2 coups de soin par boss, une seconde chance par run |
| **Cendre** | Braises tièdes → Pas léger / Marchandage → Augure → Coffre de forge / Étal élargi → Clé du geôlier | +8 % âmes, +5 % vitesse, −10 % en boutique, +1 chance, 60 âmes au départ, +1 objet en boutique, +1 clé par boss |

Chaque nœud a des prérequis ; **66 clés** pour ouvrir le tronc commun, **82**
avec la branche du personnage.

### La quatrième branche — ce qui rend une Forge dédiée utile

Les trois branches ci-dessus sont **identiques pour tout le monde**, et doivent
le rester : c'est le tronc comparable, celui qui dit ce qu'un nœud vaut. Sans
autre chose, « chaque personnage a sa Forge » n'était qu'un coût triplé.

Chacun a donc une branche de 5 nœuds (16 clés) qui n'a aucun sens sur un autre :
elle ne contient que des nœuds qui touchent **son passif** ou **sa façon de
jouer**.

| Caïn — **Marque** | |
|---|---|
| Marque vive | la Marque monte de 1,5 % par élimination au lieu de 1 % |
| Marque profonde | elle plafonne à +45 % au lieu de +25 % |
| Le sang ne sèche pas | elle ne retombe qu'à moitié entre deux vagues |
| Fratricide | elle donne aussi la moitié de sa valeur en cadence |
| Errant | les ennemis sous 12 % de vie meurent sur le coup (**hors boss**) |

| Job — **Épreuve** | |
|---|---|
| Dîme de l'éprouvé | chaque coup encaissé rend 1 âme pour 5 points de dégâts |
| Chair marquée | +20 armure |
| Vieilles blessures | +0,8 % de dégâts par point d'armure |
| Œil pour œil | qui vous touche encaisse exactement ce qu'il vous a fait |
| Il n'a pas plié | la Patience repart après 1,5 s au lieu de 3, et régénère le double |

| Loth — **Exode** | |
|---|---|
| Pieds brûlés | +5 % de vitesse |
| Ne jamais s'arrêter | le bonus de cadence en mouvement double : +20 % → +40 % |
| Main basse | +12 % d'âmes |
| Fuite en avant | +20 % de dégâts tant qu'il se déplace |
| Sodome brûle | les ennemis que vous tuez explosent |

Les nœuds de statistiques alimentent **les mêmes pools plafonnés** que le reste :
la branche accélère la montée sur un axe, elle n'ouvre aucun canal parallèle.
« Errant » épargne les boss — ils sont les contrôles de build du jeu, et effacer
les 12 derniers pourcents de Lucifer supprimerait la phase pour laquelle il a
été dessiné.

#### Le vrai problème d'un personnage qui encaisse

Les âmes tombent des éliminations, donc **le revenu suit les dégâts**. Un
personnage bâti pour survivre s'équipe moins bien, donc frappe encore moins
fort, donc s'équipe encore moins bien : l'écart se creuse tout seul. Mesuré sur
12 vagues, sans aucun objet acheté, même trajectoire pour les trois :

| | Âmes gagnées | Éliminations | Dégâts subis |
|---|---|---|---|
| Caïn | **825** | 239 | 1 595 |
| Loth | 610 *(74 %)* | 141 | 848 |
| Job | **513** *(62 %)* | 156 | 3 366 |

Job gagne 38 % d'âmes en moins que Caïn et encaisse deux fois plus. Le déficit
n'est pas une impression : c'est la même monnaie qui paie les objets, donc le
retard se compose à chaque vague.

**Chaque branche porte donc un nœud d'économie, branché sur ce que le personnage
sait faire** — et c'est la partie qu'il fallait équilibrer :

- **Caïn** est payé pour la chaîne : « Errant » raccourcit chaque fin de cible,
  ce qui fait monter la Marque plus vite, ce qui raccourcit la suivante.
- **Loth** est payé pour le ramassage : +12 % d'âmes, en plus des +10 % qu'il a
  déjà.
- **Job** est payé pour ce qu'il encaisse : 1 âme pour 5 points de dégâts subis.

La Dîme est le **premier nœud de sa branche, à une seule clé**, et c'est une
correction : en second nœud elle coûtait 3 clés, donc trois runs, et Job est le
personnage le plus pauvre du jeu tant qu'il ne l'a pas — 156 âmes par run contre
189 à Caïn et 210 à Loth, mesuré sans branche. Comme un boss ATTEINT rapporte
une clé garantie et qu'il atteint Golgota 4 fois sur 4, il l'a désormais dès sa
première run. Le coût total de la branche ne change pas : 1 + 2 + 3 + 4 + 6 = 16.

La Dîme a **trois bornes, et aucune n'est arbitraire** : les i-frames limitent
l'encaisse à deux coups par seconde ; l'armure réduit les dégâts reçus, donc
réduit la dîme (s'empiler en défense coûte des âmes — c'est la tension qu'on
voulait) ; et le débit soutenable est celui de ses soins, pas celui des ennemis,
parce qu'au-delà il paie en points de vie et que mourir termine la run.

C'est aussi pourquoi le chiffre n'a pas été calibré sur un banc immortel : un
joueur qu'on remet à plein toutes les frames encaisse 3 366 points en 12 vagues,
ce qui vaudrait 673 âmes et ferait de Job le personnage le plus riche du jeu. Un
Job qui survit réellement en encaisse 180 à 380 par run, soit **10 à 17 % de son
revenu** — un rattrapage, pas une source principale.

#### Ce que les branches changent, mesuré

Runs complètes jusqu'à la mort, avec achats aux prix réels, même trajectoire
pour les trois (cercle de rayon constant), 2 à 3 runs par cas :

| | Sans la branche | Avec la branche |
|---|---|---|
| Caïn | 189 âmes, vague 4 | **410 âmes, vague 6** |
| Job | 156 âmes, vague 4 | **435 âmes, vague 6** |
| Loth | 210 âmes, vague 4 | **376 âmes, vague 5** |

Le résultat qui compte n'est pas le doublement — c'est le **resserrement**. Sans
branche, les trois vont de 156 à 210 âmes ; avec, de 376 à 435, soit 68 à 75
âmes par vague pour les trois. La branche ne creuse pas l'écart entre les
personnages, elle le comble.

Les valeurs de Loth ont été **relevées après cette mesure** : sa branche ne
valait que +28 % de DPS là où celle de Caïn en valait +45 et celle de Job +20
plus les épines et la Dîme. C'est la seule dont tout l'intérêt est conditionnel
au déplacement, elle doit payer davantage à conditions égales.

*(Ce tableau de revenus a été mesuré avant les deux renforts de Job décrits
ci-dessous — conversion d'armure doublée et armure du premier nœud doublée.)*

#### Le chronomètre des boss ne price que les dégâts

Le défaut de fond, trouvé en mesurant et pas en lisant : `enrage_time` est un
**contrôle de DPS pur**. Passé le délai, le boss gagne ×1,6 en dégâts et ×2 en
pression, et c'est ce qui tue. Or Job fait 44 DPS contre 60 à Caïn, et les
pourcentages de dégâts multiplient l'arme de base — le rapport de 73 % ne bouge
donc **jamais**, quoi qu'il achète. Son échange « 27 % de dégâts contre 1,7× de
PV effectifs » est bon contre une horde et mauvais contre un chronomètre.

Mesuré, joueur **invincible** pour isoler ses dégâts de sa capacité à esquiver,
6 runs par valeur, achats aux prix réels :

| Job | Golgota *(enrage 60 s)* | Lilith *(enrage 50 s)* |
|---|---|---|
| Conversion 0,4 %, armure 10 | 100 s | 204 s |
| Conversion 0,8 %, armure 10 | 82 s | 208 s |
| Conversion 0,8 %, armure 20 | **80 s** | **164 s** |
| Caïn, pour référence | 50 s | 80 s |

Deux enseignements. La conversion doublée gagne 18 % sur Golgota mais rien sur
Lilith ; avancer l'armure gagne 21 % sur Lilith mais rien sur Golgota — parce
qu'à la vague 5 les objets lui en ont déjà donné autant, alors qu'à la vague 10
le nœud a composé. Les deux leviers ne visent donc pas la même vague, et il
fallait les deux.

**Pourquoi pas simplement monter ses dégâts de base**, qui aurait marché aussi :
à DPS égal il garderait 2× les PV effectifs de Caïn, donc il serait strictement
le meilleur personnage et l'axe qui les distingue disparaîtrait. Ici la puissance
se paie en armure — il ne peut pas être à la fois tank maximal et dégâts
maximaux. Et l'armure réduit les dégâts reçus, donc réduit sa Dîme : s'équiper
en défense coûte des âmes.

Il reste **1,6× plus lent que Caïn sur Golgota et 2× sur Lilith**, pour 2× ses
PV effectifs. C'est un personnage cohérent et distinct — le broyeur lent — et
non un personnage réparé. Le rendre aussi rapide demanderait de doubler son
arme, donc de faire de lui un bruiser ; ça reste possible, mais il faudrait
alors lui reprendre des points de vie pour qu'il reste sur son axe au lieu d'en
sortir.

**Ce que le banc ne sait pas mesurer :** il décrit un cercle et n'esquive
jamais. Il sous-estime donc structurellement Loth, dont tout l'intérêt est de ne
pas se faire toucher, et il surestime le temps que Job passe au contact. Les
trois nœuds à effet — achever, épines, explosion — ont donc été vérifiés un par
un en déclenchant leur événement à la main, plutôt que déduits d'un total de
run :

| Sonde | Attendu | Mesuré |
|---|---|---|
| Achever, cible à 8/100 PV | meurt | **achevée** |
| Achever, cible à 50/100 PV | survit | vivante |
| Marque, 21 éliminations | +31,5 % | +31,5 % *(+1 % sans le nœud)* |
| Marque, vague suivante | moitié reportée | 21 → 10 éliminations |
| Fratricide | moitié en cadence | +22,5 % pour +45 % de dégâts |
| Dîme, coup de 50 | +10 âmes | **+10 âmes** *(0 sans le nœud)* |
| Œil pour œil, coup de 20 | 20 rendus | 20 rendus *(0 sans le nœud)* |
| Patience accélérée, 4 s | ~7 PV | **+7 PV** *(+1 sans le nœud)* |
| Vieilles blessures, 22 armure | armure × taux | +8,8 % au taux d'alors |
| Sodome brûle | le voisin encaisse | 7 PV *(0 sans le nœud)* |

### Chaque personnage a SA Forge

Un nœud de Forge modifie les statistiques de celui qui le porte : l'investir
dans Caïn doit donc être un choix, pas une case à cocher une fois pour toutes
qui profiterait aux trois. Les clés, elles, restent communes au profil — c'est
ce qui rend le choix coûteux : chaque clé dépensée sur l'un est une clé de moins
pour les autres, et les 82 clés d'une Forge complète deviennent 246 pour tout
ouvrir partout.

**Les objets ne suivent PAS la même règle,** et ce n'est pas une incohérence :
un objet débloqué avec des clés entre au CATALOGUE de la boutique, et un
catalogue qui dépendrait du personnage rendrait les tirages incompréhensibles.
La Forge modifie un personnage, le catalogue appartient au profil.

L'écran de Forge **nomme le personnage** qu'on renforce, en tête. Sans ça, un
joueur qui l'ouvre depuis la fin de run dépenserait ses clés au mauvais endroit
— une dépense irréversible.

#### La migration ne retire rien

Les profils existants portaient leurs nœuds dans le registre commun, mêlés aux
objets. Ils sont **donnés à tous les personnages** à la première ouverture du
jeu. Les clés dépensées l'ont été avant que la règle change, et le joueur n'a
pas à en faire les frais : donner trois fois est l'erreur généreuse, reprendre
est celle qu'on ne pardonne pas.

Le tri ne peut pas se faire au préfixe, et c'est le genre de raccourci qui
corrompt une sauvegarde en silence : l'objet **Cœur de forge** a pour
identifiant `forge_heart` et se serait retrouvé classé comme un nœud de Forge.
C'est la liste `Forge.NODES` qui fait foi.

### Pourquoi ça ne trivialise pas le début de partie

*(Cette section mesure l'ANCIEN arbre, avant le triplement du budget. L'arbre
actuel vaut ×1,75 à ×2,01 de puissance — voir « La passe d'équilibrage de la
0.8.6 ».)*

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
vague 20 rapportait **40 clés** — la moitié d'une Forge complète — et
jusqu'à **270** en cumulant *Œil du vide*, *Marée montante* et *Nuée d'élites*,
soit six fois toute la méta-progression en une seule partie.

| Configuration | Clés à la vague 15 | à la vague 25 |
|---|---|---|
| Référence | 9 à 10 | 24 à 27 |
| Œil du vide + Marée montante + Nuée d'élites à chaque vague | 15 à 24 | 40 à 47 |

Mesuré sur des runs complètes, joueur increvable et catalogue complet — donc
**la borne haute** : un élite dissipé en fin de vague ne rend aucune clé, et un
joueur qui ne tue pas tout en récolte moins. L'écart entre la meilleure
configuration de farm et la run normale est de **×1,7** : accepter des
malédictions accélère toujours la Forge, mais ne la saute plus.

Le revenu se lit en deux parts, et une seule est aléatoire :

- **La part garantie**, qui ne dépend que de la vague atteinte : une clé par
  palier de boss **atteint**, plus 1 à 3 clés par boss **abattu** (Golgota 1,
  Lilith 1, Baal 2, Asmodée 2, Lucifer 3). Soit **14 clés** pour une run qui va
  au bout de Lucifer, quoi qu'il arrive.
- **La part aléatoire**, 2 % par élite tué, multipliée par les bonus de
  malédiction et de pacte. C'est elle qui porte toute la variance : 628 élites
  apparus à la vague 25 en run de référence, pour une douzaine de clés.

### Ce que coûte la Forge

**82 clés pour la Forge complète d'un personnage**, et **246 pour les trois**.
Relevé sur `Forge.NODES`, pas estimé :

| | Coût | Détail |
|---|---|---|
| Branche **Fer** | 23 | 1+2+2+3+4+5+6 |
| Branche **Chair** | 23 | 1+2+2+3+4+4+7 |
| Branche **Cendre** | 20 | 1+2+2+3+3+4+5 |
| **Tronc commun** | **66** | les 21 nœuds partagés |
| Branche propre | 16 | 1+2+3+4+6, même coût pour les trois |
| **Une Forge complète** | **82** | tronc + branche |
| **Les trois Forges** | **246** | 66×3 + 16×3 |

Le tronc commun se paie **une fois par personnage** : c'est ce qui rend le choix
coûteux, chaque clé dépensée sur l'un étant une clé de moins pour les autres.
Les clés, elles, sont communes au profil.

*(Ce paragraphe annonçait « 42 clés pour l'arbre entier », chiffre d'avant les
Forges dédiées de la 0.7.1 — la section Forge disait déjà 66 et 82. Deux nombres
pour la même chose dans le même document, c'est exactement ce qu'une mesure non
remesurée devient.)*

Les âmes ne sont volontairement pas capitalisées : une épargne inter-runs
trivialiserait les premières vagues de la partie suivante.

## Job devient paladin (0.9.0)

Les runs de Job étaient les plus ennuyeuses, et pour une raison mesurable : son
passif, la Patience, le soignait à condition de NE PAS être touché pendant
3 s. Le personnage le plus solide du jeu était récompensé pour attendre, avec une
arme qui tapait mollement (44 DPS contre 60 à Caïn) et une parade qui défendait
sans jamais menacer. Le paladin garde la solidité et retourne la défense en
attaque ; il garde aussi son verbe, la parade, et les trois règles qui
l'encadrent (pas de seconde invulnérabilité, rien de proportionnel aux dégâts
subis, rien ne pare une zone annoncée).

- **La Lance du Juste**, à la place de la boule de feu : moins de traits, plus
  lourds (19 × 2,2 au lieu de 12 × 3,5 — même DPS de départ, 44), qui
  traversent un ennemi. Nouveau projectile, `lance_sacree.tscn`.
- **La Consécration** remplace la Patience. Immobile 0,5 s, il consacre le sol
  sous ses pieds (160 px). La zone RESTE où il l'a posée : petits pas permis à
  l'intérieur, il en sort et elle s'éteint en 1,2 s. Ce qui y entre brûle à
  **0,5 × les dégâts d'arme par seconde** — un multiple de l'arme, comme le
  contre, donc elle suit toute la build sans canal à part ; il s'y soigne de
  2 PV/s. C'est l'exact contraire de Loth, qui gagne à bouger.
- **La Ferveur et le Jugement.** Chaque parade réussie charge la Ferveur (trois
  losanges sous les pieds) ; un ennemi tué sur le sol consacré en donne un
  dixième, pour que le Jugement ne soit pas réservé à qui maîtrise la parade.
  Pleine, l'appui suivant libère le **Jugement** au lieu de parer : une onde de
  240 px à **6 × les dégâts d'arme**, qui consacre le sol sur-le-champ. Parer,
  parer, frapper.
- **Sa Forge suit, sans rien retirer aux profils** : les identifiants des nœuds
  restent, leurs effets changent. « Œil pour œil » (renvoi des coups, un effet
  de tank passif) devient **Terre sainte** (zone +33 %, brûlure +50 %) ; « Il
  n'a pas plié » consacre dès l'arrêt, double le soin et ne demande que deux
  charges de Ferveur. Dîme, Chair marquée et Vieilles blessures (l'armure en
  dégâts, déjà très paladin) restent.

**Mesuré**, joueur increvable et IMMOBILE (la façon de jouer visée, identique
pour les deux personnages), deux essais par ligne :

| | Job (Patience) | Paladin, 1er réglage | **Paladin retenu** | Caïn |
|---|---|---|---|---|
| Sans Forge, horde vague 8 (30 s) | 8 à 17 | 36 à 38 | **26 à 42** | 18 à 25 |
| Sans Forge, Golgota | 109 à 120 s | 62 s | **80 s** | 70 à 81 s |
| Forge + 12 objets, horde vague 14 | 54 à 62 | 73 à 77 | **55 à 74** | 69 à 78 |
| Forge + 12 objets, Lilith | 39,6 s | 30 s | **36 s** | 32,5 s |

Le premier réglage (lance à 22, traversant deux corps, brûlure à 0,8) le rendait
au moins aussi fort que Caïn partout, avec 130 PV et son armure — or il ne peut
pas être à la fois le meilleur tank et le meilleur en dégâts, c'est l'axe qui
distingue les trois. Retenu : lance à 19, un corps traversé, brûlure à 0,5. Caïn
reste devant sur les boss et en fin de run ; Job prend la foule, qui est sa
nouvelle identité. **Deux réserves** : la horde sans Forge varie énormément
(26 et 42 pour le même réglage), il faudrait plus d'essais pour trancher ; et le
banc immobile est le meilleur cas pour la Consécration — un joueur qui doit
esquiver la quittera plus souvent. La parade n'est pas simulée : le Jugement
n'y vient que des éliminations sur le sol consacré.

Réglages si ça sonne faux en jeu : `CONSECRATION_RATIO`, `CONSECRATION_RAYON`,
`JUGEMENT_RATIO`, `FERVEUR_PAR_ELIMINATION` (`character_db.gd`).

## Histoire et cinématiques (0.9.0)

**« Le Pari ».** Dans le livre de Job, tout commence par un pari entre Dieu et
l'Accusateur : « retire-lui tout, et il te maudira ». L'Accusateur a perdu, et
il veut sa revanche. Il a fait descendre trois âmes que le Ciel avait
épargnées — un meurtrier qu'on n'a pas eu le droit de tuer, un juste brisé puis
recollé, un fuyard sorti du feu — et parie que ce qui n'a pas plié là-haut
pliera ici.

L'histoire EXPLIQUE ce que le jeu faisait déjà, au lieu de s'y superposer :
on meurt et on recommence parce que perdre une manche ne libère personne ; la
Forge est l'atelier de l'Accusateur, qui arme ses propres joueurs parce qu'un
pari trop facile ne prouve rien ; la Clé des Abysses est la seule sortie du
pari. Chacun veut autre chose que la victoire : **Caïn une fin** (la Marque lui
interdit de mourir), **Job une réponse** (il ne sait pas pourquoi il est là),
**Loth quelqu'un** (sa femme, changée en sel, dont l'âme est tombée avec
Sodome — lui qui n'a jamais su se retourner doit revenir vers le feu).

**Quand elles jouent.** Entre le choix du damné et l'arène : le Pari la toute
première fois, puis le prologue de chaque personnage la première fois qu'on le
joue. Plus rien ensuite. Les profils existants les voient donc une fois, à leur
prochaine partie. Options → Histoire → « Revoir » les rejoue, y compris depuis
la pause.

**On peut toujours passer.** B, Échap, Start ou le bouton « Passer » (toujours
affiché, jamais focalisable — sinon A le presserait) coupent **toute la file**
d'un coup : qui passe le Pari ne veut pas subir le prologue derrière. A, Entrée,
Espace ou un clic terminent la réplique en cours, puis passent à la suivante.
Une cinématique est comptée comme **vue dès qu'elle commence** : la passer est un
choix, la reproposer à chaque partie punirait justement ce joueur-là.

**Mise en scène**, avec les seules planches du jeu : bandes noires, caméra qui
glisse sur chaque plan, silhouettes éteintes qu'une réplique allume, entrées en
marchant, apparition de Lucifer avec rugissement et secousse, et la **statue de
sel** — la planche du prêtre du pack, reteintée par un shader qui garde la
luminance du pixel art (un `modulate` n'aurait fait que l'assombrir). Elle est
tirée du pack par `tools/extract_assets.py`, comme les autres planches.

**Le milieu : après Lilith** (vague 10, la première fois que CE personnage la
bat). Lilith, la première femme, chassée du premier jardin pour avoir dit non,
révèle ce que Lucifer tait : **personne là-haut n'a accepté son pari. Il joue
seul, contre un Ciel qui se tait.** Caïn apprend que sa Marque ne vient pas de
Lucifer, donc qu'il ne peut pas l'ôter ; Job, qu'il souffre pour un adversaire
qui ne regarde pas ; Loth, que sa femme s'est retournée pour leurs filles
restées dans la ville — et qu'on ne la lui rendra pas.

La scène se joue **avant la boutique, jeu figé** : l'entracte compte à rebours
vers la vague suivante, et c'est d'ordinaire la boutique qui l'arrête. Le boss
tombé est reconnu par le nom de sa scène (`lilith`) ; une scène
`<boss>_<personnage>` dans `StoryDB` suffit à en ajouter une après un autre
boss. « Revoir » ne propose les scènes d'après boss qu'une fois vues : le menu
ne divulgue pas la suite.

**Erreur corrigée au banc** : pendant le fondu de sortie, la cinématique ne
bloquait plus les entrées alors que la boutique avait déjà le focus sur
« Vague suivante ». Qui tapotait A pour faire défiler les répliques la fermait
sans l'avoir vue. La cinématique retient maintenant tout jusqu'à sa
disparition, et `MenuNav` ignore A et B 0,35 s quand elle rend la main.

**La fin : Lucifer, les trois sceaux, Hélel.**

- **L'entrée** (vague 25) : la première fois que CE damné atteint Lucifer, jeu
  figé dès que le boss apparaît, avant son premier coup.
- **Sa mort** : chacun obtient ce qu'il était venu chercher — la Marque de Caïn
  pâlit (il peut mourir, « pas tout de suite, mais je peux ») ; Job reçoit sa
  réponse (il n'y en a jamais eu) ; le sel se fend et la femme de Loth, Édith,
  revient. Puis Lucifer se relève dans sa lumière d'origine, et le **sceau de
  ce damné** se brise (sauvegardé par profil). Le compteur « {sceaux} / 3 » et
  les répliques conditionnées (`si_min`, `si_moins`) disent ce qui reste.
- **Le choix**, après CHAQUE mort de Lucifer : « Continuer — l'enfer sans fin »
  est toujours là ; « Franchir le portail — Hélel » ne s'ouvre qu'avec les trois
  sceaux, et l'écran dit lesquels manquent.
- **Hélel, fils de l'Aurore** — le nom d'avant la chute, *Hêlēl ben Šāḥar*
  (Isaïe 14:12), que la Vulgate traduit « Lucifer ». Même grammaire d'attaques
  que Lucifer sur trois phases, plus une quatrième, **l'Aurore** (plongeons
  rapprochés et spirale à trois bras). 16 000 PV de base contre 10 000, mis à
  l'échelle comme un boss de la vague en cours, sans boucle ; enragement à
  140 s. Son sprite est celui de Lucifer **repeint en or** par un shader qui
  garde la luminance : un `modulate` sur un chevalier noir ne donnait qu'un
  chevalier terne. Piège rencontré : en fragment, `COLOR` contient déjà la
  texture — la remultiplier éteignait tout l'or ; la modulation (flash des
  coups) passe donc par le vertex.
- **Le glitch** : les trois sceaux ont lié les trois âmes, qui n'ont plus qu'un
  corps pour entrer. Toutes les **10 à 16 s**, un autre damné — jamais le même —
  prend le corps, au hasard : image dédoublée rouge/cyan et tranchée en bandes
  0,45 s, nom annoncé. Il garde les objets, les âmes et la **part** de PV (Job
  130 → Loth 80 ne tue ni ne soigne), et arrive avec SES valeurs de base, SON
  pouvoir et SA Forge (mesuré : Job passe à 155 PV avec ses nœuds). Le joueur
  n'est pas remplacé : ennemis, caméra et effets tiennent une référence à lui.
  Trois restes à purger à chaque changement, relevés avant d'écrire une ligne :
  les jauges de pouvoir (jamais retirées), la parade de Job (une sanction en
  cours clouait le suivant pour toujours, elle ne décompte que chez Job), et la
  ruée de Loth (interrompue, elle laissait traverser les ennemis). Côté
  passifs, la Marque et la fuite de Loth gardent des compteurs qui les
  empêchaient silencieusement de se réécrire : ils repartent de zéro.
  Le personnage d'origine revient dès que le combat s'arrête, et la sauvegarde
  ne voit jamais passer les autres.
- **La vraie fin** : Hélel tombe, les trois lui répondent, « Le Pari est
  rompu » — même bilan et même versement de clés qu'une fin de run.

**Hélel face à une Forge complète — le verrou de phase.** Mesuré à la vague 24,
Forge complète pour les trois damnés, joueur increvable tenu à 180 px du boss
(le meilleur cas possible pour lui), changements de corps actifs :

| Build | Mise à mort | Changements de corps |
|---|---|---|
| Aucun objet | 5 à 6 % des PV en 150 s | 11 à 12 |
| 18 objets au hasard | 112 s, ou 35 % en 150 s | 8 à 11 |
| **Catalogue au maximum** (103 exemplaires) | **12,3 à 12,8 s** | **0** |

La dernière ligne est le cas réel : c'est la build qu'une run de la vague 25
possède déjà (voir la mesure de Lucifer, 9,1 s, plus haut). Hélel tombait avant
le premier changement de corps — tout le sujet du combat passait à la trappe.

La correction n'est ni un plafond de dégâts ni plus de PV : les PV allongent le
combat pour tout le monde, y compris la build à 18 objets qui met déjà deux
minutes. C'est un **plancher de durée par phase** : tant qu'une phase n'a pas
duré **14 s**, Hélel ne descend pas sous le seuil de la suivante (ni sous 1 PV
dans la dernière). Les coups en trop sont absorbés — éclat blanc au lieu du
rouge — et comptent quand même pour la jauge de pression, qui sinon punirait le
joueur qui tape sans relâche. Remesuré, catalogue au maximum : **56 s**, phases
à 14, 28 et 42 s, **4 à 5 changements de corps**, sur trois essais. Une build
modeste ne sent rien : ses phases durent déjà plus de 14 s. Dans l'Aurore, le
corps change deux fois plus souvent (5 à 8 s).

**Pas dans le Déchaînement** : un plancher de durée y serait un plafond côté
joueur, contraire à ce que ce mode mesure. Hélel y suit la courbe de l'enfer.

**Le Voile de l'Aurore** — un bouclier qui compte les COUPS, pas les dégâts, et
qui est une ATTAQUE : 110 coups à porter en 6 s, sinon le **Jugement de l'Aube**
s'abat (deux couronnes de zones annoncées et une salve en étoile, tout
s'esquive). Brisé à temps, Hélel est sonné 2,5 s et encaisse +30 %. Anneau de
segments autour de lui : ce qui reste à frapper, et le temps.

Cadence réelle mesurée contre Hélel (coups qui touchent, par seconde, Forge
complète) :

| | Caïn | Job | Loth |
|---|---|---|---|
| Sans objet | 2,5 | 2,6 | 3,1 |
| Catalogue au maximum | 36,5 | 36,4 | 36,5 |

Ce que ça a corrigé dans l'intuition de départ : l'écart de coups entre builds
est bien plus serré que l'écart de dégâts (×14 contre ~×240), mais « Loth brise
le voile plus vite que Caïn » ne tient qu'à petite build — au maximum, les trois
frappent exactement autant. 110 coups = ~3 s pour la build maximale.

Combats complets, Voile de 110 :

| Réglage | Catalogue au maximum | 18 objets |
|---|---|---|
| Voile toutes les 18-24 s, **PV +25 %** | 56 s, 4 voiles brisés, 0 jugement | **vivant à 200 s**, 0 brisé, 7-8 jugements |
| Voile à chaque phase + Aurore toutes les 22-30 s, PV d'origine | **56 s**, 4 brisés, 5 changements | vivant à 200 s, **54 à 75 % des PV**, 3-4 jugements |

Deux leçons. **Les PV en plus n'ont rien changé à la build maximale** (le verrou
décide de la durée) et n'ont fait que punir la build moyenne : retirés. **Un
voile levé partout** coûtait 6 s de dégâts à chaque fois à qui ne le brise pas :
il ne revient en boucle que dans l'Aurore, le moment qui doit être le pire.

Ce qui reste un choix assumé, à revoir si ça sonne faux en jeu : Hélel est un
**contrôle de build**, comme les autres boss. Avec 18 objets il faut 4 à 6 min —
au-delà de l'enragement (140 s) —, alors que la build d'une run qui atteint la
vague 25 est plus proche du catalogue complet. Le levier, si besoin : ses PV de
scène (16 000), qui ne touchent pas la build maximale.

**Erreur trouvée au passage** : la Clé des Abysses était ajoutée à l'arène
pendant le contact physique qui tuait Lucifer, ce que le moteur refuse
(« Can't change this state while flushing queries »). L'ajout est différé.

Le panneau de développement brise ou rend les trois sceaux, et lance le combat
contre Hélel sur-le-champ.

**Erreur corrigée au banc** : les changements de corps continuaient pendant le
ramassage du butin, après la mort d'Hélel. Un changement tombé là restait figé
à l'écran par la pause de la cinématique, jusque sur l'écran de victoire. Ils
cessent maintenant à la mort du boss, et le glitch se termine même en pause.

**Où ça vit.** Le texte et les plans sont des **données**
([`story_db.gd`](scripts/story/story_db.gd)) : corriger une réplique ne touche
pas au lecteur ([`cinematic.gd`](scripts/story/cinematic.gd)). Pendant qu'une
cinématique joue, `MenuNav` est suspendu : l'écran de dessous ne doit pas
bouger dans le dos du joueur.

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

### Naviguer dans les menus (0.8.6)

Les menus se jouaient à la manette, mais mal. Six défauts, corrigés par
l'autoload [`MenuNav`](scripts/ui/menu_navigator.gd) plutôt qu'écran par écran :

| Défaut | Correction |
|---|---|
| Une direction tenue ne se répétait pas : onze appuis pour onze malédictions | Répétition après **0,36 s**, puis un pas toutes les **0,09 s** (mesuré : 11 pas en 1,2 s de maintien) |
| Le stick en diagonale faisait deux pas | Seul l'axe dominant compte, avec hystérésis (départ à 0,6, arrêt à 0,35, changement d'axe à ×1,5) |
| L'anneau haut/bas suivait l'ordre de l'arbre : dans une grille, « bas » allait à **droite** | Voisin cherché par **géométrie** dans les quatre directions ; au bord, on repart du côté opposé (horizontalement, seulement sur la même ligne) |
| Aucune zone de défilement ne suivait le focus | Le focus clavier/manette ramène toujours son contrôle dans le champ |
| **A est aussi la ruée** : la boutique s'ouvre focus sur « Vague suivante », un joueur qui ruait la fermait sans l'avoir vue — même risque sur l'écran de fin | Un écran qui surgit sur la partie ignore A et B pendant **0,35 s** ; une direction tenue en jouant n'y fait aucun pas avant d'être relâchée |
| Le style de focus était celui du survol, plein : posé sur une carte cochée, il **masquait** qu'elle l'était | Un **anneau** clair, sans fond, par-dessus l'état du bouton (intérieur sur les cartes, que les zones de défilement rognaient) |

Et quelques gestes qu'on attend d'une manette :

- **Gauche/droite règlent** un curseur ou une liste déroulante des options, au
  lieu de quitter la ligne.
- **Se poser sur une carte de personnage le choisit** — pas au survol de la
  souris, où glisser vers « Commencer » en travers d'une carte la choisirait.
- **Les nœuds verrouillés de la Forge prennent le focus** pour afficher leur
  détail : la manette ne pouvait lire que les nœuds achetables. La navigation
  étant géométrique, les traverser ne coûte plus rien.
- **Une carte de boutique s'allume en entier** quand son bouton d'achat a le
  focus, et chaque pas fait un petit clic (`survol`, le clic du menu 11 dB plus
  bas).
- **À la souris, le focus suit le survol** : sinon deux boutons brillent à la
  fois et on ne sait plus lequel A activerait.
- **Toutes les manettes branchées** sont écoutées : les liaisons visaient la
  manette 0, et une manette vue en 1 (Steam Input, pilote tiers) ne pouvait ni
  valider ni revenir.

Un curseur libre piloté au stick a été écarté : plus lent qu'un saut de bouton
en bouton sur des écrans de cinq à trente contrôles, et le focus restait de
toute façon indispensable pour A.

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

L'action `dash` (Espace / bouton A) a longtemps été une **liaison morte** :
déclarée dans la table d'entrées et implémentée nulle part. C'est désormais la
**ruée de Loth**, et elle n'appartient qu'à lui — voir « La ruée de Loth ».

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
  enemies/                    imp · hound · cultist · brute · oeil
  projectiles/                hell_bolt (joueur) · cursed_bolt (ennemi)
  pickups/                    soul · key · heal
  bosses/                     golgota · lilith · baal · asmodee · lucifer
  combat/                     telegraph
  ui/                         splash (logo du studio) · main_menu
                              character_select · options · profiles
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
              waves/                      courbes, boss, roster, moisson
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
  packs/      LES CINQ PACKS SOURCES, tels que téléchargés. Un seul
              .gdignore à la racine les masque à Godot — donc ni importés ni
              exportés — et une seule ligne de .gitignore les exclut du dépôt.
              Rien du jeu ne pointe ici : tout en est DÉRIVÉ, par
              tools/extract_assets.py.
  sprites/    un dossier par entité : characters/cain, enemies/imp,
              bosses/lucifer, projectiles/hell_bolt, pickups/soul...
              chaque entité porte deux planches : <nom>_idle.png, <nom>_walk.png
              items/ une icône 16×16 par objet, nommée par son identifiant
              decor/ une pièce de décor par fichier, nommée pareil
              arena/floor/ les deux carreaux de sol (art du projet)
  audio/      SoundEffects/ 2 musiques + 5 effets (OGG Vorbis)
  vfx/        Effect_pushAndStars/ planche d'explosion (domaine public)
  ui/         theme.tres
  fonts/
  README.md   planches, échelles, recalages, procédure d'ajout
default_bus_layout.tres       bus Master · Musique · Effets
```

Les dossiers vides `audio/{bosses,characters,…}` et `vfx/{bosses,…}`, posés au
départ « à remplir », ont été supprimés : le contenu réel est arrivé sous
d'autres noms et ils ne servaient plus qu'à faire croire à une structure.

### Les icônes d'objets

Une par objet, dans `assets/sprites/items/<id>.png`, chargée **par convention** :
aucun chemin n'est écrit dans le catalogue, et ajouter un objet revient à déposer
un fichier au bon nom. Une icône manquante ne casse rien — la carte se contente
de ne pas en afficher.

Elles sortent d'un pack de 1244 icônes nommées `item1.png` à `item1244.png`,
**sans aucune indication de contenu**. Les correspondances ont donc été établies
à l'œil, sur des planches de contact générées pour l'occasion, et n'ont aucune
chance d'être redécouvertes autrement : elles vivent dans `ITEM_ICONS`, au sein
de [`tools/extract_assets.py`](tools/extract_assets.py). C'est la partie de ce
script qu'il ne faut pas perdre.

Les cartes les affichent en 32 px — un facteur **entier** sur la source de 16 px,
filtré au plus proche. À l'échelle 2,5 un pixel sur deux serait deux fois plus
large que son voisin.

### Le sol de l'arène, et ses deux étages

L'arène n'a pas de bord. Le sol ne peut donc pas être une image posée une fois :
c'est un seul `Sprite2D` dont la texture se répète sur une `region_rect` de
6144², recalé à chaque image sur un multiple exact de la taille du carreau pour
rester **accroché au monde** (voir
[`floor_tiler.gd`](scripts/components/floor_tiler.gd)).

Un carreau répété doit se raccorder à lui-même, et ça se mesure : on compare
l'écart de luminance entre les deux bords qui vont se toucher à l'écart entre
deux colonnes VOISINES à l'intérieur du carreau. Si le joint est au niveau du
bruit interne, il est indistinguable d'un joint normal entre deux pierres, donc
invisible.

| Carreau | taille | bruit interne | joint vertical | joint horizontal |
|---|---|---|---|---|
| `floor.png` avant | 420 × 420 | 7,8 | **53,6** | 11,2 |
| `floor.png` après recadrage | 348 × 362 | 7,3 | 2,6 | 2,3 |
| `floor2.png` | 528 × 576 | 4,6 | 5,8 | 5,2 |

`floor.png` **portait une couture visible** : une ligne franche traversait
l'arène tous les 420 px. Un recadrage interne en (68, 52) la supprime, au prix de
17 % de la surface.

`floor2.png` part d'un rendu de 1408 × 768 qui ne pouvait pas se répéter tel
quel : il est **vignetté** (bords et coins plus sombres), ce qui aurait dessiné
une grille sombre à l'infini. La tuile en est tirée en mesurant d'abord le pas
des dalles par autocorrélation (88 px en x, 96 en y), en découpant un nombre
entier de dalles aligné sur un joint, puis en divisant le vignettage — estimé
par une moyenne glissante d'exactement un pas, car c'est la seule fenêtre qui
efface le motif périodique et ne laisse que l'éclairage. Diviser par le profil
brut effacerait les joints entre dalles.

Le changement d'étage tombe à la **vague 11**, juste après Lilith : là où
s'arrêtent la plupart des premières runs, donc le passage se mérite et se
remarque.

#### On part de la pierre froide et on descend vers le rouge

C'était l'inverse, et le décor racontait donc le contraire du jeu : on commençait
dans le chaud pour s'enfoncer vers quelque chose de plus calme. Les deux planches
mesurées valent 100/93/85 et 52/73/89 en moyenne RGB, soit **+15 et −38** d'écart
rouge-bleu ; la froide est maintenant la surface, la chaude la profondeur.

Vérifié à l'écran et pas seulement dans les valeurs — quart central de l'image,
écran de malédictions fermé, arène vidée :

| Étage | RGB à l'écran | Écart rouge-bleu | Luminance perçue |
|---|---|---|---|
| Surface, vague 1 | 48 / 52 / 55 | **−7** | 51 |
| Profondeur, vague 11 | 68 / 50 / 43 | **+24** | 55 |

La luminance perçue ne bouge pas (51 contre 55) : **ce qui change est la teinte,
pas la lisibilité**, et les ennemis se lisent aussi bien aux deux étages. Le
décor suit le sol dans les deux cas — sans quoi la pierre beige flotte au-dessus
d'un sol froid comme un calque d'un autre jeu.

### Le décor de l'arène

Même problème que le sol : rien ne peut être posé une fois, l'arène n'a pas de
bord. Il a fallu deux versions jetées pour arriver à celle-ci, et les raisons
valent d'être gardées.

1. **Une pièce par cellule, tirée indépendamment.** Ça marchait et ça ne voulait
   rien dire : aucune de ces pierres n'expliquait la présence des autres, et
   l'œil ne lisait qu'un bruit régulier. Un décor n'est pas une densité.
2. **Des compositions ancrées**, quelques pièces dispersées autour d'un point
   selon une forme. Mieux, mais toujours du semis : un tas de pierres reste un
   tas de pierres, il ne dit pas d'où elles viennent.

Ce qui est en place ne sème plus des pièces, il **engendre des zones**. Deux
générateurs, un par famille, et rien d'autre. Le monde est découpé en parcelles
de 950 px, et **chacune porte une zone** : ce qui varie n'est pas leur présence
mais leur TAILLE. Petite six fois sur dix, moyenne trois fois, grande une fois.

**La ruine, c'est une empreinte.** On tire un rectangle de 2 à 4 modules sur 2 à
3, on parcourt son périmètre, et on dresse une colonne à chaque nœud de la trame
sauf ceux que l'érosion a emportés, entre 30 et 62 % d'entre eux. L'œil reconnaît
un bâtiment à son **plan**, pas à ses pierres : c'est le rectangle interrompu qui
fait la ruine. Les angles reçoivent souvent la tour, la pièce la plus haute, parce
qu'un angle debout tient le plan mieux qu'un pan de mur. La grande ruine seule
reçoit un cœur, de la poterie et la végétation qui reprend la place : c'est ce qui
en fait un endroit et non un tas. La petite n'a pas de plan du tout, juste un pan
de mur tombé et ses gravats au pied.

**L'éboulis, c'est une pente.** Un ou deux blocs en tête, puis les débris, dont
la taille **décroît** et l'écart **croît** à mesure qu'on descend : un éventail.
C'est ce double gradient qui donne une direction à la chute, donc un sens à la
scène. Un nuage de pierres de taille égale ne raconte rien. Le petit éboulis n'a
pas de pente : c'est un affleurement, un bloc et deux éclats à son pied.

Et c'est là le point qui a demandé une deuxième passe. **Trois pierres qui se
touchent font une chose ; trois pierres espacées font du bruit.** C'est parce que
les petites zones restent des scènes qu'on peut en mettre dans chaque parcelle
sans revenir au semis du début.

L'éboulis est deux fois plus fréquent que la ruine : c'est du terrain, et du
terrain il y en a partout.

**La répartition a dû être corrigée, et ça se mesure.** La version précédente ne
servait que trois parcelles sur dix, tirées indépendamment. Des points
indépendants s'agglutinent et laissent du vide ailleurs, ce qui est la loi des
grands nombres et non un mauvais réglage. Mesuré en jeu, dans un cadre de
1920 × 1080, et en marchant en ligne droite sur près de 20 000 px :

| | tirage indépendant | une zone par parcelle |
|---|---|---|
| pièces en champ, moyenne | 7,4 | 10,0 |
| vues sans aucune pièce | 16 sur 60 | 5 sur 60 |
| plus longue traversée sans rien | 4 840 px | 1 320 px |

Quatre mille huit cents pixels, c'est vingt secondes de marche sans rien croiser.

**Le point de départ est garanti.** Le joueur commence toujours à l'origine du
monde et il y regarde avant de bouger : la parcelle de l'origine porte donc
toujours une zone, ancrée à 380 px de lui plutôt qu'au hasard dans sa parcelle.
Assez loin pour ne pas être dans ses jambes, assez près pour être vue sans
marcher. La pièce la plus proche est à 277 px au lancement.

Le socle n'a pas changé : tout sort d'un **hachage des coordonnées de la
parcelle**, jamais d'un tirage au sort. Une parcelle revue redonne la même zone,
pierre par pierre, au pixel près, sans qu'on mémorise rien, et c'est infini par
construction. Seules les parcelles visibles portent des sprites, recyclés d'une
parcelle à l'autre.

Une conséquence à connaître avant de toucher aux générateurs : **l'ordre des
tirages fait partie de la définition du paysage.** Une zone se lit dans une suite
de nombres tirée du hachage, consommée dans l'ordre des appels. Sauter un tirage
dans une branche décalerait tout ce qui suit, donc les générateurs tirent toujours
le même nombre de fois par pièce, quelle que soit la branche prise. C'est pour ça
qu'on y voit des tirages faits puis ignorés.

Quatre décisions valent d'être retenues :

- **Aucune collision.** Dans un jeu où l'on lit le sol pour esquiver, un obstacle
  qui arrête le joueur sans arrêter ce qui le frappe serait une trahison.
- **Trié en Y avec les créatures**, donc le joueur passe derrière une colonne
  comme derrière un ennemi. Les zones annoncées et les projectiles vivent dans un autre
  conteneur, dessiné par-dessus : rien du décor ne peut les masquer.
- **Les créatures ne se trient pas sur leurs pieds**, et il a fallu le mesurer
  pour le voir. Leurs planches sont des frames de 100 × 100 où le dessin flotte
  au milieu : l'origine du nœud tombe à mi-corps et les pieds bien plus bas.

  | sprite | pieds sous l'origine |
  |---|---|
  | joueur | 37,5 px |
  | brute | 34,5 px |
  | cultiste | 27 px |
  | chien | 27,5 px |
  | imp | 21 px |

  Un décor trié sur sa base gagnait donc contre un joueur dont les pieds étaient
  visiblement plus bas que la pierre : le rocher lui passait devant sans raison
  visible. Le décor est donc dessiné **sa base 37,5 px sous son nœud**, la valeur
  du joueur, pour que « comparer les origines » revienne à comparer les points de
  contact. Déplacer les origines des créatures aurait décalé leurs collisions ;
  l'écart résiduel avec un imp vaut 16 px, un cinquième de corps.
- **Le tri en Y ne suffit pas**, et c'est la capture qui l'a montré. Une tour de
  gravats fait 171 px à l'écran et le joueur 84 : passer derrière elle ne le
  cachait pas à moitié, elle l'**avalait entièrement**, sans en laisser un pixel.
  Les pièces de plus de 20 px de source s'effacent donc à 35 % d'opacité quand le
  joueur est dans leur bande, en un fondu de 0,15 s — un basculement sec se
  remarquerait plus que l'occultation qu'il corrige. Le seuil vaut 20 parce que le
  dessin du joueur mesure 22 px : au-dessus, une pièce posée à ses pieds dépasse
  sa tête. Seuls le caillou et les dalles restent en dessous, et c'est heureux, on
  marche dessus sans arrêt.
- **Les deux lieux « bâtis » sont rares.** La colonnade et le sanctuaire pèsent 2
  contre 5 à l'éboulis : ils racontent trop pour être partout. Deux réglages de la
  colonnade viennent d'ailleurs d'une capture ratée — à un pas de 168 px, quatre
  pièces s'étalaient sur 670 px et l'œil ne les rattachait plus les unes aux
  autres ; et les dalles plates, posées à ce pas, lisaient comme des débris semés
  au hasard plutôt que comme des colonnes tombées. Pas resserré à 132 px, dalles
  rendues à l'éboulis.

Le contenu est de la pierre et de la terre cuite, plus trois buissons **passés à
la cendre** : la luminance de l'original est conservée (donc le modelé du pixel
art, qu'un simple filtre de teinte aplatirait) et reteintée en gris chaud. Quinze
pièces en tout, et chacune tient un **rôle** plutôt que d'attendre dans un sac
commun : mur, angle, cœur, sol, poterie, végétation, tête d'éboulis, gros, moyen,
petit débris.

Quatre d'entre elles sont bâties sur le même **socle de banc de pierre** du pack :
le banc nu, le banc chargé de gravats, celui surmonté d'une dalle levée, celui
surmonté d'une tour. Ce sont les pièces qu'on croise le plus puisqu'elles montent
les murs des ruines, et à pleine échelle la tour faisait 231 px contre 84 au
joueur, près de trois fois lui. Elles sont donc dessinées à l'échelle **2** et non
3. Deux, et pas 2,5 : c'est du pixel art, et à une échelle fractionnaire un pixel
sur deux serait deux fois plus large que son voisin. Le prix à payer est une
densité de pixels mélangée, ces quatre pièces étant plus fines que le reste du
décor ; l'entraxe des colonnes a été resserré de 115 à 95 px en conséquence, sans
quoi les murs ne se touchaient plus et cessaient de se lire comme des murs.

Deux retraits. Les quatre pièces de cimetière du pack (stèle, stèle haute, croix,
tombe gravée) sont **sorties du jeu** : le décor ne compose plus que des ruines et
des éboulis, où elles n'ont pas de place. Leurs rectangles de découpe restent en
commentaire dans [`tools/extract_assets.py`](tools/extract_assets.py), parce
qu'ils ne se retrouveraient pas autrement. Et le pack fournit aussi des caisses,
des tonneaux, des portes, un banc et des panneaux indicateurs gravés, hors sujet
dans un enfer, dont le texte serait de toute façon illisible à cette échelle.

## Effets visuels

### Les zones de boss font jaillir le sol

Une zone annoncée ne montrait que son flash dessiné à la détonation, et c'était
un choix défendable tant que la seule planche disponible était une bouffée
générique : huit zones qui partent ensemble n'ont pas besoin qu'on en rajoute.
Avec une planche d'impacts au sol, le calcul change — **un écrasement de colosse
de pierre doit faire jaillir la pierre**, et c'est le genre de chose qui
distingue un boss d'un autre sans toucher à une seule règle.

La planche compte cinq effets sur une grille de **17 × 5 cellules de 96 px**,
lus par rangée. Chacun va au boss dont il raconte l'attaque :

| Boss | Effet | Images | Pourquoi celui-là |
|---|---|---|---|
| **Golgota** | pic de pierre qui jaillit puis retombe en poussière | 51–67 | colosse de pierre, écrasements au sol, et un Calvaire où « sept croix jaillissent » |
| **Baal** | colonne de flammes qui laisse des pics calcinés | 34–50 | *Le Seigneur de l'Orage*, phase Fournaise, sillage de braise |
| **Asmodée** | roche qui éclate, sèche et brève | 1–11 | ses zones sont des points de chute de charge : un impact, pas un incendie |
| **Lucifer** | bloc de roche embrasé | 68–79 | la couronne de l'Aube brûlante |
| **Lilith** | **aucun** | — | sa seule zone annonce une téléportation et ne blesse personne |

**Une zone qui ne blesse pas n'a pas d'impact**, et c'est un garde-fou et non un
oubli : la zone de Lilith vaut 0 dégât. Y faire jaillir de la roche montrerait
un coup là où il n'y en a aucun — exactement le mensonge que toute la lisibilité
des boss cherche à éviter. `telegraph.gd` teste donc `damage <= 0`.

#### Le dessin fait la taille de la zone, et la mesure a dû être reprise

La mise à l'échelle vaut `rayon × 2 / largeur du dessin`, comme pour l'explosion
de Braise éternelle : le joueur voit la portée au lieu de la deviner. Encore
faut-il prendre la bonne largeur.

Prise sur l'**union** des images de la rangée — 90 px pour la pierre — elle
compte les gravats qui volent loin en fin d'animation, donc elle fait paraître
le pic **plus petit que sa zone** pendant tout le reste du temps. Prise sur
l'**image de pointe**, celle qui couvre le plus de surface, le dessin remplit la
zone au moment où on le regarde :

| Effet | Union | Image de pointe | Retenu |
|---|---|---|---|
| Pierre | 90 px | 75 px | **75** |
| Flamme | 83 px | 79 px | **79** |
| Roche | 88 px | 79 px | **79** |
| Braise | 58 px | 52 px | **52** |

Vérifié en jeu sur l'écrasement de Golgota : échelle 3,33, **250 px dessinés
pour un rayon de 125** — le pic touche les deux bords du disque.

L'échelle n'est **pas entière**, et c'est une exception assumée sur une planche
de pixel art. Les cas où le projet l'interdit sont des images qu'on regarde
fixement — icônes d'objets, titre, décor. Un impact passe, et faire
correspondre le dessin au rayon qui blesse est la promesse la plus forte des
deux.

#### L'impact remplace le flash de la zone

Le disque blanc de la détonation existait parce qu'il n'y avait rien d'autre à
montrer. Par-dessus un pic de pierre qui remplit la zone, il ne dit plus rien et
**délave le dessin qu'il recouvre**. La zone se retire donc dès qu'un effet
prend le relais — vérifié en jeu : au moment où l'impact paraît, il ne reste
**zéro** zone détonée à l'écran.

#### Les pics de Golgota ont la couleur de Golgota

La planche est d'un sable clair (146 / 113 / 72 en moyenne) et Golgota est une
pierre sombre à reflet violacé. Un pic sable qui jaillit sous ses pieds ne
venait de nulle part.

La teinte est **mesurée, pas choisie**, et sur les faces ÉCLAIRÉES plutôt que
sur la moyenne : la moyenne de Golgota inclut tout son ombrage (44 / 35 / 39),
et viser ce chiffre-là aurait amené les pics **sous la luminosité du sol**
(48 / 52 / 55) — invisibles au moment où ils comptent. Sur le quart le plus
clair de chaque image, lave exclue, Golgota vaut 87 / 71 / 76 et le pic
188 / 147 / 87, d'où un `modulate` de **0,46 / 0,48 / 0,87**. Les pics prennent
sa pierre et restent lisibles sur le sol.

#### La dernière image se tient, puis s'éteint

Une planche d'impact se termine sur son état final — la poussière retombée, les
pics calcinés — et disparaître à l'image suivante efface ce que l'animation
venait d'établir : le sol redevient intact en un dixième de seconde, comme si
rien ne s'était passé.

La dernière image est donc **tenue 1,45 s**, dont **0,45 s de fondu** : une
seconde pleine où le sol reste brisé, puis l'extinction. Essayée à 0,45 s, la
tenue passait encore pour la fin de l'animation plutôt que pour une trace.

Le fondu n'est pas un ornement : une tenue suivie d'une disparition sèche
remplace un défaut par un autre, la dernière image sautant au lieu de s'éteindre.

Un impact vit donc **1,73 s** en tout. Golgota enchaîne deux écrasements toutes
les 1,7 s en phase 2 : les traces se chevauchent, et c'est le comportement voulu
— un sol que le colosse a déjà brisé ne redevient pas intact entre deux coups.

#### Golgota frappe deux fois moins vite que les autres

Son impact joue à **30 images par seconde** là où les trois autres sont à 60,
soit **0,53 s** d'animation au lieu de 0,28. À 60 la pierre jaillissait d'un
coup sec puis se figeait 1,45 s : le contraste entre une éruption brève et une
trace longue faisait paraître l'animation pressée, ce qu'elle était.

C'est aussi ce que son identité demande. Golgota est « lent, écrasant », il se
déplace à 42 quand Lilith va à 140 : sa pierre n'a aucune raison de jaillir à la
vitesse d'une flamme. Les trois autres gardent 60 — le feu de Baal, la roche
sèche d'Asmodée et la braise de Lucifer sont des événements brefs.

Mesuré en jeu : **0,53 s d'animation, 1,50 s de tenue, 2,03 s en tout.**

**Et la première mesure disait 1,00 s d'animation.** Le banc enregistrait une
capture d'écran au milieu de la boucle de chronométrage : écrire un PNG de
3440 × 1440 bloque le jeu environ six dixièmes de seconde. L'horloge murale
avançait, `_time` du nœud non — c'est la comparaison des deux qui l'a montré,
et rien dans le jeu n'était ralenti. **On ne capture pas dans une mesure de
temps.**

`hold_time` et `hold_fade` valent **0 par défaut** : l'explosion de Braise
éternelle et l'animation de mort se terminent sur du vide, elles n'ont rien à
tenir et leur comportement ne change pas.

#### Chaque boss joue la planche à sa façon

Quatre boss tirent leur impact de la même planche, et rien ne les distinguait
au-delà de l'effet choisi : huit zones lancées ensemble affichaient huit fois le
même dessin, à la même orientation, dans le même sens. Trois réglages y
répondent, un par boss, et **aucun ne coûte quoi que ce soit en jeu**.

**Asmodée — un miroir une fois sur deux.** Ses zones sont des points de chute de
charge et elles tombent par paquets ; deux éclats de roche côte à côte se
lisaient comme un copier-coller. `random_flip` était à `false` sur les quatre
impacts, sans raison écrite. Il passe à `true` chez lui seul : le dessin est
assez asymétrique pour que le retournement se voie, et la lumière de la planche
vient d'en haut, donc la miroiter ne la contredit pas.

**Lucifer — une orientation au hasard.** Son embrasement projette ses débris
dans toutes les directions : c'est le seul des quatre qui n'a **ni haut ni bas**
à trahir. La rotation lui est donc réservée — sur un pic de pierre planté dans
le sol, elle ferait basculer la face éclairée et mentirait.

Deux pièges, tous deux mesurés plutôt que devinés :

- `offset` place le dessin par rapport au point touché, et il **tourne avec le
  nœud**. Sans contre-rotation, l'éclat décrirait un cercle autour du point
  d'impact au lieu de rester dessus. Il est donc contre-tourné du même angle.
- Son `offset` valait `(0, -13)`, hérité d'un alignement au sol, alors que le
  centre du dessin est à `(-1, -4)` de celui de la cellule : l'éclat paraissait
  **78 px trop haut** à l'échelle où il est joué, soit les deux tiers du rayon
  de la zone. Ça ne se voyait pas tant qu'il tombait toujours de travers de la
  même façon ; une orientation au hasard l'a rendu évident. Corrigé à `(0, 4)`,
  l'éclat est centré sur le cercle qui blesse.

**Golgota — la planche se joue à l'envers**, de la dernière image vers la
première. Sa rangée est la seule des quatre qui se **dissipe** : les trois
autres se terminent sur de la pierre plantée ou des pics calcinés, la sienne
finit en poussière emportée. Mesuré sur la couverture alpha de chaque cellule,
sur les 9 216 pixels d'une image :

| Image | 62 | 63 | 64 | 65 | 66 | 67 |
|---|---|---|---|---|---|---|
| Pixels opaques | 885 | 583 | 293 | 111 | 20 | **1** |

La dernière image est **vide**. La tenue de 1,45 s ajoutée pour que le sol ne
redevienne pas intact entre deux coups ne tenait donc **rien** chez Golgota :
elle prolongeait une cellule transparente. Lue à l'envers, la même planche
raconte la poussière qui se rassemble en pic, et surtout elle se termine sur la
**pierre plantée** (1 459 pixels) — la tenue tient enfin quelque chose.

La teinte n'a pas eu à bouger : recalculée sur l'image désormais tenue, elle
donne 0,460 / 0,478 / 0,873 contre 0,46 / 0,48 / 0,87 en place, et le pic rend
87 / 71 / 76 à l'écran contre 87 / 74 / 78 mesurés sur la capture — la couleur
de la pierre de Golgota, comme prévu.

**Ce que ça coûte à la lisibilité, et c'est assumé :** les cinq premières images
jouées sont celles qui étaient les dernières, donc les plus vides. Pendant
**0,17 s** après le coup, il ne reste que de la poussière éparse pour marquer
l'endroit touché — le flash blanc de la zone, lui, a été retiré au patch
précédent puisque l'impact le remplace. Démarrer la lecture à l'image 62, voire
58 (une image de flash, qui marquerait le coup net), supprimerait ce trou.

### L'animation de mort — la même pour les cinq ennemis

Un ennemi tué disparaîssait dans la même image que son dernier éclair de
dégâts : rien ne distinguait « il est mort » de « il est sorti du champ », et
dans une mêlée de quarante corps c'est la seule information qui compte. Les
planches de mort des packs existaient sans être jouées ; celle-ci est **dessinée
pour le projet** — une âme qui se détache et monte — et sert aux cinq types.

Elle est jouée par [`sprite_effect.gd`](scripts/vfx/sprite_effect.gd), la même
brique que l'explosion : **8 colonnes sur 5 lignes, 40 cellules dont les 6
dernières sont vides**, donc les images 0 à 33 à 60 par seconde, soit 0,57 s. Le
vide de fin est mesuré sur la couverture alpha, pas supposé — les jouer ferait
vivre le nœud un dixième de seconde de plus sans rien afficher.

L'effet est monté **sur le conteneur** et non sur l'ennemi, qui est libéré dans
la foulée : enfant de lui, il partirait avec lui sans avoir affiché une seule
image. Sa position se pose **après** l'entrée dans l'arbre, parce qu'un nœud
hors arbre n'a pas de parent et que `global_position` n'y veut rien dire de
fiable. Et il reprend l'échelle du corps qui tombe : une élite (×1,35) meurt
plus grand qu'un imp, ce qui est gratuit et juste.

#### La planche était agrandie ×4, et ça coûtait 40 Mo de VRAM

Le fichier fait 4096 × 2560 pour **48 Ko sur disque** — il se compresse si bien
qu'on ne voit rien venir. Mais une texture ne vit pas compressée en mémoire :
4096 × 2560 × 4 octets font **40 Mo de VRAM**, pour un effet de mort.

La vérification tient en une mesure, et c'est la méthode déjà employée sur
`menu.jpg` : on cherche le pas du pixel en testant si les blocs de N×N sont
uniformes.

| Pas testé | 2 | 4 | 8 | 16 | 32 |
|---|---|---|---|---|---|
| Blocs uniformes | 100 % | **100 %** | 93,5 % | 81,5 % | 72,2 % |

C'est net à 4 et ça casse à 8 : la planche est du pixel art **agrandi ×4**, sa
résolution vraie est 1024 × 640. La réduction est donc **exactement sans perte**,
chaque bloc de 4×4 ne portant qu'une couleur.

Elle se fait à l'import (`process/size_limit = 1024`) et **non sur le fichier** :
le PNG reste celui qu'on a dessiné, on peut continuer à l'exporter en 4096
depuis son outil, et c'est le moteur qui le ramène. Vérifié en mémoire :
**1024 × 640, 2,5 Mo** au lieu de 40.

La cellule fait alors 128 px et le dessin 55 × 101, et le filtrage au plus
proche est le bon.

#### Une âme de la taille du corps, pas du double

À l'échelle 1, l'âme faisait **101 px pour un imp qui en mesure 40** : la mort
était plus grande que ce qui mourait, et deux morts côte à côte se recouvraient.
À **0,5** elle fait 51 px, soit la taille du corps — 68 px pour une élite, qui
garde son ×1,35.

**Un demi n'est pas une échelle fractionnaire au sens où le projet l'interdit.**
Ce qu'on s'interdit ailleurs — 2,5 sur une source de 16 px — donne des pixels de
largeurs INÉGALES, un sur deux deux fois plus large que son voisin. Un rapport de
1/2 est régulier : chaque pixel affiché vaut exactement deux pixels source,
partout dans l'image. Ce qu'on perd est du détail, pas de la régularité — et sur
une âme qui monte, du détail à 51 px, il n'y en a pas.

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

Les planches d'attaque et de blessure existent dans les packs et ne sont pas
encore jouées — le jeu signale les coups par un éclair de `modulate`. La MORT,
elle, a la sienne depuis : une planche propre au projet, commune aux cinq types,
décrite plus haut dans « L'animation de mort ».

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

Quatorze fichiers OGG Vorbis, dans `assets/audio/`. L'OGG est le seul
format qui reboucle sans trou : le MP3 porte dans sa définition un silence
d'encodeur en tête et en queue, qui s'entendrait à chaque reprise de la musique.

Contrairement aux sprites, ces fichiers **sont versionnés** : leur licence
n'interdit la mise à disposition que sous forme de banque de sons ou de pack
autonome (voir [`CREDITS.md`](CREDITS.md)). Un clone suffit donc pour avoir le
son. S'ils venaient à manquer, le jeu démarre quand même, muet, avec un
avertissement par fichier et aucune erreur.

### L'arène a six pistes, et elles s'enchaînent

Une run qui va loin dure plus de vingt minutes. Avec une seule piste de 4 min 26,
on l'entend donc quatre ou cinq fois — et on finit par l'entendre au sens où on
ne l'écoute plus. Les six pistes portent le total à **17 min 13 avant la
première répétition** : une run complète, ou presque, sans jamais réentendre la
même musique.

**L'ordre alterne les deux sources et les durées.** On entre dans la liste à un
rang tiré au sort puis on la suit : deux pistes voisines sont deux pistes qu'on
entendra l'une après l'autre à chaque run, quel que soit le point d'entrée.

| Rang | Piste | Durée |
|---|---|---|
| 1 | `MusicGameplay.ogg` | 4 min 26 |
| 2 | `alex-morgan-thrash-metal` | 3 min 02 |
| 3 | `MusicGameplay2.ogg` | 2 min 05 |
| 4 | `wolfdudedodi-cyber-wolf` | 3 min 24 |
| 5 | `strawberry_candy-powerful-heavy-metal` | 2 min 07 |
| 6 | `mrclaps-this-heavy-metal` | 2 min 09 |

#### Les niveaux ont dû être mesurés, pas supposés

Les fichiers ne sont pas masterisés ensemble : une piste 3 dB plus forte que la
précédente s'entend comme une erreur du jeu, pas comme un choix de l'album.
Mesuré en RMS sur trois fenêtres de 4 s prises à 15 %, 45 % et 75 % de chaque
piste (l'énergie d'un morceau n'est pas la même à l'intro et au refrain, une
fenêtre unique aurait mesuré le passage sur lequel elle est tombée) :

| Piste | RMS | Correction |
|---|---|---|
| `MusicGameplay.ogg` | −14,85 dB | référence |
| `MusicGameplay2.ogg` | −14,69 dB | référence |
| `mrclaps-this-heavy-metal` | −13,95 dB | **−0,9 dB** |
| `strawberry_candy-powerful-heavy-metal` | −14,63 dB | aucune |
| `wolfdudedodi-cyber-wolf` | −15,35 dB | aucune |
| `alex-morgan-thrash-metal` | −16,62 dB | **+1,8 dB** |

Les deux pistes d'origine sont la **référence** : c'est sur elles que tous les
volumes d'effets ont été réglés, les corriger déréglerait le reste du jeu.

**Seules les pistes qui s'écartent d'au moins 1 dB sont corrigées.** En dessous,
la correction ne s'entend pas et la table mentirait sur sa précision.

#### Le RMS ne suffisait pas : les six pistes ont été repesées en LUFS

Le RMS mesure une énergie, pas une sensation. Deux morceaux au même RMS ne
s'entendent pas au même volume si l'un est dense dans le médium et l'autre
aéré — et quatre des six pistes sont du metal, c'est-à-dire exactement le cas où
l'écart se creuse. La vérification s'est donc refaite en **LUFS pondéré K**
(ITU-R BS.1770 : plateau aigu +4 dB à 1 682 Hz, coupe-bas à 38 Hz, les deux
biquads calculés à la fréquence de mixage réelle), mesuré **à la sortie master**
plutôt que sur le fichier :

| Piste | LUFS | Écart |
|---|---|---|
| `mrclaps` | −32,20 | référence |
| `strawberry_candy` | −32,20 | 0,0 |
| `MusicGameplay` | −32,52 | −0,3 |
| `MusicGameplay2` | −33,06 | −0,9 |
| `wolfdudedodi` | −33,41 | −1,2 |
| `alex-morgan` | −33,66 | −1,5 |
| `MenuSoundMusic` | **−37,36** | **−4,8** |

Les six pistes d'arène tiennent dans **1,5 dB** : l'égalisation faite au RMS
résiste à la mesure perceptive, elle n'a pas eu à bouger.

**La piste du menu, elle, est 4,8 dB en dessous.** Passer du menu à l'arène est
donc une marche vers le haut. La corriger demanderait de la remonter, or ses
crêtes sortent déjà à +6,5 dBFS : elle monterait dans la saturation. Le point
reste ouvert et il se réglera sur le fichier, pas sur un gain.

#### Les fins de piste ont été vérifiées avant de garder la jointure nette

L'enchaînement se fait sans fondu, ce qui suppose que chaque piste se termine
sur une résolution. Mesuré par tranches de 0,5 s sur les trois dernières
secondes, aucune des quatre nouvelles ne s'arrête plus sèchement que les deux
d'origine : toutes finissent entre −14 et −27 dB, comme `MusicGameplay.ogg`
(−17,5 à −21 dB). La jointure garde donc le même comportement.

#### Deux fichiers déposés ne sont pas des musiques d'arène

Le dossier en contient six ; **quatre** entrent dans la liste.

- `43084433-hard-rock-logo-intro-335297.ogg` (13,8 s) est un générique de logo.
  Dans la rotation d'arène, il ferait changer la musique au bout de treize
  secondes. Il conviendrait en revanche au menu, dont l'unique piste de 15,5 s
  se répète quatre fois par minute.
- `freesound_community-rock-destroy-6409.ogg` (2,9 s) est un **effet**, pas une
  musique — de la roche qui se brise, ce qui tombe bien pour l'écrasement de
  Golgota, qui n'a aucun son propre.

Les deux restent sur le disque, hors de toute liste, en attendant une décision.

Elles s'**enchaînent** au lieu d'être tirées au sort à l'ouverture : un tirage par
run laisserait encore une seule piste tourner en boucle pendant toute la partie,
c'est-à-dire exactement le problème qu'on voulait régler. Seule la piste de
DÉPART est tirée au sort, parce que deux runs de suite qui commencent sur la
même musique s'entendent et que c'est gratuit à éviter.

**Le bouclage dépend du nombre de pistes, et il le faut.** Une liste à une seule
piste boucle nativement, sans trou — indispensable au menu, dont la piste ne dure
que 15,5 s et dont la reprise s'entendrait quatre fois par minute. Une liste à
plusieurs pistes ne boucle **pas** : c'est le signal `finished` qui enchaîne, et
il ne se déclenche jamais sur un flux bouclé. Le réglage est posé dans le code et
non dans le fichier `.import`, donc il ne peut pas être perdu par un réimport.

Deux détails qui décident du fonctionnement :

- **Sans fondu entre deux pistes**, et ce n'est pas une économie : les deux se
  terminent sur une résolution, donc l'enchaînement est une fin suivie d'un
  début. Un fondu superposerait une fin et un début, ce qui s'entend beaucoup
  plus qu'une jointure nette.
- **C'est le lecteur ACTIF qui enchaîne**, et lui seul. Il y en a deux, pour le
  fondu enchané entre musiques ; celui qui vient d'être coupé émet lui aussi
  `finished`, et sans ce test il relancerait la musique d'arène par-dessus celle
  du menu. Vérifié : appeler l'enchaînement sur le lecteur dormant ne change
  rien.

| Sonde | Attendu | Mesuré |
|---|---|---|
| Pistes d'arène chargées | 6 | **6**, 17 min 13 au total |
| Correction de niveau appliquée | 2 pistes sur 6 | +1,8 dB et −0,9 dB, les autres à 0 |
| Bouclage des pistes d'arène | non | `loop = false` |
| Bouclage du menu | oui | `loop = true` |
| Fin de piste | passe à la suivante et joue | 3 → 4 → 5 → 0, flux changé, en lecture |
| Fin sur le lecteur coupé | ignorée | flux inchangé |

### Le curseur de musique ne descendait pas

Remonté en jeu : **la musique reste trop forte même en bas de la barre.** Deux
causes, toutes deux mesurées, et aucune des deux n'est le choix des pistes.

#### Le curseur était une amplitude, pas un volume

La valeur du curseur partait telle quelle en amplitude — `linear_to_db(v)`, soit
20 log v. Le bas de la course n'y descend presque pas : le dernier cran avant la
coupure vaut **−26 dB**, le précédent −20 dB. Quelqu'un qui trouve la musique
trop forte à ce cran-là n'a plus rien entre lui et le silence complet.

Le curseur est donc **mis au carré** — 40 log v. Le haut de la course ne bouge
pas, le bas descend vraiment :

| Cran | 0,05 | 0,10 | 0,20 | 0,35 | 0,50 | 0,70 | 1,00 |
|---|---|---|---|---|---|---|---|
| Avant | −26,0 | −20,0 | −14,0 | −9,1 | −6,0 | −3,1 | 0 |
| Après | −52,0 | −40,0 | −28,0 | −18,2 | −12,0 | −6,2 | 0 |

**Les deux curseurs suivent la même règle.** Deux réglages côte à côte qui ne
réagiraient pas pareil seraient pires que le défaut d'origine.

**Un réglage déjà enregistré change donc de sens** : un 0,10 qui donnait −20 dB
en donne −40. C'est voulu — c'est la plainte — mais il faut le savoir : il faut
remonter le curseur vers 0,40 pour retrouver l'ancien niveau, et tout ce qui est
en dessous est maintenant atteignable, ce qui n'était pas le cas.

#### À fond, la musique saturait

Mesurées à la sortie, les crêtes des pistes décodées vont de **+5,9 à
+8,1 dBFS** : ce sont des masterings modernes, limités très haut. Curseur à
fond, elles sortaient du master entre **+3,2 et +5,4 dBFS**, donc écrêtées — et
une crête écrêtée ne s'entend pas comme du volume, elle s'entend comme une
déformation. C'est une partie de ce que « trop fort » désignait.

La musique garde donc **8 dB de garde** (`MUSIC_HEADROOM`), mesurés pour que la
pire crête des sept fichiers repasse sous 0 dBFS. Vérifié après coup, curseur à
fond, sur la piste la plus crêtée : **−3,67 dBFS** de crête contre +5,4 avant,
pour −22,25 dBFS de RMS.

Le défaut du curseur passe de 0,70 à **1,00** : le haut de la course est
désormais le niveau de référence, calibré et sans saturation. À l'oreille le
réglage par défaut ne change donc pas (−22,3 contre −20,6 dBFS), c'est le reste
de la course qui devient utilisable.

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

Les musiques d'origine restent sous `SoundEffects/`, avec le `LICENSE.txt` qui
les couvre : les déplacer pour faire joli casserait cette piste-là. Les musiques
ajoutées depuis vivent sous `Music/`. Le chemin est donc écrit en entier dans la
liste plutôt que deviné à partir d'un dossier unique.

| Fichier | Durée | Rôle |
|---|---|---|
| `SoundEffects/MusicGameplay.ogg` | 4 min 26 | musique d'arène, rang 1 |
| `Music/alex-morgan-thrash-metal…` | 3 min 02 | musique d'arène, rang 2 |
| `SoundEffects/MusicGameplay2.ogg` | 2 min 05 | musique d'arène, rang 3 |
| `Music/wolfdudedodi-cyber-wolf…` | 3 min 24 | musique d'arène, rang 4 |
| `Music/strawberry_candy-powerful…` | 2 min 07 | musique d'arène, rang 5 |
| `Music/mrclaps-this-heavy-metal…` | 2 min 09 | musique d'arène, rang 6 |
| `Music/43084433-hard-rock-logo-intro…` | 13,8 s | déposé, **inutilisé** |
| `Music/freesound_community-rock-destroy…` | 2,9 s | déposé, **inutilisé** |
| `SoundEffects/MenuSoundMusic.ogg` | 15,5 s | musique des menus, en boucle |
| `Fireball.ogg` | 8,04 s | tir du joueur, coupé à 0,5 s |
| `BigRoar.ogg` | 5,09 s | apparition d'un boss |
| `chooseUpgradeSound.ogg` | 1,37 s | objet obtenu, nœud de Forge débloqué |
| `smallRoar1sec.ogg` | 0,84 s | mort d'un ennemi |
| `StoneSoundForButtonMenuSelect.ogg` | 0,47 s | clic d'interface |

Deux évènements n'ont pas encore de son faute de fichier : **le joueur qui
encaisse un coup** et **l'âme ramassée**. Ce sont les deux premiers à ajouter.

## Mode développement

`F12` **ou** `Ctrl+Shift+D` dans l'arène ouvre un panneau derrière un mot de
passe. Il sert à voir du contenu sans le mériter : sauter à n'importe quelle
vague, faire apparaître un boss, s'offrir le catalogue, se rendre invulnérable,
régler la vitesse du jeu. Deux touches parce que les rangées de F sont
capricieuses selon les claviers portables, où elles demandent parfois `Fn`.

**Il n'existe que dans l'arène**, pas dans le menu principal : tout ce qu'il
pilote n'a de sens qu'en partie.

Il s'ouvre **par-dessus n'importe quel autre écran**, et c'est une exception
assumée. Le menu de pause et la fiche de run refusent de s'ouvrir quand un autre
écran détient déjà la pause, sinon les refermer relancerait la partie alors que
la boutique est encore affichée. Ce panneau a d'abord suivi la même règle et
c'était une erreur : il devenait muet pendant la sélection de malédiction et dans
la boutique, c'est-à-dire précisément là où l'on veut sauter des vagues. Il rend
donc la pause telle qu'il l'a trouvée — ouvert depuis la boutique, le refermer
laisse la boutique en pause ; ouvert en pleine action, le refermer relance.

**Le mot de passe n'est pas une sécurité, et il ne faut pas se raconter le
contraire.** Le jeu tourne sur la machine du joueur : qui sait ouvrir un `.pck`
trouvera de quoi le contourner, et l'empreinte stockée ne résiste pas à une
attaque par dictionnaire sur un mot courant. C'est un **verrou contre la
curiosité**, il empêche d'ouvrir le panneau par accident ou par jeu.

### La vraie protection, c'est de ne pas livrer le panneau

Depuis la 0.6.4, le build destiné aux joueurs **ne contient pas le panneau** :
ni son code, ni ses libellés, ni l'empreinte du mot de passe. Il y a trois
préréglages d'export, et un seul le garde.

| Préréglage | `custom_features` | `dev_screen.gd` |
|---|---|---|
| Windows Desktop | — | exclu |
| Web | — | exclu |
| Windows Desktop (dev) | `dev_panel` | inclus |

Ça n'a été possible qu'en **retirant le nœud de la scène**. Une référence
statique dans [`main.tscn`](scenes/main/main.tscn) aurait obligé le script à
rester dans le paquet de tout le monde : sans lui, la scène de l'arène ne se
serait plus chargée du tout. Le panneau est donc monté depuis
[`main.gd`](scripts/main.gd), derrière **deux conditions redondantes** — un
indicateur d'export `dev_panel`, et l'existence du fichier. Si l'un des deux se
trompe un jour, un indicateur oublié ou un filtre mal écrit, l'autre empêche le
plantage ou la fuite. Une troisième condition, `editor`, couvre le jeu lancé
depuis les sources : on n'exporte pas un build rien que pour vérifier une vague.

**Vérifié en comparant les deux paquets**, et non en le supposant : les deux
exports diffèrent de **deux fichiers exactement**, `dev_screen.gdc` et
`dev_screen.gd.remap`, 386 fichiers contre 388. Rien d'autre ne change.

Il reste une trace dans le build joueur, et autant la nommer : le **chemin**
`res://scripts/ui/dev_screen.gd` figure encore dans l'index d'UID que le moteur
empaquette. C'est une ligne de table, pas du code — le fichier auquel elle
renvoie n'est pas là.

C'est une **empreinte SHA-256** qui est stockée, pas le mot : une chaîne en clair
dans l'exécutable se lit avec n'importe quel éditeur hexadécimal, donc sans même
chercher. Pour en changer :

```bash
python -c "import hashlib;print(hashlib.sha256(b'nouveau').hexdigest())"
```

Le déverrouillage vaut pour la **session**, pas pour le profil : relancer le jeu
redemande le mot. Un dossier de sauvegarde ne doit pas garder trace de qui a
triché.

### Ce que le panneau touche, et ce qu'il ne touche pas

Tout est **dans la run** sauf une section, séparée et signalée en rouge : les
deux boutons de Forge écrivent dans le profil actif. Débloquer est additif et se
rattrape ; réinitialiser ne se rattrape pas, donc il demande un second clic dans
les trois secondes. Le conseil qui vaut mieux que les deux : utiliser un profil
dédié, les emplacements existent pour ça.

### Deux crochets dans le code de production

Le panneau ne pilote pas le jeu par des méthodes privées. Deux fonctions ont été
ajoutées, nommées pour qu'un `grep dev_` les retrouve toutes :

- `WaveManager.dev_jump_to_wave` efface les ennemis en place et démarre la vague
  demandée. Il court-circuite la fin de vague : ni aspiration des âmes, ni
  boutique, ni récompense. On saute pour **voir** une vague, pas pour la gagner.
  Un boss en cours est annoncé mort avant d'être effacé, sans quoi sa barre de
  vie resterait à l'écran.
- `SaveGame.dev_lock_ids` reverrouille une liste explicite d'identifiants. Il ne
  vide jamais le registre en entier : objets et nœuds de Forge le partagent, et
  réinitialiser la Forge ne doit pas reverrouiller les objets gagnés en jouant.

L'invulnérabilité, elle, vit dans [`health.gd`](scripts/components/health.gd) et
non dans le panneau : c'est le seul endroit où tout ce qui blesse passe, y
compris ce qui contourne `take_damage`.

## Livrer une version

Les modèles d'export de Godot 4.6.2 sont installés (Windows, Linux, macOS, Web,
Android, iOS), et [`export_presets.cfg`](export_presets.cfg) déclare trois
préréglages prêts à l'emploi.

```bash
godot --headless --export-release "Windows Desktop" build/windows/Infernum.exe
godot --headless --export-release "Web" build/web/index.html
godot --headless --export-release "Windows Desktop (dev)" build/windows-dev/Infernum.exe
```

Les deux premiers sont **pour les joueurs** et excluent le panneau de
développement ; le troisième le garde et porte l'indicateur `dev_panel`. La
section « Mode développement » dit ce que cette séparation garantit, et comment
elle a été vérifiée.

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

- **Licences.** Récapitulées dans [`CREDITS.md`](CREDITS.md). Les cinq packs
  autorisent l'usage commercial dans un jeu et interdisent la redistribution des
  assets. **Distribuer le jeu exporté est conforme** — c'est le cas d'usage
  explicitement prévu.
- **Dépôt public.** C'est l'autre face de la même clause : « ni redistribution ni
  ré-upload, modifiés ou non ». Ni les packs ni les planches qu'on en tire ne
  sont donc versionnés — seuls le sont le code, les scènes, les réglages, et
  l'art propre au projet (les deux carreaux de sol, le sprite de Caïn fait main). Tout
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
- **Version.** `config/version` est à `0.8.2`, repris dans les métadonnées de
  l'exécutable. À incrémenter à chaque livraison — il était resté à `0.1.0` dans
  ce paragraphe pendant six versions, ce qui est exactement ce qu'une note « à
  incrémenter » finit par devenir si personne ne la relit.

## Étendre

- **Un objet statistique** : une entrée dans `ITEMS` de `item_database.gd`. Les clés de
  `mods` sont celles de `PlayerStats.add_mod()`. Respecter la règle 4 ci-dessus.
- **Un objet à effet** : ajouter un `special` et le gérer dans `item_effects.gd` —
  et lui donner une borne explicite.
- **Une arme** : dupliquer le nœud `Weapon` sous `Player/Weapons`, changer
  `projectile_scene`. Le `TargetingSystem` et les stats sont injectés automatiquement.
- **Un ennemi** : sous-classer `enemy.gd` et surcharger `_update_movement()` pour un
  nouveau comportement (ou juste une scène avec d'autres exports pour une variante de
  stats), puis lui ajouter une entrée dans `scenes/main/enemy_roster.tres` avec sa
  vague d'apparition, son poids et sa dérive. Les tests des vagues vérifient le
  nombre de types : les mettre à jour.
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
