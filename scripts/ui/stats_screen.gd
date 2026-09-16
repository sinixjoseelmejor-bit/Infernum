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

## Une ligne = intitulé, valeur, et le plafond quand il y en a un. Afficher le
## plafond n'est pas décoratif : tout l'équilibrage du jeu repose sur eux, et
## un joueur qui ignore qu'il est à +200 % de dégâts continue d'acheter des
## objets de dégâts pour rien.
const ROWS := [
	["Dégâts", "damage", PlayerStats.CAP_DAMAGE_PCT],
	["Cadence de tir", "fire_rate", PlayerStats.CAP_FIRE_RATE_PCT],
	["Projectiles", "projectiles", PlayerStats.CAP_PROJECTILE_BONUS],
	["Ennemis traversés", "pierce", PlayerStats.CAP_PIERCE],
	["Chance de critique", "crit", PlayerStats.CAP_CRIT_CHANCE],
	["Dégâts critiques", "crit_damage", 0.0],
	["PV maximum", "health", 0.0],
	["Armure", "armor", PlayerStats.CAP_ARMOR],
	["Régénération", "regen", 0.0],
	["Vol de vie", "lifesteal", PlayerStats.CAP_LIFESTEAL],
	["Vitesse", "speed", PlayerStats.CAP_MOVE_SPEED_PCT],
	["Portée de visée", "range", PlayerStats.CAP_RANGE_PCT],
	["Gain d'âmes", "souls", PlayerStats.CAP_SOUL_PCT],
	["Chance", "luck", PlayerStats.CAP_LUCK],
]

const MAXED := Color(1.0, 0.62, 0.16)
const NEUTRAL := Color(0.72, 0.72, 0.70)
const BONUS := Color(0.55, 0.85, 0.6)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	if visible:
		return
	_rebuild()
	visible = true
	get_tree().paused = true


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
	wave_label.text = "Vague %d  ·  %d âmes  ·  %d éliminations  ·  %s" % [
		RunState.wave, RunState.souls, RunState.kills, _duration()]

	UIUtils.clear_children(stats_column)
	for row in ROWS:
		stats_column.add_child(_stat_row(row[0], row[1], stats, row[2]))

	var specials := _special_names(stats)
	if not specials.is_empty():
		stats_column.add_child(HSeparator.new())
		for name in specials:
			var label := Label.new()
			label.text = "◆  " + name
			label.add_theme_font_size_override(&"font_size", 15)
			label.add_theme_color_override(&"font_color", Color(1.0, 0.62, 0.16))
			stats_column.add_child(label)

	UIUtils.clear_children(items_column)
	var owned := _owned_sorted()
	items_title.text = "OBJETS  ·  %d piles, %d distincts" % [
		RunState.owned_items.size(), owned.size()]
	if owned.is_empty():
		var empty := Label.new()
		empty.text = "Rien encore. Les âmes s'échangent entre les vagues."
		empty.add_theme_color_override(&"font_color", NEUTRAL)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		items_column.add_child(empty)
		return
	for entry in owned:
		items_column.add_child(_item_row(entry[0], entry[1]))


func _duration() -> String:
	var total := int(RunState.run_time)
	return "%d min %02d s" % [total / 60, total % 60]


## Les valeurs viennent des ACCESSEURS, pas des champs bruts : ce sont eux qui
## appliquent les plafonds, et c'est le chiffre plafonné que le joueur subit.
func _stat_row(title: String, key: String, stats: PlayerStats, cap: float) -> Control:
	var value := ""
	var raw := 0.0
	match key:
		"damage":
			raw = stats.get_damage_pct()
			value = "+%d %%" % roundi(raw * 100.0)
		"fire_rate":
			raw = stats.get_fire_rate_pct()
			value = "%+d %%" % roundi(raw * 100.0)
		"projectiles":
			raw = float(stats.get_projectile_bonus())
			value = "+%d" % int(raw)
		"pierce":
			raw = float(stats.get_pierce())
			value = "+%d" % int(raw)
		"crit":
			raw = stats.get_crit_chance()
			value = "%d %%" % roundi(raw * 100.0)
		"crit_damage":
			raw = stats.get_crit_damage_pct()
			value = "×%.2f" % (2.0 + raw)
		"health":
			raw = stats.max_health_flat
			value = "%+d" % roundi(raw)
		"armor":
			raw = stats.get_armor()
			value = "%d  (−%d %% de dégâts)" % [
				roundi(raw), roundi(stats.get_damage_reduction() * 100.0)]
		"regen":
			raw = stats.regen
			value = "%.1f PV/s" % raw
		"lifesteal":
			raw = stats.get_lifesteal()
			value = "%.1f %%" % (raw * 100.0)
		"speed":
			raw = stats.get_move_speed_pct()
			value = "%+d %%" % roundi(raw * 100.0)
		"range":
			raw = stats.get_range_pct()
			value = "+%d %%" % roundi(raw * 100.0)
		"pickup":
			raw = stats.get_pickup_radius_pct()
			value = "+%d %%" % roundi(raw * 100.0)
		"souls":
			raw = stats.get_soul_gain_pct()
			value = "+%d %%" % roundi(raw * 100.0)
		"luck":
			raw = stats.get_luck()
			value = "%.1f" % raw

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)

	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override(&"font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override(&"font_color", Color(0.78, 0.75, 0.72))
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override(&"font_size", 15)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(150, 0)
	var at_cap := cap > 0.0 and raw >= cap - 0.0001
	value_label.add_theme_color_override(&"font_color",
		MAXED if at_cap else (BONUS if absf(raw) > 0.0001 else NEUTRAL))
	row.add_child(value_label)

	if cap > 0.0:
		var cap_label := Label.new()
		cap_label.text = "PLAFOND" if at_cap else ""
		cap_label.add_theme_font_size_override(&"font_size", 11)
		cap_label.custom_minimum_size = Vector2(62, 0)
		cap_label.add_theme_color_override(&"font_color", MAXED)
		row.add_child(cap_label)
	return row


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


func _item_row(item: ItemData, count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

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
	name_label.add_theme_font_size_override(&"font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override(&"font_color", item.get_rarity_color())
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "×%d" % count if count > 1 else ""
	count_label.add_theme_font_size_override(&"font_size", 15)
	count_label.custom_minimum_size = Vector2(44, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_color_override(&"font_color",
		MAXED if count >= item.max_stacks else NEUTRAL)
	row.add_child(count_label)
	return row
