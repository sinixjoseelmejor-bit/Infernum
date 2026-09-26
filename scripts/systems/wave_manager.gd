class_name WaveManager
extends Node2D
## Enchaîne les vagues : combat, aspiration du butin, boutique, vague suivante.
##
## Ce script orchestre, les chiffres vivent ailleurs :
## - `DifficultyCurve` — PV, dégâts, vitesse, densité et élites de la piétaille ;
## - `BossCurve` — mise à l'échelle des boss et renforcement de la boucle ;
## - `EnemyRoster` — types d'ennemis et tirage (`scenes/main/enemy_roster.tres`) ;
## - `LeftoverHarvest` — ce que rendent les survivants en fin de vague.
## Raisonnement et mesures : README, « Vagues » et « Boss ».

enum State { IDLE, RUNNING, INTERMISSION, COLLECTING }

## Taux de moisson si aucun personnage n'est sélectionné (celui de Caïn et Loth).
const FALLBACK_LEFTOVER_RATIO := 0.25
## CORNE DE MOLOCH (légendaire) : les élites viennent plus souvent et valent
## davantage. Un risque qu'on achète — elles passent par le même plafond que les
## malédictions (31,5 %), donc l'objet ne se cumule pas sans fin avec elles.
const ELITE_LURE_CHANCE_MULT := 1.5
const ELITE_LURE_SOUL_MULT := 2

@export var curve: DifficultyCurve = DifficultyCurve.new()
@export var boss_curve: BossCurve = BossCurve.new()
@export var roster: EnemyRoster

@export_group("Rythme des vagues")
@export var first_wave_delay: float = 1.5
## Pause après une vague survécue (la boutique s'ouvre pendant ce temps).
@export var intermission_duration: float = 2.0
## Garde-fou de la phase d'aspiration. Au-delà, ce qui reste est encaissé
## d'office : la boutique ne doit JAMAIS rester fermée à cause d'une âme
## injoignable, un blocage vaudrait bien pire qu'une âme perdue.
@export var collect_timeout: float = 3.0

@export_group("Soin et moisson")
## Soin de fin de vague, en COUPS ENCAISSABLES et non en PV : un soin libellé en
## PV va à contresens de la difficulté (l'ancien valait 6,2 coups à la vague 3 et
## 0,7 à la vague 20). Un plancher de confort, pas une régénération. README,
## « Le soin ne se compte pas en PV ».
@export var wave_clear_heal_hits: float = 0.5
## Supplément à la mort d'un boss, en coups lui aussi : un boss se gagne rarement
## intact, et sans lui la punition dépassait la récompense.
@export var boss_clear_heal_hits: float = 1.5
## Dégâts d'un coup ennemi avant multiplicateur de vague, entre le chien (6) et
## la brute (16). C'est l'unité du soin.
@export var reference_hit_damage: float = 11.0
## ÉCHELLE GLOBALE de la moisson des survivants (0 = désactivée). Le taux
## lui-même est par personnage : `CharacterData.leftover_ratio`.
@export_range(0.0, 2.0, 0.05) var leftover_soul_scale: float = 1.0

@export_group("Apparitions")
@export var max_alive: int = 160
@export var min_spawn_distance: float = 480.0
@export var max_spawn_distance: float = 700.0

@export_group("Boss")
## Un boss toutes les `boss_wave_interval` vagues. Sa vague ne se termine PAS au
## chronomètre mais à sa mort : c'est ce qui en fait une vraie porte.
@export var boss_scenes: Array[PackedScene] = []
@export var boss_wave_interval: int = 5
## Les renforts continuent d'arriver au quart de la cadence : ils occupent le
## sol sans voler le DPS du joueur (à 0,35, le combat durait le double). README,
## « Les renforts volaient le combat ».
@export var boss_add_spawn_ratio: float = 0.25

var target: Node2D
var container: Node

var state: State = State.IDLE
var wave: int = 0
## Temps restant de la vague ou de l'entracte — ou, en vague de boss, durée
## ÉCOULÉE du combat : le chronomètre y compte vers le haut.
var time_left: float = 0.0

var _collect_time: float = 0.0
var _spawn_accumulator: float = 0.0
var _boss: Node2D = null
## LE COMBAT AU-DELÀ DU PORTAIL (Hélel). Hors roster et hors boucle : il se
## lance à la demande de l'histoire, sur la vague en cours, et se termine
## comme une vague de boss — à la mort du boss.
var _final_scene: PackedScene = null
## Cache de `_last_boss_base_health()` : 0 tant qu'il n'a pas été lu.
var _last_boss_health_cache: float = 0.0
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
			_process_intermission(delta)
		State.IDLE:
			pass


func is_boss_wave() -> bool:
	if _final_scene != null:
		return true
	return not boss_scenes.is_empty() and wave > 0 and wave % boss_wave_interval == 0


func is_final_fight() -> bool:
	return _final_scene != null


## Ouvre le combat contre `scene` sur la vague en cours : la piétaille est
## effacée, le boss arrive, et les renforts reprennent au rythme d'une vague de
## boss. Mis à l'échelle comme un boss de CETTE vague, sans boucle : c'est sa
## propre valeur de base qui le rend plus dur que Lucifer.
func start_final_fight(scene: PackedScene) -> void:
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		enemy.queue_free()
	_final_scene = scene
	state = State.RUNNING
	time_left = 0.0
	_spawn_accumulator = 0.0
	var boss := scene.instantiate() as Boss
	if boss == null:
		push_error("WaveManager : le combat final attend une scène de type Boss.")
		_final_scene = null
		return
	boss.target = target
	boss_curve.apply(boss, wave, 0, 0.0, boss_wave_interval, curve, RunState.unleashed)
	boss.global_position = _random_ring_position()
	container.add_child(boss)
	_boss = boss


func end_final_fight() -> void:
	_final_scene = null


func has_living_boss() -> bool:
	return is_instance_valid(_boss) and not _boss.is_queued_for_deletion()


## Ce que coûte un coup ennemi moyen à la vague courante. C'est l'unité dans
## laquelle le soin est libellé — le butin l'interroge aussi.
func get_hit_damage() -> float:
	return reference_hit_damage * _enemy_damage_multiplier()


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
func dev_jump_to_wave(target_wave: int) -> void:
	for boss in get_tree().get_nodes_in_group(Groups.BOSSES):
		GameEvents.boss_died.emit(boss)
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		enemy.queue_free()
	_boss = null
	wave = maxi(0, target_wave - 1)
	state = State.INTERMISSION
	_begin_wave()


# --- Cycle d'une vague ---

func _process_intermission(delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		_begin_wave()


func _begin_wave() -> void:
	wave += 1
	RunState.wave = wave
	state = State.RUNNING
	time_left = 0.0 if is_boss_wave() else curve.wave_duration(wave)
	_spawn_accumulator = 0.0
	_boss = null
	DropSystem.reset_wave_budget()
	GameEvents.wave_started.emit(wave)
	if is_boss_wave():
		# Une clé garantie en ATTEIGNANT chaque boss, et non à sa mort : une run
		# qui mourait sur Golgota rentrait sans clé, et ne pouvait jamais
		# commencer la Forge qui lui était destinée.
		RunState.add_keys(1)
		_spawn_boss()


func _process_wave(delta: float) -> void:
	if _advance_wave_clock(delta):
		_end_wave()
		return
	_process_spawns(delta)


## Fait avancer le chronomètre de la vague et dit si elle est terminée.
func _advance_wave_clock(delta: float) -> bool:
	if is_boss_wave():
		time_left += delta
		return not has_living_boss()
	time_left = maxf(0.0, time_left - delta)
	return time_left <= 0.0


## La vague tombe : on nettoie, on soigne, puis on ASPIRE le butin. La boutique
## n'ouvrira qu'une fois la carte vide — voir `_process_collect`.
func _end_wave() -> void:
	state = State.COLLECTING
	_collect_time = 0.0
	_clear_leftovers()
	_heal_target(_wave_clear_heal_hits())


## TOUT LE BUTIN REJOINT LE JOUEUR AVANT LA BOUTIQUE, pour être dépensable à
## celle qui s'ouvre au lieu d'attendre la suivante. README, « L'aspiration de
## fin de vague ».
##
## Répété à chaque image plutôt qu'une fois : un ennemi mourant au même instant
## dépose encore ses âmes en différé.
func _process_collect(delta: float) -> void:
	_collect_time += delta
	var pickups := get_tree().get_nodes_in_group(Groups.PICKUPS)
	if pickups.is_empty():
		_start_intermission()
		return

	var expired := _collect_time >= collect_timeout
	for node in pickups:
		var pickup := node as Pickup
		if pickup == null:
			continue
		if expired:
			pickup.collect()
		else:
			pickup.rush()
	if expired:
		_start_intermission()


func _start_intermission() -> void:
	state = State.INTERMISSION
	time_left = intermission_duration
	GameEvents.wave_cleared.emit(wave)


# --- Apparitions ---

func _process_spawns(delta: float) -> void:
	var rate := curve.spawn_rate(wave, Curses.get_spawn_rate_mult() * WaveMods.get_spawn_rate_mult())
	if is_boss_wave():
		rate *= boss_add_spawn_ratio
	_spawn_accumulator += rate * delta
	if _spawn_accumulator < 1.0:
		return
	# Compté une fois par image et tenu à jour à la main, plutôt que de
	# parcourir le groupe avant chaque apparition.
	var alive := get_tree().get_nodes_in_group(Groups.ENEMIES).size()
	while _spawn_accumulator >= 1.0:
		_spawn_accumulator -= 1.0
		if alive < max_alive and spawn_one() != null:
			alive += 1


func spawn_one() -> Node2D:
	if not is_instance_valid(target) or roster == null or roster.is_empty():
		return null
	var scene := roster.pick(wave, _rng.randf())
	if scene == null:
		return null

	var enemy := scene.instantiate() as Node2D
	enemy.global_position = _random_ring_position()
	var scalable := enemy as Enemy
	if scalable != null:
		scalable.target = target
		scalable.apply_wave_scaling(
			_enemy_health_multiplier(), _enemy_damage_multiplier(), _enemy_speed_multiplier()
		)
		if _rng.randf() < _elite_chance():
			scalable.make_elite()
			if RunState.has_special(&"elite_lure"):
				scalable.soul_value *= ELITE_LURE_SOUL_MULT
	container.add_child(enemy)
	return enemy


## Quel boss affronter à `boss_wave` : `x` est son rang dans le roster, `y` le
## nombre de tours de roster déjà bouclés.
static func boss_rotation(boss_wave: int, interval: int, roster_size: int) -> Vector2i:
	@warning_ignore("integer_division")
	var encounter := boss_wave / interval - 1
	@warning_ignore("integer_division")
	return Vector2i(encounter % roster_size, encounter / roster_size)


func _spawn_boss() -> void:
	var slot := boss_rotation(wave, boss_wave_interval, boss_scenes.size())
	var loops := slot.y
	var boss := boss_scenes[slot.x].instantiate() as Boss
	if boss == null:
		push_error("WaveManager : boss_scenes doit contenir des scènes de type Boss.")
		return
	boss.target = target
	var floor_health := _last_boss_base_health() if loops > 0 else 0.0
	boss_curve.apply(boss, wave, loops, floor_health, boss_wave_interval, curve, RunState.unleashed)
	boss.global_position = _random_ring_position()
	container.add_child(boss)
	_boss = boss


## PV de scène du DERNIER boss du roster, lus une fois puis retenus.
##
## Lus sur la scène et non écrits en dur : réordonner `boss_scenes` ou en ajouter
## un sixième doit suffire, sans qu'un nombre recopié ici parte à la dérive en
## silence. Une instance nue ne déclenche aucun `_ready` — elle n'entre jamais
## dans l'arbre.
func _last_boss_base_health() -> float:
	if _last_boss_health_cache > 0.0:
		return _last_boss_health_cache
	var probe := boss_scenes[-1].instantiate() as Boss
	if probe == null:
		return 0.0
	_last_boss_health_cache = probe.max_health
	probe.free()
	return _last_boss_health_cache


## Un point de l'anneau d'apparition. Jamais dans un obstacle de la carte ni
## dans la lave : quelques essais, puis le dernier tiré — un ennemi né contre une
## statue en est repoussé par la physique, alors qu'une vague qui ne ferait
## plus naître personne serait un blocage.
func _random_ring_position() -> Vector2:
	var point := Vector2.ZERO
	for _essai in 8:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(min_spawn_distance, max_spawn_distance)
		point = target.global_position + Vector2.RIGHT.rotated(angle) * distance
		if Carte.courante == null or Carte.courante.libre(point, 40.0):
			break
	return point


# --- Fin de vague : soin et moisson ---

## Le socle, plus le supplément de boss et sa part de Forge quand c'est un boss
## qui vient de tomber.
func _wave_clear_heal_hits() -> float:
	var hits := wave_clear_heal_hits
	if is_boss_wave():
		hits += boss_clear_heal_hits + Forge.get_special_total(&"boss_heal_hits")
	return hits


func _heal_target(hits: float) -> void:
	if hits <= 0.0 or not is_instance_valid(target) or not target.has_method(&"heal"):
		return
	target.call(&"heal", hits * get_hit_damage())


## Les survivants sont dissipés en rendant ce qu'on leur a pris (voir
## `LeftoverHarvest`), et les tirs et zones encore en l'air avec eux.
##
## Ces derniers surtout : la boutique met l'arbre en pause, un trait figé
## repartirait à sa fermeture sur un joueur qui regardait l'interface — mesuré,
## 10 dégâts encaissés à la réouverture sans rien avoir fait. Le conteneur de
## projectiles ne porte QUE des tirs et des télégraphes ; les âmes non ramassées
## sont enfants du conteneur d'ennemis et survivent.
func _clear_leftovers() -> void:
	var harvest := LeftoverHarvest.new()
	var ratio := _leftover_ratio()
	for node in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var whole_souls := harvest.add(_souls_owed_by(enemy, ratio))
		if whole_souls > 0:
			# Versé SUR PLACE : l'aspiration qui suit ramène tout au joueur, et
			# les orbes disent d'où elles viennent.
			DropSystem.spawn_drops(container, enemy.global_position, whole_souls, 0.0, 0.0)
		enemy.queue_free()
	RunState.leftover_souls = harvest.souls
	RunState.leftover_count = harvest.survivors
	for projectile_container in get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER):
		for child in projectile_container.get_children():
			child.queue_free()


func _leftover_ratio() -> float:
	if leftover_soul_scale <= 0.0:
		return 0.0
	var character := Characters.get_selected()
	var character_ratio: float = character.leftover_ratio if character != null else FALLBACK_LEFTOVER_RATIO
	return leftover_soul_scale * character_ratio


func _souls_owed_by(enemy: Node2D, ratio: float) -> float:
	if ratio <= 0.0:
		return 0.0
	var raw_soul_value: Variant = enemy.get(&"soul_value")
	var health := enemy.get(&"health") as Health
	if raw_soul_value == null or health == null:
		return 0.0
	return LeftoverHarvest.souls_owed(float(raw_soul_value), health.current, health.max_health, ratio)


# --- Courbes de la vague courante, malédictions et pactes compris ---
#
# Les multiplicateurs optionnels s'appliquent PAR-DESSUS la courbe de base :
# une run sans malédiction ni pacte reste exactement la run de référence.

func _enemy_health_multiplier() -> float:
	return curve.health_multiplier(wave, RunState.unleashed) \
		* Curses.get_enemy_health_mult() * WaveMods.get_enemy_health_mult()


func _enemy_damage_multiplier() -> float:
	return curve.damage_multiplier(wave, RunState.unleashed) \
		* Curses.get_enemy_damage_mult() * WaveMods.get_enemy_damage_mult()


func _enemy_speed_multiplier() -> float:
	return curve.speed_multiplier(wave) \
		* Curses.get_enemy_speed_mult() * WaveMods.get_enemy_speed_mult()


func _elite_chance() -> float:
	var lure := ELITE_LURE_CHANCE_MULT if RunState.has_special(&"elite_lure") else 1.0
	return curve.elite_chance(wave, Curses.starts_elites_immediately(),
		Curses.get_elite_mult() * WaveMods.get_elite_mult() * lure)


func _on_player_died(_player: Node2D) -> void:
	stop()
