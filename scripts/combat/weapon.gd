class_name Weapon
extends Node2D
## Arme à tir automatique.
##
## L'arme ne connaît pas le joueur : elle interroge un `TargetingSystem` qui lui
## est injecté (`setup()`), ce qui permet de la coller sur n'importe quelle
## entité (tourelle, familier, ennemi tireur).
##
## Les multiplicateurs (`damage_multiplier`, ...) sont le point d'accroche des
## futurs items / upgrades : ne modifiez pas les stats de base.

signal fired(target: Node2D)

@export var projectile_scene: PackedScene
@export var auto_fire: bool = true

@export_group("Stats")
@export var damage: float = 12.0
## Tirs par seconde.
@export var fire_rate: float = 4.0
@export var projectile_speed: float = 720.0
@export var projectile_count: int = 1
@export var spread_deg: float = 8.0
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.05
@export var crit_multiplier: float = 2.0
@export var knockback: float = 140.0
## Distance entre l'entité et le point d'apparition du projectile.
@export var muzzle_offset: float = 20.0

@export_group("Visée")
## Anticipe le déplacement de la cible (tir à l'avance).
@export var lead_target: bool = true
## Auto-correction du projectile en vol, en degrés/seconde. Filet de sécurité
## supplémentaire sur mobile ; 0 = tir purement balistique.
@export var projectile_homing_deg: float = 90.0
@export var rotate_to_target: bool = true
@export var aim_lerp_speed: float = 18.0

## Modificateurs runtime, alimentés par PlayerStats (items, buffs, malédictions).
## Ce sont des POOLS DÉJÀ AGRÉGÉS ET PLAFONNÉS : ne jamais les multiplier entre
## objets ici, l'addition se fait en amont dans PlayerStats.
var damage_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
var count_bonus: int = 0
var flat_damage_bonus: float = 0.0
var crit_chance_bonus: float = 0.0
var crit_damage_bonus: float = 0.0

var targeting: TargetingSystem
## Direction visée fournie par le porteur (déplacement du joueur en général).
var aim_hint: Vector2 = Vector2.ZERO

var _cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if targeting == null:
		targeting = _find_targeting()


func setup(targeting_system: TargetingSystem) -> void:
	targeting = targeting_system


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if targeting == null:
		return

	var target := targeting.get_target(aim_hint)
	if target != null and rotate_to_target:
		var desired := (target.global_position - global_position).angle()
		rotation = lerp_angle(rotation, desired, minf(1.0, aim_lerp_speed * delta))
	elif target == null and aim_hint != Vector2.ZERO and rotate_to_target:
		rotation = lerp_angle(rotation, aim_hint.angle(), minf(1.0, aim_lerp_speed * delta))

	if auto_fire and target != null and _cooldown <= 0.0:
		fire(target)


func get_cooldown_duration() -> float:
	return 1.0 / maxf(0.01, fire_rate * fire_rate_multiplier)


func get_projectile_count() -> int:
	return maxi(1, projectile_count + count_bonus)


## Dégâts d'UN projectile, taxe multishot comprise : le gain total du multishot
## est volontairement sous-linéaire (voir PlayerStats).
func get_projectile_damage() -> float:
	var penalty := PlayerStats.get_projectile_damage_penalty(get_projectile_count())
	return maxf(1.0, (damage + flat_damage_bonus) * damage_multiplier * penalty)


func get_crit_chance() -> float:
	return clampf(crit_chance + crit_chance_bonus, 0.0, 1.0)


func get_crit_multiplier() -> float:
	return maxf(1.0, crit_multiplier + crit_damage_bonus)


## Injecte les statistiques agrégées du joueur. Appelé à chaque objet ramassé.
func apply_stats(stats: PlayerStats) -> void:
	flat_damage_bonus = stats.damage_flat
	damage_multiplier = maxf(0.1, 1.0 + stats.get_damage_pct())
	fire_rate_multiplier = maxf(0.25, 1.0 + stats.get_fire_rate_pct())
	count_bonus = stats.get_projectile_bonus()
	crit_chance_bonus = stats.get_crit_chance()
	crit_damage_bonus = stats.get_crit_damage_pct()


func fire(target: Node2D) -> void:
	if projectile_scene == null or target == null:
		return

	var aim_point := (
		targeting.get_aim_point(target, projectile_speed)
		if lead_target and targeting != null
		else target.global_position
	)
	var base_direction := (aim_point - global_position).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT

	var total := get_projectile_count()
	var spread := deg_to_rad(spread_deg)
	var parent := _projectile_parent()
	var per_projectile_damage := get_projectile_damage()

	for i in total:
		# Éventail centré : un seul projectile part parfaitement droit.
		var offset := 0.0
		if total > 1:
			offset = lerpf(-spread, spread, float(i) / float(total - 1))
		var direction := base_direction.rotated(offset)

		var projectile := projectile_scene.instantiate() as Projectile
		if projectile == null:
			push_error("Weapon: projectile_scene doit hériter de Projectile.")
			return

		var is_crit := _rng.randf() < get_crit_chance()
		projectile.global_position = global_position + direction * muzzle_offset
		projectile.direction = direction
		projectile.speed = projectile_speed
		projectile.damage = per_projectile_damage * (get_crit_multiplier() if is_crit else 1.0)
		projectile.is_crit = is_crit
		projectile.knockback = knockback
		projectile.homing_speed_deg = projectile_homing_deg
		projectile.target = target
		projectile.source = owner if owner != null else self
		parent.add_child(projectile)

	_cooldown = get_cooldown_duration()
	fired.emit(target)


func _projectile_parent() -> Node:
	var containers := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	if not containers.is_empty():
		return containers[0]
	return get_tree().current_scene


## Repli : cherche un TargetingSystem chez le porteur si aucun n'est injecté.
func _find_targeting() -> TargetingSystem:
	var node: Node = owner if owner != null else get_parent()
	while node != null:
		for child in node.get_children():
			if child is TargetingSystem:
				return child as TargetingSystem
		node = node.get_parent()
	return null
