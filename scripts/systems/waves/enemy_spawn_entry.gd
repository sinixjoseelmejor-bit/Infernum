class_name EnemySpawnEntry
extends Resource
## Un type d'ennemi du roster : sa scène, sa vague d'entrée et son poids de
## tirage, qui dérive (vers le haut ou le bas) à chaque vague écoulée.

@export var scene: PackedScene
@export var min_wave: int = 1
@export var base_weight: float = 10.0
## Ajouté au poids à chaque vague depuis `min_wave`. Négatif : le type s'efface.
@export var weight_drift: float = 0.0
## Pourquoi ce type entre à cette vague — note de conception, lue dans l'inspecteur.
@export_multiline var design_note: String = ""


## Poids de tirage à `wave` : nul avant la vague d'entrée, jamais négatif.
func weight_at(wave: int) -> float:
	if scene == null or wave < min_wave:
		return 0.0
	return maxf(0.0, base_weight + weight_drift * (wave - min_wave))
