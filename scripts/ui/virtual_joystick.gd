class_name VirtualJoystick
extends Control
## Joystick virtuel tactile alimentant `PlayerInput.virtual_move`.
##
## Mode "dynamique" : la base se place là où le pouce touche la zone, ce qui
## évite d'avoir à viser un stick fixe. Invisible sur desktop sauf si
## `force_visible` est actif (pratique pour tester au clavier/souris).

@export var base_radius: float = 105.0
@export var knob_radius: float = 44.0
@export_range(0.0, 1.0, 0.01) var dead_zone: float = 0.15
## La base se repositionne sous le doigt au lieu de rester fixe.
@export var dynamic_origin: bool = true

@export_group("Apparence")
@export var base_color: Color = Color(0.85, 0.2, 0.15, 0.20)
@export var base_border_color: Color = Color(1.0, 0.45, 0.25, 0.40)
@export var knob_color: Color = Color(1.0, 0.55, 0.25, 0.55)

var output: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# La visibilité vient des options : « Automatique » = tactile uniquement.
	visible = Settings.should_show_joystick()
	Settings.changed.connect(_on_settings_changed)
	_origin = size * 0.5
	_knob = _origin


func _on_settings_changed() -> void:
	visible = Settings.should_show_joystick()
	if not visible:
		_end()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _active:
			_begin(touch.position, touch.index)
		elif not touch.pressed and touch.index == _touch_index:
			_end()
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_begin(click.position, -2)
			elif _touch_index == -2:
				_end()
			accept_event()
	elif event is InputEventMouseMotion and _touch_index == -2:
		_update((event as InputEventMouseMotion).position)
		accept_event()


func _begin(point: Vector2, index: int) -> void:
	_active = true
	_touch_index = index
	_origin = point if dynamic_origin else size * 0.5
	_update(point)


func _update(point: Vector2) -> void:
	var offset := (point - _origin).limit_length(base_radius)
	_knob = _origin + offset
	var raw := offset / base_radius
	output = Vector2.ZERO if raw.length() < dead_zone else raw
	PlayerInput.virtual_move = output
	queue_redraw()


func _end() -> void:
	_active = false
	_touch_index = -1
	output = Vector2.ZERO
	PlayerInput.virtual_move = Vector2.ZERO
	_origin = size * 0.5
	_knob = _origin
	queue_redraw()


func _exit_tree() -> void:
	# Le singleton survit au rechargement de scène : on nettoie l'entrée.
	PlayerInput.virtual_move = Vector2.ZERO


func _draw() -> void:
	var alpha := 1.0 if _active else 0.45
	draw_circle(_origin, base_radius, base_color * Color(1, 1, 1, alpha))
	draw_arc(_origin, base_radius, 0.0, TAU, 48, base_border_color * Color(1, 1, 1, alpha), 2.0, true)
	draw_circle(_knob, knob_radius, knob_color * Color(1, 1, 1, alpha))
