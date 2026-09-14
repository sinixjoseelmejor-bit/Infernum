class_name ItemData
extends Resource
## Définition d'un objet. Les objets sont déclarés en données dans
## `scripts/items/item_database.gd` : aucun code par objet, sauf effet spécial.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_NAMES := {
	Rarity.COMMON: "Commune",
	Rarity.RARE: "Rare",
	Rarity.EPIC: "Épique",
	Rarity.LEGENDARY: "Légendaire",
}

const RARITY_COLORS := {
	Rarity.COMMON: Color(0.72, 0.72, 0.70),
	Rarity.RARE: Color(0.35, 0.62, 0.95),
	Rarity.EPIC: Color(0.72, 0.38, 0.95),
	Rarity.LEGENDARY: Color(1.0, 0.62, 0.16),
}

## Prix de base en âmes (ajusté ensuite par la vague courante).
const RARITY_BASE_COST := {
	Rarity.COMMON: 25,
	Rarity.RARE: 45,
	Rarity.EPIC: 75,
	# Les légendaires étaient facturés 120 pour une efficacité inférieure aux
	# épiques : à rareté supérieure, le prix doit rester compétitif.
	Rarity.LEGENDARY: 100,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
## Modificateurs additifs, ex. {"damage_pct": 0.18, "move_speed_pct": -0.05}
@export var mods: Dictionary = {}
## Effet scripté (voir scripts/systems/item_effects.gd). Vide = objet pur stats.
@export var special: StringName = &""
## Nombre d'exemplaires cumulables. Les effets spéciaux sont uniques (1).
@export var max_stacks: int = 5
## Coût de déblocage en clés. 0 = disponible dès le départ.
@export var key_cost: int = 0


func get_rarity_name() -> String:
	return RARITY_NAMES[rarity]


func get_rarity_color() -> Color:
	return RARITY_COLORS[rarity]


func get_base_cost() -> int:
	return RARITY_BASE_COST[rarity]
