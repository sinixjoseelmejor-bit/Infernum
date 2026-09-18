extends Node
## Catalogue des personnages jouables (autoload `Characters`).
##
## Trois damnés, trois marchés différents avec l'enfer. Les identités reprennent
## la ligne biblique des boss : ce sont des figures de l'Ancien Testament, prises
## par ce qu'elles ont de plus brut.
##
## ÉQUILIBRAGE — les trois doivent être DIFFÉRENTS et COMPARABLES :
##   - chacun échange de la puissance sur un axe contre une faiblesse sur un
##     autre ; personne n'est meilleur partout ;
##   - les passifs sont tous PLAFONNÉS et alimentent les pools habituels, donc
##     aucun ne crée de canal de scaling parallèle ;
##   - le DPS de départ reste dans une fourchette étroite (38 à 59), l'écart se
##     fait sur la survie et la mobilité, pas sur un multiplicateur caché.

signal selection_changed(character: CharacterData)

const CHARACTERS: Array[Dictionary] = [
	{
		"id": &"cain", "name": "Caïn", "title": "Le Premier Sang",
		"archetype": "Dégâts",
		"desc": "Le premier meurtrier, marqué pour ne jamais mourir et jamais être en paix. "
			+ "Il frappe lourd et lentement, et n'a plus rien à protéger.",
		"color": Color(0.85, 0.22, 0.18),
		"sprite": "res://assets/sprites/characters/cain/cain_idle.png",
		"sprite_walk": "res://assets/sprites/characters/cain/cain_walk.png",
		"sprite_offset": Vector2(0, 3.5), "sprite_scale": 3.0,
		"max_health": 85.0, "move_speed": 215.0, "targeting_range": 340.0,
		"weapon_damage": 19.0, "weapon_fire_rate": 2.9,
		"weapon_projectile_speed": 760.0, "weapon_crit_chance": 0.08,
		"starting_mods": {},
		"passive_name": "La Marque",
		"passive_desc": "+1 % de dégâts par élimination dans la vague en cours, "
			+ "plafonné à +25 %. Remis à zéro à chaque nouvelle vague.",
		"special": &"mark_of_cain",
	},
	{
		"id": &"job", "name": "Job", "title": "L'Éprouvé",
		"archetype": "Survie",
		"desc": "On lui a tout pris pour voir s'il plierait. Il n'a pas plié. "
			+ "Il encaisse ce que les autres esquivent, mais frappe sans conviction.",
		"color": Color(0.55, 0.72, 0.85),
		"sprite": "res://assets/sprites/characters/job/job_idle.png",
		"sprite_walk": "res://assets/sprites/characters/job/job_walk.png",
		"sprite_offset": Vector2(0, 2.5), "sprite_scale": 3.0,
		"max_health": 130.0, "move_speed": 218.0, "targeting_range": 355.0,
		"weapon_damage": 12.0, "weapon_fire_rate": 3.5,
		"weapon_projectile_speed": 700.0, "weapon_crit_chance": 0.05,
		"starting_mods": {"armor": 12.0},
		"passive_name": "La Patience",
		"passive_desc": "Régénère 1.4 PV par seconde, mais uniquement après "
			+ "3 secondes sans avoir été touché.",
		"special": &"patience",
		# Le seul a toucher la moisson des survivants a taux PLEIN : user une
		# foule sans l'achever est ce qu'il fait, et c'est ce que la moisson
		# paie. Les deux autres restent a 0,25.
		"leftover_ratio": 0.5,
	},
	{
		"id": &"loth", "name": "Loth", "title": "Le Fuyard",
		"archetype": "Mobilité",
		"desc": "Il a quitté la ville en flammes sans se retourner — contrairement à sa femme. "
			+ "Rapide, léger, incapable de tenir une ligne : il tire vite et de près.",
		"color": Color(0.95, 0.85, 0.5),
		"sprite": "res://assets/sprites/characters/loth/loth_idle.png",
		"sprite_walk": "res://assets/sprites/characters/loth/loth_walk.png",
		"sprite_offset": Vector2(0, 2.5), "sprite_scale": 3.0,
		"max_health": 80.0, "move_speed": 288.0, "targeting_range": 300.0,
		"weapon_damage": 9.0, "weapon_fire_rate": 5.2,
		"weapon_projectile_speed": 820.0, "weapon_crit_chance": 0.05,
		# Il ramassait de plus loin ; ça ne rapportait rien (voir Aimant d'âmes).
		# Le fuyard fait main basse sur ce qu'il trouve : plus d'âmes.
		"starting_mods": {"soul_gain_pct": 0.10},
		"dash": true,
		"passive_name": "Ne pas se retourner",
		# La fiche doit dire les DEUX moitiés du passif. Une ruée qu'on découvre
		# en appuyant au hasard sur les touches n'est pas une surprise, c'est une
		# fonction que la plupart des joueurs n'utiliseront jamais.
		"passive_desc": "+20 % de cadence de tir tant qu'il se déplace. "
			+ "Le bonus tombe dès qu'il s'arrête.
"
			+ "RUÉE (Espace / A) : il traverse les corps sur 240 px. "
			+ "Ni les zones ni les tirs ne l'épargnent pour autant.",
		"special": &"never_look_back",
	},
]

## Plafonds des passifs, lus par `character_effects.gd`.
const MARK_PER_KILL := 0.01
const MARK_MAX := 0.25
const PATIENCE_DELAY := 3.0
const PATIENCE_REGEN := 1.4
const FLIGHT_FIRE_RATE := 0.20

## LA RUÉE DE LOTH. Trois chiffres, et chacun répond à une question précise.
##
## LA DISTANCE se lit sur ce qu'elle doit permettre de quitter, pas sur une
## impression : les zones annoncées du jeu font 78 à 135 px de rayon, et la
## couronne du Calvaire de Golgota est posée à 155 px du joueur. 1090 x 0,22 =
## 240 px sortent de n'importe laquelle d'entre elles, couronne comprise. À
## 137 px — la première valeur essayée — la ruée ne quittait même pas un
## écrasement de Golgota, donc elle ne servait à rien contre ce qui tue.
##
## LA DURÉE est courte exprès. Une ruée longue est une ruée pendant laquelle on
## ne tire plus et on ne corrige plus sa trajectoire : au-delà d'un quart de
## seconde elle cesse d'être une esquive pour devenir un déplacement.
##
## LA RECHARGE est le vrai bouton d'équilibrage. À 2,2 s elle donne une
## quinzaine de ruées par vague de 35 s — assez pour que ce soit un outil et non
## un événement, trop peu pour traverser en permanence.
const DASH_SPEED := 1090.0
const DASH_TIME := 0.22
const DASH_COOLDOWN := 2.2

var selected_id: StringName = &"cain"

var _catalog: Dictionary = {}
var _order: Array[StringName] = []


func _ready() -> void:
	for entry in CHARACTERS:
		var character := CharacterData.new()
		character.id = entry["id"]
		character.display_name = entry["name"]
		character.title = entry["title"]
		character.archetype = entry["archetype"]
		character.description = entry["desc"]
		character.color = entry["color"]
		if ResourceLoader.exists(entry["sprite"]):
			character.sprite_idle = load(entry["sprite"])
			character.portrait = _first_frame(character.sprite_idle)
		var walk_path: String = entry.get("sprite_walk", "")
		if walk_path != "" and ResourceLoader.exists(walk_path):
			character.sprite_walk = load(walk_path)
		character.sprite_offset = entry.get("sprite_offset", Vector2.ZERO)
		character.sprite_scale = entry.get("sprite_scale", 1.0)
		character.max_health = entry["max_health"]
		character.move_speed = entry["move_speed"]
		character.targeting_range = entry["targeting_range"]
		character.weapon_damage = entry["weapon_damage"]
		character.weapon_fire_rate = entry["weapon_fire_rate"]
		character.weapon_projectile_speed = entry["weapon_projectile_speed"]
		character.weapon_crit_chance = entry["weapon_crit_chance"]
		character.starting_mods = entry.get("starting_mods", {})
		character.passive_name = entry.get("passive_name", "")
		character.passive_description = entry.get("passive_desc", "")
		character.special = entry.get("special", &"")
		character.dash = entry.get("dash", false)
		character.leftover_ratio = entry.get("leftover_ratio", 0.25)
		_catalog[character.id] = character
		_order.append(character.id)

	SaveGame.profile_changed.connect(_on_profile_changed)
	_on_profile_changed(SaveGame.active_slot)


## Vignette : première image de la bande, RECADRÉE SUR LE PERSONNAGE.
##
## Les planches dessinent une figure d'une vingtaine de pixels au milieu d'une
## image de 100 : afficher la région entière, c'est afficher 95 % de vide et un
## personnage illisible. On mesure donc la zone opaque au chargement plutôt que
## de saisir un cadrage à la main pour chaque personnage.
func _first_frame(sheet: Texture2D) -> Texture2D:
	if sheet == null:
		return null
	var side := sheet.get_height()
	if sheet.get_width() <= side:
		return sheet
	var region := Rect2i(0, 0, side, side)
	var image := sheet.get_image()
	if image != null:
		var used := image.get_region(region).get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			region = used.grow(2).intersection(Rect2i(0, 0, side, side))
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(region)
	return atlas


## Chaque profil retient son propre dernier personnage joué.
func _on_profile_changed(_slot: int) -> void:
	var remembered := SaveGame.last_character
	if remembered != &"" and _catalog.has(remembered):
		selected_id = remembered
		selection_changed.emit(get_selected())


func get_all() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for id in _order:
		result.append(_catalog[id])
	return result


func get_character(id: StringName) -> CharacterData:
	return _catalog.get(id)


func get_selected() -> CharacterData:
	var character: CharacterData = _catalog.get(selected_id)
	if character == null and not _order.is_empty():
		character = _catalog[_order[0]]
	return character


func select(id: StringName) -> void:
	if not _catalog.has(id) or id == selected_id:
		return
	selected_id = id
	SaveGame.set_last_character(id)
	selection_changed.emit(get_selected())


func has_special(key: StringName) -> bool:
	var character := get_selected()
	return character != null and character.special == key
