class_name PlayerStats
extends RefCounted
## Agrégation des modificateurs apportés par les objets.
##
## RÈGLES D'ÉQUILIBRAGE — ne pas contourner sans mesurer :
##
## 1. ADDITIF, JAMAIS MULTIPLICATIF ENTRE OBJETS.
##    Deux objets à +25 % de dégâts donnent +50 %, pas ×1.5625. C'est la seule
##    règle qui empêche réellement le scaling exponentiel : sans elle, 10 objets
##    à +25 % donnent ×9.3 au lieu de ×3.5.
## 2. CHAQUE POOL EST PLAFONNÉ. Un stat maxé cesse de scaler : le joueur est
##    poussé à diversifier au lieu d'empiler la même statistique.
## 3. LES PROJECTILES SUPPLÉMENTAIRES SONT TAXÉS (pénalité globale, voir
##    `get_projectile_damage_penalty`). Le multishot est le vecteur classique de
##    DPS exponentiel : ici son gain est sous-linéaire, quel que soit l'objet.
## 4. LE VOL DE VIE EST PLAFONNÉ EN % ET EN SOIN/SECONDE, sinon cadence élevée
##    + multishot = invulnérabilité.
##
## DPS théorique maximum, tous plafonds atteints (~30 objets parfaits) :
## 3.0 (dégâts) × 2.5 (cadence) × 2.08 (multishot) × 2.5 (crit) ≈ ×39.
## Les PV des ennemis montent linéairement : la run reste jouable, pas triviale.

const CAP_DAMAGE_PCT := 2.0        ## +200 %
const CAP_FIRE_RATE_PCT := 1.5     ## +150 %
const CAP_PROJECTILE_BONUS := 4
const CAP_CRIT_CHANCE := 0.60
const CAP_CRIT_DAMAGE_PCT := 1.5   ## multiplicateur crit max = 2.0 + 1.5 = 3.5
const CAP_MOVE_SPEED_PCT := 0.60
const CAP_RANGE_PCT := 0.80
const CAP_LIFESTEAL := 0.08
const CAP_PICKUP_PCT := 3.0
const CAP_SOUL_PCT := 0.75
## L'armure était le SEUL axe de puissance sans plafond : 236 d'armure étaient
## atteignables (70 % de réduction), et les trois objets les plus rentables du
## catalogue étaient défensifs. 160 = 61,5 % de réduction au maximum.
const CAP_ARMOR := 160.0
## La chance n'était bornée que par les plafonds de poids de rareté, en aval.
const CAP_LUCK := 3.0

## Taxe appliquée à chaque projectile supplémentaire (gain total sous-linéaire).
const PROJECTILE_DAMAGE_TAX := 0.35
## Plafond de soin par vol de vie, en fraction des PV max et par seconde.
## 2.5 %/s = 2.5 PV/s à 100 PV, soit ~10 % du pire flux de dégâts entrant
## possible (2 coups/s via les i-frames). À 8 %/s, un seul objet rare annulait
## un tiers des dégâts subis et écrasait toutes les autres options défensives.
const LIFESTEAL_HEAL_CAP_PER_SEC := 0.015

# --- Pools additifs (remplis par les objets) ---
var damage_flat: float = 0.0
var damage_pct: float = 0.0
var fire_rate_pct: float = 0.0
var projectile_bonus: int = 0
var crit_chance: float = 0.0
var crit_damage_pct: float = 0.0
var move_speed_pct: float = 0.0
var max_health_flat: float = 0.0
var armor: float = 0.0
var regen: float = 0.0
var lifesteal_pct: float = 0.0
var pickup_radius_pct: float = 0.0
var range_pct: float = 0.0
var soul_gain_pct: float = 0.0
var luck: float = 0.0

var specials: Dictionary = {}


func clear() -> void:
	damage_flat = 0.0
	damage_pct = 0.0
	fire_rate_pct = 0.0
	projectile_bonus = 0
	crit_chance = 0.0
	crit_damage_pct = 0.0
	move_speed_pct = 0.0
	max_health_flat = 0.0
	armor = 0.0
	regen = 0.0
	lifesteal_pct = 0.0
	pickup_radius_pct = 0.0
	range_pct = 0.0
	soul_gain_pct = 0.0
	luck = 0.0
	specials.clear()


func add_mod(key: String, value: float) -> void:
	match key:
		"damage_flat": damage_flat += value
		"damage_pct": damage_pct += value
		"fire_rate_pct": fire_rate_pct += value
		"projectile_bonus": projectile_bonus += int(value)
		"crit_chance": crit_chance += value
		"crit_damage_pct": crit_damage_pct += value
		"move_speed_pct": move_speed_pct += value
		"max_health_flat": max_health_flat += value
		"armor": armor += value
		"regen": regen += value
		"lifesteal_pct": lifesteal_pct += value
		"pickup_radius_pct": pickup_radius_pct += value
		"range_pct": range_pct += value
		"soul_gain_pct": soul_gain_pct += value
		"luck": luck += value
		_:
			push_warning("PlayerStats : modificateur inconnu '%s'" % key)


# --- Accès plafonnés (toujours passer par ces getters) ---

func get_damage_pct() -> float:
	return minf(damage_pct, CAP_DAMAGE_PCT)


func get_fire_rate_pct() -> float:
	return minf(fire_rate_pct, CAP_FIRE_RATE_PCT)


func get_projectile_bonus() -> int:
	return mini(projectile_bonus, CAP_PROJECTILE_BONUS)


func get_crit_chance() -> float:
	return clampf(crit_chance, 0.0, CAP_CRIT_CHANCE)


func get_crit_damage_pct() -> float:
	return minf(crit_damage_pct, CAP_CRIT_DAMAGE_PCT)


func get_move_speed_pct() -> float:
	return clampf(move_speed_pct, -0.5, CAP_MOVE_SPEED_PCT)


func get_range_pct() -> float:
	return clampf(range_pct, -0.5, CAP_RANGE_PCT)


func get_lifesteal() -> float:
	return clampf(lifesteal_pct, 0.0, CAP_LIFESTEAL)


func get_pickup_radius_pct() -> float:
	return clampf(pickup_radius_pct, 0.0, CAP_PICKUP_PCT)


func get_soul_gain_pct() -> float:
	return clampf(soul_gain_pct, -0.5, CAP_SOUL_PCT)


func get_armor() -> float:
	return clampf(armor, 0.0, CAP_ARMOR)


func get_luck() -> float:
	return clampf(luck, 0.0, CAP_LUCK)


## Réduction de dégâts avec rendements décroissants ET plafonnée :
## 100 armure = 50 %, 160 (plafond) = 61,5 %. Jamais au-delà.
func get_damage_reduction() -> float:
	return get_armor() / (get_armor() + 100.0)


## Taxe multishot : 2 projectiles = ×1.48 de DPS, 5 = ×2.08. Sous-linéaire.
static func get_projectile_damage_penalty(count: int) -> float:
	return 1.0 / (1.0 + PROJECTILE_DAMAGE_TAX * maxf(0.0, count - 1.0))


func has_special(key: StringName) -> bool:
	return specials.has(key)
