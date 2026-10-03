class_name StatsTotaux
## Les TOTAUX de la fiche de run, partagés entre la fiche (TAB) et la colonne de
## stats de la boutique (0.10.1) : les deux écrans doivent dire exactement la
## même chose, donc il n'y a qu'un seul calcul.

## Intitulé, clé, plafond, UNITÉ.
##
## Afficher le plafond n'est pas décoratif : tout l'équilibrage du jeu repose sur
## eux, et un joueur qui ignore qu'il est à +210 % de dégâts continue d'acheter
## des objets de dégâts pour rien.
##
## L'unité ne sert qu'aux colonnes de source : le total garde son écriture riche
## (« ×2.00 », « 12 (−18 %) »), qui n'aurait aucun sens répétée cinq fois sur
## une ligne.
const LIGNES := [
	["Dégâts", "damage", PlayerStats.CAP_DAMAGE_PCT, "pct"],
	["  dont dégâts plats", "damage_flat", 0.0, "dec"],
	["Cadence de tir", "fire_rate", PlayerStats.CAP_FIRE_RATE_PCT, "pct"],
	["Projectiles", "projectiles", PlayerStats.CAP_PROJECTILE_BONUS, "ent"],
	["Ennemis traversés", "pierce", PlayerStats.CAP_PIERCE, "ent"],
	["Chance de critique", "crit", PlayerStats.CAP_CRIT_CHANCE, "pct"],
	["Dégâts critiques", "crit_damage", 0.0, "pct"],
	["PV maximum", "health", 0.0, "plat"],
	["Armure", "armor", PlayerStats.CAP_ARMOR, "plat"],
	["Régénération", "regen", 0.0, "dec"],
	["Vol de vie", "lifesteal", PlayerStats.CAP_LIFESTEAL, "pct"],
	["Vitesse", "speed", PlayerStats.CAP_MOVE_SPEED_PCT, "pct"],
	["Portée de visée", "range", PlayerStats.CAP_RANGE_PCT, "pct"],
	["Rayon de ramassage", "pickup", PlayerStats.CAP_PICKUP_PCT, "pct"],
	["Gain d'âmes", "souls", PlayerStats.CAP_SOUL_PCT, "pct"],
	["Chance", "luck", PlayerStats.CAP_LUCK, "dec"],
]

## Une ligne sur deux, en braise à peine visible.
const RAYURE := Color(1.0, 0.6, 0.3, 0.08)
## Le filet sous chaque ligne.
const FILET := Color(0.62, 0.26, 0.12, 0.3)
## La ligne sous la souris.
const SURVOL := Color(1.0, 0.62, 0.3, 0.16)


## LES LIGNES SE SUIVENT À L'ŒIL (0.10.1). La fiche alignait une quinzaine de
## lignes de six colonnes sans rien entre elles : on perdait sa ligne en
## allant de l'intitulé au total, 900 px plus loin. Une rayure une ligne sur
## deux, un filet sous chacune, et la ligne survolée s'allume.
##
## Dessiné SOUS les cellules, par la grille elle-même : chaque rangée se lit sur
## la position de sa première cellule, que la grille a déjà calculée.
## `premiere` saute l'en-tête.
static func zebrer(grille: GridContainer, premiere: int = 0) -> void:
	grille.add_theme_constant_override(&"v_separation", 8)
	grille.mouse_filter = Control.MOUSE_FILTER_PASS
	grille.set_meta(&"survol", -1)
	grille.draw.connect(_dessiner.bind(grille, premiere))
	grille.sort_children.connect(grille.queue_redraw)
	grille.gui_input.connect(func(evenement: InputEvent) -> void:
		if evenement is InputEventMouseMotion:
			var ligne := _ligne_sous(grille, (evenement as InputEventMouseMotion).position.y, premiere)
			if ligne != int(grille.get_meta(&"survol")):
				grille.set_meta(&"survol", ligne)
				grille.queue_redraw())
	grille.mouse_exited.connect(func() -> void:
		grille.set_meta(&"survol", -1)
		grille.queue_redraw())


static func _rangee(grille: GridContainer, ligne: int) -> Rect2:
	var cellule := grille.get_child(ligne * grille.columns) as Control
	var marge := grille.get_theme_constant(&"v_separation") * 0.5
	# Un peu au-delà de la grille à gauche et à droite : le texte ne touche pas
	# le bord de sa rayure.
	return Rect2(-10.0, cellule.position.y - marge, grille.size.x + 20.0, cellule.size.y + marge * 2.0)


static func _ligne_sous(grille: GridContainer, y: float, premiere: int) -> int:
	for ligne in range(premiere, grille.get_child_count() / maxi(1, grille.columns)):
		if _rangee(grille, ligne).has_point(Vector2(1.0, y)):
			return ligne
	return -1


static func _dessiner(grille: GridContainer, premiere: int) -> void:
	var survol := int(grille.get_meta(&"survol", -1))
	for ligne in range(premiere, grille.get_child_count() / maxi(1, grille.columns)):
		var rect := _rangee(grille, ligne)
		if ligne == survol:
			grille.draw_rect(rect, SURVOL)
		elif (ligne - premiere) % 2 == 0:
			grille.draw_rect(rect, RAYURE)
		grille.draw_line(Vector2(0.0, rect.end.y), Vector2(rect.end.x, rect.end.y), FILET, 1.0)


## Le total est-il bridé par son plafond ? Jamais en Déchaînement : plus aucun
## plafond ne s'applique, et le dire pousserait à arrêter d'acheter ce qui est
## justement devenu illimité.
static func au_plafond(valeur: float, plafond: float) -> bool:
	return not RunState.unleashed and plafond > 0.0 and valeur >= plafond - 0.0001


## Total affiché : par les ACCESSEURS, donc plafonné, et surtout lu sur les
## NŒUDS VIVANTS quand la statistique a une valeur absolue.
##
## Lire l'arme et le joueur plutôt que refaire leur calcul est le seul moyen
## d'être sûr que la fiche dise la même chose que le jeu. Une formule recopiée
## ici se désynchroniserait au premier changement d'équilibrage, et une fiche
## qui ment est pire qu'une fiche absente.
static func total(cle: String, stats: PlayerStats, arbre: SceneTree) -> Array:
	var joueur := arbre.get_first_node_in_group(&"player")
	if joueur != null and is_instance_valid(joueur):
		var arme := joueur.get_node_or_null("Weapons/Weapon")
		var visee := joueur.get_node_or_null("Targeting")
		var sante := joueur.get_node_or_null("Health")
		match cle:
			"damage":
				if arme != null:
					return [TranslationServer.translate("%.1f /tir") % arme.get_projectile_damage(), stats.get_damage_pct()]
			"fire_rate":
				if arme != null:
					var duree: float = arme.get_cooldown_duration()
					return ["%.1f /s" % (1.0 / maxf(0.01, duree)), stats.get_fire_rate_pct()]
			"projectiles":
				if arme != null:
					return ["%d" % arme.get_projectile_count(),
						float(stats.get_projectile_bonus())]
			"crit":
				if arme != null:
					return [TranslationServer.translate("%d %%") % roundi(arme.get_crit_chance() * 100.0),
						stats.get_crit_chance()]
			"crit_damage":
				if arme != null:
					return ["×%.2f" % arme.get_crit_multiplier(), stats.get_crit_damage_pct()]
			"health":
				if sante != null:
					return ["%d" % roundi(sante.max_health), stats.max_health_flat]
			"speed":
				return ["%d px/s" % roundi(joueur.move_speed), stats.get_move_speed_pct()]
			"range":
				if visee != null:
					return ["%d px" % roundi(visee.range_radius), stats.get_range_pct()]

	match cle:
		"damage":
			return [TranslationServer.translate("+%d %%") % roundi(stats.get_damage_pct() * 100.0), stats.get_damage_pct()]
		"damage_flat":
			# S'ajoute AVANT le pourcentage, donc il est multiplié par lui : +1.5
			# plat sur une arme à +50 % vaut +2.25 de dégâts réels. La ligne
			# « Dégâts » juste au-dessus en porte déjà la conséquence, celle-ci
			# ne fait que dire d'où vient l'écart.
			return ["%+.1f" % stats.damage_flat, stats.damage_flat]
		"fire_rate":
			return [TranslationServer.translate("%+d %%") % roundi(stats.get_fire_rate_pct() * 100.0), stats.get_fire_rate_pct()]
		"projectiles":
			return ["+%d" % stats.get_projectile_bonus(), float(stats.get_projectile_bonus())]
		"pierce":
			return ["+%d" % stats.get_pierce(), float(stats.get_pierce())]
		"crit":
			return [TranslationServer.translate("%d %%") % roundi(stats.get_crit_chance() * 100.0), stats.get_crit_chance()]
		"crit_damage":
			return ["×%.2f" % (2.0 + stats.get_crit_damage_pct()), stats.get_crit_damage_pct()]
		"health":
			return ["%+d" % roundi(stats.max_health_flat), stats.max_health_flat]
		"armor":
			return [TranslationServer.translate("%d  (−%d %%)") % [roundi(stats.get_armor()),
				roundi(stats.get_damage_reduction() * 100.0)], stats.get_armor()]
		"regen":
			return [TranslationServer.translate("%.1f PV/s") % stats.regen, stats.regen]
		"lifesteal":
			return [TranslationServer.translate("%.1f %%") % (stats.get_lifesteal() * 100.0), stats.get_lifesteal()]
		"speed":
			return [TranslationServer.translate("%+d %%") % roundi(stats.get_move_speed_pct() * 100.0), stats.get_move_speed_pct()]
		"range":
			return [TranslationServer.translate("+%d %%") % roundi(stats.get_range_pct() * 100.0), stats.get_range_pct()]
		"pickup":
			return [TranslationServer.translate("+%d %%") % roundi(stats.get_pickup_radius_pct() * 100.0),
				stats.get_pickup_radius_pct()]
		"souls":
			return [TranslationServer.translate("+%d %%") % roundi(stats.get_soul_gain_pct() * 100.0), stats.get_soul_gain_pct()]
		"luck":
			return ["%.1f" % stats.get_luck(), stats.get_luck()]
	return ["", 0.0]
