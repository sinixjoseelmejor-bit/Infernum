class_name DasherEnemy
extends Enemy
## Comportement « rapide » : le limier approche, se fige brièvement (télégraphe),
## puis charge en ligne droite avant de récupérer.
##
## Le temps d'armement est volontairement lisible : la menace vient de la
## pression au sol, pas d'un coup impossible à esquiver.

enum Phase { APPROACH, WINDUP, DASH, RECOVER }

@export_group("Charge")
@export var dash_trigger_distance: float = 260.0
@export var windup_duration: float = 0.45
@export var dash_speed: float = 620.0
@export var dash_duration: float = 0.32
@export var recover_duration: float = 0.6
## Bonus de dégâts au contact pendant la charge uniquement.
@export var dash_damage_multiplier: float = 1.5

var phase: Phase = Phase.APPROACH

var _phase_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _base_contact_damage: float = 0.0


func _ready() -> void:
	super()
	_base_contact_damage = contact_damage


func _update_movement(delta: float) -> void:
	if not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
		return

	_phase_timer = maxf(0.0, _phase_timer - delta)
	var to_target := target.global_position - global_position

	match phase:
		Phase.APPROACH:
			var direction := to_target.normalized()
			velocity = velocity.move_toward(direction * move_speed, acceleration * delta)
			face(direction)
			if to_target.length() <= dash_trigger_distance:
				_enter(Phase.WINDUP)

		Phase.WINDUP:
			# Immobile et visible : c'est la fenêtre d'esquive du joueur.
			velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2.0 * delta)
			_dash_direction = to_target.normalized()
			face(_dash_direction)
			if _phase_timer <= 0.0:
				_enter(Phase.DASH)

		Phase.DASH:
			velocity = _dash_direction * dash_speed
			if _phase_timer <= 0.0:
				_enter(Phase.RECOVER)

		Phase.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
			if _phase_timer <= 0.0:
				_enter(Phase.APPROACH)


## La charge part en ligne droite, annoncée pendant l'élan : ni l'élan ni la
## charge ne se dévient. Un chien lancé contre une statue s'y arrête.
func _contourne_obstacles() -> bool:
	return super() and phase != Phase.WINDUP and phase != Phase.DASH


func _enter(next: Phase) -> void:
	phase = next
	match next:
		Phase.APPROACH:
			_phase_timer = 0.0
			contact_damage = _base_contact_damage
			sprite.modulate = elite_tint if is_elite else Color.WHITE
		Phase.WINDUP:
			_phase_timer = windup_duration
			contact_damage = _base_contact_damage
			sprite.modulate = Color(1.8, 1.2, 0.6)
		Phase.DASH:
			_phase_timer = dash_duration
			contact_damage = _base_contact_damage * dash_damage_multiplier
		Phase.RECOVER:
			_phase_timer = recover_duration
			contact_damage = _base_contact_damage
			sprite.modulate = elite_tint if is_elite else Color.WHITE


func apply_wave_scaling(health_mult: float, damage_mult: float, speed_mult: float) -> void:
	super(health_mult, damage_mult, speed_mult)
	_base_contact_damage = contact_damage
	dash_speed *= speed_mult


func make_elite() -> void:
	super()
	_base_contact_damage = contact_damage
