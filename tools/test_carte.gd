extends Node
## Tests du générateur de carte : les règles de jouabilité, vérifiées sur des
## milliers de parcelles à chaque lancement.
##
##   godot --headless --path . res://tools/test_carte.tscn
##
## Code de sortie 0 si tout passe, 1 sinon. Exclu des paquets joueurs avec le
## reste de `tools/`. Demande les planches extraites (tools/extract_assets.py) :
## sans elles, il le dit et sort en échec plutôt que de tout déclarer bon.
##
## Il imprime aussi les MESURES reportées dans le README (« La carte ») : part
## de lave à l'écran, obstacles par écran, lieux tirés.

const GRAINES := 40
## Fenêtre de parcelles examinée par graine et par étage.
const RAYON := 4
## Écran de référence, en pixels du monde.
const ECRAN := Vector2(1920.0, 1080.0)
const VUES_PAR_GRAINE := 12

var _passed := 0
var _failed := 0
var _masques: Dictionary = {}


func _ready() -> void:
	if not _charger_tailles():
		push_error("test_carte : planches absentes, lancez tools/extract_assets.py")
		get_tree().quit(1)
		return
	_test_determinisme()
	_test_regles(GenerateurCarte.SURFACE)
	_test_regles(GenerateurCarte.PROFONDEUR)
	_test_exclusion_supplementaire()
	_test_connexite()
	print("\ntest_carte : %d réussis, %d échoués" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _charger_tailles() -> bool:
	for id: StringName in EnferDB.PIECES.keys():
		var chemin := EnferDB.chemin(id)
		if not ResourceLoader.exists(chemin):
			return false
		var t: Texture2D = load(chemin)
		GenerateurCarte.mesurer(id, t)
		if EnferDB.info(id).get("lave", false):
			_masques[id] = _masque(t)
	var vieux: Array = GenerateurCarte.RUINE_MUR + GenerateurCarte.RUINE_COEUR 		+ GenerateurCarte.RUINE_SOL + GenerateurCarte.POTERIE + GenerateurCarte.VEGETATION 		+ GenerateurCarte.ROCHE_GROS + GenerateurCarte.ROCHE_MOYEN 		+ GenerateurCarte.ROCHE_PETIT + [GenerateurCarte.RUINE_COIN, GenerateurCarte.ROCHE_TETE]
	for id: StringName in vieux:
		var chemin := "res://assets/sprites/decor/%s.png" % id
		if not ResourceLoader.exists(chemin):
			return false
		GenerateurCarte.mesurer(id, load(chemin))
	return true


## Même critère que `Carte._masque_lave`, sans fermeture ni érosion : le test
## mesure la lave DESSINÉE.
func _masque(t: Texture2D) -> Dictionary:
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var o := img.get_data()
	var l := img.get_width()
	var h := img.get_height()
	var m := PackedByteArray()
	m.resize(l * h)
	for i in l * h:
		m[i] = 1 if (o[i * 4 + 3] > 128 and o[i * 4] > 160 and o[i * 4 + 1] > 50
			and o[i * 4 + 2] < 110 and float(o[i * 4]) > float(o[i * 4 + 1]) * 1.25) else 0
	return {"l": l, "h": h, "m": m}


func _generateur(graine: int, etage: int) -> GenerateurCarte:
	var g := GenerateurCarte.new()
	g.graine = graine
	g.etage = etage
	return g


# --- Déterminisme ------------------------------------------------------------

func _test_determinisme() -> void:
	var a := _generateur(7, GenerateurCarte.SURFACE)
	var b := _generateur(7, GenerateurCarte.SURFACE)
	var pareil := true
	for py in range(-3, 4):
		for px in range(-3, 4):
			var p := Vector2i(px, py)
			if str(a.engendrer(p)) != str(b.engendrer(p)):
				pareil = false
	_check("une parcelle revue redonne le même lieu", pareil)
	# Relire une parcelle APRÈS d'autres ne change rien : pas d'état caché.
	var premiere := str(a.engendrer(Vector2i(2, -1)))
	for i in 20:
		a.engendrer(Vector2i(i, i * 3))
	_check("l'ordre de visite n'influe pas", str(a.engendrer(Vector2i(2, -1))) == premiere)
	var s := _generateur(7, GenerateurCarte.SURFACE)
	var p2 := _generateur(7, GenerateurCarte.PROFONDEUR)
	var differe := false
	for px in range(0, 6):
		if str(s.engendrer(Vector2i(px, 1))) != str(p2.engendrer(Vector2i(px, 1))):
			differe = true
	_check("surface et profondeur portent des lieux différents", differe)
	var autre := _generateur(8, GenerateurCarte.SURFACE)
	var differe_graine := false
	for px in range(0, 6):
		if str(a.engendrer(Vector2i(px, 2))) != str(autre.engendrer(Vector2i(px, 2))):
			differe_graine = true
	_check("deux graines, deux cartes", differe_graine)


# --- Les règles, sur de nombreuses graines -----------------------------------

func _test_regles(etage: int) -> void:
	var nom := "surface" if etage == GenerateurCarte.SURFACE else "profondeur"
	GenerateurCarte.poses_tentees = 0
	GenerateurCarte.poses_deplacees = 0
	GenerateurCarte.poses_tombees = 0
	var ecarts_violes := 0
	var hors_parcelle := 0
	var pres_du_depart := 0
	var lave_trop_pres := 0
	var inconnues := 0
	var chevauchements := 0
	var sur_lave := 0
	var marques_sur_lave := 0
	var debordent := 0
	var dressees := 0
	var obstacles_total := 0
	var parcelles := 0
	var lieux: Dictionary = {}
	var part_lave: Array[float] = []
	var rivieres_voulues := 0
	var rivieres_posees := 0
	var obstacles_par_vue: Array[int] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + etage
	for graine in GRAINES:
		var g := _generateur(1000 + graine * 7919, etage)
		var obstacles: Array[Dictionary] = []   # + "parcelle"
		var laves: Array[Dictionary] = []       # poses de lave
		for py in range(-RAYON, RAYON + 1):
			for px in range(-RAYON, RAYON + 1):
				var parcelle := Vector2i(px, py)
				var lieu := g.lieu_de(parcelle)
				lieux[lieu] = int(lieux.get(lieu, 0)) + 1
				parcelles += 1
				var riviere_posee := false
				var interieur := Rect2(Vector2(parcelle) * GenerateurCarte.ZONE_COTE,
					Vector2.ONE * GenerateurCarte.ZONE_COTE).grow(-GenerateurCarte.BORD + 0.5)
				var poses_parcelle := g.engendrer(parcelle)
				var bilan := _composition(poses_parcelle, parcelle)
				chevauchements += bilan.x
				sur_lave += bilan.y
				marques_sur_lave += bilan.z
				debordent += bilan.w
				for pose: Dictionary in poses_parcelle:
					if not EnferDB.est_plate(pose["id"]) and not pose.has("mur"):
						dressees += 1
				for pose: Dictionary in poses_parcelle:
					var id: StringName = pose["id"]
					if not pose["vieux"] and not pose.has("mur") and not EnferDB.PIECES.has(id):
						inconnues += 1
						continue
					if pose["vieux"]:
						continue
					if GenerateurCarte.bloque(pose):
						var o := GenerateurCarte.forme_obstacle(pose)
						o["parcelle"] = parcelle
						obstacles.append(o)
						var boite := Rect2(o["a"], Vector2.ZERO).expand(o["b"]).grow(o["r"])
						if not interieur.encloses(boite):
							hors_parcelle += 1
						if GenerateurCarte._distance_point_segment(Vector2.ZERO, o["a"], o["b"]) \
								- float(o["r"]) < GenerateurCarte.EXCLUSION - 0.5:
							pres_du_depart += 1
					if String(id).begins_with("riviere_"):
						riviere_posee = true
					if EnferDB.info(id).get("lave", false):
						var xf := Transform2D(float(pose["r"]), Vector2(pose["e"], pose["e"]), 0.0,
							pose["p"])
						pose["inv"] = xf.affine_inverse()
						pose["boite"] = GenerateurCarte.emprise(pose)
						laves.append(pose)
						var rect := GenerateurCarte.emprise(pose).grow(-6.0)
						if not interieur.encloses(rect):
							hors_parcelle += 1
						if GenerateurCarte._distance_point_rect(Vector2.ZERO, rect) \
								< GenerateurCarte.EXCLUSION - 0.5:
							pres_du_depart += 1
				if lieu == GenerateurCarte.Lieu.RIVIERE:
					rivieres_voulues += 1
					if riviere_posee:
						rivieres_posees += 1
		obstacles_total += obstacles.size()
		# Règle 1, toutes paires, y compris entre parcelles voisines.
		for i in obstacles.size():
			for j in range(i + 1, obstacles.size()):
				var a: Dictionary = obstacles[i]
				var b: Dictionary = obstacles[j]
				var d := GenerateurCarte._distance_segments(a["a"], a["b"], b["a"], b["b"]) \
					- float(a["r"]) - float(b["r"])
				var joints: bool = a["parcelle"] == b["parcelle"] and d <= 4.0
				if d < GenerateurCarte.ECART - 0.5 and not joints:
					ecarts_violes += 1
		# Règle 4.
		for o: Dictionary in obstacles:
			for pose: Dictionary in laves:
				var d := GenerateurCarte._distance_segment_rect(o["a"], o["b"],
					GenerateurCarte.emprise(pose).grow(-6.0)) - float(o["r"])
				if d > 0.5 and d < GenerateurCarte.ECART_LAVE - 0.5:
					lave_trop_pres += 1
		# Mesures par écran, dans la fenêtre examinée.
		var etendue := (float(RAYON) - 0.5) * GenerateurCarte.ZONE_COTE
		for _v in VUES_PAR_GRAINE:
			var centre := Vector2(rng.randf_range(-etendue, etendue) + ECRAN.x * 0.0,
				rng.randf_range(-etendue, etendue))
			var vue := Rect2(centre - ECRAN * 0.5, ECRAN)
			var n := 0
			for o: Dictionary in obstacles:
				if vue.has_point(o["a"]):
					n += 1
			obstacles_par_vue.append(n)
			if etage == GenerateurCarte.PROFONDEUR:
				part_lave.append(_part_lave(vue, laves))

	_check("%s : aucune pièce inconnue du catalogue" % nom, inconnues == 0)
	_check("%s : règle 1, obstacles jointifs ou à %d px (%d écarts violés)" \
		% [nom, int(GenerateurCarte.ECART), ecarts_violes], ecarts_violes == 0)
	_check("%s : règle 2, tout reste dans sa parcelle (%d dehors)" % [nom, hors_parcelle],
		hors_parcelle == 0)
	_check("%s : règle 3, rien près du départ (%d)" % [nom, pres_du_depart], pres_du_depart == 0)
	_check("%s : règle 4, la lave laisse l'écart aux obstacles (%d)" % [nom, lave_trop_pres],
		lave_trop_pres == 0)
	_check("%s : règle 6, aucun pied n'en recouvre un autre (%d sur %d pièces dressées)" 		% [nom, chevauchements, dressees], chevauchements == 0)
	_check("%s : règle 6, aucune marque au sol n'en recouvre une autre ni la lave (%d)" 		% [nom, marques_sur_lave], marques_sur_lave == 0)
	_check("%s : règle 7, rien de dressé dans la lave (%d)" % [nom, sur_lave], sur_lave == 0)
	_check("%s : règle 8, rien ne déborde de sa parcelle (%d)" % [nom, debordent], debordent == 0)
	print("  %s : poses — %d tentées, %d %% déplacées pour trouver leur place, %d %% tombées" 		% [nom, GenerateurCarte.poses_tentees,
			roundi(100.0 * GenerateurCarte.poses_deplacees / maxf(1, GenerateurCarte.poses_tentees)),
			roundi(100.0 * GenerateurCarte.poses_tombees / maxf(1, GenerateurCarte.poses_tentees))])
	GenerateurCarte.poses_tentees = 0
	GenerateurCarte.poses_deplacees = 0
	GenerateurCarte.poses_tombees = 0

	var moyenne := 0.0
	var maxi := 0
	var vides := 0
	for n: int in obstacles_par_vue:
		moyenne += float(n)
		maxi = maxi if maxi > n else n
		if n == 0:
			vides += 1
	moyenne /= float(obstacles_par_vue.size())
	print("  %s : %d parcelles, %.2f obstacle(s) par parcelle" \
		% [nom, parcelles, float(obstacles_total) / float(parcelles)])
	print("  %s : obstacles par écran 1920×1080 — moyenne %.2f, max %d, écrans sans obstacle %d %%" \
		% [nom, moyenne, maxi, roundi(100.0 * vides / obstacles_par_vue.size())])
	var noms := {}
	for k in GenerateurCarte.Lieu.keys():
		noms[GenerateurCarte.Lieu[k]] = k
	var ligne := "  %s : lieux —" % nom
	for lieu: int in lieux.keys():
		ligne += " %s %d %%" % [noms[lieu], roundi(100.0 * lieux[lieu] / parcelles)]
	print(ligne)
	if rivieres_voulues > 0:
		print("  %s : rivières posées %d sur %d parcelles « rivière » (les petites deviennent des champs)" 			% [nom, rivieres_posees, rivieres_voulues])
	if not part_lave.is_empty():
		part_lave.sort()
		var m := 0.0
		for v: float in part_lave:
			m += v
		m /= float(part_lave.size())
		var p95 := part_lave[int(part_lave.size() * 0.95)]
		var sans := 0
		for v: float in part_lave:
			if v <= 0.0:
				sans += 1
		print("  profondeur : lave à l'écran — moyenne %.1f %%, 95e centile %.1f %%, max %.1f %%, écrans sans lave %d %%" \
			% [m * 100.0, p95 * 100.0, part_lave[-1] * 100.0,
				roundi(100.0 * sans / part_lave.size())])
		_check("profondeur : la lave couvre en moyenne moins de 8 %% de l'écran (%.1f %%)" % (m * 100.0),
			m < 0.08)
		_check("profondeur : jamais plus de 25 %% d'un écran (%.1f %%)" % (part_lave[-1] * 100.0),
			part_lave[-1] < 0.25)


## Les règles de composition d'une parcelle (6 à 8), comptées : Vector4i(pieds
## qui se recouvrent, pièces dressées dans la lave, marques qui se recouvrent ou
## recouvrent la lave, pièces hors de leur parcelle). Les pièces du décor
## d'origine ne sont pas comparées entre elles : les colonnes d'une ruine se
## touchent à dessein, comme avant.
func _composition(poses: Array[Dictionary], parcelle: Vector2i) -> Vector4i:
	var zone := Rect2(Vector2(parcelle) * GenerateurCarte.ZONE_COTE,
		Vector2.ONE * GenerateurCarte.ZONE_COTE).grow(-GenerateurCarte.MARGE_PARCELLE + 0.5)
	var pieds: Array[Dictionary] = []
	var vieux: Array[bool] = []
	var laves: Array[Rect2] = []
	var marques: Array[Rect2] = []
	for pose: Dictionary in poses:
		if pose.has("mur"):
			continue
		var info := EnferDB.info(pose["id"])
		if info.get("lave", false):
			laves.append(GenerateurCarte.emprise(pose).grow(-6.0))
		elif info.has("sol"):
			if int(info["sol"]) != EnferDB.SOL_PLAQUE and not pose["id"] in GenerateurCarte.PONTS:
				marques.append(GenerateurCarte.emprise(pose))
		elif not info.get("creux", false):
			pieds.append(GenerateurCarte.pied_de(pose))
			vieux.append(pose["vieux"])
	var bilan := Vector4i.ZERO
	for i in pieds.size():
		var f: Dictionary = pieds[i]
		var c: Vector2 = f["c"]
		if not zone.encloses(Rect2(c - Vector2(f["rx"], f["ry"]), Vector2(f["rx"], f["ry"]) * 2.0)) 				and not vieux[i]:
			bilan.w += 1
		if vieux[i] and not zone.has_point(c):
			bilan.w += 1
		for lave: Rect2 in laves:
			var rx: float = f["rx"] * 0.8 - 0.5
			var ry: float = f["ry"] * 0.8 - 0.5
			if lave.grow_individual(rx, ry, rx, ry).has_point(c):
				bilan.y += 1
		for j in range(i + 1, pieds.size()):
			if vieux[i] and vieux[j]:
				continue
			if GenerateurCarte.chevauchent(f, pieds[j], GenerateurCarte.TOLERANCE_GRAPPE - 0.01):
				bilan.x += 1
	for i in marques.size():
		for lave: Rect2 in laves:
			if lave.intersects(marques[i].grow(-5.0)):
				bilan.z += 1
		for j in range(i + 1, marques.size()):
			var inter := marques[i].intersection(marques[j])
			if inter.get_area() > 0.16 * minf(marques[i].get_area(), marques[j].get_area()):
				bilan.z += 1
	return bilan


## Part d'un écran recouverte de lave dessinée, échantillonnée tous les 20 px.
func _part_lave(vue: Rect2, laves: Array[Dictionary]) -> float:
	var proches: Array[Dictionary] = []
	for pose: Dictionary in laves:
		if vue.intersects(pose["boite"]):
			proches.append(pose)
	if proches.is_empty():
		return 0.0
	var dedans := 0
	var total := 0
	var y := vue.position.y + 10.0
	while y < vue.end.y:
		var x := vue.position.x + 10.0
		while x < vue.end.x:
			total += 1
			var p := Vector2(x, y)
			for pose: Dictionary in proches:
				if _dans_lave(pose, p):
					dedans += 1
					break
			x += 20.0
		y += 20.0
	return float(dedans) / float(total)


func _dans_lave(pose: Dictionary, p: Vector2) -> bool:
	if not (pose["boite"] as Rect2).has_point(p):
		return false
	var m: Dictionary = _masques[pose["id"]]
	var l: int = m["l"]
	var h: int = m["h"]
	var local: Vector2 = (pose["inv"] as Transform2D) * p + Vector2(l, h) * 0.5
	var x := int(local.x)
	var y := int(local.y)
	if x < 0 or y < 0 or x >= l or y >= h:
		return false
	if pose["fh"]:
		x = l - 1 - x
	if pose["fv"]:
		y = h - 1 - y
	return (m["m"] as PackedByteArray)[y * l + x] == 1


# --- L'exclusion du changement d'étage ---------------------------------------

func _test_exclusion_supplementaire() -> void:
	var point := Vector2(3100.0, -1900.0)
	var trop_pres := 0
	for graine in 20:
		var g := _generateur(500 + graine, GenerateurCarte.PROFONDEUR)
		g.exclusions.append(point)
		var centre := Vector2i((point / GenerateurCarte.ZONE_COTE).floor())
		for py in range(centre.y - 1, centre.y + 2):
			for px in range(centre.x - 1, centre.x + 2):
				for pose: Dictionary in g.engendrer(Vector2i(px, py)):
					if pose["vieux"]:
						continue
					if GenerateurCarte.bloque(pose):
						var o := GenerateurCarte.forme_obstacle(pose)
						if GenerateurCarte._distance_point_segment(point, o["a"], o["b"]) \
								- float(o["r"]) < GenerateurCarte.EXCLUSION - 0.5:
							trop_pres += 1
					if EnferDB.info(pose["id"]).get("lave", false):
						if GenerateurCarte._distance_point_rect(point,
								GenerateurCarte.emprise(pose).grow(-6.0)) < GenerateurCarte.EXCLUSION - 0.5:
							trop_pres += 1
	_check("rien ne surgit sur le joueur au changement d'étage (%d)" % trop_pres, trop_pres == 0)


# --- Pas de poche fermée -----------------------------------------------------

## Le sol libre est-il d'un seul tenant ? Grille de 16 px sur 3 × 3 parcelles,
## obstacles gonflés du rayon d'une brute d'élite (30 px) : toute case libre doit
## être joignable depuis n'importe quelle autre.
func _test_connexite() -> void:
	var poches := 0
	var pas := 16.0
	var gonfle := 30.0
	for graine in 10:
		for etage in [GenerateurCarte.SURFACE, GenerateurCarte.PROFONDEUR]:
			var g := _generateur(3000 + graine * 31, etage)
			var obstacles: Array[Dictionary] = []
			for py in range(-1, 2):
				for px in range(-1, 2):
					for pose: Dictionary in g.engendrer(Vector2i(px, py)):
						if GenerateurCarte.bloque(pose):
							obstacles.append(GenerateurCarte.forme_obstacle(pose))
			var origine := Vector2(-1.0, -1.0) * GenerateurCarte.ZONE_COTE
			var n := int(GenerateurCarte.ZONE_COTE * 3.0 / pas)
			var bloque := PackedByteArray()
			bloque.resize(n * n)
			# Chaque obstacle ne noircit que les cases de sa boîte.
			for o: Dictionary in obstacles:
				var boite := Rect2(o["a"], Vector2.ZERO).expand(o["b"]) \
					.grow(float(o["r"]) + gonfle)
				var x0 := maxi(0, int((boite.position.x - origine.x) / pas))
				var y0 := maxi(0, int((boite.position.y - origine.y) / pas))
				var x1 := mini(n - 1, int((boite.end.x - origine.x) / pas))
				var y1 := mini(n - 1, int((boite.end.y - origine.y) / pas))
				for iy in range(y0, y1 + 1):
					for ix in range(x0, x1 + 1):
						var p := origine + Vector2(ix + 0.5, iy + 0.5) * pas
						if GenerateurCarte._distance_point_segment(p, o["a"], o["b"]) \
								< float(o["r"]) + gonfle:
							bloque[iy * n + ix] = 1
			var vu := PackedByteArray()
			vu.resize(n * n)
			var depart := -1
			var libres := 0
			for i in n * n:
				if bloque[i] == 0:
					libres += 1
					if depart < 0:
						depart = i
			var pile: Array[int] = [depart]
			vu[depart] = 1
			var atteintes := 0
			while not pile.is_empty():
				var i: int = pile.pop_back()
				atteintes += 1
				var x := i % n
				var y := i / n
				for v: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
					if v.x < 0 or v.y < 0 or v.x >= n or v.y >= n:
						continue
					var j := v.y * n + v.x
					if bloque[j] == 0 and vu[j] == 0:
						vu[j] = 1
						pile.append(j)
			if atteintes != libres:
				poches += 1
	_check("aucune poche fermée, même pour une brute d'élite (%d cartes fautives)" % poches,
		poches == 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok   ", label)
	else:
		_failed += 1
		print("  ÉCHEC ", label)
