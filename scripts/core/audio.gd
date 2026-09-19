extends Node
## Son du jeu (autoload `Audio`).
##
## DEUX BUS, PAS UN. `Musique` et `Effets` partent tous deux dans `Master` :
## c'est ce qui permet aux deux curseurs des options d'agir séparément sans
## qu'aucun `AudioStreamPlayer` n'ait à connaître le réglage. Un son se contente
## de choisir son bus à la création.
##
## POURQUOI CE NŒUD TOURNE EN PAUSE. `PROCESS_MODE_ALWAYS` : le menu de pause,
## la boutique et l'écran de malédictions mettent l'arbre en pause, et leurs
## boutons doivent quand même cliquer. Sans ça, toute l'interface devient muette
## dès qu'un écran s'ouvre — c'est-à-dire presque tout le temps.
##
## LA BANQUE DE VOIX. Un `AudioStreamPlayer` ne joue qu'un son à la fois ; on en
## garde donc `VOICES` sous la main et on distribue. Quand tout est occupé, on
## vole la voix la plus ancienne : couper un son déjà bien entamé s'entend
## infiniment moins que d'ignorer le tir qui vient de partir.

const DIR := "res://assets/audio/SoundEffects/"
## LES MUSIQUES PORTENT LEUR DOSSIER, les effets non. Les fichiers du lot
## d'origine vivent sous `SoundEffects/` avec le `LICENSE.txt` qui les couvre,
## et les déplacer pour faire joli casserait cette piste-là. Les musiques
## ajoutées depuis vivent sous `Music/`. Le chemin est donc écrit en entier
## dans la liste plutôt que deviné.
const AUDIO_DIR := "res://assets/audio/"
const VOICES := 16
## Fondu enchaîné entre deux musiques, et descente d'une voix coupée.
const MUSIC_FADE := 0.7
const CUT_FADE := 0.12
const SILENCE_DB := -60.0

## UNE PISTE OU PLUSIEURS, et c'est la taille de la liste qui décide du reste.
##
## L'arène en a six : une run qui va loin dure plus de vingt minutes, donc une
## seule piste de 4 min 26 se répète quatre fois. Elles s'ENCHAÎNENT au lieu
## d'être tirées au sort à l'ouverture : un tirage par run laisserait encore une
## seule piste tourner en boucle pendant toute la partie, ce qui est exactement
## le problème qu'on voulait régler. Les six font 17 min 14 bout à bout.
##
## L'ORDRE ALTERNE LES DEUX SOURCES et les durées : on entre dans la liste à un
## rang tiré au sort, puis on la suit, donc deux pistes voisines sont deux
## pistes qu'on entendra l'une après l'autre à chaque run.
##
## LE BOUCLAGE DÉPEND DU NOMBRE. Une liste à une piste boucle nativement, sans
## trou — c'est indispensable au menu, dont la piste ne dure que 15,5 s et dont
## la reprise s'entendrait quatre fois par minute. Une liste à plusieurs pistes
## ne boucle PAS : c'est `finished` qui enchâine, et il ne se déclenche jamais
## sur un flux bouclé.
const MUSIC := {
	&"menu": ["SoundEffects/MenuSoundMusic.ogg"],
	&"arene": [
		"SoundEffects/MusicGameplay.ogg",
		"Music/alex-morgan-thrash-metal-591343.ogg",
		"SoundEffects/MusicGameplay2.ogg",
		"Music/wolfdudedodi-cyber-wolf-529967.ogg",
		"Music/strawberry_candy-powerful-heavy-metal-heavy-force-572627.ogg",
		"Music/mrclaps-this-heavy-metal-492569.ogg",
	],
}

## CORRECTION DE NIVEAU, PISTE PAR PISTE. Les fichiers ne sont pas masterisés
## ensemble : mesurés en RMS sur trois fenêtres de 4 s prises à 15 %, 45 % et
## 75 % de chaque piste, ils s'étalent de -13,95 à -16,62 dB. Les deux pistes
## d'origine tiennent -14,85 et -14,69 dB : c'est la référence, puisque c'est
## le niveau auquel tout le reste du jeu a été réglé.
##
## Seules les pistes qui s'en écartent d'AU MOINS 1 dB figurent ici. En dessous,
## la correction ne s'entend pas et la table ment sur sa précision.
const MUSIC_GAIN := {
	"Music/alex-morgan-thrash-metal-591343.ogg": 1.8,
	"Music/mrclaps-this-heavy-metal-492569.ogg": -0.9,
}

## Un son = un fichier plus la façon de le jouer.
##   vol   : correction en dB (les fichiers ne sont pas normalisés entre eux)
##   pitch : variation aléatoire de hauteur, ±, en proportion
##   gap   : intervalle minimal entre deux déclenchements, en secondes
##   voix  : nombre maximal d'exemplaires simultanés de CE son
##   duree : coupe le son au bout de N secondes (0 = jouer le fichier entier)
##
## `tir` est le cas intéressant. Fireball.ogg dure 8 s d'énergie continue — ce
## n'est pas une détonation, c'est une nappe. L'arme tire jusqu'à 6,2 fois par
## seconde : jouer le fichier entier empilerait une vingtaine de voix et
## noierait tout le reste. On ne garde donc que l'attaque, avec un fondu court
## pour ne pas remplacer le problème par un clic.
##
## POUR UN TIR PLUS LONG. `duree` ne se change pas seule. À 1,0 s le son déborde
## son quota de 4 voix et 93 % des tirs en coupent un autre en plein vol — et un
## vol de voix est brutal, il claque. Passer à 1 s demande donc les trois
## valeurs ensemble :
##
##     "voix": 8, "duree": 1.0, "vol": -18.0
##
## Le quota monte à 8 (mesuré : 5,84 voix en moyenne), et le volume descend de
## 3 dB pour compenser l'empilement, qui passe de +4,9 à +7,7 dB. Coût : 7 des
## 16 voix mobilisées en permanence pendant les tirs.
const SFX := {
	&"clic": {"file": "StoneSoundForButtonMenuSelect.ogg", "vol": -6.0, "pitch": 0.05, "gap": 0.04, "voix": 2},
	&"objet": {"file": "chooseUpgradeSound.ogg", "vol": -3.0, "pitch": 0.0, "gap": 0.08, "voix": 2},
	&"tir": {"file": "Fireball.ogg", "vol": -15.0, "pitch": 0.12, "gap": 0.06, "voix": 4, "duree": 0.5},
	&"mort": {"file": "smallRoar1sec.ogg", "vol": -9.0, "pitch": 0.16, "gap": 0.07, "voix": 3},
	&"boss": {"file": "BigRoar.ogg", "vol": -1.0, "pitch": 0.0, "gap": 1.0, "voix": 1},
}

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
## Par voix : clé jouée, instant de départ, temps restant avant coupure (< 0 =
## pas de coupure), et volume nominal — mémorisé parce que le fondu l'écrase.
var _voice_key: Array[StringName] = []
var _voice_start: Array[float] = []
var _voice_left: Array[float] = []
var _voice_db: Array[float] = []
var _last_played: Dictionary = {}

var _playlists: Dictionary = {}
var _gains: Dictionary = {}
var _piste: int = 0
var _music: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _music_track: StringName = &""
var _music_tween: Tween

var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()

	for key in MUSIC:
		var pistes: Array = MUSIC[key]
		var flux: Array[AudioStream] = []
		var gains: Array[float] = []
		for fichier in pistes:
			var stream := _charger(AUDIO_DIR + fichier, pistes.size() == 1)
			if stream != null:
				flux.append(stream)
				gains.append(MUSIC_GAIN.get(fichier, 0.0))
		_playlists[key] = flux
		_gains[key] = gains
	for key in SFX:
		_load(key, (SFX[key] as Dictionary)["file"], false)

	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"Effets"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_voices.append(player)
		_voice_key.append(&"")
		_voice_start.append(-999.0)
		_voice_left.append(-1.0)
		_voice_db.append(0.0)

	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Musique"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = SILENCE_DB
		add_child(player)
		player.finished.connect(_piste_suivante.bind(i))
		_music.append(player)

	GameEvents.enemy_died.connect(func(_e: Node2D, _p: Vector2) -> void: play(&"mort"))
	GameEvents.boss_spawned.connect(func(_b: Node2D) -> void: play(&"boss"))
	RunState.item_gained.connect(func(_i: ItemData, _n: int) -> void: play(&"objet"))
	SaveGame.item_unlocked.connect(func(_id: StringName) -> void: play(&"objet"))
	Forge.node_unlocked.connect(func(_id: StringName) -> void: play(&"objet"))

	# TOUS LES BOUTONS, SANS TOUCHER À UN SEUL ÉCRAN. L'interface crée ses
	# boutons à la volée (boutique, Forge, personnages) : les câbler un par un
	# demanderait de repasser sur chaque script et d'y penser à chaque ajout.
	# On écoute donc l'arbre lui-même. Un bouton peut demander un autre son que
	# le clic par défaut en posant `set_meta(&"sfx", &"objet")`.
	get_tree().node_added.connect(_on_node_added)


func _load(key: StringName, file: String, looping: bool) -> void:
	var stream := _charger(DIR + file, looping)
	if stream != null:
		_streams[key] = stream


func _charger(path: String, looping: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("Audio : fichier manquant, son ignoré — " + path)
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		return null
	# La boucle se règle ici plutôt que dans le fichier `.import` : le réglage
	# suit le code, il ne peut pas être perdu par un réimport.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looping
	return stream


# --- Effets ------------------------------------------------------------------

func play(key: StringName) -> void:
	var cfg: Dictionary = SFX.get(key, {})
	var stream: AudioStream = _streams.get(key)
	if stream == null or cfg.is_empty():
		return

	# L'anti-spam sert deux fois : il évite le peigne métallique de deux copies
	# décalées de 5 ms, et il protège la banque de voix les vagues chargées, où
	# une dizaine d'ennemis peuvent mourir dans la même image.
	var gap: float = cfg.get("gap", 0.0)
	if _clock - float(_last_played.get(key, -999.0)) < gap:
		return
	_last_played[key] = _clock

	var index := _take_voice(key, int(cfg.get("voix", VOICES)))
	if index < 0:
		return
	var player := _voices[index]
	var db: float = cfg.get("vol", 0.0)
	var pitch: float = cfg.get("pitch", 0.0)
	player.stream = stream
	player.volume_db = db
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch, pitch)
	player.play()

	_voice_key[index] = key
	_voice_start[index] = _clock
	_voice_db[index] = db
	_voice_left[index] = cfg.get("duree", 0.0)
	if _voice_left[index] <= 0.0:
		_voice_left[index] = -1.0


## Une voix libre ; sinon la plus ancienne du même son s'il sature son quota ;
## sinon la plus ancienne tout court.
func _take_voice(key: StringName, limit: int) -> int:
	var free := -1
	var oldest := -1
	var oldest_same := -1
	var same := 0
	for i in _voices.size():
		if not _voices[i].playing:
			if free < 0:
				free = i
			continue
		if _voice_key[i] == key:
			same += 1
			if oldest_same < 0 or _voice_start[i] < _voice_start[oldest_same]:
				oldest_same = i
		if oldest < 0 or _voice_start[i] < _voice_start[oldest]:
			oldest = i
	if same >= limit and oldest_same >= 0:
		return oldest_same
	if free >= 0:
		return free
	return oldest


func _process(delta: float) -> void:
	_clock += delta
	for i in _voices.size():
		if _voice_left[i] < 0.0 or not _voices[i].playing:
			continue
		_voice_left[i] -= delta
		if _voice_left[i] <= 0.0:
			_voices[i].stop()
			_voice_left[i] = -1.0
		elif _voice_left[i] < CUT_FADE:
			# Couper net une nappe encore pleine claque. On descend sur la fin.
			_voices[i].volume_db = _voice_db[i] - (1.0 - _voice_left[i] / CUT_FADE) * 24.0


# --- Musique -----------------------------------------------------------------

func play_music(track: StringName) -> void:
	if track == _music_track:
		return
	_music_track = track
	# On n'entre pas toujours par la même porte : deux runs de suite qui
	# commencent sur la même piste s'entendent, et c'est gratuit à éviter.
	var flux: Array = _playlists.get(track, [])
	_piste = _rng.randi() % maxi(1, flux.size())
	var stream: AudioStream = flux[_piste] if _piste < flux.size() else null
	var outgoing := _music[_music_active]
	_music_active = 1 - _music_active
	var incoming := _music[_music_active]

	if is_instance_valid(_music_tween):
		_music_tween.kill()
	_music_tween = create_tween().set_parallel()

	if stream != null:
		incoming.stream = stream
		incoming.volume_db = SILENCE_DB
		incoming.play()
		_music_tween.tween_property(incoming, ^"volume_db", _gain_piste(), MUSIC_FADE)
	if outgoing.playing:
		_music_tween.tween_property(outgoing, ^"volume_db", SILENCE_DB, MUSIC_FADE)
		_music_tween.chain().tween_callback(outgoing.stop)


## FIN DE PISTE : on enchâine sur la suivante de la liste.
##
## Sans fondu, et ce n'est pas une économie : les deux pistes se terminent sur
## une résolution, donc l'enchaînement est une fin suivie d'un début. Un fondu
## là-dessus superposerait une fin et un début, ce qui s'entend beaucoup plus.
##
## Le lecteur qui a fini doit être le lecteur ACTIF : l'autre vient d'être coupé
## par un fondu de changement de musique, et son `finished` relancerait la piste
## d'arène par-dessus celle du menu.
func _piste_suivante(index: int) -> void:
	if index != _music_active:
		return
	var flux: Array = _playlists.get(_music_track, [])
	if flux.size() < 2:
		return
	_piste = (_piste + 1) % flux.size()
	var player := _music[_music_active]
	player.stream = flux[_piste]
	player.volume_db = _gain_piste()
	player.play()


## Correction de niveau de la piste en cours, 0 dB si elle n'en demande pas.
func _gain_piste() -> float:
	var gains: Array = _gains.get(_music_track, [])
	return gains[_piste] if _piste < gains.size() else 0.0


func stop_music() -> void:
	play_music(&"")


# --- Boutons -----------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if not (node is BaseButton):
		return
	var button := node as BaseButton
	var handler := _on_button_pressed.bind(button)
	if button.pressed.is_connected(handler):
		return
	button.pressed.connect(handler)


func _on_button_pressed(button: BaseButton) -> void:
	play(button.get_meta(&"sfx", &"clic"))
