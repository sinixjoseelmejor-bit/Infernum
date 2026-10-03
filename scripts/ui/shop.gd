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
@onready var body_scroll: ScrollContainer = %BodyScroll
@onready var body: VBoxContainer = body_scroll.get_child(0)
@onready var stats_grille: GridContainer = %ShopStats

## Plancher et plafond de la zone de l'offre. Le plafond garde la boutique dans
## l'écran (1080 unités logiques au minimum) ; entre les deux, elle prend
## exactement la hauteur de son contenu.
const BODY_MIN_HEIGHT := 360.0
const BODY_MAX_HEIGHT := 780.0

var _cards: Array[ItemCard] = []
var _pact_buttons: Array[Button] = []
var _rerolls: int = 0
var _open: bool = false
## Dernière valeur affichée de chaque stat : ce qui vient de changer s'allume.
var _stats_vues: Dictionary = {}


func _ready() -> void:
	# La boutique doit rester interactive alors que le jeu est en pause.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	StatsTotaux.zebrer(stats_grille)
	reroll_button.pressed.connect(_on_reroll_pressed)
	continue_button.pressed.connect(close)
	GameEvents.wave_cleared.connect(_on_wave_cleared)
	RunState.souls_changed.connect(_on_souls_changed)
	# DIFFÉRÉ : la santé et l'arme du joueur se remettent à jour sur le même
	# signal, et la colonne lit leurs valeurs — elle doit passer après eux.
	RunState.stats_recomputed.connect(func(_s: PlayerStats) -> void:
		if _open:
			_maj_stats.call_deferred())


## L'histoire passe AVANT la boutique — scène d'après boss, sceau de Lucifer,
## choix du portail — et c'est elle qui l'ouvre ensuite, ou pas : c'est le
## `StoryDirector` de l'arène qui décide. Sans lui, la boutique s'ouvre seule.
func _on_wave_cleared(_wave: int) -> void:
	if not RunState.is_running:
		return
	var director := get_tree().get_first_node_in_group(&"story_director")
	if director != null:
		director.call(&"before_shop")
	else:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	_rerolls = 0
	visible = true
	get_tree().paused = true
	wave_label.text = tr("Vague %d terminée") % RunState.wave
	# La récolte des survivants est DITE. Des âmes qui arrivent sans explication
	# ne s'attribuent à rien, et le joueur n'apprendrait jamais que blesser sans
	# achever rapporte quelque chose.
	if RunState.leftover_souls > 0:
		wave_label.text += tr("  ·  %d âmes arrachées à %d survivants") % [
			RunState.leftover_souls, RunState.leftover_count]
	_roll_offer()
	_roll_pacts()
	_build_sell()
	_refresh()
	_stats_vues.clear()
	_maj_stats()
	GameEvents.shop_opened.emit()
	continue_button.grab_focus()
	Ecran.apparaitre(self)


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
	# Reliquaire : la première relance de chaque boutique est offerte, et la
	# suite de la table reprend là où elle en était — il décale, il n'efface pas.
	var free := 1 if RunState.has_special(&"free_reroll") else 0
	if _rerolls < free:
		return 0
	var paid := _rerolls - free
	if paid < REROLL_COSTS.size():
		return REROLL_COSTS[paid]
	var beyond := paid - REROLL_COSTS.size() + 1
	return roundi(REROLL_COSTS[-1] * pow(REROLL_COST_GROWTH, beyond))


## LA PIÈCE RARE DE L'OFFRE est mise en valeur — mais seulement si elle est
## épique ou mieux, et strictement plus rare que toutes les autres. Un marqueur
## qui s'allumerait à chaque boutique ne signalerait plus rien.
func _feature_rarest(offer: Array[ItemData]) -> void:
	var best := -1
	var count := 0
	for item in offer:
		if int(item.rarity) > best:
			best = int(item.rarity)
			count = 1
		elif int(item.rarity) == best:
			count += 1
	if best < int(ItemData.Rarity.EPIC) or count != 1:
		return
	for card in _cards:
		if int(card.item.rarity) == best:
			card.set_featured(true)


## Même règle que la Forge et les malédictions : les noms d'objets en Jersey
## ont gagné une ligne, et une hauteur écrite à la main coupait les pactes.
##
## On mesure APRÈS une image de mise en page : avant, les textes à retour à la
## ligne n'ont pas encore leur largeur et réclament une ligne par mot — la zone
## prenait alors son plafond, avec un grand vide sous les pactes.
func _fit_body() -> void:
	await get_tree().process_frame
	body_scroll.custom_minimum_size.y = clampf(
		body.get_combined_minimum_size().y, BODY_MIN_HEIGHT, BODY_MAX_HEIGHT)


## LE VERROU (0.10.1) : une carte verrouillée garde sa place à la relance
## (`relance`), et revient en tête de la boutique suivante — au prix de la
## nouvelle vague, qui a changé. Un objet qu'on ne peut plus prendre (piles au
## maximum) perd son verrou.
func _roll_offer(relance: bool = false) -> void:
	var size := OFFER_SIZE + int(Forge.get_special_total(&"shop_slots"))
	var places: Array = []
	if relance:
		for card in _cards:
			places.append(card.item if card.locked and not card.purchased else null)
	else:
		var gardes: Array[StringName] = []
		for id in RunState.objets_verrouilles:
			var objet := ItemDB.get_item(id)
			if objet != null and RunState.can_take(objet) and places.size() < size:
				places.append(objet)
				gardes.append(id)
		RunState.objets_verrouilles = gardes
	while places.size() < size:
		places.append(null)

	var deja: Array[ItemData] = []
	for place in places:
		if place != null:
			deja.append(place)
	var neufs := ItemDB.roll_offer(places.count(null), maxi(1, RunState.wave),
		RunState.owned_counts, RunState.stats.get_luck(), deja)
	var offer: Array[ItemData] = []
	for place in places:
		if place != null:
			offer.append(place)
		elif not neufs.is_empty():
			offer.append(neufs.pop_front())

	var keep := UIUtils.capture_focus(self)
	UIUtils.clear_children(offer_row)
	_cards.clear()
	for i in offer.size():
		var item := offer[i]
		var card := ItemCard.new()
		# Nom stable par PLACE : le focus reste sur la même case après une
		# relance, qu'on ait pressé son prix ou son cadenas.
		card.name = "carte_%d" % i
		card.buy_requested.connect(_on_buy_requested)
		card.lock_toggled.connect(_on_lock_toggled)
		offer_row.add_child(card)
		card.setup(item, get_item_cost(item))
		card.set_locked(item.id in RunState.objets_verrouilles)
		_cards.append(card)
	if relance:
		UIUtils.chain_focus(self)
		UIUtils.restore_focus(self, keep, reroll_button)
	_feature_rarest(offer)
	_fit_body.call_deferred()

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
		button.text = "%s%s\n%s" % [
			item.display_name, ("  ×%d" % piles) if piles > 1 else "",
			(tr("+%d âme") if get_sell_value(item) == 1 else tr("+%d âmes")) % get_sell_value(item)]
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
	souls_label.text = (tr("%d âme") if RunState.souls == 1 else tr("%d âmes")) % RunState.souls
	var prix := get_reroll_cost()
	reroll_button.text = (tr("Relancer (%d âme)") if prix == 1 else tr("Relancer (%d âmes)")) % prix
	# Tout verrouillé : une relance ne changerait rien, elle coûterait pour rien.
	var a_relancer := _cards.any(func(c: ItemCard) -> bool: return not c.locked)
	reroll_button.disabled = RunState.souls < get_reroll_cost() or not a_relancer
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
	RunState.objets_verrouilles.erase(item.id)
	card.mark_purchased()
	# La colonne de revente suit l'achat : sans ça, l'objet acheté n'y
	# apparaissait qu'à la boutique suivante, et les compteurs ×N restaient faux.
	_build_sell.call_deferred()
	_refresh()


func _on_lock_toggled(item: ItemData, locked: bool) -> void:
	if locked:
		if not item.id in RunState.objets_verrouilles:
			RunState.objets_verrouilles.append(item.id)
	else:
		RunState.objets_verrouilles.erase(item.id)
	_refresh()


func _on_reroll_pressed() -> void:
	var cost := get_reroll_cost()
	if not RunState.spend_souls(cost):
		return
	_rerolls += 1
	_roll_offer(true)
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
		button.text = "%s\n%s\n→ %s" % [
			tr(mod["name"]), tr(mod["desc"]), _format_pact_rewards(mod)]
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
			"soul_gain_pct": parts.append(tr("%+d %% d'âmes") % roundi(value * 100.0))
			"luck": parts.append(tr("+%s chance") % _num(value))
			"range_pct": parts.append(tr("%+d %% de portée") % roundi(value * 100.0))
			_: parts.append("%s %+.2f" % [key, value])
	if float(mod.get("key_chance", 0.0)) > 0.0:
		parts.append(tr("%+d %% de chance de clé") % roundi(float(mod["key_chance"]) * 100.0))
	return ", ".join(parts)


## Même règle que l'écran de malédictions : 0.5 reste « 0,5 ».
func _num(value: float) -> String:
	return UIUtils.nombre(value)


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
		pact_status.text = tr("Pacte actif : %s (une vague)") % tr(WaveMods.current["name"])
		pact_status.add_theme_color_override(&"font_color", Color(1, 0.55, 0.3))


func _on_souls_changed(_amount: int) -> void:
	if _open:
		_refresh()


func _find_card(item: ItemData) -> ItemCard:
	for card in _cards:
		if card.item == item:
			return card
	return null


## LES STATS EN DIRECT (0.10.1) : les totaux de la fiche de run (TAB), dans une
## colonne à droite de l'offre, mis à jour à chaque achat et à chaque revente.
## Même calcul que la fiche (`StatsTotaux`) : les deux écrans ne peuvent pas se
## contredire. Ce qu'un achat vient de changer s'allume un instant — c'est la
## réponse à « qu'est-ce que ça m'a apporté ? ».
func _maj_stats() -> void:
	UIUtils.clear_children(stats_grille)
	var stats := RunState.stats
	for ligne in StatsTotaux.LIGNES:
		var cle := String(ligne[1])
		var total := StatsTotaux.total(cle, stats, get_tree())
		var valeur := float(total[1])
		# Les dégâts plats n'ont une ligne que s'ils existent (voir la fiche).
		if cle == "damage_flat" and absf(valeur) < 0.0001:
			continue
		var au_plafond := StatsTotaux.au_plafond(valeur, float(ligne[2]))

		var titre := Label.new()
		titre.text = tr(String(ligne[0]))
		titre.add_theme_font_size_override(&"font_size", 18)
		titre.add_theme_color_override(&"font_color", Color(0.78, 0.75, 0.72))
		titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_grille.add_child(titre)

		var chiffre := Label.new()
		chiffre.text = String(total[0])
		chiffre.add_theme_font_size_override(&"font_size", 18)
		chiffre.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		chiffre.custom_minimum_size = Vector2(112, 0)
		chiffre.add_theme_color_override(&"font_color", StatsScreen.MAXED if au_plafond
			else (StatsScreen.BONUS if absf(valeur) > 0.0001 else StatsScreen.NEUTRAL))
		stats_grille.add_child(chiffre)
		if _stats_vues.has(cle) and _stats_vues[cle] != chiffre.text:
			var eclat := chiffre.create_tween()
			chiffre.modulate = Color(1.6, 1.6, 1.3)
			eclat.tween_property(chiffre, ^"modulate", Color.WHITE, 0.9)
		_stats_vues[cle] = chiffre.text

		var plafond := Label.new()
		plafond.text = tr("PLAFOND") if au_plafond else ""
		plafond.add_theme_font_size_override(&"font_size", 12)
		plafond.add_theme_color_override(&"font_color", StatsScreen.MAXED)
		plafond.custom_minimum_size = Vector2(46, 0)
		stats_grille.add_child(plafond)
