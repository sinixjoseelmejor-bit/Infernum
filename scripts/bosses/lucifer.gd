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
## Vitesse de croisière du plongeon. Sa durée n'est plus fixe : il part juste
## assez tôt pour toucher le centre de sa zone quand elle détone (voir
## `Boss.ruee_annoncee`). Elle était de 0,4 s, soit 312 px : plus loin, il
## s'écrasait avant la zone, plus près, il la dépassait.
@export var dive_speed: float = 780.0
## Délai entre la zone rouge et l'impact. 0,4 s jusqu'à la 0.9.3 : IMPOSSIBLE à
## esquiver. Sortir d'une zone de 120 px depuis son centre demande 0,56 s de
## marche à 215 px/s, avant même le temps de réaction. À 0,9 s, il reste un
## tiers de seconde pour réagir.
@export var dive_windup: float = 0.9
## Anticipation de la zone : elle vise là où le joueur sera dans ce délai, en
## suivant sa trajectoire. Gardée à 0,4 s quand l'annonce s'est allongée — à
## 0,9 s, elle aurait visé deux fois plus loin devant lui, et l'annonce plus
## longue n'aurait rien donné à qui continue tout droit.
@export var dive_prediction: float = 0.4
@export var ring_count: int = 14
@export var ring_speed: float = 250.0
@export var ring_damage: float = 13.0
@export var abyss_interval: float = 1.6
## Part des dégâts appliquée à ses PROJECTILES (croix et anneaux), pas à ses
## zones annoncées : −25 % depuis la 0.10.1, à la demande — les anneaux
## contrarotatifs de la troisième phase se lisent mal, et chaque interstice raté
## coûtait trop cher.
@export var projectile_damage_scale: float = 0.75

const CLE_DES_ABYSSES := preload("res://scenes/pickups/abyss_key.tscn")

const RADIANT := Color(1.0, 0.92, 0.6)
const FALLEN := Color(1.0, 0.35, 0.25)

var _cross_angle: float = 0.0
var _ring_timer: float = 0.0
var _diving: bool = false


func _ready() -> void:
	couleur_titre = RADIANT
	super()


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			teinter_phase(Color.WHITE)
		1:
			# Les ailes prennent feu.
			teinter_phase(Color(1.4, 0.75, 0.55))
			move_speed *= 1.25
		2:
			teinter_phase(Color(1.5, 0.45, 0.45))
			move_speed *= 1.2
			engage_distance *= 0.8


func _run_phase(delta: float) -> void:
	if not is_instance_valid(target):
		return
	match current_phase:
		0:
			# 270 px, et non 330 : au-delà de 320 (`engage_distance`) sa jauge se
			# remplit. Tant que la poursuite de base le ramenait vers le joueur,
			# ça ne se voyait pas ; avec la vraie orbite (0.10.1), il forçait le
			# joueur à lui courir après pour ne pas être puni.
			strafe_around(270.0, move_speed, delta, true)
			if _attack_timer <= 0.0:
				_attack_timer = cross_interval
				# Croix de lumière, qui pivote d'un tir à l'autre.
				_cross_angle += deg_to_rad(22.0)
				geste(&"attaque1", 0.45)
				fire_ring(4, cross_speed, cross_damage * projectile_damage_scale, _cross_angle)
		1:
			if _attack_timer <= 0.0 and not is_dashing():
				_attack_timer = dive_interval
				_dive()
			_ring_timer = maxf(0.0, _ring_timer - delta)
			if _ring_timer <= 0.0:
				_ring_timer = 2.8
				geste(&"attaque2", 0.5)
				fire_ring(ring_count, ring_speed, ring_damage * projectile_damage_scale, randf() * TAU)
		2:
			if _attack_timer <= 0.0 and not is_dashing():
				_attack_timer = abyss_interval
				_dive()
			_ring_timer = maxf(0.0, _ring_timer - delta)
			if _ring_timer <= 0.0:
				_ring_timer = 1.9
				# Deux anneaux contrarotatifs : il faut lire les interstices.
				_cross_angle += deg_to_rad(13.0)
				geste(&"attaque2", 0.5)
				fire_ring(ring_count, ring_speed, ring_damage * projectile_damage_scale, _cross_angle)
				fire_ring(ring_count, ring_speed * 0.7, ring_damage * projectile_damage_scale, -_cross_angle)


func _dive() -> void:
	var destination := predicted_target_position(dive_prediction)
	telegraph_at(destination, 120.0, dive_windup, cross_damage, FALLEN)
	geste(&"attaque1", dive_windup)
	_diving = true
	await ruee_annoncee(destination, dive_windup, dive_speed)
	if not is_instance_valid(self):
		return
	_diving = false


func _update_movement(delta: float) -> void:
	if _diving:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2.0 * delta)
		return
	super(delta)


## LA CLÉ DES ABYSSES. Lucifer ne déverrouille rien en mourant : il LAISSE
## TOMBER la clé, et il faut aller la prendre.
##
## La différence n'est pas décorative. Un déverrouillage accordé dans le noir
## pendant l'écran de fin de run ne se fête pas — le joueur lit une ligne de
## texte après coup, s'il la lit. Un objet qui tombe du corps du boss, qu'on voit
## traverser l'arène et qu'on ramasse, est la récompense elle-même.
##
## Elle est posée AVANT `super()`, qui verse les clés ordinaires et déclenche la
## mort : elle sort donc du corps de Lucifer et non d'un cadavre déjà disparu.
##
## Elle n'est pas lâchée deux fois : le profil qui la possède déjà n'en reçoit
## pas d'autre. Rejouer Lucifer dans la boucle rapporte ses clés normales, pas
## une seconde clé sans objet.
func _on_died(source: Node) -> void:
	if not SaveGame.abyss_key:
		var cle := CLE_DES_ABYSSES.instantiate() as Node2D
		cle.global_position = global_position
		# Différé : la mort tombe souvent PENDANT un contact physique (projectile), et
		# ajouter une aire à ce moment-là est refusé par le moteur.
		get_parent().add_child.call_deferred(cle)
	super(source)


## L'AUBE BRÛLANTE : le cercle s'embrase exactement là où se tient le joueur.
## Plus il est loin, plus la couronne est vaste — et longue à franchir.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	var zones := clampi(roundi(distance / 55.0), 8, 20)
	geste(&"attaque3", 1.1)
	telegraph_ring(global_position, zones, distance, 82.0, 1.1, cross_damage, RADIANT)
	GameEvents.request_shake(9.0)
