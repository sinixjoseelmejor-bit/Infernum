extends Node
## Génération des butins (autoload `DropSystem`).
##
## Les âmes sont la monnaie de run : abondante, dépensée en boutique.
## Les clés sont la monnaie de méta-progression : rare, conservée entre les runs.
## Elles ne tombent que sur les élites — et une est garantie toutes les 5 vagues
## côté WaveManager, pour que la progression ne dépende pas que de la chance.

const SOUL_SCENE := preload("res://scenes/pickups/soul.tscn")
const KEY_SCENE := preload("res://scenes/pickups/key.tscn")

## Une grosse récompense est éclatée en plusieurs orbes, plus lisibles.
const SOULS_PER_ORB := 5
const MAX_ORBS := 6
const SCATTER_RADIUS := 26.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func spawn_drops(container: Node, position: Vector2, soul_value: int, key_chance: float) -> void:
	if container == null or not is_instance_valid(container):
		return
	if soul_value > 0:
		_spawn_souls(container, position, soul_value)
	# Les deux bonus s'ADDITIONNENT. Composés (×1.25 × ×1.35), une malédiction et
	# un pacte de clés se renforçaient l'un l'autre et faisaient exploser le
	# revenu de méta-progression.
	key_chance *= 1.0 + Curses.get_key_chance_bonus() + WaveMods.get_key_chance_bonus()
	if key_chance > 0.0 and _rng.randf() < key_chance:
		_spawn(KEY_SCENE, container, position, 1)


## Récompense garantie (boss) : ne passe pas par le tirage aléatoire.
func spawn_keys(container: Node, position: Vector2, count: int) -> void:
	if container == null or not is_instance_valid(container) or count <= 0:
		return
	for _i in count:
		_spawn(KEY_SCENE, container, position, 1)


func _spawn_souls(container: Node, position: Vector2, total: int) -> void:
	var orbs := clampi(ceili(float(total) / SOULS_PER_ORB), 1, MAX_ORBS)
	var per_orb := total / orbs
	var remainder := total % orbs
	for i in orbs:
		var value := per_orb + (1 if i < remainder else 0)
		if value > 0:
			_spawn(SOUL_SCENE, container, position, value)


func _spawn(scene: PackedScene, container: Node, position: Vector2, value: int) -> void:
	var pickup := scene.instantiate() as Pickup
	if pickup == null:
		return
	pickup.value = value
	pickup.global_position = position + Vector2(
		_rng.randf_range(-SCATTER_RADIUS, SCATTER_RADIUS),
		_rng.randf_range(-SCATTER_RADIUS, SCATTER_RADIUS)
	)
	container.add_child.call_deferred(pickup)
