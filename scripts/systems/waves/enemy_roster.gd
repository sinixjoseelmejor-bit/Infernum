class_name EnemyRoster
extends Resource
## Les types d'ennemis ordinaires d'une arène et leur tirage pondéré par vague.

@export var entries: Array[EnemySpawnEntry] = []


func is_empty() -> bool:
	return entries.is_empty()


## Tire une scène pour `wave`. `roll` est un nombre uniforme dans [0, 1) : le
## hasard vient de l'appelant, ce qui rend le tirage reproductible en test.
##
## Si aucun type n'est éligible (poids total nul), retombe sur le premier : une
## vague ne doit jamais rester vide faute de roster.
func pick(wave: int, roll: float) -> PackedScene:
	if entries.is_empty():
		return null
	var weights: Array[float] = []
	var total := 0.0
	for entry in entries:
		var weight := entry.weight_at(wave)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return entries[0].scene

	var remaining := roll * total
	for i in entries.size():
		remaining -= weights[i]
		if remaining <= 0.0:
			return entries[i].scene
	return entries[0].scene
