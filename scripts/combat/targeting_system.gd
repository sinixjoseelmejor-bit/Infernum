class_name TargetingSystem
extends Area2D
## Sélection automatique de cible dans un rayon.
##
## Pensé pour le tactile : la tolérance angulaire est volontairement très large
## (le joueur "vise" simplement en se déplaçant), la cible est collante pour
## éviter le clignotement entre deux ennemis équidistants, et le système peut
## renvoyer un point d'interception anticipant le déplacement de la cible.
##
## Le nœud doit posséder une CollisionShape2D (CircleShape2D) ; son rayon est
## synchronisé automatiquement avec `range_radius`.

enum Priority {
	NEAREST,       ## Le plus proche, point. (Brotato-like)
	AIM_ASSISTED,  ## Le plus proche pondéré par la direction visée. (mobile)
	LOWEST_HEALTH, ## Achève les cibles blessées.
	HIGHEST_HEALTH,## Concentre les gros ennemis.
}

@export var range_radius: float = 340.0:
	set(value):
		range_radius = maxf(1.0, value)
		_apply_radius()

@export var target_priority: Priority = Priority.AIM_ASSISTED

## Bonus de score accordé aux boss, dans la même échelle que le score lui-même
## (0 = idéal, 1 = bord de portée). 0 désactive.
##
## Le classement se fait par DISTANCE, et c'est structurellement défavorable aux
## boss : ils sont lents et massifs, les renforts foncent sur le joueur. Pendant
## une vague de boss, les renforts sont donc presque toujours plus près — et
## Golgota, mesuré, ne recevait que 55 à 61 % des tirs. Les PV des boss étant
## calibrés en supposant que TOUT le DPS leur tombe dessus, le combat durait trois
## fois la durée pour laquelle ses phases sont écrites, et le joueur encaissait
## trois fois plus d'attaques au sol.
##
## Le biais reste modéré à dessein : trop haut, le joueur ne nettoie plus rien et
## se fait submerger — mesuré aussi, à 0,50 les dégâts encaissés REMONTENT.
@export_range(0.0, 1.0, 0.01) var boss_bonus: float = 0.20

@export_group("Aide à la visée (mobile)")
## Demi-angle toléré autour de la direction visée. Large = très permissif.
@export_range(0.0, 180.0, 1.0) var aim_tolerance_deg: float = 110.0
## Poids de l'angle dans le score final (0 = distance pure, 1 = angle pur).
@export_range(0.0, 1.0, 0.01) var aim_weight: float = 0.35
## Bonus de score accordé à la cible courante : évite le "target flickering".
@export_range(0.0, 1.0, 0.01) var sticky_bonus: float = 0.18
## Délai pendant lequel une cible sortie de portée reste privilégiée.
@export var sticky_grace: float = 0.35

@export_group("Filtrage")
@export var target_group: StringName = Groups.ENEMIES
## Ignore les cibles derrière un mur (coûte un raycast par évaluation).
@export var require_line_of_sight: bool = false
@export_flags_2d_physics var line_of_sight_mask: int = Layers.WORLD

var _candidates: Array[Node2D] = []
var _current: Node2D = null
var _grace_timer: float = 0.0


func _ready() -> void:
	monitorable = false
	_apply_radius()
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	area_entered.connect(_on_entered)
	area_exited.connect(_on_exited)


func _process(delta: float) -> void:
	if _grace_timer > 0.0:
		_grace_timer = maxf(0.0, _grace_timer - delta)


## Renvoie la meilleure cible, ou null. `aim_hint` est la direction visée
## (typiquement la direction de déplacement du joueur) ; Vector2.ZERO désactive
## la pondération angulaire.
func get_target(aim_hint: Vector2 = Vector2.ZERO) -> Node2D:
	_prune()
	if _candidates.is_empty():
		_current = null
		return null

	var origin := global_position
	var has_hint: bool = aim_hint != Vector2.ZERO and target_priority == Priority.AIM_ASSISTED
	var hint := aim_hint.normalized() if has_hint else Vector2.ZERO
	var tolerance := deg_to_rad(maxf(1.0, aim_tolerance_deg))

	var best: Node2D = null
	var best_score := INF

	for candidate in _candidates:
		if require_line_of_sight and not _has_line_of_sight(candidate):
			continue

		var offset := candidate.global_position - origin
		var distance := offset.length()
		if distance > range_radius:
			continue

		# Score normalisé, 0 = idéal. La distance reste la composante dominante.
		var score := (distance / range_radius) * (1.0 - aim_weight)

		if has_hint and distance > 1.0:
			var angle := absf(hint.angle_to(offset / distance))
			# Au-delà de la tolérance la pénalité sature : on ne renonce jamais
			# à tirer, on préfère juste ce qui est devant. Crucial sur mobile où
			# la direction du pouce est imprécise.
			score += minf(angle / tolerance, 1.0) * aim_weight

		match target_priority:
			Priority.LOWEST_HEALTH:
				score += _health_ratio(candidate) * 0.5
			Priority.HIGHEST_HEALTH:
				score += (1.0 - _health_ratio(candidate)) * 0.5
			_:
				pass

		if boss_bonus > 0.0 and candidate is Boss:
			score -= boss_bonus

		if candidate == _current:
			score -= sticky_bonus

		if score < best_score:
			best_score = score
			best = candidate

	if best != null:
		_current = best
		_grace_timer = sticky_grace
	elif _grace_timer <= 0.0:
		_current = null
	return best


func has_target() -> bool:
	return get_target() != null


func get_current_target() -> Node2D:
	return _current if is_instance_valid(_current) else null


func get_targets_in_range() -> Array[Node2D]:
	_prune()
	return _candidates.duplicate()


## Point d'interception : où tirer pour toucher une cible en mouvement.
## Renvoie la position brute si la vitesse du projectile est nulle/inconnue.
func get_aim_point(target: Node2D, projectile_speed: float) -> Vector2:
	if target == null or not is_instance_valid(target):
		return global_position
	return predict_intercept(
		global_position, target.global_position, _velocity_of(target), projectile_speed
	)


static func predict_intercept(
	origin: Vector2, target_position: Vector2, target_velocity: Vector2, speed: float
) -> Vector2:
	if speed <= 0.0 or target_velocity == Vector2.ZERO:
		return target_position
	# Deux itérations de point fixe : largement suffisant et sans cas dégénéré.
	var t := (target_position - origin).length() / speed
	for _i in 2:
		t = (target_position + target_velocity * t - origin).length() / speed
	return target_position + target_velocity * t


func _apply_radius() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			(child.shape as CircleShape2D).radius = range_radius
			return


func _on_entered(node: Node) -> void:
	var entity := _resolve_entity(node)
	if entity != null and not _candidates.has(entity):
		_candidates.append(entity)


func _on_exited(node: Node) -> void:
	var entity := _resolve_entity(node)
	if entity != null:
		_candidates.erase(entity)
		if entity == _current:
			_current = null


## Accepte soit l'entité elle-même, soit une hurtbox enfant de l'entité.
func _resolve_entity(node: Node) -> Node2D:
	if node == null:
		return null
	if node.is_in_group(target_group) and node is Node2D:
		return node as Node2D
	var parent := node.get_parent()
	if parent != null and parent.is_in_group(target_group) and parent is Node2D:
		return parent as Node2D
	return null


func _prune() -> void:
	var kept: Array[Node2D] = []
	for candidate in _candidates:
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			kept.append(candidate)
	_candidates = kept
	if _current != null and not _candidates.has(_current):
		_current = null


func _has_line_of_sight(target: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, line_of_sight_mask
	)
	# Des RID, pas des nœuds : `exclude` est typé. Ce chemin n'avait jamais servi
	# avant que la carte ait des obstacles — la visée ne regardait pas les murs.
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


func _health_ratio(node: Node2D) -> float:
	var health := node.get_node_or_null(^"Health") as Health
	return health.get_ratio() if health != null else 1.0


static func _velocity_of(node: Node2D) -> Vector2:
	if node is CharacterBody2D:
		return (node as CharacterBody2D).velocity
	if node is RigidBody2D:
		return (node as RigidBody2D).linear_velocity
	return Vector2.ZERO
