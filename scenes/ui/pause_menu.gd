class_name PauseMenu
extends CanvasLayer
## Esc during a flight: pauses the game and shows RESUME / RESTART / MENU,
## volume sliders (Master, Engine, Effects; saved via GameState) and the key
## list. Esc again (or RESUME) carries on. Added by the flight scene, which
## sets `enabled` false once the flight is over (the result screen takes over).
## Runs while the tree is paused (process_mode ALWAYS).

signal restart_pressed
signal menu_pressed

## Key list shown on the pause screen: [keys, what they do].
const KEYS := [
	["UP / DOWN", "THROTTLE (HOLD)"],
	["LEFT", "NOSE UP"],
	["RIGHT", "NOSE DOWN"],
	["E", "ENGINE ON/OFF"],
	["F", "FLAPS UP/TO/LDG"],
	["G", "GEAR UP/DOWN"],
	["B", "BRAKES / AIR BRAKE"],
	["T", "FUEL TRUCK"],
	["R", "RESTART"],
	["ESC", "PAUSE"],
]
const LABEL_COLOR := Color(0.75, 0.78, 0.72)
const TEXT_COLOR := Color(0.9, 0.9, 0.85)
const KEY_COLOR := Color(1.0, 0.85, 0.3)

## False once the flight has ended: Esc does nothing.
var enabled := true
var _resume: Button
## Short sound played when a slider is let go, so the new level can be heard
## while everything else is paused.
var _preview: AudioStreamPlayer


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		elif enabled:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("restart"):
		_leave(restart_pressed)
		get_viewport().set_input_as_handled()


func open() -> void:
	get_tree().paused = true
	visible = true
	_resume.grab_focus()


func close() -> void:
	GameState.save_settings()
	visible = false
	get_tree().paused = false


func _leave(sig: Signal) -> void:
	close()
	sig.emit()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.12, 0.95)
	style.border_color = Color(0.55, 0.57, 0.6)
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(380, 0)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_label("PAUSED", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	box.add_child(top)

	# Buttons.
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	_resume = _button("RESUME (ESC)")
	_resume.pressed.connect(close)
	var restart := _button("RESTART (R)")
	restart.pressed.connect(_leave.bind(restart_pressed))
	var menu := _button("MAIN MENU")
	menu.pressed.connect(_leave.bind(menu_pressed))
	for b in [_resume, restart, menu]:
		buttons.add_child(b)
	top.add_child(buttons)

	# Volume sliders.
	var vol := GridContainer.new()
	vol.columns = 2
	vol.add_theme_constant_override("h_separation", 8)
	vol.add_theme_constant_override("v_separation", 8)
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for bus in GameState.VOLUME_BUSES:
		vol.add_child(_label(bus.to_upper(), 8, LABEL_COLOR))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = GameState.volumes[bus]
		s.custom_minimum_size = Vector2(150, 16)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(func(v: float) -> void: GameState.set_volume(bus, v))
		s.drag_ended.connect(func(_changed: bool) -> void: _play_preview(bus))
		vol.add_child(s)
	var vol_box := VBoxContainer.new()
	vol_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_box.add_child(_label("VOLUME", 8, Color.WHITE))
	vol_box.add_child(vol)
	top.add_child(vol_box)

	box.add_child(HSeparator.new())

	# Keys, two pairs per row.
	box.add_child(_label("KEYS", 8, Color.WHITE))
	var keys := GridContainer.new()
	keys.columns = 4
	keys.add_theme_constant_override("h_separation", 10)
	keys.add_theme_constant_override("v_separation", 3)
	for k in KEYS:
		keys.add_child(_label(k[0], 8, KEY_COLOR))
		keys.add_child(_label(k[1], 8, TEXT_COLOR))
	box.add_child(keys)

	# Centre the panel on the 640x360 screen once it knows its size.
	panel.resized.connect(func() -> void:
		panel.position = ((Vector2(640, 360) - panel.size) * 0.5).round())

	_preview = AudioStreamPlayer.new()
	_preview.stream = SoundSynth.thump()
	add_child(_preview)


func _play_preview(bus: String) -> void:
	_preview.bus = bus if bus != "Master" else &"Effects"
	_preview.play()


func _label(text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 22)
	b.add_theme_font_size_override("font_size", 8)
	return b
