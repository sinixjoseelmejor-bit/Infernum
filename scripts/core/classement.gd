extends Node
## LE CLASSEMENT (autoload `Classement`, 0.9.3) : les meilleures runs, pour
## l'instant sur ce poste.
##
## DEUX TABLEAUX, parce que ce ne sont pas les mêmes épreuves : le classique, et
## le DÉCHAÎNEMENT — le défi de classement du jeu, où plus rien n'est plafonné
## (voir CLAUDE.md). Mélangés, une run déchaînée écraserait tout le reste.
##
## L'ORDRE : la vague atteinte d'abord — c'est ce que le jeu demande, descendre
## —, puis les éliminations, puis le temps le plus court. Deux runs à la même
## vague se départagent par ce qu'elles ont fait en route.
##
## LOCAL POUR L'INSTANT, STEAM ENSUITE. Tout ce que l'écran et la fin de run
## connaissent, ce sont `soumettre`, `entrees` et `nom_joueur` : le stockage est
## derrière. Aujourd'hui un fichier commun à tous les profils du poste
## (`FICHIER`), et le nom affiché est celui du profil. Avec Steam, ces trois
## fonctions passent par les leaderboards du jeu, et le nom devient celui du
## compte Steam — le reste du jeu ne change pas. Voir README, « Le classement ».

signal change()

const FICHIER := "user://infernum_classement.cfg"
const CLASSIQUE := &"classique"
const DECHAINE := &"dechaine"
## Entrées gardées par tableau. L'écran en montre les dix premières ; les
## suivantes servent à dire « 14e » à qui n'entre pas dans le haut du tableau.
const TAILLE := 50

var _tableaux: Dictionary = {CLASSIQUE: [], DECHAINE: []}


func _ready() -> void:
	_charger()


## Le nom sous lequel le joueur entre au classement. Aujourd'hui le profil ;
## avec Steam, le nom du compte.
func nom_joueur() -> String:
	return SaveGame.profile_name


## Enregistre une run terminée. `run` : "personnage", "vague", "eliminations",
## "temps", "dechaine". Rend le rang obtenu (1 = premier), ou 0 si la run n'a
## pas sa place — une run morte avant la première vague n'en a jamais.
func soumettre(run: Dictionary) -> int:
	if int(run.get("vague", 0)) < 1:
		return 0
	var entree := {
		"nom": nom_joueur(),
		"profil": SaveGame.active_slot,
		"personnage": String(run.get("personnage", "")),
		"vague": int(run["vague"]),
		"eliminations": int(run.get("eliminations", 0)),
		"temps": float(run.get("temps", 0.0)),
		"date": int(Time.get_unix_time_from_system()),
	}
	var tableau: Array = _tableaux[DECHAINE if run.get("dechaine", false) else CLASSIQUE]
	tableau.append(entree)
	tableau.sort_custom(_avant)
	var rang := tableau.find(entree) + 1
	if tableau.size() > TAILLE:
		tableau.resize(TAILLE)
	_sauver()
	change.emit()
	return rang if rang <= TAILLE else 0


## Les entrées d'un tableau, dans l'ordre.
func entrees(tableau: StringName) -> Array:
	return _tableaux.get(tableau, [])


## Vrai si `a` passe devant `b`.
static func _avant(a: Dictionary, b: Dictionary) -> bool:
	if a["vague"] != b["vague"]:
		return a["vague"] > b["vague"]
	if a["eliminations"] != b["eliminations"]:
		return a["eliminations"] > b["eliminations"]
	return a["temps"] < b["temps"]


func _charger() -> void:
	var config := ConfigFile.new()
	if config.load(FICHIER) != OK:
		return
	for tableau in [CLASSIQUE, DECHAINE]:
		var lu: Array = config.get_value("classement", String(tableau), [])
		_tableaux[tableau] = lu.duplicate(true)
		(_tableaux[tableau] as Array).sort_custom(_avant)


func _sauver() -> void:
	var config := ConfigFile.new()
	for tableau in [CLASSIQUE, DECHAINE]:
		config.set_value("classement", String(tableau), _tableaux[tableau])
	var err := config.save(FICHIER)
	if err != OK:
		push_warning("Classement : échec de la sauvegarde (%d)" % err)


## Efface le classement du poste (panneau de développement, tests).
func vider() -> void:
	_tableaux = {CLASSIQUE: [], DECHAINE: []}
	_sauver()
	change.emit()
