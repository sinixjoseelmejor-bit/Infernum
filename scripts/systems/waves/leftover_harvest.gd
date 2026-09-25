class_name LeftoverHarvest
extends RefCounted
## La moisson des survivants : ce que rendent les ennemis encore debout quand la
## vague tombe, au prorata des PV qu'on leur a pris.
##
## Filet contre la spirale de la build qui ne tue plus assez vite : sans rien
## changer pour un joueur qui tue tout, puisqu'il n'a pas de survivant. Jamais au
## prix plein, et le taux dépend du personnage. README, « Les survivants rendent
## ce qu'on leur a pris ».
##
## Le reliquat est CUMULÉ d'un ennemi à l'autre : arrondir par ennemi ferait
## disparaître la récolte entière (un imp à moitié entamé vaut 0,75 âme, donc
## zéro après arrondi — quarante fois zéro).

## Âmes entières versées depuis le début de la moisson.
var souls: int = 0
## Ennemis qui ont rendu quelque chose.
var survivors: int = 0
var _fraction: float = 0.0


## Ce qu'un ennemi rend en disparaissant. Lu sur les PV et non sur un compteur
## de dégâts tenu à part : un compteur parallèle finirait par mentir (soins
## d'ennemis, élites redimensionnées après coup).
static func souls_owed(soul_value: float, current_health: float, max_health: float,
		ratio: float) -> float:
	if ratio <= 0.0 or soul_value <= 0.0 or max_health <= 0.0:
		return 0.0
	var damage_share := clampf(1.0 - current_health / max_health, 0.0, 1.0)
	return soul_value * damage_share * ratio


## Ajoute la part d'un ennemi et renvoie les âmes ENTIÈRES à verser tout de suite.
func add(owed: float) -> int:
	if owed <= 0.0:
		return 0
	survivors += 1
	_fraction += owed
	if _fraction < 1.0:
		return 0
	var whole := floori(_fraction)
	_fraction -= float(whole)
	souls += whole
	return whole
