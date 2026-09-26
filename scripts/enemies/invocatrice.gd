class_name Invocatrice
extends Enemy
## L'INVOCATRICE (0.9.2) — elle punit celui qui ignore l'arrière.
##
## Le cultiste pose déjà la question « nettoyer la mêlée ou aller faire taire
## les tireurs ? ». L'invocatrice la rend pressante : tant qu'elle vit, la
## mêlée se RECONSTRUIT. Elle garde ses distances, annonce au sol l'endroit où
## ses imps vont naître, puis les appelle.
##
## TROIS RÈGLES :
##
##   1. SES IMPS NE RAPPORTENT RIEN. Une invocatrice qu'on laisse vivre serait
##      sinon une ferme à âmes, et la bonne stratégie deviendrait de la garder
##      en vie — l'exact contraire de ce qu'elle doit apprendre.
##   2. LA TUER LES RENVOIE EN CENDRE. C'est la récompense d'avoir traversé la
##      foule pour elle : la mêlée qu'elle a bâtie tombe avec elle. En cendre
##      et non en morts — aucune explosion d'objet, aucune Marque, aucun feu
##      propagé ne doit naître d'un corps qu'elle reprend.
##   3. L'APPEL EST ANNONCÉ. Des cercles violets, sans dégâts, marquent les
##      points d'apparition pendant l'incantation — la brique de Lilith quand
##      elle annonce sa téléportation. Rien n'apparaît sans avoir été montré.
##
## Plafonnée à six imps vivants : au-delà, elle incante dans le vide.

const IMP := preload("res://scenes/enemies/imp.tscn")
const TELEGRAPHE := preload("res://scenes/combat/telegraph.tscn")
const VIOLET := Color(0.78, 0.45, 1.0)

@export var distance_confort: float = 380.0
@export var tolerance: float = 50.0
@export var intervalle: float = 7.0
@export var incantation: float = 0.9
@export var par_appel: int = 3
@export var plafond: int = 6

var _minuteur: float = 3.0
var _incante: float = 0.0
var _points: Array[Vector2] = []
var _invoques: Array[Enemy] = []


func _update_movement(delta: float) -> void:
	if not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
		return
	var ecart := target.global_position - global_position
	var distance := ecart.length()
	var direction := ecart / maxf(distance, 0.001)
	face(direction)
	var voulu := Vector2.ZERO
	# Immobile pendant l'incantation : c'est la fenêtre pour aller la chercher.
	if _incante <= 0.0:
		if distance > distance_confort + tolerance:
			voulu = direction * move_speed
		elif distance < distance_confort - tolerance:
			voulu = -direction * move_speed * 0.85
	velocity = velocity.move_toward(voulu, acceleration * delta)


func _physics_process(delta: float) -> void:
	super(delta)
	if health.is_dead:
		return
	if _incante > 0.0:
		_incante -= delta
		if _incante <= 0.0:
			_appeler()
		return
	_minuteur -= delta
	if _minuteur <= 0.0:
		_minuteur = intervalle
		_commencer()


func _vivants() -> int:
	_invoques = _invoques.filter(func(e: Enemy) -> bool:
		return is_instance_valid(e) and not e.is_queued_for_deletion())
	return _invoques.size()


func _commencer() -> void:
	var places := mini(par_appel, plafond - _vivants())
	if places <= 0:
		return
	_incante = incantation
	_points.clear()
	var depart := randf() * TAU
	for i in places:
		_points.append(global_position + Vector2.from_angle(depart + TAU * i / places) * 70.0)
	var bacs := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	var hote: Node = bacs[0] if not bacs.is_empty() else get_parent()
	for p in _points:
		var zone := TELEGRAPHE.instantiate() as Telegraph
		zone.radius = 26.0
		zone.delay = incantation
		zone.damage = 0.0
		zone.shake = 0.0
		zone.color = VIOLET
		hote.add_child(zone)
		zone.global_position = p
	_teinter()


func _appeler() -> void:
	for p in _points:
		var imp := engendrer(IMP, p)
		if imp == null:
			continue
		imp.soul_value = 0
		imp.heal_chance = 0.0
		imp.key_chance = 0.0
		_invoques.append(imp)
	_points.clear()
	_teinter()


func _teinte_repos() -> Color:
	return super() * VIOLET * 1.6 if _incante > 0.0 else super()


func _on_died(source: Node) -> void:
	for imp in _invoques:
		if is_instance_valid(imp) and not imp.is_queued_for_deletion() and not imp.health.is_dead:
			imp.retourner_en_cendre()
	_invoques.clear()
	super(source)
