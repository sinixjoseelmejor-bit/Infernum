class_name GameCamera
extends Camera2D
## Caméra de suivi : enfant du joueur (le suivi est donc gratuit et exact),
## elle ajoute un lissage, une anticipation dans la direction du déplacement et
## un tremblement à la demande via `GameEvents.camera_shake_requested`.

@export_group("Anticipation")
## Décalage de la caméra en avant du joueur, en secondes de déplacement.
@export var look_ahead: float = 0.16
@export var look_ahead_max: float = 96.0
@export var look_ahead_speed: float = 4.0

@export_group("Tremblement")
@export var shake_max_offset: float = 26.0
@export var shake_decay: float = 4.0
## Le traumatisme est élevé au carré : les petits coups restent discrets.
@export var trauma_power: float = 2.0

var _trauma: float = 0.0
var _look: Vector2 = Vector2.ZERO
var _noise_time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	make_current()
	GameEvents.camera_shake_requested.connect(add_trauma)


func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody2D
	var desired := Vector2.ZERO
	if body != null:
		desired = (body.velocity * look_ahead).limit_length(look_ahead_max)
	_look = _look.lerp(desired, minf(1.0, look_ahead_speed * delta))

	_trauma = maxf(0.0, _trauma - shake_decay * delta)
	var shake := Vector2.ZERO
	if _trauma > 0.0:
		_noise_time += delta
		var amount: float = pow(_trauma, trauma_power) * shake_max_offset
		shake = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * amount

	offset = _look + shake


## L'échelle vient des options : à 0, plus aucune secousse (confort visuel).
func add_trauma(strength: float) -> void:
	_trauma = clampf(_trauma + strength * Settings.shake_scale / 10.0, 0.0, 1.0)
