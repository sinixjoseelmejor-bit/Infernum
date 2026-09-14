class_name BossLucifer
extends Boss
## LUCIFER — « L'Étoile du Matin ».
##
## Identité : *lucifer*, « porteur de lumière », nom latin de l'étoile du matin,
## devenu par lecture d'Isaïe celui de l'ange déchu. Boss final, en TROIS phases
## qui racontent la chute : d'abord lumineux et distant, précis, presque calme ;
## puis les ailes brûlent et il fond sur le joueur ; enfin l'Abîme, où les deux
## registres se superposent.
##
## Anti-immobilisation — L'AUBE BRÛLANTE : la couronne de feu n'apparaît pas
## autour du joueur mais À LA DISTANCE OÙ IL SE TIENT, centrée sur Lucifer. Plus
## le joueur recule, plus le cercle qui s'embrase est grand — et plus il est long
## à traverser. Le seul endroit sûr est près de lui.

@export_group("Lucifer")
@export var cross_interval: float = 1.4
@export var cross_speed: float = 300.0
@export var cross_damage: float = 15.0
@export var dive_interval: float = 2.5
@export var dive_speed: float = 780.0
@export var dive_duration: float = 0.4
@export var dive_windup: float = 0.4
@export var ring_count: int = 14
@export var ring_speed: float = 250.0
@export var ring_damage: float = 13.0
@export var abyss_interval: float = 1.6

const RADIANT := Color(1.0, 0.92, 0.6)
const FALLEN := Color(1.0, 0.35, 0.25)

var _cross_angle: float = 0.0
var _ring_timer: float = 0.0
var _diving: bool = false


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			sprite.modulate = Color.WHITE
		1:
			# Les ailes prennent feu.
			sprite.modulate = Color(1.4, 0.75, 0.55)
			move_speed *= 1.25
		2:
			sprite.modulate = Color(1.5, 0.45, 0.45)
			move_speed *= 1.2
			engage_distance *= 0.8


func _run_phase(delta: float) -> void:
	if not is_instance_valid(target):
		return
	match current_phase:
		0:
			strafe_around(330.0, move_speed, delta, true)
			if _attack_timer <= 0.0:
				_attack_timer = cross_interval
				# Croix de lumière, qui pivote d'un tir à l'autre.
				_cross_angle += deg_to_rad(22.0)
				fire_ring(4, cross_speed, cross_damage, _cross_angle)
		1:
			if _attack_timer <= 0.0 and not is_dashing():
				_attack_timer = dive_interval
				_dive()
			_ring_timer = maxf(0.0, _ring_timer - delta)
			if _ring_timer <= 0.0:
				_ring_timer = 2.8
				fire_ring(ring_count, ring_speed, ring_damage, randf() * TAU)
		2:
			if _attack_timer <= 0.0 and not is_dashing():
				_attack_timer = abyss_interval
				_dive()
			_ring_timer = maxf(0.0, _ring_timer - delta)
			if _ring_timer <= 0.0:
				_ring_timer = 1.9
				# Deux anneaux contrarotatifs : il faut lire les interstices.
				_cross_angle += deg_to_rad(13.0)
				fire_ring(ring_count, ring_speed, ring_damage, _cross_angle)
				fire_ring(ring_count, ring_speed * 0.7, ring_damage, -_cross_angle)


func _dive() -> void:
	var destination := predicted_target_position(dive_windup)
	telegraph_at(destination, 120.0, dive_windup, cross_damage, FALLEN)
	_diving = true
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(dive_windup).timeout
	if not is_instance_valid(self) or health.is_dead:
		return
	_diving = false
	dash_toward(destination, dive_speed, dive_duration)


func _update_movement(delta: float) -> void:
	if _diving:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2.0 * delta)
		return
	super(delta)


## L'AUBE BRÛLANTE : le cercle s'embrase exactement là où se tient le joueur.
## Plus il est loin, plus la couronne est vaste — et longue à franchir.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	var zones := clampi(roundi(distance / 55.0), 8, 20)
	telegraph_ring(global_position, zones, distance, 82.0, 1.1, cross_damage, RADIANT)
	GameEvents.request_shake(9.0)
