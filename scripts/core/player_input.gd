extends Node
## Couche d'abstraction des entrées (autoload `PlayerInput`).
##
## Fusionne clavier / manette et joystick virtuel tactile : le joueur ne lit
## jamais `Input` directement, ce qui rend le portage mobile transparent.

const DEAD_ZONE := 0.2

## Écrit par le joystick virtuel de l'UI (voir scripts/ui/virtual_joystick.gd).
var virtual_move := Vector2.ZERO
## Stick droit virtuel (tactile). Le stick droit physique est lu directement.
var virtual_aim := Vector2.ZERO


func get_move_vector(eight_way: bool = false) -> Vector2:
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", DEAD_ZONE)
	# Le tactile prend le dessus s'il est plus expressif que le clavier/manette.
	if virtual_move.length() > v.length():
		v = virtual_move
	v = v.limit_length(1.0)
	if v.length() < DEAD_ZONE:
		return Vector2.ZERO
	if eight_way:
		v = snap_to_eight(v)
	return v


## Visée explicite, indépendante du déplacement. Vide = pas de visée manuelle,
## l'appelant retombe alors sur la direction de course.
##
## C'est ce qui rend le jeu jouable en twin-stick à la manette : l'auto-visée ne
## change pas, mais c'est le stick droit qui lui dit où regarder plutôt que la
## direction dans laquelle on fuit.
func get_aim_vector() -> Vector2:
	var v := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", DEAD_ZONE)
	if v.length() < DEAD_ZONE:
		v = virtual_aim
	if v.length() < DEAD_ZONE:
		return Vector2.ZERO
	return v.normalized()


## Quantifie un vecteur analogique sur 8 directions (N, NE, E, SE, S, SW, W, NW).
static func snap_to_eight(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2.ZERO
	var step := TAU / 8.0
	return Vector2.RIGHT.rotated(snappedf(v.angle(), step)) * v.length()
