class_name RangedEnemy
extends Enemy
## Comportement « distance » : le cultiste garde une distance de tir et recule
## si le joueur s'approche trop, ce qui force le joueur à arbitrer entre nettoyer
## la mêlée et aller faire taire les tireurs.

@export_group("Kiting")
## Distance de confort visée.
@export var preferred_distance: float = 320.0
## Zone morte autour de cette distance, pour ne pas osciller.
@export var distance_tolerance: float = 45.0
## Vitesse de recul, en fraction de `move_speed`.
@export var retreat_speed_ratio: float = 0.85
## Il s'immobilise pour tirer : ouvre une fenêtre d'approche pour le joueur.
@export var stop_to_fire: bool = true

@onready var weapon: Weapon = $Weapons/Weapon
@onready var targeting: TargetingSystem = $Targeting

var _projectile_damage_multiplier: float = 1.0


func _ready() -> void:
	super()
	weapon.setup(targeting)
	weapon.damage_multiplier = _projectile_damage_multiplier
	# Pas d'aide à la visée pour les ennemis : c'est au joueur d'esquiver, pas
	# au tireur de rater. La tolérance large est un confort réservé au joueur.
	weapon.aim_hint = Vector2.ZERO


func apply_wave_scaling(health_mult: float, damage_mult: float, speed_mult: float) -> void:
	super(health_mult, damage_mult, speed_mult)
	_projectile_damage_multiplier *= damage_mult


func make_elite() -> void:
	super()
	_projectile_damage_multiplier *= elite_damage_multiplier


func _update_movement(delta: float) -> void:
	if not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
		return

	var offset := target.global_position - global_position
	var distance := offset.length()
	var direction := offset / maxf(distance, 0.001)
	face(direction)

	var desired := Vector2.ZERO
	if distance > preferred_distance + distance_tolerance:
		desired = direction * move_speed
	elif distance < preferred_distance - distance_tolerance:
		desired = -direction * move_speed * retreat_speed_ratio
	elif not stop_to_fire:
		# Strafe perpendiculaire pour rester mobile dans la zone de confort.
		desired = direction.orthogonal() * move_speed * 0.5

	velocity = velocity.move_toward(desired, acceleration * delta)
