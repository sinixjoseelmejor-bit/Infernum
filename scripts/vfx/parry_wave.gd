class_name ParryWave
extends Node2D
## L'ONDE DU REFUS DE PLIER : ce qu'on voit quand Job pare un coup.
##
## Dessinée par code et non en planche d'images, pour la raison qui vaut déjà
## pour l'anneau de la seconde chance : son rayon est celui de la portée réelle
## du contre, connu à l'exécution. Une planche mise à l'échelle mentirait le
## jour où le rayon change.
##
## ELLE PART DU CORPS ET VA JUSQU'AU BORD de ce qui a été frappé — pas plus
## loin, pas moins : le joueur doit apprendre la portée en la voyant, une fois.
##
## SANS EFFET DE JEU. Les dégâts et le recul sont déjà partis quand elle
## apparaît ; elle ne fait que les raconter.

## Rayon atteint à la fin, posé par le joueur depuis la portée du contre.
var rayon: float = 150.0
var duree: float = 0.35
## Le bleu de Job. Pas de rouge : le rouge dit « touché », et il vient
## précisément de ne pas l'être.
var teinte: Color = Color(0.62, 0.80, 0.95)
## Aux pieds, comme tout ce qui se pose au sol.
var decalage_pieds: float = 34.0

var _temps: float = 0.0


func _ready() -> void:
	z_index = 40
	position.y += decalage_pieds


func _process(delta: float) -> void:
	_temps += delta
	if _temps >= duree:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_temps / maxf(0.01, duree), 0.0, 1.0)
	# L'onde ralentit en s'élargissant : une expansion linéaire se lit comme un
	# cercle qui grandit, une expansion amortie comme un choc qui se propage.
	var r := rayon * (1.0 - pow(1.0 - p, 2.2))
	var reste := 1.0 - p
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
		Color(teinte.r, teinte.g, teinte.b, 0.85 * reste), 4.0 * reste + 1.0, true)
	# Un second anneau en retard donne l'épaisseur du choc sans coûter un dessin.
	if p > 0.12:
		var r2 := rayon * (1.0 - pow(1.0 - (p - 0.12) / 0.88, 2.2))
		draw_arc(Vector2.ZERO, r2, 0.0, TAU, 48,
			Color(1.0, 1.0, 1.0, 0.35 * reste), 2.0, true)
