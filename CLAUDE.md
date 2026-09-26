# Instructions de travail — Infernum

Roguelite d'action top-down en français (thème enfer / démons), **Godot 4.6.2**.
Dépôt GitHub **privé** `sinixjoseelmejor-bit/Infernum`, branche `main`.

## À lire avant toute chose

- **[README.md](README.md)** est le document de **conception**, pas un fichier
  d'installation. Il contient le raisonnement et **toutes les mesures** derrière
  chaque réglage : équilibrage, économie des âmes, Forge, boss, arène, décor,
  audio. **Ne jamais refaire une mesure qui y est déjà écrite.**
- **[CREDITS.md](CREDITS.md)** — licences des sept packs sources.

Toute mesure nouvelle, toute décision et toute erreur corrigée se **reporte dans
le README**, dans la section concernée. C'est la mémoire du projet.

## Règles de travail

- **Ne jamais commit ni push sans permission explicite**, à chaque fois.
- **Aucune mention de Claude / Anthropic** comme co-auteur, nulle part : ni dans
  les messages de commit, ni dans les PR, ni dans les releases, ni dans le code.
- **Messages de commit en ASCII sans accents.** Titres et corps des **PR** et des
  **releases** en **français accentué**.
- Les résumés (PR, notes de version) parlent de ce qui change **pour le joueur**,
  et **pourquoi** — pas de comment c'est implémenté.
- **Pas d'estimations de durée.**
- En investigation : être **critique et pessimiste**. Vérifier qu'un code est
  réellement **atteignable** et que ses **conditions** sont réunies avant de
  désigner un coupable. Ne pas conclure sur le premier suspect.
- Vérifier que la branche n'a pas changé ou n'est pas éditée en parallèle avant
  d'implémenter.

## Discipline de mesure

C'est la culture du projet et elle a de la valeur : plusieurs intuitions se sont
révélées fausses ici, et les erreurs sont documentées dans le README.

- **Mesurer avant de changer, remesurer après.**
- Un banc d'essai est un **script temporaire** enregistré en autoload `Banc` dans
  `project.godot`, puis **SUPPRIMÉ avec son script** une fois la mesure faite.
- Un banc attend sur le **TEMPS** (`create_timer`), **jamais sur des frames** :
  le jeu tourne à ~170 fps en fenêtré.
- Pour mesurer un coût **par image**, **désactiver la vsync** — sinon tout se
  vaut.
- **Ne jamais prendre une capture d'écran DANS une boucle de chronométrage.**
  Enregistrer un PNG de 3440 × 1440 bloque le jeu ~0,6 s : une animation de
  0,53 s a été mesurée à 1,00 s pour cette seule raison. En cas de doute,
  comparer l'horloge murale au temps que le NŒUD a vécu — s'ils divergent, c'est
  le banc qui bloque, pas le jeu qui rame.
- Les `Array` et `Dictionary` déclarés en `const` sont en **lecture seule à
  l'exécution** dans Godot 4 : impossible de les patcher en mémoire pour un A/B.
  Il faut éditer le fichier.
- Un banc qui décrit un cercle et n'esquive jamais **joue mal Loth**, dont tout
  l'intérêt est d'éviter les coups, et **surestime** le temps que Job passe au
  contact. Les effets ponctuels se vérifient en déclenchant leur événement à la
  main, pas en lisant un total de run.
- Une seule run ne prouve rien : le tirage d'objets domine tout le reste
  (1,22 puis 0,42 à la vague 15 pour la même configuration). **Moyenner.**
- **Le joueur tire tout seul.** Un banc qui compte des ennemis — arrivés,
  coincés, survivants — le désarme d'abord (`%Weapons`, `CharacterEffects`,
  `ItemEffects`) : sans ça, chaque ennemi abattu en route fausse le compte. Le
  premier banc de contournement de la carte l'a appris à ses dépens.

### Sauvegardes

Elles vivent dans
`C:\Users\josel\AppData\Roaming\Godot\app_userdata\Infernum\`.

**En faire une copie avant tout banc.** Si le fichier diffère à la fin,
**COMPARER avant de restaurer** : ça peut être la partie du joueur, pas le banc.
Et avant d'accuser le banc, vérifier que le code lancé PEUT écrire la clé qui
diffère : `last_character` n'est écrit que par l'écran de choix du personnage,
qu'aucun banc ne traverse — une fois, il avait changé parce que le joueur avait
choisi Caïn dans le menu, et une restauration hâtive l'aurait effacé.

## Godot

Binaire :
`C:\Users\josel\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`

```bash
godot --headless --path . --import
godot --headless --path . --export-release "Windows Desktop"
godot --headless --path . --export-release "Web"
godot --headless --path . --export-release "Windows Desktop (dev)"
godot --headless --path . res://tools/test_waves.tscn
godot --headless --path . res://tools/test_carte.tscn
```

- L'avant-dernière ligne lance les **tests des vagues** (courbes, boss, roster,
  moisson), code de sortie 0 si tout passe. À relancer après toute retouche de
  `scripts/systems/wave_manager.gd` ou de `scripts/systems/waves/`.
- La dernière lance les **tests de la carte** : règles de jouabilité et de
  composition sur 6 480 parcelles, poches fermées, part de lave à l'écran. À relancer après toute
  retouche de `scripts/world/`. Il demande les planches extraites.
- **Toujours sous `timeout`.** Une erreur de compilation dans le script d'une
  scène de test laisse Godot ouvert au lieu de quitter : sans garde-fou, on
  attend un test qui n'a jamais tourné.

- Les deux premiers préréglages sont **pour les joueurs** et **excluent le
  panneau de développement**. Le troisième le garde et porte l'indicateur
  d'export `dev_panel` (touche `F12` ou `Ctrl+Shift+D` en jeu).
- Le panneau dev **ne doit jamais retourner dans une scène** : il est monté
  depuis `main.gd` derrière deux conditions redondantes. Une référence statique
  dans `main.tscn` forcerait son script dans le paquet de tout le monde.
- Lancer **sans `--headless`** (fenêtré) pour les captures d'écran.

## Le Déchaînement, et à quoi il sert

C'est un **défi de classement** : on y pousse aussi loin qu'on peut, **plus rien
n'est plafonné** côté joueur, et c'est le sens de la Clé des Abysses. Deux
règles en découlent, à respecter dans tout ce qui touche à ce mode :

- **Ne rien replafonner côté joueur.** La seule borne qui survit est la
  réduction de dégâts de l'armure (90 %), et elle plafonne le TEMPS DE JEU, pas
  la puissance : à 99 % le joueur est immortel et la run ne finit jamais.
- **Tout ce qui résiste au joueur suit la même courbe**, boss compris. Un mode
  où l'on mesure une limite ne peut pas comporter une vague où l'on se repose.

## Points ouverts

- **Licences à confirmer avant toute diffusion publique** : l'illustration
  **menu.jpg**, et **MusicGameplay2.ogg**, déposée dans le dossier audio sans
  qu'on sache si le `LICENSE.txt` du lot la couvre. Les quatre musiques de
  `assets/audio/Music/` et la planche `vfx-Sheet.png` sont dans un autre cas :
  elles ont été annoncées libres au téléchargement ou à l'achat, **sans fichier
  de licence joint** — c'est la page d'origine qui fait foi.
- **Un fichier audio déposé et inutilisé** : un générique de logo de 13,8 s
  (irait au menu). La roche brisée sert à Golgota depuis la 0.9.1.
- **La planche des touches clavier** (`assets/packs/Touches/`, 0.9.1) n'a ni
  nom de pack ni licence consignés : à renseigner dans CREDITS avant une
  diffusion publique.
- **Les 26 effets de `Sfx/` n'ont pas leurs sources consignées** (CREDITS) :
  lien et licence par fichier, avant une diffusion publique. Leur MIX n'est
  réglé que sur les crêtes mesurées, pas à l'oreille.
- **Un verbe par personnage, les trois sont faits** : Loth traverse (la ruée),
  Caïn dépense sa Marque (le Prix du sang), Job pare (le Refus de plier,
  qui charge son Jugement de paladin depuis la 0.9.0). Trois
  règles à ne pas casser en y touchant : pas de seconde source
  d'invulnérabilité, pas d'effet proportionnel aux dégâts SUBIS (le
  Déchaînement les fait exploser), et **rien ne pare une zone annoncée** — le
  placement est le cœur du jeu.
- **Quatre objets de la 0.8.6 ne se jugent qu'en jeu** : Fléau des géants
  (porte de boss), Serpent d'airain (esquive), Corne de Moloch (risque) et
  Reliquaire (boutique). La métrique du banc ne les voit pas ; leurs effets
  sont vérifiés, leur valeur ne l'est pas.
- **L'histoire est complète de bout en bout** (0.9.0) : le Pari, les
  prologues, Lilith, Lucifer (entrée, fin de chacun, sceaux), le portail et
  Hélel avec ses changements de personnage, la vraie fin. Golgota, Baal et
  Asmodée n'ont pas encore de scène. Hélel a un **verrou de 14 s par phase**
  et le **Voile de l'Aurore** (mesurés, voir README) ; ce qui n'est pas
  mesuré, c'est le DANGER qu'il présente — le banc tenait le joueur
  invincible. Avec une build moyenne (18 objets) il tient 4 à 6 min.
- La **piste du menu est 4,8 dB sous celles de l'arène** (mesuré en LUFS) :
  passer du menu au jeu est une marche vers le haut. La remonter la ferait
  saturer, ses crêtes sortant déjà à +6,5 dBFS — ça se règle sur le fichier.
- La **branche de Forge de Loth** est la moins bien mesurée des trois : le banc
  décrit un cercle et n'esquive jamais, donc il joue mal un personnage dont
  l'intérêt est d'éviter.
- **La carte de l'enfer** (0.9.1, voir README) : ses règles sont testées et le
  contournement mesuré, mais deux choses ne le sont pas — le **danger réel de la
  lave** dans une run (aucun banc ne l'évite ni ne la cherche) et l'effet des
  obstacles sur **l'équilibrage des vagues**. Pas encore de son de brûlure.
  Le lien de la page du pack est à consigner dans CREDITS.
- Les **deux anciens carreaux de sol** (`assets/sprites/arena/floor/`) ne
  servent plus qu'en repli, quand le pack de l'enfer n'est pas extrait. On peut
  les supprimer si ce repli ne sert à personne.
- Boutons de réglage si l'équilibrage sonne faux en jeu : `leftover_ratio` par
  personnage, `PUISSANCE_DECHAINEE` et `DEGATS_DECHAINES`, les 82 clés d'une
  Forge complète.
