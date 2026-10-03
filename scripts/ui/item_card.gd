class_name ItemCard
extends PanelContainer
## Carte d'objet de la boutique. Elle construit ses propres enfants : une carte
## est purement dérivée de son `ItemData`, il n'y a rien à régler dans l'éditeur.

signal buy_requested(item: ItemData)
## Le cadenas a été basculé (0.10.1) : la boutique tient la liste.
signal lock_toggled(item: ItemData, locked: bool)

const CARD_MIN_SIZE := Vector2(196, 214)

var item: ItemData
var cost: int = 0
var purchased: bool = false
## VERROUILLÉE : la carte reste à la relance et revient à la boutique suivante.
var locked: bool = false
## La pièce rare de l'offre : liseré épais et fond teinté de sa rareté.
var featured: bool = false
## Le bouton d'achat a le focus : c'est la CARTE entière qui doit se désigner,
## pas un petit bouton au pied d'un bloc de texte.
var _focused: bool = false

var _icon: TextureRect
var _name_label: Label
var _rarity_label: Label
var _desc_label: Label
var _mods_label: Label
var _buy_button: Button
var _lock_button: Button
var _cadenas: TextureRect

## Vert menthe : aucune rareté ne l'utilise. Le cyan d'abord essayé se
## confondait avec le bleu des objets rares.
const VERROU := Color(0.5, 1.0, 0.68)
## Le cadenas du kit d'interface (32 px, affiché à sa taille : facteur entier).
## Ouvert, il est éteint ; fermé, en pleine couleur.
const CADENAS := preload("res://assets/sprites/ui/lock.png")
## Le cadre du kit d'interface, celui des grands panneaux (0.10.1). La carte
## était un rectangle à bordure plate, dessiné par le code : c'est ce qui
## faisait le plus « interface générée » à l'écran le plus fréquenté du jeu.
## Depuis la refonte des menus, la version neutre du cadre de l'enfer : son
## liseré est gris, la teinte de la rareté le colore sans se mêler à la braise.
const CADRE := preload("res://assets/sprites/ui/enfer/cadre_neutre.png")


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

	# L'icône vit dans la même ligne que le nom : elle ne coûte donc pas de
	# hauteur à la carte, dont la taille est déjà contrainte par l'écran.
	var title := HBoxContainer.new()
	title.add_theme_constant_override(&"separation", 8)
	box.add_child(title)

	_icon = TextureRect.new()
	# 16 px d'origine agrandis d'un facteur ENTIER, au plus proche : à l'échelle
	# 2,5 un pixel sur deux serait deux fois plus large que son voisin.
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(_icon)

	_name_label = Label.new()
	_name_label.theme_type_variation = &"TitleLabel"
	_name_label.add_theme_font_size_override(&"font_size", 30)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(_name_label)

	_rarity_label = Label.new()
	_rarity_label.add_theme_font_size_override(&"font_size", 15)
	box.add_child(_rarity_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override(&"font_size", 16)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_desc_label)

	_mods_label = Label.new()
	_mods_label.add_theme_font_size_override(&"font_size", 16)
	_mods_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_mods_label)

	# Le prix et le cadenas sur la même ligne : le cadenas ne coûte aucune
	# hauteur à une carte déjà contrainte par l'écran.
	var pied := HBoxContainer.new()
	pied.add_theme_constant_override(&"separation", 6)
	box.add_child(pied)

	_buy_button = Button.new()
	_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_button.pressed.connect(_on_buy_pressed)
	_buy_button.focus_entered.connect(_set_focused.bind(true))
	_buy_button.focus_exited.connect(_set_focused.bind(false))
	pied.add_child(_buy_button)

	_lock_button = Button.new()
	_lock_button.theme_type_variation = &"SecondaryButton"
	_lock_button.custom_minimum_size = Vector2(44, 0)
	_lock_button.tooltip_text = tr("Verrouiller : l'objet reste à la relance et revient à la boutique suivante.")
	_lock_button.pressed.connect(_on_lock_pressed)
	_lock_button.focus_entered.connect(_set_focused.bind(true))
	_lock_button.focus_exited.connect(_set_focused.bind(false))
	pied.add_child(_lock_button)
	_cadenas = TextureRect.new()
	_cadenas.texture = CADENAS
	_cadenas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cadenas.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_cadenas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cadenas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_button.add_child(_cadenas)

	_refresh()


func setup(new_item: ItemData, new_cost: int) -> void:
	item = new_item
	cost = new_cost
	purchased = false
	if is_node_ready():
		_refresh()


func set_locked(value: bool) -> void:
	locked = value
	if is_node_ready():
		_refresh()


func set_featured(value: bool) -> void:
	featured = value
	if is_node_ready():
		_refresh()


func _set_focused(value: bool) -> void:
	_focused = value
	_refresh()


func set_affordable(affordable: bool) -> void:
	if _buy_button != null:
		_buy_button.disabled = purchased or not affordable


func mark_purchased() -> void:
	purchased = true
	locked = false
	if _buy_button != null:
		_buy_button.disabled = true
		_buy_button.text = "Acquis"
	if _lock_button != null:
		_lock_button.disabled = true
		_cadenas.modulate = _teinte_cadenas(false)
	modulate = Color(0.55, 0.55, 0.55)


func _refresh() -> void:
	if item == null:
		return
	var color := item.get_rarity_color()
	_icon.texture = item.icon
	_icon.visible = item.icon != null
	_name_label.text = item.display_name
	_name_label.add_theme_color_override(&"font_color", color)
	_rarity_label.text = item.get_rarity_name().to_upper()
	_rarity_label.add_theme_color_override(&"font_color", color)
	_desc_label.text = item.description
	_mods_label.text = format_mods(item.mods)
	_mods_label.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.85))
	_buy_button.text = (tr("%d âme") if cost == 1 else tr("%d âmes")) % cost

	# Le cadre du kit, TEINTÉ : sa dorure prend la couleur de la rareté, et le
	# fond s'en colore à peine. Les états modulent la même teinte au lieu
	# d'épaissir une bordure.
	var style := StyleBoxTexture.new()
	style.texture = CADRE
	style.set_texture_margin_all(16.0)
	style.set_content_margin_all(4)
	var teinte := Color.WHITE.lerp(color, 0.75)
	if featured:
		# La pièce rare : la teinte de sa rareté, pleine.
		teinte = color.lerp(Color.WHITE, 0.15)
		_rarity_label.text = tr("%s  ·  PIÈCE RARE") % item.get_rarity_name().to_upper()
	if locked:
		# La couleur du cadenas : la carte gardée se voit de loin.
		teinte = VERROU
		_rarity_label.text += "  ·  " + tr("VERROUILLÉ")
	_cadenas.modulate = _teinte_cadenas(locked)
	if _focused:
		teinte = teinte * 1.35
	style.modulate_color = teinte
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
		var label: String = TranslationServer.translate(LABELS.get(String(key), String(key)))
		var value := float(mods[key])
		var line := ""
		if String(key) in PERCENT_KEYS:
			line = TranslationServer.translate("%+d %% %s") % [roundi(value * 100.0), label]
		elif String(key) in INTEGER_KEYS:
			line = "%+d %s" % [roundi(value), label]
		else:
			line = "%+.1f %s" % [value, label]
		lines.append(line)
	return "\n".join(lines)


func _teinte_cadenas(ferme: bool) -> Color:
	return Color.WHITE if ferme else Color(0.55, 0.52, 0.52, 0.55)


func _on_lock_pressed() -> void:
	if purchased or item == null:
		return
	set_locked(not locked)
	lock_toggled.emit(item, locked)


func _on_buy_pressed() -> void:
	if not purchased and item != null:
		buy_requested.emit(item)
