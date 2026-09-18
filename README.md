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

| Courbe | Formule | Note |
|---|---|---|
| Durée | `20 s + 2 s × (vague-1)`, max 45 s | |
| Densité | `0.8 + 0.19 × (vague-1)` spawn/s, max 6 | |
| PV ennemis | `× (1 + 0.10 × (vague-1))`, **+0.16/vague à partir de la 16** | additif ; la seconde pente fait retomber la marge en fin de run |
| Dégâts ennemis | `× (1 + 0.095 × (vague-1))` | la seule courbe qui rend la fin de run dangereuse |
| Vitesse ennemis | `× (1 + 0.015 × (vague-1))`, max ×1.35 | |
| Élites | à partir de la vague 4, jusqu'à 18 % (31,5 % avec options) | PV ×4, **dégâts ×1,35**, âmes ×2, 2 % de clé, 8 % de soin |
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
`spawns_per_second_growth` (0.22) et `health_growth` (0.14) dans `wave_manager.gd`.

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
vu de dessus — et le titre est composé en **Alagard**, une police pixel.

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

Le titre est en **112 px**, un multiple de 16 : Alagard est dessinée sur une
grille de 16 px, et une taille non multiple ferait tomber ses traits entre deux
pixels. Pour la même raison, son import coupe le **lissage**, le **hinting** et
le **positionnement sous-pixel** — trois réglages faits pour les polices
vectorielles, et qui ne savent qu'abîmer une police pixel.

Les quatre sous-écrans posent leur propre voile à 92 %, ce qui laisse deviner le
gouffre derrière eux sans jamais disputer la lecture.

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
| Boutique | 880 × 706 | 445 à 514 / **560** |
| Objets (colonne de gauche) | 330 × 706 | 642 pour 9 objets / 632 — elle défile, et c'est normal |
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
| Passif | **La Marque** : +1 % de dégâts par élimination dans la vague, plafonné à **+25 %**, remis à zéro à chaque vague | **La Patience** : 0.9 PV/s, mais seulement après **4 s sans être touché** | **Ne pas se retourner** : **+20 % de cadence** tant qu'il se déplace, et la **RUÉE** (Espace / A) — 240 px à travers les corps, toutes les 2,2 s |

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

Leurs PV **suivent la vague** (`× (1 + 0.09 × (vague − 5))`, dégâts `× (1 + 0.04 × …)`).
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
`get_health_multiplier()`. C'est voulu : leur difficulté est celle de leur
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
et `DEGATS_DECHAINES` dans [`wave_manager.gd`](scripts/systems/wave_manager.gd)
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
| **Fer** | Braise de forge → Trempe / Mécanisme huilé → Fil rasoir → Acier noir | +12 % dégâts, +5 % cadence, +4 % crit |
| **Chair** | Cuir cousu → Plaques rivetées / Souffle lent → Carcasse épaisse → Écaille de forge | +18 PV, +16 armure, +0.3 PV/s |
| **Cendre** | Braises tièdes → Pas léger / Appel des âmes → Augure → Coffre de forge | +8 % âmes, +4 % vitesse, +40 % ramassage, +1 chance, 60 âmes au départ |

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

Huit fichiers OGG Vorbis, dans `assets/audio/SoundEffects/`. L'OGG est le seul
format qui reboucle sans trou : le MP3 porte dans sa définition un silence
d'encodeur en tête et en queue, qui s'entendrait à chaque reprise de la musique.

Contrairement aux sprites, ces fichiers **sont versionnés** : leur licence
n'interdit la mise à disposition que sous forme de banque de sons ou de pack
autonome (voir [`CREDITS.md`](CREDITS.md)). Un clone suffit donc pour avoir le
son. S'ils venaient à manquer, le jeu démarre quand même, muet, avec un
avertissement par fichier et aucune erreur.

### L'arène a deux pistes, et elles s'enchaînent

Une run qui va loin dure plus de vingt minutes. Avec une seule piste de 4 min 26,
on l'entend donc quatre ou cinq fois — et on finit par l'entendre au sens où on
ne l'écoute plus. La seconde piste (2 min 05) porte le total à **6 min 31 avant
la première répétition**.

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
| Pistes d'arène chargées | 2 | **2** (266 s et 125 s) |
| Bouclage des pistes d'arène | non | `loop = false` |
| Bouclage du menu | oui | `loop = true` |
| Fin de piste | passe à l'autre et joue | piste 1 → 0, flux changé, en lecture |
| Fin sur le lecteur coupé | ignorée | flux inchangé |

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
| `MusicGameplay.ogg` | 4 min 26 | musique d'arène, 1re piste |
| `MusicGameplay2.ogg` | 2 min 05 | musique d'arène, 2e piste |
| `MenuSoundMusic.ogg` | 15,5 s | musique des menus, en boucle |
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
- **Version.** `config/version` est à `0.8.0`, repris dans les métadonnées de
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
