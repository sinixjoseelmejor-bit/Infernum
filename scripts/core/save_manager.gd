extends Node
## Progression persistante (autoload `SaveGame`), répartie en PROFILS.
##
## Trois emplacements indépendants, chacun avec ses clés, ses déblocages de Forge
## et ses statistiques.
##
## LA FORGE EST PAR PERSONNAGE, les objets sont par profil. Ce n'est pas une
## incohérence : un nœud de Forge modifie les statistiques de celui qui le porte,
## donc l'investir dans Caïn est un choix qui doit coûter quelque chose ; un
## objet débloqué, lui, entre au CATALOGUE de la boutique, et un catalogue qui
## dépendrait du personnage rendrait les tirages incompréhensibles. Changer de profil ou en effacer un permet de repartir de
## zéro sans perdre une progression existante — c'est le seul moyen de
## « recommencer », puisque les clés sont irréversibles au sein d'un profil.
##
## Un fichier par profil (`user://infernum_profile_N.cfg`) plus un index
## (`user://infernum_profiles.cfg`) qui retient l'emplacement actif.

signal keys_changed(total: int)
signal item_unlocked(id: StringName)
signal profile_changed(slot: int)

const PROFILE_COUNT := 3
const INDEX_PATH := "user://infernum_profiles.cfg"

var active_slot: int = 0
## Le nom par défaut s'écrit dans la sauvegarde dans la langue du moment
## (« Profil 1 ») : il est relu dans celle du joueur, un nom choisi reste tel quel.
var profile_name: String = "":
	get: return nom_affiche(active_slot, profile_name)
var banked_keys: int = 0
var best_wave: int = 0
var total_runs: int = 0
var last_character: StringName = &""

## Déblocages d'objets, communs au profil.
var _unlocked: Dictionary = {}

## Nœuds de Forge, PAR PERSONNAGE : { "cain": { &"forge_ember": true } }.
var _forge: Dictionary = {}

## Déchaînement armé, PAR PERSONNAGE : { "cain": true }.
##
## C'est un réglage de Forge et non un choix de run, parce que c'est à la Forge
## qu'on l'arme. Il persiste donc, comme un nœud. Caïn peut être déchaîné pendant
## que Job reste bridé — c'est la même logique que l'arbre lui-même : ce qu'on
## investit dans un personnage ne déborde pas sur les autres.
var _dechaine: Dictionary = {}

## La CLÉ DES ABYSSES est-elle en possession du profil ?
##
## Ce n'est pas « Lucifer est mort » : c'est « la clé a été ramassée ». La
## nuance est le sujet — Lucifer la LAISSE TOMBER, et il faut aller la prendre.
## Un déverrouillage qui s'accorde dans le noir pendant l'écran de fin ne se
## fête pas ; un objet qu'on voit tomber et qu'on va chercher, si.
var abyss_key: bool = false

## Cinématiques déjà vues : { &"le_pari": true }. PASSER une cinématique la
## compte comme vue — la reproposer à chaque partie punirait justement celui
## qui a choisi de ne pas la regarder.
var _story_seen: Dictionary = {}

## LES TROIS SCEAUX, un par damné : { "cain": true }. Un sceau se brise quand CE
## personnage abat Lucifer. Les trois brisés, le portail vers Hélel s'ouvre —
## le pari ne se rompt qu'à trois, parce qu'il portait sur les trois.
var _seals: Dictionary = {}


func _ready() -> void:
	var index := ConfigFile.new()
	if index.load(INDEX_PATH) == OK:
		active_slot = clampi(int(index.get_value("index", "active_slot", 0)), 0, PROFILE_COUNT - 1)
	load_profile(active_slot, false)


# --- Profils -----------------------------------------------------------------

static func get_profile_path(slot: int) -> String:
	return "user://infernum_profile_%d.cfg" % slot


static func get_default_name(slot: int) -> String:
	return TranslationServer.translate("Profil %d") % (slot + 1)


## Un nom par défaut, écrit dans n'importe quelle langue du jeu, se lit dans la
## langue du joueur.
static func nom_affiche(slot: int, nom: String) -> String:
	for defaut in ["Profil %d", "Profile %d"]:
		if nom == defaut % (slot + 1):
			return get_default_name(slot)
	return nom


func profile_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_profile_path(slot))


## Lit un profil SANS l'activer : sert à afficher la liste dans le menu.
func get_profile_summary(slot: int) -> Dictionary:
	var summary := {
		"slot": slot,
		"exists": profile_exists(slot),
		"name": get_default_name(slot),
		"keys": 0, "best_wave": 0, "total_runs": 0, "forge_nodes": 0,
	}
	if not summary["exists"]:
		return summary
	var config := ConfigFile.new()
	if config.load(get_profile_path(slot)) != OK:
		return summary
	summary["name"] = nom_affiche(slot, config.get_value("meta", "profile_name", get_default_name(slot)))
	summary["keys"] = config.get_value("meta", "banked_keys", 0)
	summary["best_wave"] = config.get_value("meta", "best_wave", 0)
	summary["total_runs"] = config.get_value("meta", "total_runs", 0)
	var forge_resume: Dictionary = config.get_value("meta", "forge", {})
	var noeuds := 0
	for perso in forge_resume:
		noeuds += (forge_resume[perso] as Array).size()
	# Un profil pas encore migré porte encore ses nœuds dans `unlocked`, mêlés
	# aux objets : on ne peut pas les compter ici sans connaître la liste des
	# nœuds, et ce résumé s'affiche avant que la Forge soit prête.
	summary["forge_nodes"] = noeuds
	return summary


func get_all_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in PROFILE_COUNT:
		result.append(get_profile_summary(slot))
	return result


## Active un emplacement. Un emplacement vide démarre une progression neuve.
func load_profile(slot: int, notify: bool = true) -> void:
	active_slot = clampi(slot, 0, PROFILE_COUNT - 1)
	_reset_memory()

	var config := ConfigFile.new()
	if config.load(get_profile_path(active_slot)) == OK:
		profile_name = config.get_value("meta", "profile_name", get_default_name(active_slot))
		banked_keys = config.get_value("meta", "banked_keys", 0)
		best_wave = config.get_value("meta", "best_wave", 0)
		total_runs = config.get_value("meta", "total_runs", 0)
		last_character = StringName(config.get_value("meta", "last_character", ""))
		abyss_key = bool(config.get_value("meta", "abyss_key", false))
		for id in config.get_value("meta", "unlocked", []):
			_unlocked[StringName(id)] = true
		for id in config.get_value("meta", "story_seen", []):
			_story_seen[StringName(id)] = true
		for perso in config.get_value("meta", "seals", []):
			_seals[String(perso)] = true
		var dechaine_lu: Dictionary = config.get_value("meta", "dechaine", {})
		for perso in dechaine_lu:
			_dechaine[String(perso)] = bool(dechaine_lu[perso])
		var forge_lu: Dictionary = config.get_value("meta", "forge", {})
		for perso in forge_lu:
			var ensemble := {}
			for id in forge_lu[perso]:
				ensemble[StringName(id)] = true
			_forge[String(perso)] = ensemble

	_save_index()
	if notify:
		profile_changed.emit(active_slot)
		keys_changed.emit(banked_keys)


## Efface définitivement un profil. Si c'est le profil actif, il redevient neuf.
func delete_profile(slot: int) -> void:
	var path := get_profile_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if slot == active_slot:
		load_profile(slot)


func rename_profile(new_name: String) -> void:
	profile_name = new_name.strip_edges()
	if profile_name == "":
		profile_name = get_default_name(active_slot)
	save_game()
	profile_changed.emit(active_slot)


func _reset_memory() -> void:
	profile_name = get_default_name(active_slot)
	banked_keys = 0
	best_wave = 0
	total_runs = 0
	last_character = &""
	abyss_key = false
	_unlocked.clear()
	_forge.clear()
	_dechaine.clear()
	_story_seen.clear()
	_seals.clear()


# --- Déblocages et monnaie ---------------------------------------------------

func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


# --- Forge, par personnage ---------------------------------------------------

func is_forge_unlocked(personnage: StringName, id: StringName) -> bool:
	return (_forge.get(String(personnage), {}) as Dictionary).has(id)


func unlock_forge(personnage: StringName, id: StringName) -> void:
	var cle := String(personnage)
	if not _forge.has(cle):
		_forge[cle] = {}
	if (_forge[cle] as Dictionary).has(id):
		return
	_forge[cle][id] = true
	save_game()


func get_forge_ids(personnage: StringName) -> Array:
	return (_forge.get(String(personnage), {}) as Dictionary).keys()


## Nœuds ouverts, tous personnages confondus. Sert au résumé de profil : c'est la
## mesure de l'investissement total, pas de la puissance d'un personnage.
func count_forge_nodes() -> int:
	var total := 0
	for perso in _forge:
		total += (_forge[perso] as Dictionary).size()
	return total


func is_unleashed(personnage: StringName) -> bool:
	# Sans la clé, le réglage ne vaut rien : l'effacer d'un profil réinitialisé
	# ne suffirait pas, un fichier modifié à la main le rallumerait. La clé est
	# la condition, à chaque lecture.
	return abyss_key and bool(_dechaine.get(String(personnage), false))


func set_unleashed(personnage: StringName, actif: bool) -> void:
	if not abyss_key:
		return
	_dechaine[String(personnage)] = actif
	save_game()


## Reverrouille des nœuds pour UN personnage. RÉSERVÉ AU PANNEAU DE DÉV.
func dev_lock_forge(personnage: StringName, ids: Array) -> void:
	var table: Dictionary = _forge.get(String(personnage), {})
	var touche := false
	for id in ids:
		if table.erase(id):
			touche = true
	if touche:
		save_game()


## Retourne true si la clé vient d'être acquise, false si le profil l'avait
## déjà : l'appelant s'en sert pour n'annoncer la nouvelle qu'une fois.
func grant_abyss_key() -> bool:
	if abyss_key:
		return false
	abyss_key = true
	save_game()
	return true


## Fait passer les nœuds de Forge de l'ancien registre commun vers le registre
## par personnage. Appelée par la Forge, qui est la seule à savoir ce qu'est un
## nœud — le préfixe `forge_` ne suffirait PAS : l'objet « Cœur de forge » a pour
## identifiant `forge_heart` et se serait retrouvé classé comme un nœud.
##
## Les nœuds sont donnés à TOUS les personnages. Une migration ne doit jamais
## retirer ce qui a été payé : les clés dépensées l'ont été avant que la règle
## change, et le joueur n'a pas à en faire les frais. Donner trois fois est
## l'erreur généreuse, reprendre est celle qu'on ne pardonne pas.
func migrate_forge(node_ids: Array, character_ids: Array) -> bool:
	var a_migrer: Array[StringName] = []
	for id in node_ids:
		if _unlocked.has(id):
			a_migrer.append(id)
	if a_migrer.is_empty():
		return false
	for perso in character_ids:
		var cle := String(perso)
		if not _forge.has(cle):
			_forge[cle] = {}
		for id in a_migrer:
			_forge[cle][id] = true
	for id in a_migrer:
		_unlocked.erase(id)
	save_game()
	return true


func get_unlocked_ids() -> Array:
	return _unlocked.keys()


func add_keys(amount: int) -> void:
	if amount <= 0:
		return
	banked_keys += amount
	keys_changed.emit(banked_keys)
	save_game()


## Débite des clés. Retourne false si le solde est insuffisant.
func spend_keys(amount: int) -> bool:
	if amount <= 0 or banked_keys < amount:
		return false
	banked_keys -= amount
	keys_changed.emit(banked_keys)
	save_game()
	return true


## Marque un identifiant comme débloqué (objet ou nœud de Forge : les deux
## partagent le même registre, les identifiants ne se recoupent pas).
func unlock_id(id: StringName) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	item_unlocked.emit(id)
	save_game()


## Tente de débloquer un objet. Retourne false si clés insuffisantes.
func unlock_item(item: ItemData) -> bool:
	if item == null or item.key_cost <= 0 or is_unlocked(item.id):
		return false
	if not spend_keys(item.key_cost):
		return false
	unlock_id(item.id)
	return true


func has_seal(personnage: StringName) -> bool:
	return _seals.has(String(personnage))


## Retourne true si le sceau vient de se briser : l'appelant ne l'annonce
## qu'une fois.
func break_seal(personnage: StringName) -> bool:
	if _seals.has(String(personnage)):
		return false
	_seals[String(personnage)] = true
	save_game()
	return true


## Panneau de développement : rend les trois sceaux.
func dev_clear_seals() -> void:
	_seals.clear()
	save_game()


func seal_count() -> int:
	return _seals.size()


func has_seen_story(id: StringName) -> bool:
	return _story_seen.has(id)


func mark_story_seen(id: StringName) -> void:
	if _story_seen.has(id):
		return
	_story_seen[id] = true
	save_game()


func set_last_character(id: StringName) -> void:
	last_character = id
	save_game()


func register_run_result(wave_reached: int) -> void:
	total_runs += 1
	best_wave = maxi(best_wave, wave_reached)
	save_game()


# --- Écriture ----------------------------------------------------------------

func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "profile_name", profile_name)
	config.set_value("meta", "banked_keys", banked_keys)
	config.set_value("meta", "best_wave", best_wave)
	config.set_value("meta", "total_runs", total_runs)
	config.set_value("meta", "last_character", String(last_character))
	config.set_value("meta", "unlocked", _unlocked.keys())
	config.set_value("meta", "abyss_key", abyss_key)
	var vues: Array[String] = []
	for id in _story_seen:
		vues.append(String(id))
	config.set_value("meta", "story_seen", vues)
	var sceaux: Array[String] = []
	for perso in _seals:
		sceaux.append(String(perso))
	config.set_value("meta", "seals", sceaux)
	# Les clés du dictionnaire écrit sont des String : un ConfigFile relit les
	# StringName comme des String, autant l'écrire tel qu'il sera relu.
	var forge_ecrit := {}
	for perso in _forge:
		var liste: Array[String] = []
		for id in _forge[perso]:
			liste.append(String(id))
		forge_ecrit[String(perso)] = liste
	config.set_value("meta", "forge", forge_ecrit)
	var dechaine_ecrit := {}
	for perso in _dechaine:
		dechaine_ecrit[String(perso)] = bool(_dechaine[perso])
	config.set_value("meta", "dechaine", dechaine_ecrit)
	var err := config.save(get_profile_path(active_slot))
	if err != OK:
		push_warning("SaveGame : échec de la sauvegarde (%d)" % err)


func _save_index() -> void:
	var index := ConfigFile.new()
	index.set_value("index", "active_slot", active_slot)
	index.save(INDEX_PATH)


## Utilitaire de test / debug : remet le profil actif à neuf.
func wipe() -> void:
	_reset_memory()
	save_game()
	keys_changed.emit(banked_keys)
