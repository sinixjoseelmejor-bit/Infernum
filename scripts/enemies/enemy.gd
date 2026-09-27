class_name Enemy
extends CharacterBody2D
## Ennemi de base : poursuite directe et dégâts au contact (corps-à-corps).
##
## Les variantes de COMPORTEMENT héritent de ce script :
##   - `ranged_enemy.gd` : garde ses distances et tire ;
##   - `dasher_enemy.gd` : charge par à-coups.
## Les variantes de STATISTIQUES (brute tanky) sont de simples scènes réglant
## les exports — inutile de créer une sous-classe pour changer des chiffres.

@export_group("Déplacement")
@export var move_speed: float = 95.0
@export var acceleration: float = 900.0
@export var knockback_friction: float = 1200.0
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0

@export_group("Combat")
@export var contact_damage: float = 8.0
@export var contact_cooldown: float = 0.7
@export var max_health: float = 30.0

@export_group("Mort")
## Planche de mort, commune aux cinq types d'ennemis.
const DEATH_VFX := preload("res://scenes/vfx/mort.tscn")
## Échelle de l'effet, multipliée par celle du corps.
##
## La planche est du pixel art AGRANDI ×4 dans le fichier — vérifié, 100 % des
## blocs de 4×4 y sont uniformes et ça casse à 8 — donc elle est ramenée à sa
## résolution native (1024 × 640) à l'import. Le dessin fait alors 55 × 101 px
## dans une cellule de 128.
##
## À L'ÉCHELLE 1 L'ÂME FAISAIT 101 px pour un imp qui en mesure 40 : la mort
## était plus grande que ce qui mourait, et deux morts côte à côte se
## recouvraient. À 0,5 elle fait 50 px, soit la taille du corps.
##
## UN DEMI N'EST PAS UNE ÉCHELLE FRACTIONNAIRE AU SENS OÙ LE PROJET L'INTERDIT.
## Ce qu'on s'interdit ailleurs — 2,5 sur une source de 16 px — donne des pixels
## de largeurs INÉGALES, un sur deux deux fois plus large que son voisin. Un
## rapport de 1/2 est régulier : chaque pixel affiché vaut exactement deux
## pixels source, partout dans l'image. Ce qu'on perd est du détail, pas de la
## régularité — et sur une âme qui monte, du détail à 50 px, il n'y en a pas.
@export var death_vfx_scale: float = 0.5

@export_group("Récompenses")
@export var soul_value: int = 3
## Chance de lâcher une clé. Réservé aux élites : 0 sur les ennemis normaux.
@export_range(0.0, 1.0, 0.01) var key_chance: float = 0.0
@export_range(0.0, 1.0, 0.01) var heal_chance: float = 0.0

@export_group("Élite")
@export var elite_health_multiplier: float = 4.0
## Combiné à la courbe de dégâts, 1.6 faisait de l'élite un ennemi qui tue en
## une touche en fin de partie : elle doit être une menace, pas une sentence.
@export var elite_damage_multiplier: float = 1.35
@export var elite_scale: float = 1.35
@export var elite_soul_multiplier: int = 2
## 6 % par élite faisaient tomber ~40 clés sur une run allant à la vague 20,
## alors que la Forge entière en coûte 42 : l'arbre se terminait en deux runs.
@export var elite_key_chance: float = 0.02
## Chance qu'une élite laisse un soin. Seules les élites en laissent : un
## ennemi de base est trop nombreux pour porter une ressource de survie.
@export_range(0.0, 1.0, 0.01) var elite_heal_chance: float = 0.08
@export var elite_tint: Color = Color(1.35, 0.75, 1.3)

## LES DEUX ÉTATS que les objets posent sur un ennemi (0.9.2) : la BRÛLURE et
## l'ENTRAVE. Ils vivent ici, sur le corps, et non dans un gestionnaire qui
## parcourrait tous les ennemis : deux cents corps en feu coûtent deux cents
## soustractions, rien de plus.
##
## LA BRÛLURE EST UNE RÉSERVE DE DÉGÂTS, qui se vide d'un quart toutes les
## 0,5 s : 68 % tombent en 2 s, 90 % en 4 s. Chaque coup qui enflamme AJOUTE à
## la réserve au lieu de la remplacer — sans ça, une arme rapide rafraîchirait
## sans cesse la même petite flamme et la brûlure ne vaudrait rien sur elle.
## Chaque pas est un vrai coup — éclair blanc compris, c'est ce qui fait lire
## « il brûle » sur un corps parmi quarante — et 0,5 s est le rythme où cet
## éclair se lit comme un battement plutôt que comme un scintillement.
const TICK_BRULURE := 0.5
const PART_BRULURE_PAR_TICK := 0.25
## Teintes de repos des états, multipliées à celle du corps. Orange pour le
## feu, bleu froid pour l'entrave : on doit lire l'état d'une foule d'un coup
## d'œil, c'est lui qui dit si une synergie travaille.
const TEINTE_FEU := Color(1.3, 0.78, 0.5)
const TEINTE_ENTRAVE := Color(0.7, 0.86, 1.25)

@onready var health: Health = $Health
@onready var sprite: Sprite2D = $Sprite

var target: Node2D
var is_elite: bool = false

var _brulure: float = 0.0
var _brulure_generation: int = 0
var _brulure_auteur: Node = null
var _tick_brulure: float = 0.0
## Vrai le temps d'un pas de brûlure : si ce pas tue, l'ennemi est mort EN
## FEU, même si la réserve vient d'être vidée par ce même pas.
var _pas_de_brulure: bool = false
var _entrave: float = 0.0
var _entrave_restante: float = 0.0
var _tween_flash: Tween

var _knockback: Vector2 = Vector2.ZERO
var _contact_timer: float = 0.0
## Rayon du corps, lu sur sa forme de collision : c'est la marge que
## l'évitement garde autour des obstacles.
var _rayon_corps: float = 16.0


func _ready() -> void:
	add_to_group(Groups.ENEMIES)
	health.max_health = max_health
	health.current = max_health
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
	if is_elite:
		sprite.modulate = elite_tint
	for enfant in get_children():
		var forme := enfant as CollisionShape2D
		if forme != null and forme.shape is CircleShape2D:
			_rayon_corps = (forme.shape as CircleShape2D).radius * absf(scale.x)
			break
	GameEvents.enemy_spawned.emit(self)


## Appelé par le WaveManager AVANT l'entrée dans l'arbre : la montée en
## difficulté est additive côté vague, jamais composée ici.
func apply_wave_scaling(health_mult: float, damage_mult: float, speed_mult: float) -> void:
	max_health *= health_mult
	contact_damage *= damage_mult
	move_speed *= speed_mult


func make_elite() -> void:
	is_elite = true
	max_health *= elite_health_multiplier
	contact_damage *= elite_damage_multiplier
	soul_value *= elite_soul_multiplier
	key_chance = maxf(key_chance, elite_key_chance)
	heal_chance = maxf(heal_chance, elite_heal_chance)
	scale *= elite_scale


func _physics_process(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	_avancer_etats(delta)
	if health.is_dead:
		return
	_update_movement(delta)
	# Les obstacles de la carte : la vitesse VOULUE est déviée le long de ceux
	# qu'on s'apprête à percuter, avant le recul et le glissement.
	if Carte.courante != null and _contourne_obstacles():
		velocity = Carte.courante.contourner(global_position, velocity, _rayon_corps,
			get_instance_id())

	# `velocity` porte ici la vitesse VOULUE. Le recul s'y ajoute uniquement le
	# temps du déplacement, puis on la restaure : l'ajouter durablement le
	# réinjecterait à chaque frame et ferait diverger la vitesse.
	var intent := velocity
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_friction * delta)
	# L'entrave ne touche que le DÉPLACEMENT de l'instant, jamais la vitesse
	# voulue qu'on restaure ensuite : réduite à chaque image, elle se
	# composerait avec l'accélération et figerait l'ennemi bien en dessous de
	# ce qu'annonce l'objet.
	velocity = intent * (1.0 - _entrave) + _knockback
	move_and_slide()
	velocity = intent

	_handle_contact_damage()


## Faut-il contourner les obstacles de la carte en ce moment ?
##
## Oui pour qui les heurte — les boss, eux, n'ont pas la couche du monde dans
## leur masque et passent au travers. Surchargé par le chien, dont la charge est
## un trait annoncé : la dévier mentirait sur ce qu'il a promis.
func _contourne_obstacles() -> bool:
	return (collision_mask & Layers.WORLD) != 0


## Surchargé par les variantes de comportement.
func _update_movement(delta: float) -> void:
	if not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
		return
	var direction := (target.global_position - global_position).normalized()
	velocity = velocity.move_toward(direction * move_speed, acceleration * delta)
	face(direction)


func face(direction: Vector2) -> void:
	if absf(direction.x) > 0.1:
		sprite.flip_h = direction.x < 0.0


func _handle_contact_damage() -> void:
	if _contact_timer > 0.0 or contact_damage <= 0.0:
		return
	for i in get_slide_collision_count():
		var body := get_slide_collision(i).get_collider() as Node2D
		if body == null or not body.is_in_group(Groups.PLAYER):
			continue
		# UNE CIBLE EN PLEINE RUÉE TRAVERSE LES CORPS. Le joueur a retiré la
		# couche des ennemis de son masque le temps du trajet, mais l'ennemi,
		# lui, continue de le voir : sans ce test, traverser une mêlée coûterait
		# un coup à chaque fois et la ruée cesserait d'être une sortie.
		#
		# Elle ne protège QUE du contact. Zones annoncées, projectiles et rayons
		# ne passent pas par ici et touchent comme avant — voir `_lancer_ruee`.
		if body.has_method(&"is_dashing") and body.call(&"is_dashing"):
			continue
		if body.has_method(&"apply_damage"):
			var push: Vector2 = (body.global_position - global_position).normalized() * 220.0
			body.call(&"apply_damage", contact_damage, self, push)
			GameEvents.player_contact_hit.emit(self, contact_damage)
		_contact_timer = contact_cooldown
		return


func apply_damage(amount: float, source: Node = null, impulse: Vector2 = Vector2.ZERO) -> void:
	if not health.take_damage(amount, source):
		return
	_knockback += impulse * (1.0 - knockback_resistance)
	_flash()


func _flash() -> void:
	if _tween_flash != null:
		_tween_flash.kill()
	_tween_flash = create_tween()
	sprite.modulate = Color(3.0, 2.2, 2.2)
	_tween_flash.tween_property(sprite, ^"modulate", _teinte_repos(), 0.12)


# --- États : brûlure et entrave ----------------------------------------------

## Ajoute `reserve` dégâts à brûler. `generation` compte les propagations du
## Feu grégeois : 0 pour un feu allumé par le joueur.
func enflammer(reserve: float, auteur: Node, generation: int = 0) -> void:
	if reserve <= 0.0 or health.is_dead:
		return
	if _brulure <= 0.0:
		_tick_brulure = TICK_BRULURE
		_brulure_generation = generation
	else:
		# Un feu ravivé par le joueur redevient un feu de première main.
		_brulure_generation = mini(_brulure_generation, generation)
	_brulure += reserve
	_brulure_auteur = auteur
	_teinter()


## Retire `part` de la vitesse pendant `duree` secondes. La plus forte entrave
## en cours l'emporte ; elles ne s'additionnent pas — deux sources à 30 % ne
## font pas un ennemi à 60 %.
func entraver(part: float, duree: float) -> void:
	if not _entravable() or health.is_dead:
		return
	_entrave = maxf(_entrave, clampf(part, 0.0, 0.9))
	_entrave_restante = maxf(_entrave_restante, duree)
	_teinter()


func est_en_feu() -> bool:
	return _brulure > 0.0 or _pas_de_brulure


func est_entrave() -> bool:
	return _entrave_restante > 0.0


func get_brulure() -> float:
	return _brulure


func get_generation_feu() -> int:
	return _brulure_generation


## Faut-il laisser l'entrave agir en ce moment ? Non pour les boss et pour une
## charge annoncée (voir `DasherEnemy`) : ralentie, elle tomberait plus court
## que le trait qu'elle a promis, et rien ne doit mentir sur une annonce.
func _entravable() -> bool:
	return not is_in_group(Groups.BOSSES)


func _avancer_etats(delta: float) -> void:
	if _entrave_restante > 0.0:
		_entrave_restante -= delta
		if _entrave_restante <= 0.0 or not _entravable():
			_entrave_restante = 0.0
			_entrave = 0.0
			_teinter()
	if _brulure <= 0.0:
		return
	_tick_brulure -= delta
	if _tick_brulure > 0.0:
		return
	_tick_brulure += TICK_BRULURE
	var coup := minf(_brulure, maxf(_brulure * PART_BRULURE_PAR_TICK, 1.0))
	_brulure -= coup
	var auteur: Node = _brulure_auteur if is_instance_valid(_brulure_auteur) else null
	GameEvents.damage_dealt.emit(coup, global_position, false)
	_pas_de_brulure = true
	apply_damage(coup, auteur, Vector2.ZERO)
	_pas_de_brulure = false
	if _brulure < 0.5 and not health.is_dead:
		_brulure = 0.0
		_teinter()


func _teinte_repos() -> Color:
	var teinte := elite_tint if is_elite else Color.WHITE
	# Les boss gardent leurs propres teintes de phase et d'enragement.
	if is_in_group(Groups.BOSSES):
		return teinte
	if _brulure > 0.0:
		teinte *= TEINTE_FEU
	if _entrave_restante > 0.0:
		teinte *= TEINTE_ENTRAVE
	return teinte


func _teinter() -> void:
	if is_in_group(Groups.BOSSES):
		return
	if _tween_flash != null and _tween_flash.is_running():
		_tween_flash.kill()
	sprite.modulate = _teinte_repos()


## L'ANIMATION DE MORT, la même pour tous les ennemis.
##
## Jusqu'ici un ennemi tué disparaissait dans la même image que son dernier
## éclair de dégâts : rien ne distinguait « il est mort » de « il est sorti du
## champ », et dans une mêlée de quarante corps c'est la seule information qui
## compte. Les planches de mort des packs existaient sans être jouées ; celle-ci
## est dessinée pour le projet et vaut pour les cinq types.
##
## L'EFFET EST MONTÉ SUR LE CONTENEUR et non sur l'ennemi, qui est libéré dans
## la foulée : enfant de lui, il partirait avec lui sans avoir affiché une seule
## image.
##
## Il reprend l'échelle du corps qui tombe, donc une élite (×1,35) meurt plus
## grand qu'un imp. C'est gratuit et c'est juste : ce qui était gros laisse une
## grosse trace.
func _spawn_death_effect() -> void:
	var effet := DEATH_VFX.instantiate() as Node2D
	if effet == null:
		return
	effet.scale = scale * death_vfx_scale
	var conteneur := get_parent()
	if conteneur == null or not is_instance_valid(conteneur):
		return
	conteneur.add_child(effet)
	# La position se pose APRÈS l'entrée dans l'arbre : hors de l'arbre, un nœud
	# n'a pas de parent, donc `global_position` n'y veut rien dire de fiable.
	effet.global_position = global_position


func _on_died(_source: Node) -> void:
	_spawn_death_effect()
	DropSystem.spawn_drops(get_parent(), global_position, soul_value, key_chance, heal_chance)
	GameEvents.enemy_died.emit(self, global_position)
	queue_free()
