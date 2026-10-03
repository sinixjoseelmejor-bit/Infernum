class_name StatsScreen
extends CanvasLayer
## Fiche de run : TAB au clavier, Back à la manette.
##
## AUCUN CONTRÔLE FOCALISABLE, volontairement. TAB est déjà l'action
## `ui_focus_next` du jeu : si cet écran portait des boutons, appuyer sur TAB
## pour le refermer déplacerait le focus au lieu de fermer. Sans contrôle
## focalisable, il n'y a pas de conflit à arbitrer — l'écran se lit et se ferme,
## il ne se parcourt pas.
##
## QUI POSSÈDE LA PAUSE. Même règle que le menu de pause : si l'arbre est déjà
## en pause sans que cet écran soit visible, c'est qu'un autre écran la détient
## (boutique, malédictions, fin de run) et TAB ne doit rien faire. Ouvrir la
## fiche par-dessus la boutique, puis la fermer, relancerait la partie alors que
## la boutique est encore affichée.

@onready var wave_label: Label = %StatsWave
@onready var stats_column: VBoxContainer = %StatsColumn
@onready var items_column: VBoxContainer = %StatsItems
@onready var items_title: Label = %StatsItemsTitle

## Intitulé, clé, plafond, unité : partagés avec la colonne de la boutique,
## voir `StatsTotaux`.
const ROWS := StatsTotaux.LIGNES

## Lignes qui disparaissent quand AUCUNE source ne les alimente.
##
## Les dégâts plats n'existent que par la Braise ardente. Garder la ligne en
## permanence, ce serait six tirets de plus sur chaque fiche pour un objet
## commun que la plupart des runs n'auront pas — or la fiche a été refaite
## précisément pour qu'on y trouve les chiffres qui comptent.
const LIGNES_CONDITIONNELLES := ["damage_flat"]

## Largeur d'une colonne de source, et de la colonne du total.
const LARGEUR_SOURCE := 118
const LARGEUR_TOTAL := 176

const MAXED := Color(1.0, 0.62, 0.16)
const NEUTRAL := Color(0.72, 0.72, 0.70)
const BONUS := Color(0.55, 0.85, 0.6)
## Une source peut RETIRER : le Siphon du vide coûte des dégâts, une malédiction
## coûte du confort. Un malus vert se lirait comme un gain.
const MALUS := Color(0.95, 0.5, 0.45)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	if visible:
		return
	_rebuild()
	visible = true
	get_tree().paused = true
	Ecran.apparaitre(self)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	var asked := event.is_action_pressed(&"show_stats")
	var cancelled := visible and event.is_action_pressed(&"ui_cancel")
	if not asked and not cancelled:
		return
	if visible:
		get_viewport().set_input_as_handled()
		close()
	elif asked and not get_tree().paused:
		get_viewport().set_input_as_handled()
		open()


func _rebuild() -> void:
	var stats := RunState.stats
	wave_label.text = tr("Vague %d  ·  %d âmes  ·  %d éliminations  ·  %s") % [
		RunState.wave, RunState.souls, RunState.kills, _duration()]
	if RunState.unleashed:
		wave_label.text += "  ·  " + tr("DÉCHAÎNEMENT")
		wave_label.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.2))
	else:
		wave_label.remove_theme_color_override(&"font_color")

	UIUtils.clear_children(stats_column)
	var sources := RunState.get_stat_sources()
	var grille := GridContainer.new()
	grille.columns = 3 + sources.size()
	grille.add_theme_constant_override(&"h_separation", 10)
	grille.add_theme_constant_override(&"v_separation", 4)
	stats_column.add_child(grille)

	grille.add_child(_entete(""))
	for source: Array in sources:
		grille.add_child(_entete(String(source[0]).to_upper(), LARGEUR_SOURCE))
	grille.add_child(_entete(tr("= TOTAL"), LARGEUR_TOTAL))
	grille.add_child(_entete(""))

	for row in ROWS:
		if String(row[1]) in LIGNES_CONDITIONNELLES and not _alimentee(String(row[1]), sources):
			continue
		_ligne(grille, row, stats, sources)
	StatsTotaux.zebrer(grille, 1)

	var specials := _special_names(stats)
	if not specials.is_empty():
		stats_column.add_child(HSeparator.new())
		for name in specials:
			var label := Label.new()
			label.text = "◆  " + name
			label.add_theme_font_size_override(&"font_size", 19)
			label.add_theme_color_override(&"font_color", Color(1.0, 0.62, 0.16))
			stats_column.add_child(label)

	UIUtils.clear_children(items_column)
	var owned := _owned_sorted()
	items_title.text = tr("OBJETS  ·  %d piles, %d distincts") % [
		RunState.owned_items.size(), owned.size()]
	if owned.is_empty():
		var empty := Label.new()
		empty.text = "Rien encore. Les âmes s'échangent entre les vagues."
		empty.add_theme_color_override(&"font_color", NEUTRAL)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		items_column.add_child(empty)
		return
	for i in owned.size():
		items_column.add_child(_item_row(owned[i][0], owned[i][1], i))


func _duration() -> String:
	var total := int(RunState.run_time)
	return tr("%d min %02d s") % [total / 60, total % 60]


## Une source apporte-t-elle quelque chose sur cette statistique ?
func _alimentee(cle: String, sources: Array) -> bool:
	for source: Array in sources:
		if absf(_valeur_brute(cle, source[1])) > 0.0001:
			return true
	return false


## Une ligne : l'intitulé, une cellule par source, le total, le plafond.
##
## Les sources sont BRUTES, le total est PLAFONNÉ. Une ligne dont les colonnes
## additionnées dépassent le total est une ligne où l'on a acheté pour rien :
## c'est là que la mention PLAFOND s'allume.
func _ligne(grille: GridContainer, row: Array, stats: PlayerStats, sources: Array) -> void:
	var titre := Label.new()
	titre.text = tr(String(row[0]))
	titre.add_theme_font_size_override(&"font_size", 19)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre.add_theme_color_override(&"font_color", Color(0.78, 0.75, 0.72))
	grille.add_child(titre)

	# Première colonne : ce que vaut la statistique avec le personnage SEUL,
	# en valeur absolue. Les suivantes restent des modificateurs.
	grille.add_child(_cellule_base(String(row[1]), sources[0][1]))
	for i in range(1, sources.size()):
		grille.add_child(_cellule_source(String(row[1]), String(row[3]), sources[i][1]))

	var brut := _valeur_totale(String(row[1]), stats)
	# `brut` est un tableau non typé : sans ces conversions explicites, GDScript
	# ne sait pas déduire le type de la comparaison au plafond.
	var valeur := float(brut[1])
	var cap := float(row[2])
	# DÉCHAÎNEMENT : plus aucun plafond ne s'applique, donc plus aucun ne
	# s'allume. Laisser la mention serait le pire mensonge possible sur cette
	# fiche — elle dirait au joueur d'arrêter d'acheter ce qui est justement
	# devenu illimité.
	var au_plafond := StatsTotaux.au_plafond(valeur, cap)
	var total := Label.new()
	total.text = String(brut[0])
	total.add_theme_font_size_override(&"font_size", 19)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total.custom_minimum_size = Vector2(LARGEUR_TOTAL, 0)
	total.add_theme_color_override(&"font_color",
		MAXED if au_plafond else (BONUS if absf(valeur) > 0.0001 else NEUTRAL))
	grille.add_child(total)

	var plafond := Label.new()
	plafond.text = tr("PLAFOND") if au_plafond else ""
	plafond.add_theme_font_size_override(&"font_size", 13)
	plafond.custom_minimum_size = Vector2(72, 0)
	plafond.add_theme_color_override(&"font_color", MAXED)
	grille.add_child(plafond)


## Ce que vaut la statistique avec le PERSONNAGE SEUL, en valeur absolue quand
## elle en a une.
##
## C'est la colonne qui manquait : la fiche n'affichait que des modificateurs,
## donc elle disait « PV maximum +30 » sans jamais dire que la base est 100, ni
## que l'arme tape à 12 et tire 4 fois par seconde. Un pourcentage sans son
## point d'appui ne se compare a rien.
##
## Les statistiques qui n'ont pas de base — armure, régénération, vol de vie,
## chance, projectiles supplémentaires — gardent leur écriture de bonus : leur
## base EST zéro, et écrire « 0 » serait plus bavard que « — ».
func _cellule_base(cle: String, perso: PlayerStats) -> Label:
	var personnage := Characters.get_selected()
	var texte := ""
	match cle:
		"damage":
			var base: float = (personnage.weapon_damage + perso.damage_flat) \
				* (1.0 + perso.damage_pct)
			texte = "%.1f" % base
		"fire_rate":
			texte = "%.1f /s" % (personnage.weapon_fire_rate * (1.0 + perso.fire_rate_pct))
		"crit":
			texte = tr("%d %%") % roundi((personnage.weapon_crit_chance + perso.crit_chance) * 100.0)
		"crit_damage":
			texte = "×%.2f" % (2.0 + perso.crit_damage_pct)
		"health":
			texte = "%d" % roundi(personnage.max_health + perso.max_health_flat)
		"speed":
			texte = "%d" % roundi(personnage.move_speed * (1.0 + perso.move_speed_pct))
		"range":
			texte = "%d" % roundi(personnage.targeting_range * (1.0 + perso.range_pct))
		_:
			# Pas de base : on retombe sur l'écriture de modificateur.
			return _cellule_source(cle, _unite(cle), perso)

	var cellule := Label.new()
	cellule.text = texte
	cellule.add_theme_font_size_override(&"font_size", 17)
	cellule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cellule.custom_minimum_size = Vector2(LARGEUR_SOURCE, 0)
	cellule.add_theme_color_override(&"font_color", Color(0.78, 0.75, 0.72))
	return cellule


func _unite(cle: String) -> String:
	for row in ROWS:
		if String(row[1]) == cle:
			return String(row[3])
	return "pct"


## Contribution d'une source, en écriture COMPACTE. Un tiret quand elle
## n'apporte rien : quatorze lignes de « +0 % » répétées quatre fois seraient un
## mur de zéros où le regard ne trouverait plus les chiffres qui comptent.
func _cellule_source(cle: String, unite: String, source: PlayerStats) -> Label:
	var brut := _valeur_brute(cle, source)
	var cellule := Label.new()
	cellule.add_theme_font_size_override(&"font_size", 17)
	cellule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cellule.custom_minimum_size = Vector2(LARGEUR_SOURCE, 0)
	if absf(brut) < 0.0001:
		cellule.text = "—"
		cellule.add_theme_color_override(&"font_color", Color(0.42, 0.40, 0.40))
		return cellule
	match unite:
		"pct":
			cellule.text = tr("%+d %%") % roundi(brut * 100.0)
		"ent":
			cellule.text = "%+d" % int(brut)
		"plat":
			cellule.text = "%+d" % roundi(brut)
		_:
			cellule.text = "%+.1f" % brut
	cellule.add_theme_color_override(&"font_color", BONUS if brut > 0.0 else MALUS)
	return cellule


## Valeur brute d'une source : les CHAMPS, et non les accesseurs. Les accesseurs
## appliquent les plafonds, or un plafond ne se répartit pas entre les sources.
func _valeur_brute(cle: String, stats: PlayerStats) -> float:
	match cle:
		"damage": return stats.damage_pct
		"damage_flat": return stats.damage_flat
		"fire_rate": return stats.fire_rate_pct
		"projectiles": return float(stats.projectile_bonus)
		"pierce": return float(stats.pierce)
		"crit": return stats.crit_chance
		"crit_damage": return stats.crit_damage_pct
		"health": return stats.max_health_flat
		"armor": return stats.armor
		"regen": return stats.regen
		"lifesteal": return stats.lifesteal_pct
		"speed": return stats.move_speed_pct
		"range": return stats.range_pct
		"pickup": return stats.pickup_radius_pct
		"souls": return stats.soul_gain_pct
		"luck": return stats.luck
	return 0.0


func _valeur_totale(cle: String, stats: PlayerStats) -> Array:
	return StatsTotaux.total(cle, stats, get_tree())


func _entete(texte: String, largeur: int = 0) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override(&"font_size", 13)
	l.add_theme_color_override(&"font_color", Color(0.62, 0.58, 0.56))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if largeur > 0:
		l.custom_minimum_size = Vector2(largeur, 0)
	return l


func _special_names(stats: PlayerStats) -> Array[String]:
	var out: Array[String] = []
	for item in RunState.owned_items:
		if item.special != &"" and not out.has(item.display_name):
			out.append(item.display_name)
	return out


## Groupé par objet, raretés hautes d'abord : c'est l'ordre dans lequel on lit
## une build, et celui qui rend les piles comparables.
func _owned_sorted() -> Array:
	var out: Array = []
	for id in RunState.owned_counts:
		var item := ItemDB.get_item(id)
		if item != null:
			out.append([item, int(RunState.owned_counts[id])])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0].rarity != b[0].rarity:
			return a[0].rarity > b[0].rarity
		return a[0].display_name < b[0].display_name)
	return out


func _item_row(item: ItemData, count: int, rang: int) -> Control:
	# La même rayure que les statistiques, une ligne sur deux.
	var fond := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = StatsTotaux.RAYURE if rang % 2 == 0 else Color(0, 0, 0, 0)
	style.border_color = StatsTotaux.FILET
	style.border_width_bottom = 1
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	fond.add_theme_stylebox_override(&"panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	fond.add_child(row)

	var icon := TextureRect.new()
	# Facteur ENTIER sur la source de 16 px, au plus proche : un agrandissement
	# fractionnaire donnerait des pixels de tailles inégales.
	icon.custom_minimum_size = Vector2(32, 32)
	icon.texture = item.icon
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_size_override(&"font_size", 19)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override(&"font_color", item.get_rarity_color())
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "×%d" % count if count > 1 else ""
	count_label.add_theme_font_size_override(&"font_size", 19)
	count_label.custom_minimum_size = Vector2(52, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_color_override(&"font_color",
		MAXED if count >= item.max_stacks else NEUTRAL)
	row.add_child(count_label)
	return fond
