class_name Bestiaire
extends RefCounted
## LE BESTIAIRE (0.10.1) : chaque créature de l'enfer, recensée à sa première
## élimination.
##
## Un fichier de données, comme `StoryDB`. Une fiche dit d'où vient la créature
## (« histoire ») et ce qu'elle punit (« conseil ») — les deux doivent rester
## VRAIS : un conseil se vérifie dans le script de la créature, pas de mémoire.
##
## Les éliminations se comptent par profil (`SaveGame.compter_tue`), par le nom
## de la scène de la créature (« imp », « golgota ») : un slime né d'un autre et
## un imp d'invocatrice comptent sous le nom de leur espèce.

## La part de la case de 100 px qu'occupe le dessin : tous les sprites tiennent
## dans x 32-77, y 29-59 (mesuré sur la première image de chaque planche de
## repos). Asmodée, lames comprises, fixe la largeur.
const CADRAGE := Rect2(32, 20, 46, 42)

const CREATURES := [
	{"id": &"imp", "nom": "Imp", "planche": "enemies/imp/imp",
		"histoire": "Les plus petits de l'enfer. Ils ne savent faire qu'une chose : venir.",
		"conseil": "Seul, rien. En meute, tout."},
	{"id": &"hound", "nom": "Limier", "planche": "enemies/hound/hound",
		"histoire": "Il a senti ta peur avant de te voir.",
		"conseil": "Il se fige avant de charger, et sa charge ne dévie pas : un pas de côté suffit."},
	{"id": &"cultist", "nom": "Cultiste", "planche": "enemies/cultist/cultist",
		"histoire": "Il prie encore, par habitude, un dieu qui ne vient pas.",
		"conseil": "Il recule quand on l'approche, mais s'arrête pour tirer : c'est là qu'on le rattrape."},
	{"id": &"brute", "nom": "Brute", "planche": "enemies/brute/brute",
		"histoire": "On l'a nourrie de tout ce qui ne servait plus.",
		"conseil": "Lente, mais elle frappe deux fois plus fort qu'un imp. Ne la laisse pas t'acculer."},
	{"id": &"chauve_souris", "nom": "Chauve-souris", "planche": "enemies/chauve_souris/chauve_souris",
		"histoire": "Ni le feu ni la pierre ne l'arrêtent.",
		"conseil": "Elle vole : se cacher derrière le décor ne sert à rien. Elle tombe au premier tir."},
	{"id": &"slime_lave", "nom": "Slime de lave", "planche": "enemies/slime_lave/slime_lave",
		"histoire": "La lave a appris à ramper.",
		"conseil": "Tué, il se divise en deux. Ce qui traverse ou qui brûle en vient à bout."},
	{"id": &"feu_follet", "nom": "Feu follet", "planche": "enemies/feu_follet/feu_follet",
		"histoire": "Une âme égarée qui cherche quelqu'un avec qui brûler.",
		"conseil": "Abats-le pendant sa mèche, et rien n'explose. S'il détone, il ne rapporte rien."},
	{"id": &"oeil", "nom": "Œil", "planche": "enemies/oeil/oeil",
		"histoire": "Il ne cligne jamais. Il attend que tu t'arrêtes.",
		"conseil": "Il se fige pour viser, puis son rayon se verrouille : fonce sur lui pendant qu'il vise."},
	{"id": &"invocatrice", "nom": "Invocatrice", "planche": "enemies/invocatrice/invocatrice",
		"histoire": "Elle appelle, et l'enfer répond toujours.",
		"conseil": "Ses imps tombent en cendre avec elle, et ne rapportent rien. Vise-la d'abord."},
	# Les boss. `vague` : un profil d'avant le bestiaire qui a dépassé cette
	# vague l'a forcément vaincu.
	{"id": &"golgota", "nom": "Golgota", "planche": "bosses/golgota/golgota", "boss": true, "vague": 5,
		"histoire": "Le Mont du Crâne : les os de ceux qui ont joué avant toi.",
		"conseil": "Lent, mais c'est le sol qui frappe. S'éloigner ne fait qu'appeler les croix."},
	{"id": &"lilith", "nom": "Lilith", "planche": "bosses/lilith/lilith", "boss": true, "vague": 10,
		"histoire": "La première femme. Elle a dit non, une fois.",
		"conseil": "Elle disparaît, puis surgit sur toi avec sa progéniture. Garde-la sous le feu."},
	{"id": &"baal", "nom": "Baal", "planche": "bosses/baal/baal", "boss": true, "vague": 15,
		"histoire": "Un dieu qu'on a cessé de prier. Il tonne encore.",
		"conseil": "Chaque cercle bleu est un éclair qui va tomber. Rester loin ne protège de rien."},
	{"id": &"asmodee", "nom": "Asmodée", "planche": "bosses/asmodee/asmodee", "boss": true, "vague": 20,
		"histoire": "Trois têtes, et la chaîne de Salomon.",
		"conseil": "Chaque tête a son attaque. Sa chaîne te tire vers lui avant de charger."},
	{"id": &"lucifer", "nom": "Lucifer", "planche": "bosses/lucifer/lucifer", "boss": true, "vague": 25,
		"histoire": "Il a parié, et il a perdu. Il ne l'a pas accepté.",
		"conseil": "Son cercle de feu s'allume à la distance où tu te tiens. Le seul endroit sûr est près de lui."},
	# Rien de lui ne se montre avant de l'avoir abattu, pas même son nom.
	{"id": &"helel", "nom": "Hélel", "planche": "bosses/lucifer/lucifer", "boss": true, "secret": true,
		"histoire": "Le nom d'avant la chute. Fils de l'Aurore.",
		"conseil": "Trois âmes, un seul corps : il te fait changer de damné en plein combat."},
]


## Le nom d'espèce d'une créature : celui du fichier de sa scène.
static func id_de(creature: Node) -> StringName:
	return StringName(creature.scene_file_path.get_file().get_basename())


static func connue(fiche: Dictionary) -> bool:
	var id: StringName = fiche["id"]
	if SaveGame.nombre_tues(id) > 0:
		return true
	# Les profils d'avant le bestiaire n'ont rien compté : ce qu'ils ont
	# forcément vaincu se déduit de leur progression.
	if fiche.has("vague") and SaveGame.best_wave > int(fiche["vague"]):
		return true
	match id:
		&"lucifer":
			return SaveGame.seal_count() > 0
		&"helel":
			return SaveGame.has_seen_story(StoryDB.HELEL_FIN)
	return false


static func vaincu(id: StringName) -> bool:
	for fiche in CREATURES:
		if fiche["id"] == id:
			return connue(fiche)
	return false


static func nombre_connues() -> int:
	var n := 0
	for fiche in CREATURES:
		if connue(fiche):
			n += 1
	return n


## La première image de sa planche de repos, recadrée sur le dessin.
static func portrait(fiche: Dictionary) -> Texture2D:
	var chemin := "res://assets/sprites/%s_idle.png" % fiche["planche"]
	if not ResourceLoader.exists(chemin):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(chemin)
	atlas.region = CADRAGE
	return atlas
