class_name Boss
extends Enemy
## Socle commun des combats de boss : phases, primitives d'attaque, et surtout
## la mécanique ANTI-IMMOBILISATION.
##
## LE PROBLÈME : dans un jeu à tir automatique, un boss qui poursuit bêtement se
## bat tout seul. Le joueur recule en cercle, l'auto-aim fait le travail, et le
## combat devient une formalité sans aucune prise de risque.
##
## LA SOLUTION — une jauge de PRESSION, partagée par les cinq boss :
##   - elle monte quand le joueur reste au-delà de `engage_distance`, et d'autant
##     plus vite qu'il est loin ;
##   - elle monte AUSSI quand le boss n'a rien subi depuis `idle_damage_window`,
##     ce qui interdit de tourner en rond sans tirer ;
##   - elle redescend uniquement au corps-à-corps, sous le feu ;
##   - à saturation, elle déclenche `_release_pressure()`, que chaque boss
##     implémente à sa façon (colonnes, téléportation, chaîne, couronne de feu).
##
## Le kiting n'est pas interdit — il est facturé. Le joueur doit revenir prendre
## des risques régulièrement, ce qui est exactement l'intention.
##
## Second garde-fou : l'ENRAGEMENT. Passé `enrage_time`, le boss gagne en dégâts
## et la pression monte deux fois plus vite. Un combat ne peut pas s'éterniser.

@export_group("Identité")
@export var boss_name: String = "Boss"
@export var subtitle: String = ""

@export_group("Phases")
## Seuils de PV (ratio) où la phase change. [0.5] = deux phases.
@export var phase_thresholds: Array[float] = [0.5]

@export_group("Anti-immobilisation")
## Au-delà de cette distance, la pression monte.
@export var engage_distance: float = 320.0
@export var pressure_rate: float = 1.0
@export var pressure_decay: float = 1.5
@export var pressure_max: float = 4.0
## La pression monte aussi si le boss ne subit aucun dégât pendant ce délai.
@export var idle_damage_window: float = 3.0
## Accélération maximale de la montée quand le joueur s'éloigne. Bornée : la
## sanction doit escalader, pas se déclencher en boucle à très grande distance.
@export var max_distance_scaling: float = 2.0

@export_group("Enragement")
@export var enrage_time: float = 100.0
@export var enrage_damage_multiplier: float = 1.6
@export var enrage_pressure_multiplier: float = 2.0

@export_group("Récompenses")
@export var guaranteed_keys: int = 1

@export_group("Attaques")
@export var projectile_scene: PackedScene
@export var telegraph_scene: PackedScene
## CE QUI JAILLIT DU SOL QUAND LA ZONE DÉTONE, propre à chaque boss.
##
## Les zones annoncées n'affichaient que leur flash dessiné, et c'était un choix
## défendable tant que la seule planche disponible était une bouffée générique :
## huit zones qui partent ensemble n'ont pas besoin qu'on en rajoute. Avec une
## planche d'impacts au sol, le calcul change — un écrasement de colosse de
## pierre DOIT faire jaillir la pierre, et c'est le genre de chose qui distingue
## un boss d'un autre sans toucher à une seule règle.
##
## Lilith n'en a pas : sa seule zone annonce une téléportation et ne blesse
## personne (voir le garde-fou dans `telegraph.gd`).
@export var telegraph_impact: PackedScene
## Largeur utile du dessin dans sa cellule, mesurée sur la couverture alpha.
## Elle diffère d'un effet à l'autre — 58 px pour la braise, 90 pour la pierre —
## et c'est elle qui fait correspondre le dessin au RAYON de la zone.
@export var telegraph_impact_width: float = 88.0

## Mise a l'echelle des degats d'ATTAQUE (zones annoncees et projectiles), posee
## par le WaveManager a l'apparition. Les valeurs ecrites dans chaque boss sont
## calibrees sur la vague du PREMIER palier : sans ce facteur, la foudre de
## Lucifer vague 25 frappe comme le marteau de Golgota vague 5, alors que le
## joueur a entre-temps multiplie ses PV, son armure et ses soins. Seul le degat
## de CONTACT etait mis a l'echelle, et deux fois moins vite que la pietaille qui
## accompagne le boss.
var attack_damage_multiplier: float = 1.0

## Cadence des attaques, posee par le WaveManager pour les rencontres REPETEES.
## Elle multiplie le temps vu par la boucle de phase : les intervalles entre
## deux frappes se resserrent, sans toucher au PREAVIS des zones annoncees ni
## aux degats par coup. C'est le seul levier qui ajoute de la DIFFICULTE et non
## de la DUREE — gonfler les PV allonge le combat, il ne le rend pas plus dur.
##
## Il est PLAFONNE cote WaveManager, et la borne n'est pas decorative : les
## 0,4 s d'invulnerabilite du joueur bornent les degats entrants a 2,5 coups par
## seconde. Baal, le boss le plus dense, produit deja 1,94 zone par seconde :
## 1,94 x 1,25 = 2,43, on reste dessous. A x1,30 il passait a 2,52 et le combat
## cessait d'etre esquivable.
var attack_speed_multiplier: float = 1.0

var current_phase: int = 0
var fight_time: float = 0.0
var pressure: float = 0.0
var is_enraged: bool = false

## Vitesse imposée par une charge en cours ; annule le déplacement normal.
var _dash_velocity: Vector2 = Vector2.ZERO
var _dash_time: float = 0.0
var _time_since_damage: float = 0.0
var _attack_timer: float = 0.0
var _attack_step: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	_rng.randomize()
	add_to_group(&"bosses")
	GameEvents.boss_spawned.emit(self)
	GameEvents.boss_phase_changed.emit(current_phase, phase_thresholds.size() + 1)
	health.health_changed.connect(_on_health_changed)
	_on_phase_entered(0)


func _physics_process(delta: float) -> void:
	fight_time += delta
	_time_since_damage += delta
	_dash_time = maxf(0.0, _dash_time - delta)
	_update_enrage()
	_update_phase()
	_update_pressure(delta)
	# La boucle de phase voit un temps ACCELERE pour les rencontres repetees ;
	# `fight_time` reste en temps reel, sans quoi l'enragement se declencherait
	# plus tot sans que personne l'ait demande. Les rares boss qui se servent de
	# ce delta pour orbiter (Lilith, Baal, Lucifer) atteignent leur vitesse de
	# croisiere un peu plus vite : `move_toward` la borne, la vitesse de pointe
	# ne bouge pas.
	var rythme := delta * attack_speed_multiplier
	_attack_timer = maxf(0.0, _attack_timer - rythme)
	_run_phase(rythme)
	super(delta)


# --- Phases ------------------------------------------------------------------

func _update_phase() -> void:
	var ratio := health.get_ratio()
	var phase := 0
	for threshold in phase_thresholds:
		if ratio <= threshold:
			phase += 1
	if phase != current_phase:
		current_phase = phase
		_attack_timer = 0.0
		_attack_step = 0
		_on_phase_entered(phase)
		GameEvents.boss_phase_changed.emit(current_phase, phase_thresholds.size() + 1)
		GameEvents.request_shake(9.0)


## Surchargé : changement de comportement visuel / d'ouverture de phase.
func _on_phase_entered(_phase: int) -> void:
	pass


## Surchargé : la boucle d'attaque de la phase courante.
func _run_phase(_delta: float) -> void:
	pass


# --- Anti-immobilisation -----------------------------------------------------

func _update_pressure(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	var too_far := distance > engage_distance
	var starving := _time_since_damage > idle_damage_window
	var rate := pressure_rate * (enrage_pressure_multiplier if is_enraged else 1.0)

	if too_far or starving:
		# Plus le joueur est loin, plus la sanction arrive vite.
		var excess := clampf(distance / engage_distance - 1.0, 0.0, max_distance_scaling)
		pressure += rate * (1.0 + excess) * delta
	else:
		pressure -= pressure_decay * delta
	pressure = clampf(pressure, 0.0, pressure_max)

	if pressure >= pressure_max:
		pressure = 0.0
		_release_pressure()


## Surchargé : la sanction propre à chaque boss quand la pression sature.
func _release_pressure() -> void:
	pass


func get_pressure_ratio() -> float:
	return pressure / maxf(0.01, pressure_max)


func _update_enrage() -> void:
	if is_enraged or fight_time < enrage_time:
		return
	is_enraged = true
	contact_damage *= enrage_damage_multiplier
	GameEvents.boss_enraged.emit(self)
	GameEvents.request_shake(12.0)


# --- Déplacement -------------------------------------------------------------

func _update_movement(delta: float) -> void:
	if _dash_time > 0.0:
		velocity = _dash_velocity
		return
	super(delta)


## Déplacement sur rail : le boss traverse, indifférent aux frottements.
func dash_toward(point: Vector2, speed: float, duration: float) -> void:
	var direction := (point - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	_dash_velocity = direction * speed
	_dash_time = duration
	face(direction)


func is_dashing() -> bool:
	return _dash_time > 0.0


## Orbite autour de la cible à `preferred` : base des phases « insaisissables ».
func strafe_around(preferred: float, speed: float, delta: float, clockwise: bool = true) -> void:
	if not is_instance_valid(target):
		return
	var offset := global_position - target.global_position
	var distance := offset.length()
	var radial := offset.normalized()
	var tangent := radial.orthogonal() * (1.0 if clockwise else -1.0)
	var correction := radial * clampf((preferred - distance) / 120.0, -1.0, 1.0)
	velocity = velocity.move_toward((tangent + correction).normalized() * speed, acceleration * delta)
	face(-radial)


# --- Primitives d'attaque ----------------------------------------------------

func fire_ring(count: int, speed: float, damage: float, offset_angle: float = 0.0) -> void:
	for i in count:
		var angle := offset_angle + TAU * float(i) / float(maxi(1, count))
		_spawn_projectile(Vector2.RIGHT.rotated(angle), speed, damage)


func fire_spread(direction: Vector2, count: int, arc_deg: float, speed: float, damage: float) -> void:
	var arc := deg_to_rad(arc_deg)
	for i in count:
		var offset := 0.0
		if count > 1:
			offset = lerpf(-arc * 0.5, arc * 0.5, float(i) / float(count - 1))
		_spawn_projectile(direction.rotated(offset), speed, damage)


func fire_at_target(count: int, arc_deg: float, speed: float, damage: float) -> void:
	if not is_instance_valid(target):
		return
	fire_spread((target.global_position - global_position).normalized(), count, arc_deg, speed, damage)


func _spawn_projectile(direction: Vector2, speed: float, damage: float) -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Projectile
	if projectile == null:
		return
	projectile.global_position = global_position + direction * 42.0
	projectile.direction = direction
	projectile.speed = speed
	projectile.damage = _outgoing_damage(damage)
	projectile.source = self
	_projectile_parent().add_child(projectile)


## Point de passage unique de tous les degats sortants : palier de vague, puis
## enragement. Tout ce qui blesse le joueur doit passer par ici.
func _outgoing_damage(damage: float) -> float:
	var enrage := enrage_damage_multiplier if is_enraged else 1.0
	return damage * attack_damage_multiplier * enrage


func _projectile_parent() -> Node:
	var containers := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	return containers[0] if not containers.is_empty() else get_tree().current_scene


## Zone annoncée puis frappée. Toute la difficulté des boss passe par là.
func telegraph_at(point: Vector2, radius: float, delay: float, damage: float,
		color: Color = Color(1.0, 0.35, 0.2)) -> void:
	if telegraph_scene == null:
		return
	var zone := telegraph_scene.instantiate() as Telegraph
	if zone == null:
		return
	zone.global_position = point
	zone.radius = radius
	zone.delay = delay
	zone.damage = _outgoing_damage(damage)
	zone.color = color
	zone.impact_scene = telegraph_impact
	zone.impact_content_width = telegraph_impact_width
	_projectile_parent().add_child(zone)


## Couronne de zones autour d'un point : la brique des sanctions anti-kite.
func telegraph_ring(center: Vector2, count: int, ring_radius: float, zone_radius: float,
		delay: float, damage: float, color: Color = Color(1.0, 0.35, 0.2)) -> void:
	var start := _rng.randf() * TAU
	for i in count:
		var angle := start + TAU * float(i) / float(maxi(1, count))
		telegraph_at(center + Vector2.RIGHT.rotated(angle) * ring_radius,
			zone_radius, delay, damage, color)


func spawn_add(scene: PackedScene, at: Vector2) -> Node2D:
	if scene == null:
		return null
	var add := scene.instantiate() as Node2D
	add.global_position = at
	if add is Enemy:
		(add as Enemy).target = target
	get_parent().add_child(add)
	return add


func random_point_around_target(min_distance: float, max_distance: float) -> Vector2:
	if not is_instance_valid(target):
		return global_position
	var angle := _rng.randf() * TAU
	return target.global_position + Vector2.RIGHT.rotated(angle) \
		* _rng.randf_range(min_distance, max_distance)


## Position anticipée du joueur : les zones lentes visent là où il ira.
func predicted_target_position(lead_time: float) -> Vector2:
	if not is_instance_valid(target):
		return global_position
	var velocity_of_target := Vector2.ZERO
	if target is CharacterBody2D:
		velocity_of_target = (target as CharacterBody2D).velocity
	return target.global_position + velocity_of_target * lead_time


# --- Dégâts et mort ----------------------------------------------------------

func apply_damage(amount: float, source: Node = null, impulse: Vector2 = Vector2.ZERO) -> void:
	# Les boss ne sont pas repoussés : le recul annulerait leurs charges.
	super(amount, source, Vector2.ZERO)
	_time_since_damage = 0.0


func _on_health_changed(current: float, maximum: float) -> void:
	GameEvents.boss_health_changed.emit(current, maximum)


func apply_wave_scaling(_health_mult: float, _damage_mult: float, _speed_mult: float) -> void:
	# Les boss ont des valeurs fixes : leur difficulté est celle de leur palier,
	# pas celle de la courbe de vague. Le WaveManager les met à l'échelle lui-même
	# pour les rencontres répétées (boucle au-delà du dernier boss).
	pass


func _on_died(source: Node) -> void:
	GameEvents.boss_died.emit(self)
	var keys := guaranteed_keys + int(Forge.get_special_total(&"boss_keys"))
	DropSystem.spawn_keys(get_parent(), global_position, keys)
	super(source)
