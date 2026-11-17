extends Control
## Start screen: title, name entry ("Avn Cdt <name>") and FLY.
## Aircraft selection is added here in chunk 1.8.
## The first click/keypress here also unlocks browser audio on the web build.

const FLIGHT_SCENE := "res://scenes/flight/flight.tscn"

var _name_edit: LineEdit
var _fly: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_name_edit.text = GameState.pilot_name
	_name_edit.grab_focus()
	_name_edit.caret_column = _name_edit.text.length()
	_update_button()


func _build() -> void:
	# Background: sky gradient, ground strip and the trainer on the runway.
	var sky := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.42, 0.63, 0.86), Color(0.85, 0.92, 0.96)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_to = Vector2(0, 1)
	sky.texture = tex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.42, 0.62, 0.3)
	ground.position = Vector2(0, 318)
	ground.size = Vector2(640, 42)
	add_child(ground)
	var runway := ColorRect.new()
	runway.color = Color(0.32, 0.32, 0.35)
	runway.position = Vector2(0, 318)
	runway.size = Vector2(640, 4)
	add_child(runway)
	var plane := TextureRect.new()
	plane.texture = load("res://assets/sprites/super_mushshak_body.png")
	plane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plane.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	plane.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	plane.position = Vector2(440, 292)
	plane.size = Vector2(140, 26)
	add_child(plane)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.position = Vector2(120, 40)
	box.size = Vector2(400, 240)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	box.add_child(_label("PROJECT SHAHEEN", 32, Color(0.08, 0.2, 0.14)))
	box.add_child(_label("PAF ACADEMY ASGHAR KHAN, RISALPUR", 8, Color(0.1, 0.2, 0.25)))
	box.add_child(_spacer(10))
	box.add_child(_label("ENTER YOUR NAME, CADET", 16, Color(0.08, 0.15, 0.2)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var rank := _label(GameState.RANK, 16, Color(0.08, 0.15, 0.2))
	row.add_child(rank)
	_name_edit = LineEdit.new()
	_name_edit.max_length = GameState.MAX_NAME_LENGTH
	_name_edit.placeholder_text = "YOUR NAME"
	_name_edit.custom_minimum_size = Vector2(190, 24)
	_name_edit.add_theme_font_size_override("font_size", 16)
	_name_edit.text_changed.connect(func(_t: String) -> void: _update_button())
	_name_edit.text_submitted.connect(func(_t: String) -> void: _start())
	row.add_child(_name_edit)
	box.add_child(row)

	_fly = Button.new()
	_fly.text = "FLY"
	_fly.custom_minimum_size = Vector2(120, 26)
	_fly.add_theme_font_size_override("font_size", 16)
	_fly.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fly.pressed.connect(_start)
	box.add_child(_fly)

	box.add_child(_spacer(6))
	box.add_child(_label("TODAY: SUPER MUSHSHAK, RISALPUR TO PESHAWAR", 8, Color(0.1, 0.2, 0.25)))

	var keys := _label("UP/DOWN THROTTLE   LEFT/RIGHT PITCH   E ENGINE   F FLAPS   G GEAR   B BRAKE   R RESTART", 8, Color.WHITE)
	add_child(keys)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	keys.offset_top = -24
	keys.offset_bottom = -10


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _update_button() -> void:
	_fly.disabled = _name_edit.text.strip_edges() == ""


func _start() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		return
	GameState.pilot_name = n
	get_tree().change_scene_to_file(FLIGHT_SCENE)
