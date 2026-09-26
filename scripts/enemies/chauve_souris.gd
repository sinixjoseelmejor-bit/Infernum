class_name ChauveSouris
extends Enemy
## LA CHAUVE-SOURIS INFERNALE (0.9.2) — elle punit le joueur qui s'abrite.
##
## Depuis la carte de la 0.9.1, le décor a pris de la place dans le jeu : un
## chevalet, une statue, une rivière de lave arrêtent la foule, et se placer
## derrière est devenu une défense. Rien ne la contournait. La chauve-souris
## VOLE : ni obstacle, ni lave, ni mêlée ne l'arrêtent — son masque ne voit que
## le joueur. Elle ne rend pas le décor inutile, elle rappelle qu'il n'est pas
## un mur.
##
## ELLE ZIGZAGUE. Une approche en ligne droite à cette vitesse serait un
## projectile qu'on esquive d'un pas ; l'oscillation latérale la rend difficile
## à anticiper sans la rendre imprévisible — l'amplitude est fixe, seul le
## déphasage change d'une bête à l'autre. L'auto-visée la trouve quand même,
## c'est au joueur de s'en occuper avant qu'elle arrive.
##
## FRAGILE ET RAPIDE : 14 PV pour 26 à l'imp, 170 de vitesse pour 105. Elle
## tombe au premier tir, mais elle arrive la première.

## Amplitude de l'oscillation, en fraction de la vitesse.
@export var zigzag: float = 0.75
## Pulsation de l'oscillation, en radians par seconde.
@export var pulsation: float = 7.0

var _phase: float = 0.0


func _ready() -> void:
	super()
	_phase = randf() * TAU


func _update_movement(delta: float) -> void:
	if not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
		return
	_phase += pulsation * delta
	var direction := (target.global_position - global_position).normalized()
	# L'oscillation s'éteint au contact : à moins de 60 px elle ferait tourner
	# la bête autour du joueur au lieu de le toucher.
	var proche := clampf(global_position.distance_to(target.global_position) / 160.0, 0.0, 1.0)
	var voulu := direction + direction.orthogonal() * sin(_phase) * zigzag * proche
	velocity = velocity.move_toward(voulu.normalized() * move_speed, acceleration * delta)
	face(direction)
