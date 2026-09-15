class_name ItemEffects
extends Node
## Effets d'objets qui ne se réduisent pas à un modificateur de statistique.
##
## Chaque effet est explicitement borné. Les deux pièges classiques du genre
## sont neutralisés ici :
##   - l'explosion à la mort ne s'enchaîne pas (pas de réaction en chaîne qui
##     nettoie l'écran depuis un seul kill) ;
##   - le vol de vie est plafonné en soin par seconde, sinon cadence élevée
##     + multishot rendent le joueur intuable.

const EXPLOSION_VFX := preload("res://scenes/vfx/explosion.tscn")
## Largeur utile de la planche d'explosion, en pixels — mesurée sur la boîte
## englobante de ses 29 images, pas lue sur le nom du fichier (une cellule fait
## 120 px mais le dessin n'en occupe que 111).
const EXPLOSION_VFX_CONTENT := 111.0

@export var explosion_radius: float = 135.0
@export var explosion_damage_ratio: float = 0.70
@export var thorns_ratio: float = 0.30

var _player: Player
var _explosion_active: bool = false
var _lifesteal_budget: float = 0.0
var _regen_carry: float = 0.0


func _ready() -> void:
	GameEvents.player_spawned.connect(_on_player_spawned)
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.player_damage_dealt.connect(_on_player_damage_dealt)
	GameEvents.player_contact_hit.connect(_on_player_contact_hit)
	_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player


func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _player.health.is_dead:
		return

	# Le budget de vol de vie se recharge dans le temps : les pics de dégâts ne
	# se convertissent pas intégralement en soin.
	var cap := _player.health.max_health * PlayerStats.LIFESTEAL_HEAL_CAP_PER_SEC
	_lifesteal_budget = minf(_lifesteal_budget + cap * delta, cap)

	var regen := RunState.stats.regen
	if regen > 0.0:
		_regen_carry += regen * delta
		if _regen_carry >= 1.0:
			var whole := floorf(_regen_carry)
			_regen_carry -= whole
			_player.health.heal(whole)


func _on_player_spawned(player: Node2D) -> void:
	_player = player as Player


func _on_player_damage_dealt(amount: float, _target: Node2D) -> void:
	var ratio := RunState.stats.get_lifesteal()
	if ratio <= 0.0 or not is_instance_valid(_player):
		return
	var heal := minf(amount * ratio, _lifesteal_budget)
	if heal <= 0.0:
		return
	_lifesteal_budget -= heal
	_player.health.heal(heal)


func _on_player_contact_hit(attacker: Node2D, amount: float) -> void:
	if not RunState.has_special(&"thorns"):
		return
	if attacker == null or not is_instance_valid(attacker):
		return
	if attacker.has_method(&"apply_damage"):
		attacker.call(&"apply_damage", amount * thorns_ratio, _player, Vector2.ZERO)


func _on_enemy_died(_enemy: Node2D, death_position: Vector2) -> void:
	if not RunState.has_special(&"explode_on_kill"):
		return
	# Garde anti-chaîne : une explosion qui tue ne déclenche pas d'explosion.
	if _explosion_active:
		return
	_explosion_active = true
	_explode(death_position)
	_explosion_active = false


func _explode(at: Vector2) -> void:
	var damage := _get_reference_weapon_damage() * explosion_damage_ratio
	if damage <= 0.0:
		return
	_spawn_explosion_vfx(at)
	GameEvents.damage_dealt.emit(damage, at, false)
	GameEvents.request_shake(3.0)
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var node := enemy as Node2D
		if node == null or node.is_queued_for_deletion():
			continue
		if node.global_position.distance_to(at) > explosion_radius:
			continue
		if node.has_method(&"apply_damage"):
			node.call(&"apply_damage", damage, _player, Vector2.ZERO)


## L'effet est purement décoratif, mais sa TAILLE ne l'est pas : elle est
## calculée depuis `explosion_radius`, pour que le joueur voie la portée réelle
## de l'explosion au lieu de la deviner. Changer le rayon change le dessin.
##
## Il vit dans le conteneur des projectiles : c'est le seau des objets de monde
## éphémères, et la fin de vague le vide — un effet en cours y disparaît, ce qui
## est exactement le comportement voulu.
func _spawn_explosion_vfx(at: Vector2) -> void:
	var containers := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	if containers.is_empty():
		return
	var vfx := EXPLOSION_VFX.instantiate() as Node2D
	if vfx == null:
		return
	containers[0].add_child(vfx)
	vfx.global_position = at
	vfx.scale = Vector2.ONE * (explosion_radius * 2.0 / EXPLOSION_VFX_CONTENT)


## L'explosion suit l'arme principale : elle profite des objets de dégâts, mais
## pas de la cadence ni du multishot — c'est ce qui l'empêche de scaler seule.
func _get_reference_weapon_damage() -> float:
	if not is_instance_valid(_player):
		return 0.0
	var weapons := _player.get_weapons()
	if weapons.is_empty():
		return 0.0
	return weapons[0].get_projectile_damage()
