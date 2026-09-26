class_name BossLilith
extends Boss
## LILITH — « La Première Nuit ».
##
## Identité : première femme d'Adam dans le folklore hébraïque, partie plutôt que
## se soumettre, devenue démone de la nuit et mère des lilim. Insaisissable, elle
## ne se bat presque jamais de front : elle tourne autour du joueur, envoie sa
## progéniture, et disparaît dans le noir. En phase 2 elle devient à demi
## invisible et se téléporte.
##
## Anti-immobilisation — L'APPEL : à saturation, elle se téléporte SUR le joueur
## et fait surgir quatre lilim tout autour. Prendre ses distances ne l'éloigne
## pas, ça multiplie ce qu'il y a entre elle et vous. Le seul moyen de calmer
## l'arène est de la garder sous le feu.

@export_group("Lilith")
@export var add_scene: PackedScene
@export var orbit_distance: float = 290.0
@export var volley_interval: float = 1.5
@export var summon_interval: float = 6.0
@export var summon_count: int = 2
@export var blink_interval: float = 2.8
@export var blink_distance: float = 200.0
@export var bolt_speed: float = 300.0
@export var bolt_damage: float = 13.0
@export var max_lilim: int = 14

var _summon_timer: float = 0.0
var _clockwise: bool = true


func _ready() -> void:
	super()
	_summon_timer = summon_interval * 0.5


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			sprite.modulate = Color.WHITE
		1:
			# Elle s'efface dans la nuit : plus rapide, à peine visible.
			sprite.modulate = Color(0.85, 0.75, 1.0, 0.45)
			move_speed *= 1.3
			orbit_distance *= 0.8


func _run_phase(delta: float) -> void:
	if not is_instance_valid(target):
		return

	_summon_timer = maxf(0.0, _summon_timer - delta)
	if _summon_timer <= 0.0:
		_summon_timer = summon_interval
		_summon(summon_count)

	match current_phase:
		0:
			strafe_around(orbit_distance, move_speed, delta, _clockwise)
			if _attack_timer <= 0.0:
				_attack_timer = volley_interval
				fire_at_target(3, 22.0, bolt_speed, bolt_damage)
				_attack_step += 1
				if _attack_step % 3 == 0:
					_clockwise = not _clockwise
		1:
			strafe_around(orbit_distance, move_speed, delta, _clockwise)
			if _attack_timer <= 0.0:
				_attack_timer = blink_interval
				_blink(random_point_around_target(120.0, blink_distance))
				fire_at_target(7, 70.0, bolt_speed * 1.1, bolt_damage)
				_clockwise = not _clockwise


func _blink(to: Vector2) -> void:
	telegraph_at(global_position, 60.0, 0.25, 0.0, Color(0.7, 0.45, 1.0))
	global_position = to
	Audio.play(&"teleportation")
	GameEvents.request_shake(2.5)


func _summon(count: int) -> void:
	if add_scene == null:
		return
	# Plafond dur : l'Appel ne doit pas transformer l'arène en mur infranchissable.
	if get_tree().get_nodes_in_group(Groups.ENEMIES).size() >= max_lilim:
		return
	for _i in count:
		spawn_add(add_scene, random_point_around_target(180.0, 320.0))


## L'APPEL : elle apparaît sur le joueur, entourée de sa progéniture.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	_blink(target.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 70.0)
	fire_ring(10, bolt_speed, bolt_damage, randf() * TAU)
	for i in 4:
		var angle := TAU * float(i) / 4.0
		spawn_add(add_scene, target.global_position + Vector2.RIGHT.rotated(angle) * 130.0)
	GameEvents.request_shake(6.0)
