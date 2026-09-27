class_name FloorTiler
extends Sprite2D
## Sol carrelé infini.
##
## L'arène n'a pas de bord : le sol ne peut donc pas être une image posée une
## fois. Un seul Sprite2D suffit pourtant — `texture_repeat` répète la texture
## sur toute la `region_rect`, il n'y a ni grille de nœuds ni TileMap à tenir.
##
## Le motif doit rester ACCROCHÉ AU MONDE. Si le sprite suivait la caméra au
## pixel près, le sol paraîtrait immobile et le joueur donnerait l'impression de
## courir sur place. On recale donc la position sur un multiple exact de la
## taille du carreau : le décalage est invisible (un carreau en vaut un autre),
## et le dallage ne bouge pas d'un pixel par rapport au monde.
##
## DEUX ÉTAGES. Passé `deep_from_wave`, le carreau change : on descend. C'est la
## seule récompense purement visuelle du jeu, et elle tombe là où la plupart des
## runs s'arrêtent — voir le commentaire de ce réglage.
##
## LE SENS DE LA DESCENTE. On part sur la PIERRE FROIDE et on descend vers la
## pierre rouge, et pas l'inverse : mesurées, les deux planches valent 100/93/85
## et 52/73/89 en moyenne RGB, soit +15 et −38 d'écart rouge-bleu. Commencer par
## la chaude, c'était s'enfoncer vers quelque chose de plus calme — le décor
## racontait le contraire du jeu. Les deux teintes gardent la même luminance
## perçue (49 contre 53) : ce qui change est la couleur, pas la lisibilité, et
## les ennemis se lisent aussi bien aux deux étages.
##
## LE SOL DE L'ENFER. Quand le pack de la carte (2DML SET 3, depuis la 0.9.2)
## est extrait, le sol est son carreau sombre aux deux étages, teinté comme
## toutes les pièces de la carte — l'ancien dallage peint, bien plus lisse,
## faisait deux jeux superposés. Sans le pack (dépôt fraîchement cloné),
## l'ancien carreau de la scène reste.
##
## DES RÉGIONS. Un carreau unique répété à l'infini, c'est un sol sans lieu : on
## ne sait jamais si l'on a avancé. Un shader y découpe des RÉGIONS d'un second
## sol selon un bruit tiré à chaque run, avec un liseré sombre à la frontière
## pour qu'elle se lise comme un changement de matière et non comme une tache.
## En surface un sol brun, en profondeur un sol rougeâtre — jamais orange :
## rien au sol ne doit passer pour de la lave qui brûle.
## Purement visuel : ni la carte ni le jeu n'en dépendent, d'où un bruit à part
## plutôt que celui du générateur.

@export_group("Profondeur")
## Le carreau du second étage. Vide = un seul sol, le premier.
@export var deep_texture: Texture2D
## Teinte appliquée au second carreau. Chaque planche garde la sienne : la
## pierre froide passée sous la teinte chaude tournerait au mauve, et la pierre
## chaude sous la teinte froide perdrait exactement ce qu'on descend chercher.
@export var deep_modulate: Color = Color(0.66, 0.52, 0.5)
## Vague à partir de laquelle on change d'étage. Onze, soit juste après Lilith :
## c'est le mur où s'arrêtent la plupart des premières runs, donc le passage se
## mérite et se remarque.
@export var deep_from_wave: int = 11

@export_group("Sol de l'enfer")
## Les teintes du carreau sont celles de TOUTES les pièces de la carte
## (`EnferDB.TEINTE_SURFACE` et `TEINTE_PROFONDEUR`) : le sol et le décor du
## pack ont été peints ensemble, et la bordure de sol d'un bassin doit se
## fondre dans le carreau voisin.
##
## Part du sol couverte par les régions, en seuil de bruit. Moins en
## profondeur : le sol rougeâtre y est plus chargé.
@export_range(0.0, 0.6, 0.01) var region_part: float = 0.34
@export_range(0.0, 0.6, 0.01) var region_part_profonde: float = 0.24
## Période du bruit des régions, en pixels du monde. Deux lectures à des
## échelles sans rapport simple se superposent : la répétition du bruit, qui
## boucle, ne se voit pas.
@export var region_echelle: float = 4200.0

## Le carreau est LE SOL QUE BORDE LE BASSIN dans la planche (72/71/75 contre
## 71/70/74) : une nappe de lave posée dessus s'y fond sans liseré. Mesuré sans
## couture sur 192 × 160 : joints de 0,44 et 0,18 pour un bruit interne de 0,5
## et 0,8 (méthode du README).
const SOL_ENFER := "res://assets/sprites/enfer/sol/tex_sol.png"
## Les régions : un sol brun en surface, un sol rougeâtre en profondeur, tous
## deux sans couture (joints sous le bruit interne). Le premier choix, un grand
## carreau olive, portait une des taches en fleur de la planche : répété, il
## semait des nuages festonnés sur toute la région (vu en capture).
const REGION_SURFACE := "res://assets/sprites/enfer/sol/tex_brun.png"
const REGION_PROFONDEUR := "res://assets/sprites/enfer/sol/tex_rouge.png"
## Vrai pixel art, affiché à l'échelle entière de toutes les pièces
## (voir EnferDB.ECHELLE).
const ECHELLE_ENFER := 2.0

const SHADER_REGIONS := """
shader_type canvas_item;
uniform sampler2D region_tex : repeat_enable, filter_nearest;
uniform sampler2D bruit : repeat_enable, filter_linear;
uniform vec2 taille_region = vec2(216.0);
uniform vec4 teinte_region = vec4(1.0);
uniform vec4 moyenne = vec4(0.0);
uniform float contraste = 1.0;
uniform vec4 moyenne_region = vec4(0.0);
uniform float contraste_region = 1.0;
uniform float part = 0.3;
uniform float echelle = 2600.0;
varying vec2 monde;
void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float n = texture(bruit, monde / echelle).r * 0.8
		+ texture(bruit, monde / (echelle * 0.61) + vec2(0.31, 0.77)).r * 0.2;
	n += (texture(bruit, monde / 190.0).r - 0.5) * 0.04;
	float seuil = 1.0 - part;
	float m = smoothstep(seuil - 0.008, seuil + 0.008, n);
	vec3 base = mix(moyenne.rgb, COLOR.rgb, contraste);
	vec3 r = mix(moyenne_region.rgb,
		texture(region_tex, monde / taille_region).rgb * teinte_region.rgb, contraste_region);
	float lisere = 1.0 - 0.15 * (1.0 - smoothstep(0.0, 0.02, abs(n - seuil)));
	COLOR.rgb = mix(base, r, m) * lisere;
}
"""

var _shallow_texture: Texture2D
var _shallow_modulate: Color
var _deep: bool = false
var _regions: ShaderMaterial
var _region_surface: Texture2D
var _region_profondeur: Texture2D
var _moyenne := Color.BLACK


func _ready() -> void:
	# Le sol est sur le calque de lumière du décor (voir `Carte.MASQUE_DECOR`) :
	# la lave et le feu l'éclairent.
	light_mask = Carte.MASQUE_DECOR
	_preparer_enfer()
	_shallow_texture = texture
	_shallow_modulate = modulate
	GameEvents.wave_started.connect(_on_wave_started)


func _preparer_enfer() -> void:
	for chemin in [SOL_ENFER, REGION_SURFACE, REGION_PROFONDEUR]:
		if not ResourceLoader.exists(chemin):
			return
	var sol: Texture2D = load(SOL_ENFER)
	_moyenne = _couleur_moyenne(sol)
	texture = sol
	deep_texture = sol
	scale = Vector2(ECHELLE_ENFER, ECHELLE_ENFER)
	modulate = EnferDB.TEINTE_SURFACE
	deep_modulate = EnferDB.TEINTE_PROFONDEUR
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_region_surface = load(REGION_SURFACE)
	_region_profondeur = load(REGION_PROFONDEUR)
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bruit.seed = randi()
	bruit.frequency = 0.012
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = bruit
	var shader := Shader.new()
	shader.code = SHADER_REGIONS
	_regions = ShaderMaterial.new()
	_regions.shader = shader
	_regions.set_shader_parameter(&"bruit", tex)
	_regions.set_shader_parameter(&"part", region_part)
	# Le carreau est lisse (bruit interne de 0,5) : rien à calmer, pleine force.
	_regions.set_shader_parameter(&"contraste", 1.0)
	_regions.set_shader_parameter(&"echelle", region_echelle)
	material = _regions
	_regions_de(false)


func _regions_de(profond: bool) -> void:
	if _regions == null:
		return
	var region := _region_profondeur if profond else _region_surface
	var t := EnferDB.teinte(profond)
	_regions.set_shader_parameter(&"region_tex", region)
	_regions.set_shader_parameter(&"taille_region",
		Vector2(region.get_width(), region.get_height()) * ECHELLE_ENFER)
	# Le `modulate` du nœud teinte le sol de base AVANT le shader (il est dans
	# COLOR) ; la région est lue à part, donc sa teinte est absolue. La moyenne
	# vers laquelle on ramène le pavé prend la teinte de l'étage.
	_regions.set_shader_parameter(&"teinte_region", Vector4(t.r, t.g, t.b, 1.0))
	var m := _moyenne * EnferDB.teinte(profond)
	_regions.set_shader_parameter(&"moyenne", Vector4(m.r, m.g, m.b, 1.0))
	var mr := _couleur_moyenne(region) * t
	_regions.set_shader_parameter(&"moyenne_region", Vector4(mr.r, mr.g, mr.b, 1.0))
	_regions.set_shader_parameter(&"contraste_region", 1.0)
	_regions.set_shader_parameter(&"part", region_part_profonde if profond else region_part)


static func _couleur_moyenne(t: Texture2D) -> Color:
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var o := img.get_data()
	var somme := Vector3.ZERO
	var n := img.get_width() * img.get_height()
	for i in n:
		somme += Vector3(o[i * 4], o[i * 4 + 1], o[i * 4 + 2])
	somme /= float(n) * 255.0
	return Color(somme.x, somme.y, somme.z)


## Le sol suit la vague dans les deux sens : une nouvelle run repart en surface
## sans qu'on ait à le remettre à la main.
##
## LE CHANGEMENT S'ANNONCE D'ABORD, puis s'applique au plus noir du fondu que
## joue la carte (`Carte.FONDU`) : changer le carreau à vue, une fraction de
## seconde avant que tout le reste change, trahirait la coulisse.
func _on_wave_started(wave: int) -> void:
	var profond := deep_texture != null and wave >= deep_from_wave
	if profond == _deep:
		return
	_deep = profond
	GameEvents.arena_depth_changed.emit(profond)
	get_tree().create_timer(Carte.FONDU, false).timeout.connect(_appliquer.bind(profond))


func _appliquer(profond: bool) -> void:
	if profond != _deep:
		return
	texture = deep_texture if profond else _shallow_texture
	modulate = deep_modulate if profond else _shallow_modulate
	_regions_de(profond)


func _process(_delta: float) -> void:
	if texture == null:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var tile := Vector2(texture.get_width(), texture.get_height()) * scale
	if tile.x <= 0.0 or tile.y <= 0.0:
		return
	global_position = (camera.get_screen_center_position() / tile).floor() * tile
