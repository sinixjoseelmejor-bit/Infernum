extends Node
## Génération des butins (autoload `DropSystem`).
##
## Les âmes sont la monnaie de run : abondante, dépensée en boutique.
## Les clés sont la monnaie de méta-progression : rare, conservée entre les runs.
## Elles ne tombent que sur les élites — et une est garantie toutes les 5 vagues
## côté WaveManager, pour que la progression ne dépende pas que de la chance.

const SOUL_SCENE := preload("res://scenes/pickups/soul.tscn")
const KEY_SCENE := preload("res://scenes/pickups/key.tscn")
const HEAL_SCENE := preload("res://scenes/pickups/heal.tscn")

## Nombre maximal de soins tombés dans une même vague.
##
## POURQUOI UN PLAFOND, ET PAS SEULEMENT UNE PROBABILITÉ. Le nombre d'élites par
## vague passe d'environ 2 à la vague 5 à une quarantaine à la vague 20 : une
## simple chance par élite rendrait le soin vingt fois plus abondant en fin de
## partie qu'au début, c'est-à-dire précisément là où le jeu est censé mordre.
## Le plafond est ce qui empêche le soin de devenir un canal de scaling.
const MAX_HEALS_PER_WAVE := 2

## Une grosse récompense est éclatée en plusieurs orbes, plus lisibles.
const SOULS_PER_ORB := 5
const MAX_ORBS := 6
const SCATTER_RADIUS := 26.0

var _rng := RandomNumberGenerator.new()
var _heals_this_wave: int = 0


func _ready() -> void:
	_rng.randomize()


## Remis à zéro au début de chaque vague par le `WaveManager`.
func reset_wave_budget() -> void:
	_heals_this_wave = 0


func spawn_drops(container: Node, position: Vector2, soul_value: int, key_chance: float,
		heal_chance: float = 0.0) -> void:
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

	# Le soin n'est DÉLIBÉRÉMENT pas multiplié par les malédictions ni les pactes,
	# contrairement aux clés. Ces systèmes sont les canaux de puissance du jeu ;
	# y brancher la survie en ouvrirait un de plus, et celui-là annulerait
	# directement la difficulté qu'ils sont censés ajouter.
	if heal_chance > 0.0 and _heals_this_wave < MAX_HEALS_PER_WAVE 			and _rng.randf() < heal_chance:
		_heals_this_wave += 1
		_spawn(HEAL_SCENE, container, position, 1)


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
