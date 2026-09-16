class_name Health
extends Node
## Composant de points de vie réutilisable (joueur, ennemis, destructibles).
##
## À brancher en enfant d'une entité ; l'entité relaie les dégâts via
## `apply_damage()` et écoute `died`.

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal health_changed(current: float, maximum: float)
signal died(source: Node)

@export var max_health: float = 100.0
## Durée d'invulnérabilité après un coup (i-frames). 0 = désactivé.
@export var invulnerability_time: float = 0.0

var current: float = 0.0
var is_dead: bool = false

var _invuln_timer: float = 0.0


func _ready() -> void:
	current = max_health
	set_process(invulnerability_time > 0.0)


func _process(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)


func is_invulnerable() -> bool:
	return _invuln_timer > 0.0


## Retourne true si les dégâts ont été appliqués.
func take_damage(amount: float, source: Node = null) -> bool:
	if is_dead or amount <= 0.0 or is_invulnerable():
		return false
	current = maxf(0.0, current - amount)
	_invuln_timer = invulnerability_time
	damaged.emit(amount, source)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit(source)
	return true


## Relève l'entité à une fraction de ses PV max, invulnérable un instant : la
## « seconde chance » de la Forge. Ne fait rien sur une entité déjà morte, le
## coup fatal doit être intercepté AVANT `take_damage`.
func revive(ratio: float, invulnerability: float) -> void:
	if is_dead:
		return
	current = clampf(max_health * ratio, 1.0, max_health)
	_invuln_timer = maxf(_invuln_timer, invulnerability)
	healed.emit(current)
	health_changed.emit(current, max_health)


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(max_health, current + amount)
	healed.emit(amount)
	health_changed.emit(current, max_health)


func set_max_health(value: float, keep_ratio: bool = true) -> void:
	var ratio := current / max_health if max_health > 0.0 else 1.0
	max_health = maxf(1.0, value)
	current = max_health * ratio if keep_ratio else minf(current, max_health)
	health_changed.emit(current, max_health)


## Variation de PV max qui reporte le delta sur les PV courants : gagner un objet
## de vie soigne d'autant, en perdre un ne tue jamais (plancher à 1 PV).
func add_max_health(delta: float) -> void:
	if is_equal_approx(delta, 0.0):
		return
	max_health = maxf(1.0, max_health + delta)
	current = clampf(current + delta, 1.0, max_health)
	health_changed.emit(current, max_health)


func get_ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0
