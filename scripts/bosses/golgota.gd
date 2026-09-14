class_name BossGolgota
extends Boss
## GOLGOTA — « Le Mont du Crâne ».
##
## Identité : le Golgotha n'est pas un démon mais un LIEU, le mont du Crâne où
## l'on dressait les croix. Ici c'est un colosse d'ossements et de pierre, lent
## et écrasant, qui ne poursuit pas vraiment : il fait venir le calvaire au
## joueur. Énormes PV, déplacement de statue, dégâts au sol.
##
## Anti-immobilisation — LE CALVAIRE : à saturation, sept croix jaillissent en
## couronne serrée autour du joueur, plus une sous ses pieds. Il n'y a pas de
## « bonne distance » : rester loin ne fait qu'accélérer leur venue. C'est le
## boss qui rend le sol dangereux, pas celui qui court après vous.

@export_group("Golgota")
@export var slam_radius: float = 125.0
## Golgota est le SEUL boss rencontré sans build : à la vague 5 le joueur n'a ni
## armure ni PV bonus, soit environ 85 points de vie. À 20, quatre écrasements le
## tuaient ; à 17, il en faut six. Les boss suivants n'ont pas ce problème.
@export var slam_damage: float = 17.0
@export var slam_delay: float = 0.95
@export var slam_interval: float = 2.6
@export var fracture_interval: float = 1.7
@export var skull_ring_interval: float = 3.2
@export var skull_count: int = 12
@export var skull_speed: float = 250.0
@export var skull_damage: float = 12.0

var _ring_timer: float = 0.0


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			sprite.modulate = Color.WHITE
		1:
			# La masse se fend : des crânes s'en échappent.
			sprite.modulate = Color(1.25, 0.85, 0.8)
			move_speed *= 1.25


func _run_phase(delta: float) -> void:
	if not is_instance_valid(target):
		return
	match current_phase:
		0:
			if _attack_timer <= 0.0:
				_attack_timer = slam_interval
				_slam(predicted_target_position(slam_delay * 0.7))
		1:
			if _attack_timer <= 0.0:
				_attack_timer = fracture_interval
				# Deux impacts : un anticipé, un décalé pour couper l'esquive.
				_slam(predicted_target_position(slam_delay * 0.7))
				_slam(random_point_around_target(60.0, 170.0))
			_ring_timer = maxf(0.0, _ring_timer - delta)
			if _ring_timer <= 0.0:
				_ring_timer = skull_ring_interval
				fire_ring(skull_count, skull_speed, skull_damage, randf() * TAU)


func _slam(at: Vector2) -> void:
	telegraph_at(at, slam_radius, slam_delay, slam_damage, Color(0.85, 0.78, 0.68))


## LE CALVAIRE : une couronne de croix se dresse autour du joueur.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	var center: Vector2 = target.global_position
	telegraph_ring(center, 7, 155.0, 78.0, 1.05, slam_damage * 0.8, Color(0.9, 0.85, 0.75))
	telegraph_at(center, 95.0, 1.35, slam_damage, Color(0.9, 0.85, 0.75))
	GameEvents.request_shake(7.0)
