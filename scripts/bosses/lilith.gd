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
## Anti-immobilisation — L'APPEL : à saturation, elle se téléporte près du
## joueur et fait surgir quatre lilim tout autour. Prendre ses distances ne
## l'éloigne pas, ça multiplie ce qu'il y a entre elle et vous. Le seul moyen de
## calmer l'arène est de la garder sous le feu.
##
## CE QUI A CHANGÉ EN 0.10.1, et pourquoi :
##
##   - SES SAUTS S'ANNONCENT À L'ARRIVÉE. Le cercle violet marquait l'endroit
##     qu'elle QUITTAIT — l'information inutile — et elle tirait dès qu'elle
##     réapparaissait, à 120 px : sept traits arrivaient en un tiers de seconde,
##     avant qu'on l'ait retrouvée. Le cercle marque maintenant où elle va, elle
##     s'efface, réapparaît, puis lève sa faux avant de tirer.
##   - L'APPEL NE TIRE PLUS À BOUT PORTANT. Elle surgissait à 70 px du joueur
##     et lâchait son anneau dans la même image : un coup impossible à éviter,
##     ce que les boss ne font jamais. Elle surgit à 150 px, et l'anneau part à
##     la fin de son geste.
##   - LA DANSE. Sa première phase ne tirait que des volées de trois traits ;
##     une volée sur quatre devient une spirale à trois bras qui tourne
##     lentement. On la lit et on se glisse entre les bras.

@export_group("Lilith")
@export var add_scene: PackedScene
@export var orbit_distance: float = 290.0
@export var volley_interval: float = 1.5
@export var summon_interval: float = 6.0
@export var summon_count: int = 2
## 2,8 s jusqu'à la 0.10.1. Ses sauts tiraient à bout portant, et une partie de
## ce qu'elle infligeait en Nuit venait de là ; maintenant qu'ils s'annoncent,
## la Nuit tombait de 0,59 à 0,40 coup/s au banc. Sauter plus souvent rend la
## menace sans rendre le coup injuste.
@export var blink_interval: float = 2.3
@export var blink_distance: float = 200.0
@export var bolt_speed: float = 300.0
@export var bolt_damage: float = 13.0
@export var max_lilim: int = 14

@export_group("Saut")
## Durée pendant laquelle le cercle d'arrivée est visible avant qu'elle y soit.
@export var blink_warning: float = 0.35
## Le geste entre la réapparition et la salve.
@export var cast_time: float = 0.3
@export var appel_distance: float = 150.0
@export var appel_windup: float = 0.45

@export_group("Danse")
## Une volée sur `dance_period` est une danse.
@export var dance_period: int = 4
@export var dance_bursts: int = 6
@export var dance_step: float = 0.2
@export var dance_arms: int = 3
@export var dance_turn_deg: float = 22.0

const VIOLET := Color(0.7, 0.45, 1.0)

var _summon_timer: float = 0.0
var _clockwise: bool = true
var _danse: int = 0
var _danse_timer: float = 0.0
var _danse_angle: float = 0.0
var _en_saut: bool = false


func _ready() -> void:
	couleur_titre = VIOLET
	super()
	_summon_timer = summon_interval * 0.5


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			teinter_phase(Color.WHITE)
		1:
			# Elle s'efface dans la nuit : plus rapide, à demi visible. À 0,45
			# d'opacité elle se perdait sur le sol sombre de la carte, au point
			# qu'on ne savait plus où tirer ; 0,6 garde l'idée et la lecture.
			teinter_phase(Color(0.85, 0.75, 1.0, 0.6))
			move_speed *= 1.3
			orbit_distance *= 0.8


func _run_phase(delta: float) -> void:
	if not is_instance_valid(target):
		return

	_summon_timer = maxf(0.0, _summon_timer - delta)
	if _summon_timer <= 0.0:
		_summon_timer = summon_interval
		_summon(summon_count)

	if _en_saut:
		# Disparue : elle ne bouge pas, et la poursuite de base ne doit pas
		# reprendre la main.
		velocity = Vector2.ZERO
		_orbite = true
		return

	if _danse > 0:
		strafe_around(orbit_distance, move_speed * 0.4, delta, _clockwise)
		_danse_timer -= delta
		if _danse_timer <= 0.0:
			_danse_timer = dance_step
			_danse -= 1
			_danse_angle += deg_to_rad(dance_turn_deg)
			fire_ring(dance_arms, bolt_speed * 0.9, bolt_damage, _danse_angle)
		return

	match current_phase:
		0:
			strafe_around(orbit_distance, move_speed, delta, _clockwise)
			if _attack_timer <= 0.0:
				_attack_timer = volley_interval
				_attack_step += 1
				if _attack_step % dance_period == 0:
					_danse = dance_bursts
					_danse_timer = 0.25
					_danse_angle = randf() * TAU
					geste(&"attaque2", 0.25 + dance_step * dance_bursts)
					_attack_timer = volley_interval + dance_step * dance_bursts
				else:
					geste(&"attaque1", 0.45)
					fire_at_target(3, 22.0, bolt_speed, bolt_damage)
				if _attack_step % 3 == 0:
					_clockwise = not _clockwise
		1:
			strafe_around(orbit_distance, move_speed, delta, _clockwise)
			if _attack_timer <= 0.0:
				_attack_timer = blink_interval
				_saut_et_salve(random_point_around_target(120.0, blink_distance))
				_clockwise = not _clockwise


func _vivante() -> bool:
	return is_instance_valid(self) and not health.is_dead and is_instance_valid(target)


## LE SAUT : le cercle marque l'arrivée, elle s'efface, puis réapparaît dedans.
## La zone ne blesse pas (voir `telegraph.gd`) : elle dit seulement où regarder.
func _sauter(to: Vector2) -> void:
	_en_saut = true
	telegraph_at(to, 60.0, blink_warning, 0.0, VIOLET)
	Audio.play(&"teleportation")
	create_tween().tween_property(sprite, ^"self_modulate:a", 0.0, blink_warning * 0.5)
	await get_tree().create_timer(blink_warning, false, true).timeout
	if not is_instance_valid(self):
		return
	global_position = to
	create_tween().tween_property(sprite, ^"self_modulate:a", 1.0, 0.12)
	_en_saut = false
	GameEvents.request_shake(2.5)


func _saut_et_salve(to: Vector2) -> void:
	await _sauter(to)
	if not _vivante():
		return
	geste(&"attaque3", cast_time + 0.25)
	await get_tree().create_timer(cast_time, false, true).timeout
	if not _vivante():
		return
	fire_at_target(7, 70.0, bolt_speed * 1.1, bolt_damage)


func _summon(count: int) -> void:
	if add_scene == null:
		return
	# Plafond dur : l'Appel ne doit pas transformer l'arène en mur infranchissable.
	if get_tree().get_nodes_in_group(Groups.ENEMIES).size() >= max_lilim:
		return
	for _i in count:
		spawn_add(add_scene, random_point_around_target(180.0, 320.0))


## L'APPEL : elle surgit près du joueur, entourée de sa progéniture, et
## l'anneau part à la fin de son geste.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	if _en_saut:
		# Déjà en plein saut : l'Appel attendra qu'elle soit retombée.
		pressure = pressure_max * 0.9
		return
	_appel()


func _appel() -> void:
	await _sauter(target.global_position + Vector2.RIGHT.rotated(randf() * TAU) * appel_distance)
	if not _vivante():
		return
	for i in 4:
		var angle := TAU * float(i) / 4.0
		spawn_add(add_scene, target.global_position + Vector2.RIGHT.rotated(angle) * 130.0)
	geste(&"attaque2", appel_windup + 0.3)
	GameEvents.request_shake(6.0)
	await get_tree().create_timer(appel_windup, false, true).timeout
	if not _vivante():
		return
	fire_ring(10, bolt_speed, bolt_damage, randf() * TAU)
