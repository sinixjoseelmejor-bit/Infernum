extends CanvasLayer
## Boutique d'entre-deux-vagues.
##
## Les objets s'ACHÈTENT avec des âmes au lieu d'être offerts : c'est le
## régulateur principal de la puissance. Le joueur ne peut pas tout prendre, il
## doit choisir un axe — et c'est ce choix forcé qui empêche l'accumulation
## simultanée de tous les stats multiplicatifs.

const OFFER_SIZE := 4
## Coût d'une relance, remis à zéro à chaque ouverture de boutique.
##
## Les deux premières sont presque offertes : elles servent à ne pas rester
## bloqué sur une offre entièrement hors sujet, ce qui est du gâchis de tour,
## pas un choix. La troisième change de registre — au-delà, relancer se paie.
##
## Ce n'est PAS un robinet à puissance : une relance ne donne pas d'âme, donc
## pas d'objet en plus. Le nombre d'achats par vague reste tenu par le prix des
## objets (`COST_PER_OWNED_ITEM`), que ceci ne touche pas. Ce qu'on achète ici,
## c'est de la précision de build.
const REROLL_COSTS: Array[int] = [1, 2, 10, 20]
## Au-delà de la table, doublement — dans la continuité du 10 -> 20.
const REROLL_COST_GROWTH := 2.0
## Les prix suivent DEUX courbes, parce que le revenu en âmes croît beaucoup plus
## vite que la difficulté : le nombre d'ennemis par vague est multiplié par ~14
## entre les vagues 1 et 20, et la valeur unitaire monte encore avec les élites.
## Sans la seconde courbe, le joueur pouvait s'offrir une dizaine d'objets par
## vague en fin de partie, ce qui supprimait tout arbitrage.
const COST_WAVE_GROWTH := 0.15
## Renchérissement par objet déjà possédé : plus la build est avancée, plus
## chaque ajout coûte cher. Maintient ~2-3 achats par vague sur toute la run.
## La composante QUADRATIQUE est le frein de la boucle de rétroaction : plus de
## puissance = plus de kills = plus d'âmes = plus de puissance. Une courbe
## linéaire ne rattrape jamais cette boucle, et une run cumulant malédictions et
## pactes de densité finissait avec 3 fois la puissance d'une run normale.
## MESURÉ : à 0.06 / 0.0035, une run de 21 vagues finissait avec 58 piles pour
## 24 objets distincts — c'est-à-dire TOUT le catalogue au maximum d'empilement,
## 20 000 âmes gagnées et 150 non dépensées. À partir de la vague 17 la boutique
## cessait d'être un système de décision pour devenir un distributeur.
const COST_PER_OWNED_ITEM := 0.062
const COST_PER_OWNED_ITEM_SQ := 0.0045

## REVENTE : part du prix de BASE rendue, et non du prix payé.
##
## C'est la sortie de secours d'une build enfermée — trois objets défensifs
## achetés tôt, plus assez de dégâts pour gagner les âmes du quatrième. Elle ne
## crée pas de revenu : le prix payé vaut au moins le prix de base et monte avec
## la vague et la richesse, donc revendre est toujours une perte sèche. Aucun
## aller-retour ne rapporte, quel que soit le moment.
const SELL_RATIO := 0.5

@onready var offer_row: HFlowContainer = %OfferRow
@onready var pact_row: HFlowContainer = %PactRow
@onready var pact_status: Label = %PactStatus
@onready var souls_label: Label = %ShopSoulsLabel
@onready var wave_label: Label = %ShopWaveLabel
@onready var inventaire: PanelContainer = %Inventaire
@onready var sell_title: Label = %SellTitle
@onready var sell_row: VBoxContainer = %SellRow
@onready var reroll_button: Button = %RerollButton
@onready var continue_button: Button = %ContinueButton

var _cards: Array[ItemCard] = []
var _pact_buttons: Array[Button] = []
var _rerolls: int = 0
var _open: bool = false


func _ready() -> void:
	# La boutique doit rester interactive alors que le jeu est en pause.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	reroll_button.pressed.connect(_on_reroll_pressed)
	continue_button.pressed.connect(close)
	GameEvents.wave_cleared.connect(_on_wave_cleared)
	RunState.souls_changed.connect(_on_souls_changed)


func _on_wave_cleared(_wave: int) -> void:
	if RunState.is_running:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	_rerolls = 0
	visible = true
	get_tree().paused = true
	wave_label.text = "Vague %d terminée" % RunState.wave
	# La récolte des survivants est DITE. Des âmes qui arrivent sans explication
	# ne s'attribuent à rien, et le joueur n'apprendrait jamais que blesser sans
	# achever rapporte quelque chose.
	if RunState.leftover_souls > 0:
		wave_label.text += "  ·  %d âmes arrachées à %d survivants" % [
			RunState.leftover_souls, RunState.leftover_count]
	_roll_offer()
	_roll_pacts()
	_build_sell()
	_refresh()
	GameEvents.shop_opened.emit()
	continue_button.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	GameEvents.shop_closed.emit()


## Bouton B de la manette / Échap : retour. Sans ça, un écran ouvert à la manette
## est un cul-de-sac — il n'y a aucun moyen d'en sortir sans souris.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func get_item_cost(item: ItemData) -> int:
	var wave_factor := 1.0 + COST_WAVE_GROWTH * maxf(0.0, RunState.wave - 1.0)
	var owned := float(RunState.owned_items.size())
	var wealth_factor := 1.0 + COST_PER_OWNED_ITEM * owned + COST_PER_OWNED_ITEM_SQ * owned * owned
	var discount := 1.0 - Forge.get_special_total(&"shop_discount")
	return maxi(1, roundi(item.get_base_cost() * wave_factor * wealth_factor * discount))


func get_reroll_cost() -> int:
	if _rerolls < REROLL_COSTS.size():
		return REROLL_COSTS[_rerolls]
	var beyond := _rerolls - REROLL_COSTS.size() + 1
	return roundi(REROLL_COSTS[-1] * pow(REROLL_COST_GROWTH, beyond))


func _roll_offer() -> void:
	UIUtils.clear_children(offer_row)
	_cards.clear()

	var size := OFFER_SIZE + int(Forge.get_special_total(&"shop_slots"))
	var offer := ItemDB.roll_offer(
		size, maxi(1, RunState.wave), RunState.owned_counts, RunState.stats.get_luck()
	)
	for item in offer:
		var card := ItemCard.new()
		card.buy_requested.connect(_on_buy_requested)
		offer_row.add_child(card)
		card.setup(item, get_item_cost(item))
		_cards.append(card)

	if offer.is_empty():
		var label := Label.new()
		label.text = "Plus rien à vendre : vous avez tout pris."
		offer_row.add_child(label)


## L'INVENTAIRE EST UN PANNEAU À PART, À CÔTÉ DE LA BOUTIQUE.
##
## La revente vivait au fond du corps de la boutique, sous l'offre et sous les
## pactes, donc dans la même zone de défilement : au-delà de quelques objets
## elle passait sous le bord et il fallait faire défiler pour SAVOIR ce qu'on
## possédait. Or ce n'est pas la même question que « qu'est-ce que j'achète ».
## L'une se lit d'un coup d'œil et sert à décider de l'autre.
##
## Les deux colonnes n'ont donc ni le même défilement ni la même largeur, et
## l'inventaire est une LISTE VERTICALE plutôt qu'un `HFlowContainer` : dans une
## colonne de 330 px, un flux se serait replié sur une ou deux cases par ligne,
## c'est-à-dire une liste, mais irrégulière.
##
## Un bouton par objet DISTINCT, avec le nombre d'exemplaires : une liste de
## 58 lignes pour 24 objets serait illisible, et vendre « un » exemplaire suffit
## puisqu'ils sont identiques.
func _build_sell() -> void:
	# Le bouton pressé disparaît quand on vend le dernier exemplaire : on retient
	# le focus par NOM pour le rendre au même bouton s'il survit, et au bouton
	# « Continuer » sinon. Sans ça, vendre à la manette laisse un écran sans
	# focus, donc sans sortie.
	var keep := UIUtils.capture_focus(self)
	UIUtils.clear_children(sell_row)
	var vus := {}
	var distincts: Array[ItemData] = []
	for item in RunState.owned_items:
		if item == null or vus.has(item.id):
			continue
		vus[item.id] = true
		distincts.append(item)

	# LE PANNEAU ENTIER DISPARAÎT quand on ne possède rien, et pas seulement son
	# contenu : une colonne vide de 330 px à gauche de la boutique décentrerait
	# l'écran de la première vague sans rien apprendre à personne.
	var quelque_chose := not distincts.is_empty()
	inventaire.visible = quelque_chose
	if not quelque_chose:
		UIUtils.restore_focus(self, keep, continue_button)
		return

	sell_title.text = "REVENDRE — la moitié du prix de base"
	for item in distincts:
		var piles := int(RunState.owned_counts.get(item.id, 0))
		var button := Button.new()
		# Nom stable : c'est par lui que le focus se retrouve après reconstruction.
		button.name = "vendre_%s" % item.id
		button.theme_type_variation = &"CardButton"
		# Pleine largeur de la colonne : des boutons de largeur variable dans une
		# liste verticale donnent un bord droit en dents de scie.
		button.custom_minimum_size = Vector2(0, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# L'ICÔNE, comme sur les cartes de l'offre. Une liste de noms demande de
		# LIRE pour retrouver un objet ; la même liste avec son icone se parcourt
		# des yeux, et c'est exactement ce qu'on fait quand on cherche quoi
		# revendre. C'est aussi la même image que celle qu'on a vue en l'achetant.
		#
		# Filtrage au plus proche et taille ENTIÈREMENT multiple de la source :
		# les icônes font 16 px, affichées à 32. À l'échelle 2,5 un pixel sur deux
		# serait deux fois plus large que son voisin.
		if item.icon != null:
			button.icon = item.icon
			# `expand_icon` ET `icon_max_width` ensemble, et les deux sont
			# nécessaires : sans le premier l'icône est dessinée à sa taille
			# native, soit 16 px, deux fois trop petite ; sans le second elle
			# prendrait toute la hauteur du bouton. Le résultat est 32, facteur
			# ENTIER sur une source de 16.
			button.expand_icon = true
			button.add_theme_constant_override(&"icon_max_width", 32)
			button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s%s
+%d âmes" % [
			item.display_name, ("  ×%d" % piles) if piles > 1 else "",
			get_sell_value(item)]
		button.add_theme_color_override(&"font_color", item.get_rarity_color())
		button.pressed.connect(func() -> void: _on_sell_pressed(item))
		sell_row.add_child(button)
	UIUtils.chain_focus(self)
	UIUtils.restore_focus(self, keep, continue_button)


func get_sell_value(item: ItemData) -> int:
	return maxi(1, floori(item.get_base_cost() * SELL_RATIO))


## Vendre détruit le bouton qui vient d'être pressé : on reconstruit en FIN DE
## FRAME, jamais depuis l'exécution du signal — le même piège que l'écran de la
## Forge, et il plante de la même façon.
func _on_sell_pressed(item: ItemData) -> void:
	var gain := get_sell_value(item)
	if not RunState.remove_item(item):
		return
	RunState.add_souls(gain)
	_build_sell.call_deferred()
	_refresh.call_deferred()


func _refresh() -> void:
	UIUtils.chain_focus(self)
	souls_label.text = "%d âmes" % RunState.souls
	reroll_button.text = "Relancer (%d âmes)" % get_reroll_cost()
	reroll_button.disabled = RunState.souls < get_reroll_cost() or _cards.is_empty()
	for card in _cards:
		card.set_affordable(RunState.souls >= card.cost)


func _on_buy_requested(item: ItemData) -> void:
	var card := _find_card(item)
	if card == null or card.purchased:
		return
	if not RunState.can_take(item):
		card.mark_purchased()
		return
	if not RunState.spend_souls(card.cost):
		return
	RunState.add_item(item)
	card.mark_purchased()
	_refresh()


func _on_reroll_pressed() -> void:
	var cost := get_reroll_cost()
	if not RunState.spend_souls(cost):
		return
	_rerolls += 1
	_roll_offer()
	_refresh()


## Pactes de vague : proposition facultative, valable pour la prochaine vague.
## Un seul pacte à la fois ; « Aucun pacte » est toujours disponible et gratuit.
func _roll_pacts() -> void:
	UIUtils.clear_children(pact_row)
	_pact_buttons.clear()
	WaveMods.clear_current()

	for mod in WaveMods.roll_offer(RunState.wave + 1, 2):
		var button := Button.new()
		button.theme_type_variation = &"CardButton"
		button.custom_minimum_size = Vector2(300, 88)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s
%s
→ %s" % [
			mod["name"], mod["desc"], _format_pact_rewards(mod)]
		button.toggle_mode = true
		var id: StringName = mod["id"]
		button.pressed.connect(func() -> void: _on_pact_pressed(id))
		pact_row.add_child(button)
		_pact_buttons.append(button)

	_refresh_pacts()


func _format_pact_rewards(mod: Dictionary) -> String:
	var parts: Array[String] = []
	for key in mod.get("rewards", {}):
		var value := float(mod["rewards"][key])
		match String(key):
			"soul_gain_pct": parts.append("%+d %% d'âmes" % roundi(value * 100.0))
			"luck": parts.append("+%s chance" % _num(value))
			"range_pct": parts.append("%+d %% de portée" % roundi(value * 100.0))
			_: parts.append("%s %+.2f" % [key, value])
	if float(mod.get("key_chance", 0.0)) > 0.0:
		parts.append("%+d %% de chance de clé" % roundi(float(mod["key_chance"]) * 100.0))
	return ", ".join(parts)


## Même règle que l'écran de malédictions : 0.5 reste « 0,5 ».
func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) 		else String.num(value, 1).replace(".", ",")


func _on_pact_pressed(id: StringName) -> void:
	# Re-cliquer sur le pacte actif l'annule : le refus reste toujours accessible.
	if WaveMods.has_modifier() and WaveMods.current.get("id", &"") == id:
		WaveMods.decline()
	else:
		WaveMods.accept(id)
	_refresh_pacts()


func _refresh_pacts() -> void:
	var active: StringName = WaveMods.current.get("id", &"")
	for i in _pact_buttons.size():
		var mod: Dictionary = WaveMods.offer[i] if i < WaveMods.offer.size() else {}
		_pact_buttons[i].button_pressed = mod.get("id", &"") == active
	if active == &"":
		pact_status.text = "Aucun pacte — la vague suivante se joue normalement."
		pact_status.add_theme_color_override(&"font_color", Color(0.68, 0.64, 0.64))
	else:
		pact_status.text = "Pacte actif : %s (une vague)" % WaveMods.current["name"]
		pact_status.add_theme_color_override(&"font_color", Color(1, 0.55, 0.3))


func _on_souls_changed(_amount: int) -> void:
	if _open:
		_refresh()


func _find_card(item: ItemData) -> ItemCard:
	for card in _cards:
		if card.item == item:
			return card
	return null
