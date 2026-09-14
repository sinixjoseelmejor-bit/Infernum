class_name BossBaal
extends Boss
## BAAL — « Le Seigneur de l'Orage ».
##
## Identité : divinité cananéenne de l'orage et de la fertilité, « le Seigneur »,
## dont le culte par le feu revient sans cesse dans la Bible hébraïque. Il ne
## court pas après le joueur : il tient ses distances et fait tomber la foudre.
## En phase 2 la pluie devient fournaise — il laisse derrière lui un sillage de
## braise qui ferme peu à peu les trajectoires.
##
## Anti-immobilisation — LE DÉLUGE : c'est le boss qui rend le kiting absurde par
## nature, puisque sa portée est l'arène entière. À saturation, huit éclairs
## tombent d'un coup en couronne autour du joueur. Rester au loin ne met à l'abri
## de rien ; il faut venir le faire taire.

@export_group("Baal")
@export var keep_distance: float = 380.0
@export var bolt_radius: float = 95.0
@export var bolt_delay: float = 0.8
@export var bolt_damage: float = 17.0
@export var storm_interval: float = 1.5
@export var furnace_interval: float = 1.1
@export var ember_interval: float = 0.45
@export var ember_radius: float = 58.0
@export var ember_delay: float = 1.1
@export var ember_damage: float = 9.0
@export var ring_interval: float = 3.0
@export var ring_count: int = 10
@export var ring_speed: float = 265.0
@export var ring_damage: float = 12.0

const LIGHTNING := Color(0.55, 0.8, 1.0)
const FIRE := Color(1.0, 0.5, 0.15)

var _ember_timer: float = 0.0
var _ring_timer: float = 0.0
var _clockwise: bool = true


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			sprite.modulate = Color.WHITE
		1:
			sprite.modulate = Color(1.3, 0.8, 0.55)
			move_speed *= 1.2
			keep_distance *= 0.85


func _run_phase(delta: float) -> void:
	if not is_instance_valid(target):
		return
	strafe_around(keep_distance, move_speed, delta, _clockwise)

	match current_phase:
		0:
			if _attack_timer <= 0.0:
				_attack_timer = storm_interval
				_strike(predicted_target_position(bolt_delay * 0.8))
				_attack_step += 1
				if _attack_step % 4 == 0:
					_clockwise = not _clockwise
		1:
			if _attack_timer <= 0.0:
				_attack_timer = furnace_interval
				_strike(predicted_target_position(bolt_delay * 0.8))

			# Sillage de braise : ferme progressivement les lignes de fuite.
			_ember_timer = maxf(0.0, _ember_timer - delta)
			if _ember_timer <= 0.0:
				_ember_timer = ember_interval
				telegraph_at(global_position, ember_radius, ember_delay, ember_damage, FIRE)

			_ring_timer = maxf(0.0, _ring_timer - delta)
			if _ring_timer <= 0.0:
				_ring_timer = ring_interval
				fire_ring(ring_count, ring_speed, ring_damage, randf() * TAU)


func _strike(at: Vector2) -> void:
	telegraph_at(at, bolt_radius, bolt_delay, bolt_damage, LIGHTNING)


## LE DÉLUGE : la foudre tombe en couronne, là où le joueur se croyait tranquille.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	telegraph_ring(target.global_position, 8, 140.0, 80.0, 0.95, bolt_damage * 0.85, LIGHTNING)
	telegraph_at(target.global_position, 100.0, 1.25, bolt_damage, LIGHTNING)
	GameEvents.request_shake(7.0)
