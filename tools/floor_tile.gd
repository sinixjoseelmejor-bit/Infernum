extends SceneTree
## Fabrique le carreau du second etage a partir de son rendu source.
##
##     Godot --headless --path . --script res://tools/floor_tile.gd
##
## Godot est utilise ici, et pas tools/extract_assets.py, parce qu'il sait
## decoder le JPEG — ce que le pur Python de tools/pngio.py ne sait pas.
##
## Le rendu source ne peut pas se repeter tel quel : il est VIGNETTE, donc le
## repeter dessinerait une grille sombre a l'infini. L'outil mesure le pas des
## dalles par autocorrelation, decoupe un nombre entier de dalles aligne sur un
## joint, affine la decoupe en minimisant l'ecart au joint, puis divise le
## vignettage. Il imprime les mesures : un joint au niveau du bruit entre
## colonnes voisines est invisible.
##
## Le rendu source vit dans source/, masque a Godot par un .gdignore : il ne
## doit pas partir dans l'export. Seul le carreau produit est utilise par le jeu.

const SRC := "assets/sprites/arena/floor/source/Floor2.jpg"
const DST := "assets/sprites/arena/floor/floor2.png"


func _initialize() -> void:
	var racine := ProjectSettings.globalize_path("res://")
	var img := Image.load_from_file(racine.path_join(SRC))
	if img == null:
		print("ECHEC : lecture de ", SRC)
		quit(1)
		return
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	print("source ", w, "x", h)

	# --- Profils de luminance -------------------------------------------------
	var col := _profil(img, w, h, true)
	var lig := _profil(img, w, h, false)

	# --- Pas des dalles : autocorrelation, mesuree separement en x et en y ----
	var pas_x := _periode(col)
	var pas_y := _periode(lig)
	print("pas des dalles mesure : x=", pas_x, " y=", pas_y, " px")

	# --- Phase : le decoupage doit commencer SUR un joint (colonne sombre) ----
	var phase_x := _phase(col, pas_x)
	var phase_y := _phase(lig, pas_y)

	# --- Plus grand carre entier de dalles qui tienne dans la hauteur ---------
	# Une dalle de marge en haut et en bas : le vignettage est le plus violent
	# dans les tout derniers pixels, autant ne pas les prendre.
	var n := maxi(1, int(floor(float(h - phase_y) / float(pas_y))) - 2)
	var larg := n * pas_x
	var haut := n * pas_y
	var x0 := phase_x + int(round(float(w - phase_x - larg) / (2.0 * pas_x))) * pas_x
	var y0 := phase_y + int(round(float(h - phase_y - haut) / (2.0 * pas_y))) * pas_y
	x0 = clampi(x0, 0, w - larg)
	y0 = clampi(y0, 0, h - haut)

	# --- Reglage fin : la periode entiere n'est pas forcement la meilleure ----
	# Le pas reel peut etre fractionnaire (768 / 88 ne tombe pas juste). On essaie
	# donc quelques largeurs et hauteurs autour de la valeur theorique et on garde
	# celle qui minimise l'ECART AU JOINT, c'est-a-dire le defaut qu'on cherche a
	# supprimer, plutot que de faire confiance a la periode.
	var bruit := _bruit(img, x0, y0, larg, haut)
	larg = _affine(img, x0, y0, larg, haut, true)
	haut = _affine(img, x0, y0, larg, haut, false)
	print("decoupe ", larg, "x", haut, " en (", x0, ",", y0, "), ", n, " dalles de cote")
	print("bruit entre colonnes voisines : ", snappedf(bruit * 255.0, 0.01), " /255")
	print("joint avant aplatissement : v=",
		snappedf(_joint(img, x0, y0, larg, haut, true) * 255.0, 0.01), " h=",
		snappedf(_joint(img, x0, y0, larg, haut, false) * 255.0, 0.01))

	var tuile := img.get_region(Rect2i(x0, y0, larg, haut))

	# --- Aplatir le vignettage ------------------------------------------------
	# Le profil d'une colonne melange deux choses : le vignettage (lent) et les
	# joints entre dalles (periodiques). Une moyenne glissante sur EXACTEMENT un
	# pas efface le periodique et ne laisse que le vignettage : c'est lui, et lui
	# seul, qu'on divise. Diviser par le profil brut effacerait les joints.
	var pc := _profil(tuile, larg, haut, true)
	var pl := _profil(tuile, larg, haut, false)
	var vx := _lisse(pc, pas_x)
	var vy := _lisse(pl, pas_y)
	var mx := _moyenne(vx)
	var my := _moyenne(vy)

	for y in haut:
		for x in larg:
			var c := tuile.get_pixel(x, y)
			var k := (mx / maxf(0.001, vx[x])) * (my / maxf(0.001, vy[y]))
			tuile.set_pixel(x, y, Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0),
				minf(c.b * k, 1.0)))

	print("joint apres aplatissement : v=",
		snappedf(_joint(tuile, 0, 0, larg, haut, true) * 255.0, 0.01), " h=",
		snappedf(_joint(tuile, 0, 0, larg, haut, false) * 255.0, 0.01),
		"   (invisible si proche du bruit ci-dessus)")

	var err := tuile.save_png(racine.path_join(DST))
	print("ecrit ", DST, " ", larg, "x", haut, " (code ", err, ")")
	quit(0)


## Luminance moyenne par colonne (`par_colonne`) ou par ligne.
func _profil(img: Image, w: int, h: int, par_colonne: bool) -> PackedFloat32Array:
	var n := w if par_colonne else h
	var m := h if par_colonne else w
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var acc := 0.0
		for j in m:
			var c := img.get_pixel(i, j) if par_colonne else img.get_pixel(j, i)
			acc += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
		out[i] = acc / float(m)
	return out


## Periode dominante du profil, par autocorrelation sur le signal centre.
func _periode(p: PackedFloat32Array) -> int:
	var n := p.size()
	var moy := _moyenne(p)
	var centre := PackedFloat32Array()
	centre.resize(n)
	for i in n:
		centre[i] = p[i] - moy
	var meilleur := 0
	var score := -1e30
	for lag in range(55, 130):
		var acc := 0.0
		for i in range(n - lag):
			acc += centre[i] * centre[i + lag]
		acc /= float(n - lag)
		if acc > score:
			score = acc
			meilleur = lag
	return meilleur


## Decalage qui aligne le decoupage sur les joints : celui qui minimise la
## luminance aux positions phase + k*pas (les joints sont sombres).
func _phase(p: PackedFloat32Array, pas: int) -> int:
	var meilleur := 0
	var score := 1e30
	for ph in pas:
		var acc := 0.0
		var n := 0
		var i := ph
		while i < p.size():
			acc += p[i]
			n += 1
			i += pas
		if n > 0 and acc / float(n) < score:
			score = acc / float(n)
			meilleur = ph
	return meilleur


## Moyenne glissante sur une fenetre d'un pas, bords replies.
func _lisse(p: PackedFloat32Array, pas: int) -> PackedFloat32Array:
	var n := p.size()
	var demi := pas / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var acc := 0.0
		for k in range(-demi, demi + 1):
			var j := absi(i + k)
			if j >= n:
				j = 2 * (n - 1) - j
			acc += p[clampi(j, 0, n - 1)]
		out[i] = acc / float(2 * demi + 1)
	return out


func _moyenne(p: PackedFloat32Array) -> float:
	var acc := 0.0
	for v in p:
		acc += v
	return acc / float(maxi(1, p.size()))


## Ecart moyen de luminance entre les deux bords qui se toucheront une fois la
## tuile repetee. `vertical` = bord gauche contre bord droit.
func _joint(img: Image, x0: int, y0: int, w: int, h: int, vertical: bool) -> float:
	var acc := 0.0
	if vertical:
		for y in h:
			acc += absf(_l(img, x0, y0 + y) - _l(img, x0 + w - 1, y0 + y))
		return acc / float(h)
	for x in w:
		acc += absf(_l(img, x0 + x, y0) - _l(img, x0 + x, y0 + h - 1))
	return acc / float(w)


## Ecart moyen entre deux colonnes VOISINES a l'interieur de la decoupe. C'est
## la reference : un joint a ce niveau-la est indistinguable d'un joint normal
## entre deux colonnes de pierre, donc invisible.
func _bruit(img: Image, x0: int, y0: int, w: int, h: int) -> float:
	var acc := 0.0
	var n := 0
	for y in h:
		var x := 0
		while x < w - 1:
			acc += absf(_l(img, x0 + x, y0 + y) - _l(img, x0 + x + 1, y0 + y))
			n += 1
			x += 7
	return acc / float(maxi(1, n))


## Cherche, a quelques pixels pres, la dimension qui minimise le joint.
func _affine(img: Image, x0: int, y0: int, w: int, h: int, largeur: bool) -> int:
	var base := w if largeur else h
	var meilleur := base
	var score := 1e30
	for d in range(-7, 8):
		var t := base + d
		if largeur:
			if x0 + t > img.get_width():
				continue
		elif y0 + t > img.get_height():
			continue
		var e := _joint(img, x0, y0, t if largeur else w, h if largeur else t, largeur)
		if e < score:
			score = e
			meilleur = t
	return meilleur


func _l(img: Image, x: int, y: int) -> float:
	var c := img.get_pixel(x, y)
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
