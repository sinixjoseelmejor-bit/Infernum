class_name DifficultyCurve
extends Resource
## Courbes de difficulté de la piétaille, en fonction du seul numéro de vague.
##
## Fonctions PURES : aucune lecture d'autoload, aucun état. Ce qui dépend de la
## run (Déchaînement, malédictions, pactes) arrive en argument, ce qui permet de
## les vérifier sans lancer de partie — voir `tools/test_waves.gd`.
##
## Hors Déchaînement, toute la montée est LINÉAIRE (additive), jamais composée :
## à la vague 20, un imp a ×3,35 PV, pas ×6,1. Chiffres et raisonnement :
## README, « Vagues » et « L'enfer répond ».

## DÉCHAÎNEMENT : PV ennemis multipliés par ce facteur à CHAQUE vague. Calibré
## sur les DPS mesurés : le joueur mène jusqu'à la trentaine, la courbe le
## rattrape vers la vague 36-38. Premier réglage à bouger après avoir joué —
## c'est le chiffre qui allonge ou raccourcit la course.
const PUISSANCE_DECHAINEE := 1.15
## DÉCHAÎNEMENT : dégâts ennemis, plus doucement. Sans eux la fin de partie
## serait spongieuse — des ennemis qui ne tuent pas font une run qu'on abandonne
## d'ennui, pas une run difficile.
const DEGATS_DECHAINES := 1.08

## DEUX PLAFONDS, dans cet ordre : la courbe de base s'arrête à
## `max_spawns_per_second` / `max_elite_chance`, PUIS les malédictions et les
## pactes multiplient, jusqu'à ×1,5 / ×1,75 de ce plafond.
##
## Un seul plafond appliqué après les options les rendait gratuites en fin de
## partie : la vague normale l'atteignait d'elle-même (élites à 31,5 % dès la
## vague 19), et « Nuée d'élites » versait ses clés sans plus rien coûter.
## README, « Une option doit toujours coûter ».
const MODDED_SPAWN_RATE_CAP_FACTOR := 1.5
## Les élites valent 3 fois plus d'âmes et portent toute la chance de clé : à
## 54 % (l'ancien plafond), une run maudite rapportait ×6 une run normale.
const MODDED_ELITE_CHANCE_CAP_FACTOR := 1.75

@export_group("Rythme des vagues")
@export var wave_base_duration: float = 20.0
@export var wave_duration_growth: float = 2.0
@export var wave_max_duration: float = 45.0

@export_group("Densité")
@export var base_spawns_per_second: float = 0.8
@export var spawns_per_second_growth: float = 0.19
@export var max_spawns_per_second: float = 6.0

@export_group("Difficulté")
## Additif : +10 % des PV de base par vague écoulée. Mesuré à 14 % : la marge du
## joueur restait collée à 0,90 de la vague 6 à la 21 (README, « La passe
## d'équilibrage de la 0.5.0 »).
@export var health_growth: float = 0.10
## Supplément à partir de `late_wave` : fait retomber la marge en fin de run,
## pour qu'elle se conclue au lieu de s'étirer à l'équilibre.
@export var late_health_growth: float = 0.09
@export var late_wave: int = 16
## La courbe qui rend la fin de run dangereuse : les i-frames bornent les coups
## encaissés, seuls les dégâts PAR coup comptent. À 11 %, une brute élite tuait
## en une touche et demie à la vague 20 (README, « Vagues »).
@export var damage_growth: float = 0.095
@export var speed_growth: float = 0.015
@export var max_speed_multiplier: float = 1.35
@export var elite_start_wave: int = 4
@export var elite_chance_growth: float = 0.02
@export var max_elite_chance: float = 0.18


func wave_duration(wave: int) -> float:
	return minf(wave_base_duration + wave_duration_growth * (wave - 1), wave_max_duration)


## `mods_mult` : produit des multiplicateurs de malédiction et de pacte. Ils
## s'appliquent PAR-DESSUS la courbe, qui reste celle de la run de référence.
func spawn_rate(wave: int, mods_mult: float = 1.0) -> float:
	var base := minf(base_spawns_per_second + spawns_per_second_growth * (wave - 1),
		max_spawns_per_second)
	return minf(base * mods_mult, max_spawns_per_second * MODDED_SPAWN_RATE_CAP_FACTOR)


func health_multiplier(wave: int, unleashed: bool) -> float:
	var base := 1.0 + health_growth * (wave - 1)
	if wave >= late_wave:
		base += late_health_growth * (wave - late_wave + 1)
	return base * unleashed_health_factor(wave, unleashed)


func damage_multiplier(wave: int, unleashed: bool) -> float:
	return (1.0 + damage_growth * (wave - 1)) * unleashed_damage_factor(wave, unleashed)


func speed_multiplier(wave: int) -> float:
	return minf(1.0 + speed_growth * (wave - 1), max_speed_multiplier)


## `elites_from_start` : une malédiction avance l'arrivée des élites à la vague 1.
func elite_chance(wave: int, elites_from_start: bool, mods_mult: float = 1.0) -> float:
	var from_wave := 1 if elites_from_start else elite_start_wave
	if wave < from_wave:
		return 0.0
	var base := minf(elite_chance_growth * (wave - from_wave + 1), max_elite_chance)
	return minf(base * mods_mult, max_elite_chance * MODDED_ELITE_CHANCE_CAP_FACTOR)


## Facteurs du Déchaînement, partagés par la piétaille et les boss : le même
## facteur des deux côtés laisse leur rapport identique au régime normal (README,
## « Le Déchaînement s'applique aussi aux boss »).
static func unleashed_health_factor(wave: int, unleashed: bool) -> float:
	return pow(PUISSANCE_DECHAINEE, wave) if unleashed else 1.0


static func unleashed_damage_factor(wave: int, unleashed: bool) -> float:
	return pow(DEGATS_DECHAINES, wave) if unleashed else 1.0
