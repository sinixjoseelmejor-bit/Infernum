class_name FeuFollet
extends Enemy
## LE FEU FOLLET (0.9.2) — il punit celui qui laisse venir.
##
## Il flotte vers le joueur, s'arrête à portée et S'EMBRASE : une zone annoncée
## se pose sous lui, se remplit, puis détone. Il se consume dans l'explosion.
## C'est la brique des boss — le cercle qui se remplit, le test de distance, le
## recul — posée par un ennemi ordinaire : la difficulté vient du placement et
## jamais d'un coup qu'on ne voit pas venir.
##
## TROIS RÈGLES, et chacune est reprise d'une leçon déjà écrite ailleurs :
##
##   1. LE TUER PENDANT LA MÈCHE ANNULE L'EXPLOSION. C'est la faiblesse qui
##      donne un sens à l'annonce — la leçon de l'Œil, dont le rayon survivait
##      à sa mort et frappait au nom d'un mort (README).
##   2. IL NE RECULE PLUS UNE FOIS EMBRASÉ. La zone est posée où il était ; un
##      tir qui le repousserait l'éloignerait de sa propre explosion, et le
##      dessin mentirait sur l'endroit du coup.
##   3. UNE DÉTONATION N'EST PAS UNE ÉLIMINATION : ni âmes, ni compteur. Il faut
##      l'abattre pour être payé — le laisser exploser ne rapporte rien.
##
## Il flotte : ni décor ni lave ne l'arrêtent, et il traverse la foule sans la
## pousser. Il ne blesse pas au contact ; `contact_damage` porte les dégâts de
## sa détonation, pour hériter sans code de la courbe de vague et de l'élite.

const TELEGRAPHE := preload("res://scenes/combat/telegraph.tscn")
const EXPLOSION := preload("res://scenes/vfx/explosion.tscn")

## Distance au joueur où il s'embrase.
@export var portee_amorce: float = 95.0
@export var rayon_explosion: float = 105.0
## La fenêtre d'esquive : plus longue que les chairs volatiles (0,55 s), qui
## détonent là où l'on vient de tuer, parce qu'ici l'ennemi vient À VOUS.
@export var meche: float = 1.0

var _embrase: bool = false
var _temps_meche: float = 0.0
var _zone: Telegraph = null
var _echelle_sprite := Vector2.ONE


func _update_movement(delta: float) -> void:
	if _embrase:
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
		return
	var ecart := target.global_position - global_position
	if ecart.length() <= portee_amorce:
		_embraser()
		return
	velocity = velocity.move_toward(ecart.normalized() * move_speed, acceleration * delta)
	face(ecart)


func _physics_process(delta: float) -> void:
	super(delta)
	if not _embrase or health.is_dead:
		return
	_temps_meche += delta
	# Il gonfle et pâlit à mesure que la mèche brûle : la zone dit OÙ, lui dit
	# QUAND.
	var p := clampf(_temps_meche / meche, 0.0, 1.0)
	sprite.scale = _echelle_sprite * (1.0 + 0.35 * p + 0.08 * sin(_temps_meche * 30.0))
	if _temps_meche >= meche:
		# La zone détone d'elle-même au même instant ; lui disparaît sans mourir.
		queue_free()



func _embraser() -> void:
	_embrase = true
	_temps_meche = 0.0
	velocity = Vector2.ZERO
	knockback_resistance = 1.0
	_echelle_sprite = sprite.scale
	sprite.modulate = Color(2.2, 1.6, 1.1)
	var zone := TELEGRAPHE.instantiate() as Telegraph
	if zone == null:
		return
	zone.radius = rayon_explosion
	zone.delay = meche
	zone.damage = contact_damage
	zone.knockback = 260.0
	zone.color = Color(0.55, 0.85, 1.0)
	zone.impact_scene = EXPLOSION
	var bacs := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	(bacs[0] if not bacs.is_empty() else get_parent()).add_child(zone)
	zone.global_position = global_position
	_zone = zone


## L'éclair d'un coup reçu revient à la teinte de l'embrasement, pas au blanc.
func _teinte_repos() -> Color:
	return Color(2.2, 1.6, 1.1) if _embrase else super()


## Embrasé, il ne bouge plus : l'entrave n'a plus rien à ralentir, et sa
## teinte bleue couvrirait celle de l'embrasement.
func _entravable() -> bool:
	return super() and not _embrase


func _on_died(source: Node) -> void:
	if is_instance_valid(_zone) and not _zone.is_queued_for_deletion():
		_zone.queue_free()
	_zone = null
	super(source)


## Ses dégâts de contact sont ceux de sa détonation : il ne doit pas en
## infliger en touchant. Son masque ne voit rien, mais la garde coûte une ligne.
func _handle_contact_damage() -> void:
	pass
