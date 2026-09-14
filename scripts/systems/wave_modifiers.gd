extends Node
## Pactes de vague (autoload `WaveMods`) : règles qui changent d'une vague — et
## d'une run — à l'autre.
##
## ENTIÈREMENT OPTIONNEL, et à granularité fine : deux pactes sont proposés en
## boutique entre chaque vague, le joueur en prend UN ou refuse. Refuser ne coûte
## rien et ne ferme rien. Contrairement aux malédictions (qui durent toute la
## run), un pacte ne dure qu'une vague : c'est le levier de risque à court terme.
##
## ÉQUILIBRAGE : un seul pacte actif à la fois, récompenses versées dans les
## pools plafonnés habituels, et effacées à la fin de la vague. Comme pour les
## malédictions, la récompense suit le risque MESURÉ : les i-frames du joueur
## bornent les dégâts entrants à 2 coups/seconde, donc les pactes de densité
## (Horde, Nuée d'élites) sont presque gratuits et paient peu, tandis que ceux
## qui augmentent les dégâts par coup (Fureur) paient le plus.

signal offer_changed()
signal modifier_changed(modifier: Dictionary)

const MODIFIERS: Array[Dictionary] = [
	{
		"id": &"volatile", "name": "Chairs volatiles",
		"desc": "Les ennemis explosent à leur mort. Éloignez-vous.",
		"explosive": true,
		"rewards": {"soul_gain_pct": 0.25},
		"danger": 3,
	},
	{
		"id": &"damned_haste", "name": "Célérité damnée",
		"desc": "Ennemis +35 % de vitesse.",
		"enemy_speed": 0.35,
		"rewards": {"soul_gain_pct": 0.30},
		"danger": 3,
	},
	{
		"id": &"horde", "name": "Horde",
		"desc": "+45 % d'ennemis.",
		"spawn_rate": 0.45,
		"rewards": {"soul_gain_pct": 0.15},
		"danger": 3,
	},
	{
		"id": &"carapace", "name": "Carapace",
		"desc": "Ennemis +65 % de PV.",
		"enemy_health": 0.65,
		"rewards": {"soul_gain_pct": 0.30},
		"danger": 2,
	},
	{
		"id": &"fury", "name": "Fureur",
		"desc": "Ennemis +60 % de dégâts.",
		"enemy_damage": 0.60,
		"rewards": {"luck": 1.0, "soul_gain_pct": 0.35},
		"danger": 4,
	},
	{
		"id": &"elite_swarm", "name": "Nuée d'élites",
		"desc": "Trois fois plus d'élites.",
		"elite_mult": 3.0,
		"rewards": {"soul_gain_pct": 0.08},
		"key_chance": 0.35,
		"danger": 4,
	},
	{
		"id": &"fog", "name": "Brouillard de cendre",
		"desc": "Votre portée de ciblage est réduite de 30 %.",
		"rewards": {"range_pct": -0.30, "soul_gain_pct": 0.35},
		"danger": 3,
	},
	{
		"id": &"frenzy", "name": "Frénésie",
		"desc": "Ennemis +25 % de vitesse et +30 % de PV.",
		"enemy_speed": 0.25, "enemy_health": 0.30,
		"rewards": {"soul_gain_pct": 0.22, "luck": 0.5},
		"danger": 3,
	},
]

## Dégâts de l'explosion des chairs volatiles, en fraction des PV max du joueur.
const VOLATILE_DAMAGE_RATIO := 0.12
const VOLATILE_RADIUS := 110.0
## Délai avant détonation : la fenêtre d'esquive du joueur.
const VOLATILE_FUSE := 0.55

var current: Dictionary = {}
var offer: Array[Dictionary] = []

var _by_id: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for mod in MODIFIERS:
		_by_id[mod["id"]] = mod
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.wave_cleared.connect(func(_w: int) -> void: clear_current())


func get_modifier(id: StringName) -> Dictionary:
	return _by_id.get(id, {})


func has_modifier() -> bool:
	return not current.is_empty()


## Tirage de l'offre proposée en boutique. Les pactes les plus dangereux
## n'apparaissent qu'une fois la run lancée.
func roll_offer(wave: int, count: int = 2) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for mod in MODIFIERS:
		if wave < 3 and int(mod.get("danger", 0)) >= 4:
			continue
		pool.append(mod)
	offer = []
	for _i in count:
		if pool.is_empty():
			break
		var picked: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
		pool.erase(picked)
		offer.append(picked)
	offer_changed.emit()
	return offer


func accept(id: StringName) -> void:
	current = get_modifier(id)
	RunState.recompute_stats()
	modifier_changed.emit(current)


func decline() -> void:
	clear_current()


func clear_current() -> void:
	if current.is_empty():
		return
	current = {}
	RunState.recompute_stats()
	modifier_changed.emit(current)


# --- Multiplicateurs consommés par le WaveManager et le DropSystem ---

func get_enemy_health_mult() -> float:
	return 1.0 + float(current.get("enemy_health", 0.0))


func get_enemy_damage_mult() -> float:
	return 1.0 + float(current.get("enemy_damage", 0.0))


func get_enemy_speed_mult() -> float:
	return 1.0 + float(current.get("enemy_speed", 0.0))


func get_spawn_rate_mult() -> float:
	return 1.0 + float(current.get("spawn_rate", 0.0))


func get_elite_mult() -> float:
	return float(current.get("elite_mult", 1.0))


## Additif, comme celui des malédictions (voir `DropSystem`).
func get_key_chance_bonus() -> float:
	return float(current.get("key_chance", 0.0))


func get_reward_mods() -> Dictionary:
	return current.get("rewards", {})


# --- Chairs volatiles -------------------------------------------------------

func _on_enemy_died(_enemy: Node2D, death_position: Vector2) -> void:
	if not bool(current.get("explosive", false)):
		return
	_detonate.call_deferred(death_position)


func _detonate(at: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	# Mèche : l'explosion est télégraphiée, le joueur peut sortir du rayon.
	await tree.create_timer(VOLATILE_FUSE).timeout
	var player := tree.get_first_node_in_group(Groups.PLAYER)
	if player == null or not is_instance_valid(player):
		return
	GameEvents.request_shake(3.0)
	if player.global_position.distance_to(at) > VOLATILE_RADIUS:
		return
	if player.has_method(&"apply_damage"):
		var damage: float = player.health.max_health * VOLATILE_DAMAGE_RATIO
		var push: Vector2 = (player.global_position - at).normalized() * 260.0
		player.call(&"apply_damage", damage, null, push)
