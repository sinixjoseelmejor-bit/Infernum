class_name BeamEnemy
extends Enemy
## L'ŒIL — tireur à rayon, la menace des vagues hautes.
##
## CE QU'IL APPORTE QUE LES AUTRES N'APPORTAIENT PAS. Le cultiste tire des
## traits : ils se lisent un par un et s'esquivent en marchant. L'œil, lui,
## sanctionne l'IMMOBILITÉ. Sa ligne de visée vous suit, se verrouille, et ce
## qui était une position sûre pendant deux secondes devient le seul endroit où
## il ne faut pas être. Dans une arène où l'on tourne en rond en tirant
## automatiquement, c'est la première chose qui punit le fait de se poser.
##
## IL N'A PAS D'ARME au sens du jeu : pas de `Weapon`, pas de projectile, pas de
## `TargetingSystem`. Son attaque est un [LaserBeam], qui vit dans le conteneur
## des projectiles et se débrouille seul une fois lâché. C'est pour ça qu'il
## n'hérite pas de [RangedEnemy], dont tout le code suppose une arme.
##
## SON DÉPLACEMENT EST SA FAIBLESSE. Il se fige pendant toute la charge, visée
## et verrouillage compris, soit plus d'une seconde d'arrêt complet. C'est la
## fenêtre pour lui tomber dessus : un œil qu'on laisse tranquille tire tous les
## `beam_interval`, un œil qu'on charge meurt sans avoir fini de viser. Il ne
## recule pas non plus quand on l'approche — il ne sait pas fuir, il sait
## regarder.

@export_group("Rayon")
@export var beam_scene: PackedScene
## Distance de confort. Plus loin que le cultiste : l'œil tire à travers
## l'arène, il n'a aucune raison de venir au contact.
@export var preferred_distance: float = 430.0
@export var distance_tolerance: float = 60.0
## Portée au-delà de laquelle il ne commence même pas à viser.
@export var beam_range: float = 950.0
## Délai entre deux rayons, charge comprise.
@export var beam_interval: float = 3.4
## Premier tir retardé d'une fraction de l'intervalle : sans ça, deux œils
## apparus ensemble tirent ensemble pour toujours.
@export var beam_initial_delay: float = 1.2
@export var beam_damage: float = 16.0

var _beam_timer: float = 0.0
var _beam: Node2D = null
var _beam_damage_multiplier: float = 1.0


func _ready() -> void:
	super()
	_beam_timer = beam_initial_delay + randf() * beam_interval * 0.35


func apply_wave_scaling(health_mult: float, damage_mult: float, speed_mult: float) -> void:
	super(health_mult, damage_mult, speed_mult)
	_beam_damage_multiplier *= damage_mult


func make_elite() -> void:
	super()
	_beam_damage_multiplier *= elite_damage_multiplier


func _physics_process(delta: float) -> void:
	super(delta)
	_beam_timer = maxf(0.0, _beam_timer - delta)
	if _beam_timer <= 0.0 and not _charge_en_cours() and _cible_a_portee():
		_tirer()


func _charge_en_cours() -> bool:
	return is_instance_valid(_beam)


func _cible_a_portee() -> bool:
	return is_instance_valid(target) \
		and global_position.distance_to(target.global_position) <= beam_range


func _tirer() -> void:
	if beam_scene == null:
		return
	var beam := beam_scene.instantiate() as LaserBeam
	if beam == null:
		return
	beam.global_position = global_position
	beam.source = self
	beam.damage = beam_damage * _beam_damage_multiplier
	_beam = beam
	_conteneur_projectiles().add_child(beam)
	_beam_timer = beam_interval


func _conteneur_projectiles() -> Node:
	var containers := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	return containers[0] if not containers.is_empty() else get_tree().current_scene


## Immobile pendant la charge, sinon il tient sa distance. Il ne recule jamais :
## un œil acculé est un œil mort, et c'est la récompense de celui qui a vu d'où
## partait le rayon.
func _update_movement(delta: float) -> void:
	if not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
		return

	var offset := target.global_position - global_position
	var direction := offset.normalized()
	face(direction)

	if _charge_en_cours():
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2.0 * delta)
		return

	var desired := Vector2.ZERO
	var distance := offset.length()
	if distance > preferred_distance + distance_tolerance:
		desired = direction * move_speed
	elif distance < preferred_distance - distance_tolerance:
		# Il s'écarte de côté plutôt que de reculer : il garde le joueur en vue.
		desired = direction.orthogonal() * move_speed * 0.8
	velocity = velocity.move_toward(desired, acceleration * delta)
