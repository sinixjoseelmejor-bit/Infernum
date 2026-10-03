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
##
## LA FISSURE (0.10.1). Sa première phase ne faisait qu'une chose — un
## écrasement toutes les 2,6 s — et un joueur qui tournait autour de lui n'en
## prenait presque aucun (0,06 coup/s au banc). Une frappe sur trois ouvre
## maintenant une faille : une ligne de zones qui court du colosse vers le
## joueur, chacune un peu après la précédente. Elle ne s'esquive pas en
## courant tout droit, comme l'écrasement, mais en sortant de sa ligne. En
## seconde phase la faille se divise en trois.

@export_group("Golgota")
@export var slam_radius: float = 125.0
## Golgota est le SEUL boss rencontré sans build : à la vague 5 le joueur n'a ni
## armure ni PV bonus, soit environ 85 points de vie. À 20, quatre écrasements le
## tuaient ; à 17, il en faut six. Les boss suivants n'ont pas ce problème.
##
## Il est aussi le PREMIER CONTRÔLE DE BUILD : 3 800 PV et un enragement à 60 s
## (voir la scène). Une arme de départ nue (60 DPS) ne le tue pas avant qu'il
## s'enrage ; cinq ou six objets d'attaque, si. Le joueur qui a dépensé ses âmes
## en vitesse et en ramassage apprend ici qu'il faut construire.
@export var slam_damage: float = 17.0
@export var slam_delay: float = 0.95
@export var slam_interval: float = 2.6
@export var fracture_interval: float = 1.7
@export var skull_ring_interval: float = 3.2
@export var skull_count: int = 12
@export var skull_speed: float = 250.0
@export var skull_damage: float = 12.0
## Le geste qui précède l'anneau de crânes. Sans lui l'anneau partait du corps
## sans prévenir, et c'est au contact — là où la pression pousse le joueur —
## qu'il arrivait le plus vite.
@export var skull_windup: float = 0.45

@export_group("Fissure")
## Une frappe sur `fissure_period` est une fissure.
@export var fissure_period: int = 3
@export var fissure_zones: int = 5
@export var fissure_radius: float = 62.0
@export var fissure_spacing: float = 105.0
## Retard entre deux zones de la faille : elle COURT vers le joueur.
@export var fissure_step: float = 0.1
## Écart des deux failles latérales en seconde phase. À 35°, deux failles
## voisines laissent un passage d'une cinquantaine de pixels à 300 px du
## colosse : on passe entre elles, on ne les traverse pas.
@export var fissure_fan_deg: float = 35.0

var _ring_timer: float = 0.0
var _windup_skulls: float = -1.0


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			teinter_phase(Color.WHITE)
		1:
			# La masse se fend : des crânes s'en échappent.
			teinter_phase(Color(1.25, 0.85, 0.8))
			move_speed *= 1.25


func _run_phase(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# L'anneau de crânes part à la fin de son geste.
	if _windup_skulls >= 0.0:
		_windup_skulls -= delta
		if _windup_skulls < 0.0:
			fire_ring(skull_count, skull_speed, skull_damage, randf() * TAU)
	match current_phase:
		0:
			if _attack_timer <= 0.0:
				_attack_timer = slam_interval
				_attack_step += 1
				if _attack_step % fissure_period == 0:
					_fissure([0.0], true)
				else:
					_slam(predicted_target_position(slam_delay * 0.7))
		1:
			if _attack_timer <= 0.0:
				_attack_timer = fracture_interval
				_attack_step += 1
				if _attack_step % fissure_period == 0:
					_fissure([-fissure_fan_deg, 0.0, fissure_fan_deg], false)
				else:
					# Deux impacts : un anticipé, un décalé pour couper l'esquive.
					_slam(predicted_target_position(slam_delay * 0.7))
					_slam(random_point_around_target(60.0, 170.0))
			_ring_timer = maxf(0.0, _ring_timer - delta)
			if _ring_timer <= 0.0 and _windup_skulls < 0.0:
				_ring_timer = skull_ring_interval
				_windup_skulls = skull_windup
				geste(&"attaque3", skull_windup + 0.2)


func _slam(at: Vector2) -> void:
	geste(&"attaque1", slam_delay)
	telegraph_at(at, slam_radius, slam_delay, slam_damage, Color(0.85, 0.78, 0.68))


## LA FISSURE : une ligne de zones par angle donné (en degrés autour de l'axe
## colosse-joueur), qui part du pied de Golgota et court vers le joueur.
##
## La faille seule vise là où le joueur VA, comme l'écrasement : tracée vers sa
## position du moment, elle manquait toujours celui qui tournait autour du
## colosse. Les trois failles de la seconde phase visent là où il EST : déjà
## larges, anticipées elles faisaient monter la phase de 0,30 à 0,41 coup/s
## au banc — un durcissement, pas une variante.
func _fissure(angles: Array, anticipee: bool) -> void:
	var vise: Vector2 = predicted_target_position(slam_delay * 0.7) if anticipee 		else target.global_position
	var axe := (vise - global_position).normalized()
	if axe == Vector2.ZERO:
		axe = Vector2.RIGHT
	geste(&"attaque2", slam_delay)
	for angle_deg: float in angles:
		var direction := axe.rotated(deg_to_rad(angle_deg))
		for i in fissure_zones:
			telegraph_at(global_position + direction * (110.0 + fissure_spacing * float(i)),
				fissure_radius, slam_delay + fissure_step * float(i), slam_damage,
				Color(0.85, 0.78, 0.68))


## LE CALVAIRE : une couronne de croix se dresse autour du joueur.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	var center: Vector2 = target.global_position
	geste(&"attaque2", 1.05)
	telegraph_ring(center, 7, 155.0, 78.0, 1.05, slam_damage * 0.8, Color(0.9, 0.85, 0.75))
	telegraph_at(center, 95.0, 1.35, slam_damage, Color(0.9, 0.85, 0.75))
	GameEvents.request_shake(7.0)
