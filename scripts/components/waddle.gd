class_name Waddle
extends Node
## Démarche procédurale : aucune image d'animation, tout est calculé.
##
## Le composant n'anime QUE le nœud visuel qu'on lui confie, jamais le corps
## physique. La collision reste rigide : l'animation ne peut pas déplacer le
## joueur ni fausser une esquive.
##
## Deux oscillations superposées, toutes deux pilotées par la même phase :
##
##   inclinaison = sin(phase)        → le corps penche d'un côté puis de l'autre
##   rebond      = abs(sin(phase))   → le corps se soulève
##
## Le `abs()` est tout l'intérêt : `sin` a une période de TAU, `abs(sin)` une
## période de PI. Le rebond va donc DEUX FOIS plus vite que l'inclinaison, soit
## un soulèvement par penché — un rebond par pas. C'est ce décalage de fréquence
## qui fait lire « il marche » au lieu de « il se balance ».

## Nœud visuel animé. Laissé vide, le composant prend le premier Node2D frère.
@export var target: Node2D

@export_group("Démarche")
## Pas par seconde à pleine vitesse. Un pas = une demi-période de l'inclinaison.
@export_range(0.0, 12.0, 0.1) var cadence: float = 4.2
@export_range(0.0, 45.0, 0.5) var max_tilt_deg: float = 9.0
@export_range(0.0, 16.0, 0.5) var bounce_height: float = 2.5

@export_group("Calage")
## Hauteur du pivot sous l'origine du sprite. Une démarche pivote aux PIEDS :
## avec un pivot au centre du corps, ce sont les pieds qui partent sur les côtés.
@export var pivot_y: float = 27.0
## Vitesse de retour au neutre à l'arrêt.
@export var settle_speed: float = 12.0

var _phase: float = 0.0
var _base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if target == null:
		target = _find_sibling_sprite()
	if target != null:
		_base_position = target.position


func _find_sibling_sprite() -> Node2D:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null


## `speed_ratio` : vitesse réelle rapportée à la vitesse nominale. La cadence
## suit donc le déplacement — ralenti par un recul, la démarche ralentit aussi.
func advance(delta: float, speed_ratio: float) -> void:
	if target == null:
		return
	if speed_ratio <= 0.01:
		_settle(delta)
		return

	# Un pas = une demi-période, d'où le PI (et non TAU) par pas.
	_phase += delta * cadence * PI * clampf(speed_ratio, 0.0, 1.5)
	var tilt := sin(_phase) * deg_to_rad(max_tilt_deg)
	var bounce := absf(sin(_phase)) * bounce_height

	target.rotation = tilt
	target.position = _base_position + _pivot_compensation(tilt) + Vector2(0.0, -bounce)


## Fait pivoter le sprite autour d'un point situé sous son origine plutôt que
## autour de l'origine elle-même : `position += P - P.tourné(angle)`.
func _pivot_compensation(angle: float) -> Vector2:
	var pivot := Vector2(0.0, pivot_y)
	return pivot - pivot.rotated(angle)


func _settle(delta: float) -> void:
	# On repart de zéro : sin(0) = 0, donc aucun saut visuel à la remise en route.
	_phase = 0.0
	var weight := minf(1.0, settle_speed * delta)
	target.rotation = lerp_angle(target.rotation, 0.0, weight)
	target.position = target.position.lerp(_base_position, weight)
