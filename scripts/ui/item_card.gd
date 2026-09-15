class_name ItemCard
extends PanelContainer
## Carte d'objet de la boutique. Elle construit ses propres enfants : une carte
## est purement dérivée de son `ItemData`, il n'y a rien à régler dans l'éditeur.

signal buy_requested(item: ItemData)

const CARD_MIN_SIZE := Vector2(196, 214)

var item: ItemData
var cost: int = 0
var purchased: bool = false

var _name_label: Label
var _rarity_label: Label
var _desc_label: Label
var _mods_label: Label
var _buy_button: Button


func _ready() -> void:
	custom_minimum_size = CARD_MIN_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# La carte laisse passer la molette : sans ça, survoler une carte bloque le
	# défilement de la boutique, qui n'a plus qu'une seule zone scrollable.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(StringName("margin_" + side), 14)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	margin.add_child(box)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override(&"font_size", 20)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_name_label)

	_rarity_label = Label.new()
	_rarity_label.add_theme_font_size_override(&"font_size", 13)
	box.add_child(_rarity_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override(&"font_size", 14)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_desc_label)

	_mods_label = Label.new()
	_mods_label.add_theme_font_size_override(&"font_size", 14)
	_mods_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_mods_label)

	_buy_button = Button.new()
	_buy_button.pressed.connect(_on_buy_pressed)
	box.add_child(_buy_button)

	_refresh()


func setup(new_item: ItemData, new_cost: int) -> void:
	item = new_item
	cost = new_cost
	purchased = false
	if is_node_ready():
		_refresh()


func set_affordable(affordable: bool) -> void:
	if _buy_button != null:
		_buy_button.disabled = purchased or not affordable


func mark_purchased() -> void:
	purchased = true
	if _buy_button != null:
		_buy_button.disabled = true
		_buy_button.text = "Acquis"
	modulate = Color(0.55, 0.55, 0.55)


func _refresh() -> void:
	if item == null:
		return
	var color := item.get_rarity_color()
	_name_label.text = item.display_name
	_name_label.add_theme_color_override(&"font_color", color)
	_rarity_label.text = item.get_rarity_name().to_upper()
	_rarity_label.add_theme_color_override(&"font_color", color)
	_desc_label.text = item.description
	_mods_label.text = format_mods(item.mods)
	_mods_label.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.85))
	_buy_button.text = "%d âmes" % cost

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.05, 0.06, 0.96)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(2)
	add_theme_stylebox_override(&"panel", style)


## Rendu lisible des modificateurs : les malus apparaissent explicitement, un
## objet ne doit jamais cacher sa contrepartie.
static func format_mods(mods: Dictionary) -> String:
	const LABELS := {
		"damage_flat": "dégâts",
		"damage_pct": "dégâts",
		"fire_rate_pct": "cadence",
		"projectile_bonus": "projectile",
		"pierce": "ennemi traversé",
		"crit_chance": "chance critique",
		"crit_damage_pct": "dégâts critiques",
		"move_speed_pct": "vitesse",
		"max_health_flat": "PV max",
		"armor": "armure",
		"regen": "PV/s",
		"lifesteal_pct": "vol de vie",
		"pickup_radius_pct": "rayon de ramassage",
		"range_pct": "portée",
		"soul_gain_pct": "âmes",
		"luck": "chance",
	}
	## Stats qui se comptent en entiers : « +1.0 projectile » n'a aucun sens.
	const INTEGER_KEYS := ["projectile_bonus", "pierce"]
	const PERCENT_KEYS := [
		"damage_pct", "fire_rate_pct", "crit_chance", "crit_damage_pct",
		"move_speed_pct", "lifesteal_pct", "pickup_radius_pct", "range_pct",
		"soul_gain_pct",
	]
	var lines: Array[String] = []
	for key in mods:
		var label: String = LABELS.get(String(key), String(key))
		var value := float(mods[key])
		var line := ""
		if String(key) in PERCENT_KEYS:
			line = "%+d %% %s" % [roundi(value * 100.0), label]
		elif String(key) in INTEGER_KEYS:
			line = "%+d %s" % [roundi(value), label]
		else:
			line = "%+.1f %s" % [value, label]
		lines.append(line)
	return "\n".join(lines)


func _on_buy_pressed() -> void:
	if not purchased and item != null:
		buy_requested.emit(item)
