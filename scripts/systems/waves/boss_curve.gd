class_name BossCurve
extends Resource
## Mise à l'échelle des boss : leur palier, puis le renforcement de la boucle.
##
## Les boss sont des CONTRÔLES DE BUILD : chaque scène fixe ses PV et son
## `enrage_time` pour qu'un DPS insuffisant fasse durer le combat jusqu'à
## l'enragement. Cette courbe leur rend la durée pour laquelle leurs patterns
## sont écrits. README, « Boss — un palier toutes les 5 vagues ».

## PV : +9 % par vague écoulée depuis le premier palier. Sans cela, Asmodée et
## Lucifer tombaient en 4 s sans jamais atteindre leur phase 2.
@export var wave_health_growth: float = 0.09

@export_group("Rencontres répétées")
## Au-delà du dernier boss, le roster reboucle. Renforcement PAR TOUR de boucle :
## les PV allongent le combat, les dégâts et la cadence le rendent plus dur.
## README, « La boucle repartait du boss le plus faible ».
@export var repeat_health_growth: float = 0.45
@export var repeat_damage_growth: float = 0.20
## Les intervalles se resserrent, le préavis des zones annoncées ne bouge pas.
@export var repeat_attack_growth: float = 0.15
## CALCULÉ, pas choisi : à ×1,25, Baal reste sous les 2,5 coups par seconde que
## bornent les i-frames du joueur. À ×1,30 son combat cessait d'être esquivable.
@export var repeat_attack_max: float = 1.25


## Met `boss` à l'échelle de `wave`, AVANT son entrée dans l'arbre.
##
## `loops` compte les tours de roster déjà bouclés (0 au premier passage).
## `floor_health` est le réservoir de scène du dernier boss du roster : en
## boucle, aucun boss ne descend dessous — un PLANCHER, pas un remplacement.
func apply(boss: Boss, wave: int, loops: int, floor_health: float,
		first_boss_wave: int, curve: DifficultyCurve, unleashed: bool) -> void:
	boss.max_health = health(boss.max_health, floor_health, wave, loops, first_boss_wave, unleashed)
	var threat := threat_multiplier(wave, first_boss_wave, curve, unleashed)
	var repeat_damage := repeat_damage_factor(loops)
	boss.contact_damage *= threat * repeat_damage
	boss.attack_damage_multiplier = threat * repeat_damage
	boss.attack_speed_multiplier = attack_speed_multiplier(loops)


func health(scene_health: float, floor_health: float, wave: int, loops: int,
		first_boss_wave: int, unleashed: bool) -> float:
	var base := scene_health
	if loops > 0:
		base = maxf(base, floor_health)
	var elapsed := float(wave - first_boss_wave)
	var result := base * (1.0 + wave_health_growth * elapsed)
	result *= DifficultyCurve.unleashed_health_factor(wave, unleashed)
	return result * (1.0 + repeat_health_growth * loops)


## Les dégâts d'un boss dans l'unité du jeu : le coup de référence, qui grandit
## de `damage_growth` à chaque vague. Les valeurs écrites dans chaque boss sont
## calibrées sur le premier palier, et ce facteur les y ramène. Avant lui, une
## attaque de Lucifer vague 25 valait 0,55 coup, un marteau de Golgota vague 5
## en valait 1,7.
func threat_multiplier(wave: int, first_boss_wave: int, curve: DifficultyCurve,
		unleashed: bool) -> float:
	var reference := 1.0 + curve.damage_growth * (first_boss_wave - 1)
	var base := (1.0 + curve.damage_growth * maxf(0.0, wave - 1.0)) / reference
	return base * DifficultyCurve.unleashed_damage_factor(wave, unleashed)


func repeat_damage_factor(loops: int) -> float:
	return 1.0 + repeat_damage_growth * loops


func attack_speed_multiplier(loops: int) -> float:
	return minf(1.0 + repeat_attack_growth * loops, repeat_attack_max)
