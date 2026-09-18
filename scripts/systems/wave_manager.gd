class_name WaveManager
extends Node2D
## Vagues successives : densité et difficulté croissantes, boutique entre deux.
##
## ÉQUILIBRAGE — toute la montée en puissance est LINÉAIRE, jamais exponentielle.
## Les PV ennemis gagnent +14 % de la valeur de base par vague (additif), pas
## ×1.14 par vague : à la vague 20, un imp a ×3.66 PV et non ×13.7. La puissance
## du joueur monte elle aussi de façon plafonnée : les deux courbes restent
## comparables au lieu de diverger.

enum State { IDLE, RUNNING, INTERMISSION, COLLECTING }

@export_group("Rythme des vagues")
@export var wave_base_duration: float = 20.0
@export var wave_duration_growth: float = 2.0
@export var wave_max_duration: float = 45.0
## Pause après une vague survécue (la boutique s'ouvre pendant ce temps).
@export var intermission_duration: float = 2.0
## Garde-fou de la phase d'aspiration. Au-delà, ce qui reste est encaissé
## d'office : la boutique ne doit JAMAIS rester fermée à cause d'une âme
## injoignable, un blocage vaudrait bien pire qu'une âme perdue.
@export var collect_timeout: float = 3.0
## Soin de fin de vague, exprimé en COUPS ENCAISSABLES et non en points de vie.
##
## POURQUOI PAS EN PV. Mesuré sur l'ancienne valeur fixe de 5 PV : elle valait
## 6,2 coups à la vague 3 et 0,7 à la vague 20. Les dégâts ennemis montent de
## 11 % par vague, les PV du joueur non — un soin libellé en PV va donc
## mécaniquement à contresens de la difficulté, généreux quand le jeu est facile
## et dérisoire quand il mord. Libellé en coups, il garde la même valeur.
##
## Sans cela, la moindre erreur se payait jusqu'à la fin de la run : les seules
## sources de soin étaient des objets qu'il fallait choisir au détriment des
## dégâts. Une run pouvait être condamnée dès la vague 6 sans l'être vraiment,
## le joueur traînant vingt vagues avec 12 PV. C'est un plancher de confort,
## pas une régénération : 5 PV ne rattrapent pas une vague mal jouée.
@export var wave_clear_heal_hits: float = 0.5
## ÉCHELLE GLOBALE de la moisson des survivants. 0 = l'ancien comportement
## (les survivants ne rendent rien).
##
## Le taux lui-même est PAR PERSONNAGE et vit dans le catalogue
## (`CharacterData.leftover_ratio`) : Job à 0,5, Caïn et Loth à 0,25. Ce chiffre
## n'est là que pour désactiver ou atténuer la mécanique d'un coup.
@export_range(0.0, 2.0, 0.05) var leftover_soul_scale: float = 1.0
## Dégâts de référence d'un coup ennemi, avant multiplicateur de vague : entre
## le chien (6) et le brute (16). Sert d'unité au soin.
@export var reference_hit_damage: float = 11.0
## Un boss se gagne rarement intact : sans ce supplément, le survivre revenait à
## entamer la suite avec les restes, et la punition dépassait la récompense.
## Soin supplémentaire à la mort d'un boss, en coups lui aussi.
@export var boss_clear_heal_hits: float = 1.5
@export var first_wave_delay: float = 1.5

@export_group("Densité")
@export var base_spawns_per_second: float = 0.8
@export var spawns_per_second_growth: float = 0.19
@export var max_spawns_per_second: float = 6.0
@export var max_alive: int = 160

@export_group("Difficulté")
## Additif : +12 % des PV de base par vague écoulée.
##
## MESURÉ : à 14 %, la marge du joueur (ses dégâts possibles divisés par ceux
## qu'il faudrait pour tuer tout ce qui apparaît) restait collée à 0,90 de la
## vague 6 à la vague 21 — quinze vagues de tapis roulant, sans escalade ni
## récompense, et 10 % de chaque vague qui survit et s'accumule jusqu'à saturer
## l'arène. La courbe descend donc, et la montée est reportée en fin de partie.
@export var health_growth: float = 0.10
## Supplément appliqué à partir de `late_wave` : c'est lui qui fait retomber la
## marge après la vague 15, pour qu'une run finisse par se conclure au lieu de
## s'étirer indéfiniment à l'équilibre.
@export var late_health_growth: float = 0.09
@export var late_wave: int = 16
## Les i-frames du joueur (0,5 s) bornent les dégâts entrants à 2 coups/seconde :
## la seule courbe qui rend vraiment la fin de run dangereuse est celle-ci, et
## elle était la plus plate du jeu (+7 %/vague contre +14 % de PV et +27 %
## d'ennemis). Les PV effectifs devenaient un problème résolu dès la vague 8.
## MESURÉ : à 11 %, un brute élite frappait pour 79 à la vague 20 — soit un
## joueur mort en une touche et demie, quel que soit son équipement. C'est la
## courbe qui rend la fin de run dangereuse, elle doit mordre, mais pas
## supprimer le droit à l'erreur.
@export var damage_growth: float = 0.095
@export var speed_growth: float = 0.015
@export var max_speed_multiplier: float = 1.35
@export var elite_start_wave: int = 4
@export var elite_chance_growth: float = 0.02
@export var max_elite_chance: float = 0.18

@export_group("Boss")
## Un boss toutes les N vagues. La vague ne se termine PAS au chronomètre : elle
## se termine quand le boss tombe. C'est ce qui en fait une vraie porte.
@export var boss_scenes: Array[PackedScene] = []
@export var boss_wave_interval: int = 5
## Les ennemis normaux continuent d'arriver, mais au ralenti : le boss reste
## lisible sans que le joueur puisse l'affronter dans une arène vide.
##
## 0.35 était trop : l'auto-visée classant par distance, les renforts captaient la
## moitié du DPS du joueur et le combat de boss durait le double. Ils restent
## présents — ils ne sont pas là pour faire des dégâts mais pour occuper le sol.
@export var boss_add_spawn_ratio: float = 0.25
## Au-delà du dernier boss, on reboucle en renforçant (PV et dégâts).
@export var boss_repeat_health_growth: float = 0.45
@export var boss_repeat_damage_growth: float = 0.20
## Les PV des boss étaient FIXES alors que le DPS du joueur grandit à chaque
## vague : Asmodée tombait sans jamais atteindre sa phase 2 (45 % de PV) ni son
## enragement (100 s). Cette courbe rend au combat la durée pour laquelle les
## patterns sont écrits.
##
## LES BOSS SONT DES CONTRÔLES DE BUILD. Chaque scène de boss fixe ses PV et son
## `enrage_time` de sorte qu'un DPS insuffisant fasse durer le combat jusqu'à
## l'enragement (dégâts ×1,6, pression ×2) — et c'est là que la run se termine.
## Le seuil de DPS visé, en multiples du DPS de départ (≈ 60) : Golgota ×1,25,
## Lilith ×3, Baal ×5, Asmodée ×7, Lucifer ×9. Sans Forge, une bonne build
## franchit Lilith et bute sur Baal ; la Forge complète (≈ ×2 de DPS) porte
## jusqu'à Lucifer. C'est la boucle « rejouer pour aller plus loin ».
##
## Mesuré en partie réelle avant ce réglage : 116 s pour Baal et 542 s pour
## Lucifer avec une build faible et la mort neutralisée — c'est précisément ce
## que l'enragement transforme désormais en mort.
@export var boss_wave_health_growth: float = 0.09

@export_group("Placement")
@export var min_spawn_distance: float = 480.0
@export var max_spawn_distance: float = 700.0

## Roster : chaque entrée déclare à partir de quelle vague le type apparaît et
## son poids relatif (croissant ou décroissant avec les vagues).
##
## L'ŒIL entre à la vague 11, juste après Lilith, et c'est un seuil de jeu et
## non d'équilibrage : il sanctionne l'immobilité, ce qu'aucun autre ennemi ne
## fait. L'introduire plus tôt punirait un joueur qui n'a pas encore de quoi
## choisir où se placer. Son poids monte doucement, il ne doit jamais devenir
## l'ennemi principal — deux ou trois yeux dans l'arène suffisent à interdire
## de se poser, dix en feraient un jeu de couloirs.
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_min_wave: Array[int] = [1, 2, 3, 4, 11]
@export var enemy_base_weight: Array[float] = [60.0, 25.0, 22.0, 14.0, 14.0]
@export var enemy_weight_drift: Array[float] = [-2.0, 1.0, 1.5, 2.0, 1.4]

var target: Node2D
var container: Node

var state: State = State.IDLE
var _collect_time: float = 0.0
var wave: int = 0
var time_left: float = 0.0

var _spawn_accumulator: float = 0.0
var _boss: Node2D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if target == null:
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
	if container == null:
		var found := get_tree().get_nodes_in_group(Groups.ENEMY_CONTAINER)
		container = found[0] if not found.is_empty() else get_parent()
	GameEvents.player_died.connect(_on_player_died)


func start() -> void:
	wave = 0
	state = State.INTERMISSION
	time_left = first_wave_delay


func stop() -> void:
	state = State.IDLE


func _process(delta: float) -> void:
	match state:
		State.RUNNING:
			_process_wave(delta)
		State.COLLECTING:
			_process_collect(delta)
		State.INTERMISSION:
			time_left = maxf(0.0, time_left - delta)
			if time_left <= 0.0:
				_begin_wave()
		State.IDLE:
			pass


func is_boss_wave() -> bool:
	return not boss_scenes.is_empty() and wave > 0 and wave % boss_wave_interval == 0


func has_living_boss() -> bool:
	return is_instance_valid(_boss) and not _boss.is_queued_for_deletion()


func _process_wave(delta: float) -> void:
	if is_boss_wave():
		# Le chronomètre ne clôt pas une vague de boss : seule sa mort le fait.
		time_left += delta
		if not has_living_boss():
			_end_wave()
			return
	else:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			_end_wave()
			return

	var rate := get_spawn_rate()
	if is_boss_wave():
		rate *= boss_add_spawn_ratio
	_spawn_accumulator += rate * delta
	while _spawn_accumulator >= 1.0:
		_spawn_accumulator -= 1.0
		if get_tree().get_nodes_in_group(Groups.ENEMIES).size() < max_alive:
			spawn_one()


func _begin_wave() -> void:
	wave += 1
	RunState.wave = wave
	state = State.RUNNING
	time_left = 0.0 if is_boss_wave() else get_wave_duration()
	_spawn_accumulator = 0.0
	_boss = null
	DropSystem.reset_wave_budget()
	GameEvents.wave_started.emit(wave)
	if is_boss_wave():
		# Une clé garantie en ATTEIGNANT chaque boss. Elle était versée à la fin
		# de la vague : une run qui mourait sur Golgota rentrait avec zéro clé, et
		# le joueur pour qui la Forge est faite ne pouvait jamais la commencer.
		RunState.add_keys(1)
		_spawn_boss()


## Saute directement à une vague donnée.
##
## RÉSERVÉ AU PANNEAU DE DÉVELOPPEMENT. Il court-circuite la fin de vague :
## ni aspiration des âmes restantes, ni boutique, ni récompense. C'est voulu —
## on saute pour VOIR une vague, pas pour la gagner. Les ennemis en place sont
## effacés sans mourir, donc sans rien lâcher.
##
## Un boss en cours est annoncé mort avant d'être effacé : sans ça sa barre de
## vie resterait à l'écran, l'interface n'ayant aucun autre moyen d'apprendre
## qu'il a disparu.
func dev_jump_to_wave(target: int) -> void:
	for boss in get_tree().get_nodes_in_group(&"bosses"):
		GameEvents.boss_died.emit(boss)
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		enemy.queue_free()
	_boss = null
	wave = maxi(0, target - 1)
	state = State.INTERMISSION
	_begin_wave()


func _spawn_boss() -> void:
	var index := wave / boss_wave_interval - 1
	var loops := index / boss_scenes.size()
	var scene: PackedScene = boss_scenes[index % boss_scenes.size()]
	var boss := scene.instantiate() as Boss
	if boss == null:
		push_error("WaveManager : boss_scenes doit contenir des scènes de type Boss.")
		return
	boss.target = target
	var elapsed := float(wave - boss_wave_interval)
	boss.max_health *= 1.0 + boss_wave_health_growth * elapsed
	var threat := get_boss_threat_multiplier(wave)
	boss.contact_damage *= threat
	boss.attack_damage_multiplier = threat
	if loops > 0:
		# Rencontre répétée : on renforce, sans toucher aux patterns.
		boss.max_health *= 1.0 + boss_repeat_health_growth * loops
		boss.contact_damage *= 1.0 + boss_repeat_damage_growth * loops
		boss.attack_damage_multiplier *= 1.0 + boss_repeat_damage_growth * loops
	boss.global_position = _random_ring_position()
	container.add_child(boss)
	_boss = boss


## La vague tombe : on nettoie, on verse la clé, puis on ASPIRE le butin. La
## boutique n'ouvrira qu'une fois la carte vide — voir `_process_collect`.
func _end_wave() -> void:
	state = State.COLLECTING
	_collect_time = 0.0
	_clear_leftovers()
	if is_instance_valid(target) and target.has_method(&"heal"):
		var hits := wave_clear_heal_hits
		if is_boss_wave():
			hits += boss_clear_heal_hits + Forge.get_special_total(&"boss_heal_hits")
		if hits > 0.0:
			target.call(&"heal", hits * get_hit_damage())
	# (La clé garantie des vagues de boss est versée à l'ARRIVÉE du boss, dans
	# `_begin_wave` : mourir contre lui doit quand même rapporter quelque chose.)


## TOUT LE BUTIN REJOINT LE JOUEUR AVANT LA BOUTIQUE.
##
## Les âmes au sol n'étaient PAS perdues — vérifié : elles survivent au nettoyage
## de fin de vague et à la vague suivante, sans durée de vie. Le problème était
## autre : elles n'étaient pas DÉPENSABLES à la boutique qui venait de s'ouvrir.
## Elles attendaient que le joueur repasse dessus pendant la vague suivante, et
## ne comptaient qu'à la boutique d'après. Le joueur devait donc arbitrer entre
## finir sa tournée de ramassage et se battre, ce qui punissait surtout les fins
## de vague chargées — celles où il y a le plus à ramasser.
##
## L'appel est répété à chaque image plutôt que fait une fois : du butin peut
## encore apparaître après l'appel initial, un ennemi mourant au même instant
## déposant ses âmes en différé.
func _process_collect(delta: float) -> void:
	_collect_time += delta
	var pickups := get_tree().get_nodes_in_group(Groups.PICKUPS)
	if pickups.is_empty():
		_start_intermission()
		return

	var expired := _collect_time >= collect_timeout
	for pickup in pickups:
		if not (pickup is Pickup):
			continue
		if expired:
			(pickup as Pickup).collect()
		else:
			(pickup as Pickup).rush()
	if expired:
		_start_intermission()


func _start_intermission() -> void:
	state = State.INTERMISSION
	time_left = intermission_duration
	GameEvents.wave_cleared.emit(wave)


## Les survivants de la vague sont dissipés — en rendant CE QU'ON LEUR A PRIS.
##
## LE DÉFAUT QUE ÇA CORRIGE. Les âmes ne tombaient que des éliminations, donc
## les dégâts partiels ne valaient rien : on pouvait enlever 90 % des points de
## vie de quarante ennemis et rentrer avec zéro. Or c'est exactement la
## situation d'un joueur dont la build ne tue plus assez vite — et comme les
## âmes achètent les objets qui font les dégâts, il ne pouvait pas s'en sortir.
## Moins de dégâts, moins d'âmes, moins d'objets, moins de dégâts.
##
## LA MESURE NE CHANGE RIEN QUAND TOUT VA BIEN, et c'est sa qualité principale :
## un joueur qui tue tout n'a aucun survivant, donc ne touche pas une âme de
## plus. Aucun recalibrage de l'économie, aucun canal de puissance nouveau en
## fin de partie. Le filet ne se déclenche que dans le cas qu'il vise.
##
## JAMAIS AU PRIX PLEIN, sinon grignoter vaudrait autant qu'achever et
## l'incitation à finir ses cibles disparaîtrait. Ce n'est pas davantage un
## distributeur gratuit : on est payé au prorata des dégâts réellement infligés,
## et seulement d'eux.
##
## LE TAUX DÉPEND DU PERSONNAGE (`CharacterData.leftover_ratio`) : Job à 50 %,
## Caïn et Loth à 25 %. Mesurée à taux uniforme, la moisson profitait le MOINS à
## celui pour qui elle avait été écrite — elle paie les dégâts répartis sur des
## cibles qui survivent, donc elle va à qui arrose, pas à qui encaisse. Elle
## reste une sortie de secours pour les trois, mais c'est à Job qu'elle s'adresse.
##
## LES TIRS ET LES ZONES AUSSI, et c'est le point important. La boutique met
## l'arbre en pause : un trait de cultiste ou une zone de boss encore en l'air
## quand la vague tombe y reste figé, puis repart à la fermeture de la
## boutique — sur un joueur qui regardait l'interface et n'a aucun moyen de
## l'anticiper. La durée de vie des projectiles ne le sauve pas : son minuteur
## est gelé lui aussi, donc ils attendent aussi longtemps que la boutique reste
## ouverte. Mesuré avant correction : six traits en vol, 3 s de boutique, et le
## joueur encaissait à la réouverture sans avoir rien fait.
##
## Le conteneur ne porte QUE des projectiles et des télégraphes ; les âmes non
## ramassées sont enfants du conteneur d'ennemis et survivent, comme il se doit.
func _clear_leftovers() -> void:
	# Le reliquat est CUMULÉ d'un ennemi à l'autre avant d'être versé : arrondir
	# par ennemi ferait disparaître la récolte entière (un imp vaut 3 âmes, donc
	# 0,75 âme à moitié entamé, donc zéro après arrondi — quarante fois zéro).
	var reliquat := 0.0
	var recolte := 0
	var survivants := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var noeud := enemy as Node2D
		if noeud == null:
			continue
		var du := _ames_arrachees(noeud)
		if du > 0.0:
			survivants += 1
			reliquat += du
			if reliquat >= 1.0:
				var entier := floori(reliquat)
				reliquat -= float(entier)
				# Versé SUR PLACE, là où l'ennemi tombe : la phase d'aspiration
				# qui suit ramène tout au joueur, et les orbes disent d'où elles
				# viennent au lieu d'apparaître sous ses pieds.
				DropSystem.spawn_drops(container, noeud.global_position, entier, 0.0, 0.0)
				recolte += entier
		noeud.queue_free()
	RunState.leftover_souls = recolte
	RunState.leftover_count = survivants
	for container in get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER):
		for child in container.get_children():
			child.queue_free()


## Ce qu'un ennemi rend en disparaissant : sa valeur en âmes, au prorata des
## points de vie qu'il a perdus, et de moitié.
##
## Lu sur les PV et non sur un compteur de dégâts tenu à part : c'est la même
## information, et un compteur parallèle finirait par mentir (soins d'ennemis,
## remises à l'échelle de vague, élites redimensionnées après coup).
func _ames_arrachees(enemy: Node2D) -> float:
	if leftover_soul_scale <= 0.0:
		return 0.0
	var personnage := Characters.get_selected()
	var taux: float = leftover_soul_scale * (personnage.leftover_ratio if personnage != null else 0.25)
	if taux <= 0.0:
		return 0.0
	var brut: Variant = enemy.get(&"soul_value")
	var vie := enemy.get(&"health") as Health
	if brut == null or vie == null or vie.max_health <= 0.0:
		return 0.0
	var valeur := float(brut)
	if valeur <= 0.0:
		return 0.0
	var part := clampf(1.0 - vie.current / vie.max_health, 0.0, 1.0)
	return valeur * part * taux


# --- Courbes de difficulté (toutes additives) ---

func get_wave_duration() -> float:
	return minf(wave_base_duration + wave_duration_growth * (wave - 1), wave_max_duration)


## Les multiplicateurs optionnels (malédictions, pacte de vague) s'appliquent
## PAR-DESSUS la courbe de base. Ils ne modifient pas la courbe elle-même : une
## run sans malédiction ni pacte reste exactement la run de référence.
func get_spawn_rate() -> float:
	var base := base_spawns_per_second + spawns_per_second_growth * (wave - 1)
	var modded := base * Curses.get_spawn_rate_mult() * WaveMods.get_spawn_rate_mult()
	return minf(modded, max_spawns_per_second * 1.5)


## DÉCHAÎNEMENT : les PV des ennemis montent en PUISSANCE, et non plus
## linéairement.
##
## Sans ça, le mode ne serait pas un défi mais une promenade. La build du joueur
## atteint environ ×200 de dégâts contre ×39 aujourd'hui, alors que la courbe
## normale ajoute 10 % de PV par vague — à la vague 40 les ennemis ont ×4,9 de
## PV et le joueur ×200 de dégâts. Casser le jeu n'est amusant que s'il reste
## quelque chose à casser : la courbe déchaînée double les PV toutes les six
## vagues et finit par rattraper n'importe quelle build.
##
## CALIBRÉE SUR LES DPS MESURÉS, pas sur une intuition. En déchaîné, la build
## vaut ×8 à 20 objets, ×32 à 40, ×190 à 80, ×1 256 à 160 — le mode ne change
## presque rien avant 40 objets, puisque c'est là que les plafonds commencent à
## mordre en régime normal. En comptant ~3,5 objets par vague, le joueur passe
## ×450 vers la vague 30 et ×950 vers la 40.
##
## À 1,15 par vague, les ennemis valent ×265 à la vague 30 et ×1 310 à la 40 :
## le joueur mène largement jusqu'à la trentaine, puis la courbe le rattrape
## vers la vague 36-38. C'est la forme voulue — on casse le jeu, on en profite
## longtemps, et l'enfer finit par répondre.
##
## PREMIER RÉGLAGE, à bouger après avoir joué : c'est le seul chiffre à toucher
## pour rendre la course plus longue ou plus courte.
const PUISSANCE_DECHAINEE := 1.15

## Les dégâts montent aussi, plus doucement. Sans eux la fin de partie serait
## seulement SPONGIEUSE : des ennemis à ×1 300 de PV qui ne tuent pas ne font pas
## une run difficile, ils font une run qu'on abandonne d'ennui. Le joueur
## déchaîné monte jusqu'à 90 % de réduction et un vol de vie sans budget : il
## faut de quoi passer au travers.
const DEGATS_DECHAINES := 1.08

func get_health_multiplier() -> float:
	var base := 1.0 + health_growth * (wave - 1)
	if wave >= late_wave:
		base += late_health_growth * (wave - late_wave + 1)
	if RunState.unleashed:
		base *= pow(PUISSANCE_DECHAINEE, wave)
	return base * Curses.get_enemy_health_mult() * WaveMods.get_enemy_health_mult()


## Les dégâts d'un boss dans l'unité du jeu : le « coup » de
## `reference_hit_damage`, qui grandit de `damage_growth` à chaque vague. Les
## valeurs écrites dans chaque boss sont calibrées sur la vague du premier
## palier, et cette fonction les y ramène.
##
## LE DÉFAUT QU'ELLE CORRIGE : seul le dégât de CONTACT montait, et deux fois
## moins vite que la piétaille (4 % contre 9,5 % par vague). Les dégâts
## d'ATTAQUE — foudre, braise, salves, tout ce qui blesse réellement le joueur —
## ne montaient pas du tout. Une attaque de Lucifer vague 25 valait 0,55 coup
## quand un marteau de Golgota vague 5 en valait 1,7 : le boss le plus tardif
## était le moins dangereux du jeu.
func get_boss_threat_multiplier(at_wave: int) -> float:
	var reference := 1.0 + damage_growth * (boss_wave_interval - 1)
	return (1.0 + damage_growth * maxf(0.0, at_wave - 1.0)) / reference


func get_damage_multiplier() -> float:
	var base := 1.0 + damage_growth * (wave - 1)
	if RunState.unleashed:
		base *= pow(DEGATS_DECHAINES, wave)
	return base * Curses.get_enemy_damage_mult() * WaveMods.get_enemy_damage_mult()


func get_speed_multiplier() -> float:
	var base := minf(1.0 + speed_growth * (wave - 1), max_speed_multiplier)
	return base * Curses.get_enemy_speed_mult() * WaveMods.get_enemy_speed_mult()


## Ce que coûte un coup ennemi moyen à la vague courante. C'est l'unité dans
## laquelle le soin est libellé, et la seule qui suive la difficulté.
func get_hit_damage() -> float:
	return reference_hit_damage * get_damage_multiplier()


func get_elite_chance() -> float:
	var from_wave := 1 if Curses.starts_elites_immediately() else elite_start_wave
	if wave < from_wave:
		return 0.0
	var base := elite_chance_growth * (wave - from_wave + 1)
	var modded := base * Curses.get_elite_mult() * WaveMods.get_elite_mult()
	# Les élites valent 3 fois plus d'âmes et portent toute la chance de clé :
	# à 54 % (l'ancien plafond), elles devenaient la majorité des apparitions et
	# le revenu d'une run maudite dépassait celui d'une run normale de ×6.
	return minf(modded, max_elite_chance * 1.75)


func spawn_one() -> Node2D:
	if not is_instance_valid(target) or enemy_scenes.is_empty():
		return null
	var scene := _pick_scene()
	if scene == null:
		return null

	var enemy := scene.instantiate() as Node2D
	enemy.global_position = _random_ring_position()
	if enemy is Enemy:
		var e := enemy as Enemy
		e.target = target
		e.apply_wave_scaling(
			get_health_multiplier(), get_damage_multiplier(), get_speed_multiplier()
		)
		if _rng.randf() < get_elite_chance():
			e.make_elite()
	container.add_child(enemy)
	return enemy


func _pick_scene() -> PackedScene:
	var total := 0.0
	var weights: Array[float] = []
	for i in enemy_scenes.size():
		var w := 0.0
		if wave >= _min_wave(i):
			w = maxf(0.0, _base_weight(i) + _weight_drift(i) * (wave - _min_wave(i)))
		weights.append(w)
		total += w
	if total <= 0.0:
		return enemy_scenes[0]

	var roll := _rng.randf() * total
	for i in enemy_scenes.size():
		roll -= weights[i]
		if roll <= 0.0:
			return enemy_scenes[i]
	return enemy_scenes[0]


func _min_wave(i: int) -> int:
	return enemy_min_wave[i] if i < enemy_min_wave.size() else 1


func _base_weight(i: int) -> float:
	return enemy_base_weight[i] if i < enemy_base_weight.size() else 10.0


func _weight_drift(i: int) -> float:
	return enemy_weight_drift[i] if i < enemy_weight_drift.size() else 0.0


func _random_ring_position() -> Vector2:
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(min_spawn_distance, max_spawn_distance)
	return target.global_position + Vector2.RIGHT.rotated(angle) * distance


func _on_player_died(_player: Node2D) -> void:
	stop()
