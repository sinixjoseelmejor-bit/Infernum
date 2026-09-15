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
## PV rendus à chaque vague franchie.
##
## Sans cela, la moindre erreur se payait jusqu'à la fin de la run : les seules
## sources de soin étaient des objets qu'il fallait choisir au détriment des
## dégâts. Une run pouvait être condamnée dès la vague 6 sans l'être vraiment,
## le joueur traînant vingt vagues avec 12 PV. C'est un plancher de confort,
## pas une régénération : 5 PV ne rattrapent pas une vague mal jouée.
@export var wave_clear_heal: float = 5.0
## Soin supplémentaire à la mort d'un boss, en fraction des PV max. Un boss se
## gagne rarement intact : sans cela, le survivre laissait entamer la vague
## suivante avec les restes, et la punition dépassait de loin la récompense.
@export_range(0.0, 1.0, 0.05) var boss_clear_heal_ratio: float = 0.25
@export var first_wave_delay: float = 1.5

@export_group("Densité")
@export var base_spawns_per_second: float = 0.8
@export var spawns_per_second_growth: float = 0.22
@export var max_spawns_per_second: float = 6.0
@export var max_alive: int = 160

@export_group("Difficulté")
## Additif : +14 % des PV de base par vague écoulée.
@export var health_growth: float = 0.14
## Les i-frames du joueur (0,5 s) bornent les dégâts entrants à 2 coups/seconde :
## la seule courbe qui rend vraiment la fin de run dangereuse est celle-ci, et
## elle était la plus plate du jeu (+7 %/vague contre +14 % de PV et +27 %
## d'ennemis). Les PV effectifs devenaient un problème résolu dès la vague 8.
@export var damage_growth: float = 0.11
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
## Les PV des boss étaient FIXES alors que le DPS du joueur est multiplié par 22
## entre les vagues 5 et 20 : Asmodée tombait en 4 s, sans jamais atteindre sa
## phase 2 (50 % de PV) ni son enragement (100 s). Ces deux courbes maintiennent
## le combat entre 12 et 21 s, la durée pour laquelle les patterns sont écrits.
@export var boss_wave_health_growth: float = 0.09
@export var boss_wave_damage_growth: float = 0.04

@export_group("Placement")
@export var min_spawn_distance: float = 480.0
@export var max_spawn_distance: float = 700.0

## Roster : chaque entrée déclare à partir de quelle vague le type apparaît et
## son poids relatif (croissant ou décroissant avec les vagues).
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_min_wave: Array[int] = [1, 2, 3, 4]
@export var enemy_base_weight: Array[float] = [60.0, 25.0, 22.0, 14.0]
@export var enemy_weight_drift: Array[float] = [-2.0, 1.0, 1.5, 2.0]

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
		_spawn_boss()


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
	boss.contact_damage *= 1.0 + boss_wave_damage_growth * elapsed
	if loops > 0:
		# Rencontre répétée : on renforce, sans toucher aux patterns.
		boss.max_health *= 1.0 + boss_repeat_health_growth * loops
		boss.contact_damage *= 1.0 + boss_repeat_damage_growth * loops
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
		var amount := wave_clear_heal
		if is_boss_wave() and boss_clear_heal_ratio > 0.0:
			var hp := target.get(&"health") as Health
			if hp != null:
				amount += hp.max_health * boss_clear_heal_ratio
		if amount > 0.0:
			target.call(&"heal", amount)
	# Une clé garantie toutes les 5 vagues : le joueur régulier progresse même
	# sans dépendre du drop aléatoire des élites.
	if wave % 5 == 0:
		RunState.add_keys(1)


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


## Les survivants de la vague sont dissipés — sans récompense, pour ne pas
## transformer la fin de vague en distributeur d'âmes gratuit.
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
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		if enemy is Node2D:
			(enemy as Node2D).queue_free()
	for container in get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER):
		for child in container.get_children():
			child.queue_free()


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


func get_health_multiplier() -> float:
	var base := 1.0 + health_growth * (wave - 1)
	return base * Curses.get_enemy_health_mult() * WaveMods.get_enemy_health_mult()


func get_damage_multiplier() -> float:
	var base := 1.0 + damage_growth * (wave - 1)
	return base * Curses.get_enemy_damage_mult() * WaveMods.get_enemy_damage_mult()


func get_speed_multiplier() -> float:
	var base := minf(1.0 + speed_growth * (wave - 1), max_speed_multiplier)
	return base * Curses.get_enemy_speed_mult() * WaveMods.get_enemy_speed_mult()


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
