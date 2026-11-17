extends Control
## Start screen: title, name entry (rank comes from the aircraft: "AVN CDT" in the
## Super Mushshak, "SQN LDR" in the F-16), aircraft choice, DAY/NIGHT and FLY.
## The first click/keypress here also unlocks browser audio on the web build.

const FLIGHT_SCENE := "res://scenes/flight/flight.tscn"

## Card text per aircraft (same order as GameState.AIRCRAFT).
const AIRCRAFT_BLURB := [
	"TRAINER. SLOW AND FORGIVING.",
	"FIGHTER. FAST, AFTERBURNER, HARD.",
]

var _name_edit: LineEdit
var _fly: Button
var _preview: TextureRect
var _rank_label: Label
## Text colour of the selected DAY/NIGHT button.
const SELECTED_COLOR := Color(1.0, 0.82, 0.35)


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
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_preview.position = Vector2(470, 268)
	_preview.size = Vector2(150, 50)
	add_child(_preview)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.position = Vector2(100, 14)
	box.size = Vector2(440, 270)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	box.add_child(_label("PROJECT SHAHEEN", 32, Color(0.08, 0.2, 0.14)))
	box.add_child(_label("PAF ACADEMY ASGHAR KHAN, RISALPUR", 8, Color(0.1, 0.2, 0.25)))
	box.add_child(_spacer(4))
	box.add_child(_label("ENTER YOUR NAME", 16, Color(0.08, 0.15, 0.2)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	_rank_label = _label(GameState.aircraft_data().pilot_rank, 16, Color(0.08, 0.15, 0.2))
	row.add_child(_rank_label)
	_name_edit = LineEdit.new()
	_name_edit.max_length = GameState.MAX_NAME_LENGTH
	_name_edit.placeholder_text = "YOUR NAME"
	_name_edit.custom_minimum_size = Vector2(190, 24)
	_name_edit.add_theme_font_size_override("font_size", 16)
	_name_edit.text_changed.connect(func(_t: String) -> void: _update_button())
	_name_edit.text_submitted.connect(func(_t: String) -> void: _start())
	row.add_child(_name_edit)
	box.add_child(row)

	box.add_child(_spacer(2))
	box.add_child(_label("CHOOSE YOUR AIRCRAFT", 8, Color(0.08, 0.15, 0.2)))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in GameState.AIRCRAFT.size():
		cards.add_child(_aircraft_card(i, group))
	box.add_child(cards)

	# Time of day + FLY on one row.
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_CENTER
	go_row.add_theme_constant_override("separation", 4)
	var time_group := ButtonGroup.new()
	for night in [false, true]:
		var b := Button.new()
		b.text = "NIGHT" if night else "DAY"
		b.toggle_mode = true
		b.button_group = time_group
		b.custom_minimum_size = Vector2(56, 26)
		b.add_theme_font_size_override("font_size", 8)
		b.add_theme_color_override("font_pressed_color", SELECTED_COLOR)
		b.add_theme_color_override("font_hover_pressed_color", SELECTED_COLOR)
		b.button_pressed = GameState.night == night
		b.toggled.connect(func(on: bool) -> void:
			if on:
				GameState.night = night)
		go_row.add_child(b)
	go_row.add_child(_spacer(0))
	go_row.get_child(-1).custom_minimum_size = Vector2(14, 0)
	_fly = Button.new()
	_fly.text = "FLY"
	_fly.custom_minimum_size = Vector2(120, 26)
	_fly.add_theme_font_size_override("font_size", 16)
	_fly.pressed.connect(_start)
	go_row.add_child(_fly)
	box.add_child(go_row)

	box.add_child(_label("ROUTE: RISALPUR TO PESHAWAR", 8, Color(0.1, 0.2, 0.25)))

	var keys := _label("UP/DOWN THROTTLE   LEFT/RIGHT PITCH   E ENGINE   F FLAPS   G GEAR   B BRAKE   R RESTART", 8, Color.WHITE)
	add_child(keys)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	keys.offset_top = -24
	keys.offset_bottom = -10


## A selectable card: aircraft picture, name and a one-line description.
func _aircraft_card(index: int, group: ButtonGroup) -> Button:
	var path: String = GameState.AIRCRAFT[index]
	var data: AircraftData = load(path)
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = group
	card.custom_minimum_size = Vector2(200, 70)
	card.button_pressed = path == GameState.aircraft_path
	card.toggled.connect(func(on: bool) -> void:
		if on:
			_select(path))
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 4
	inner.offset_right = -4
	inner.offset_top = 3
	inner.offset_bottom = -3
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 1)
	var pic := TextureRect.new()
	pic.texture = data.sprite
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.custom_minimum_size = Vector2(0, 34)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(pic)
	var name_label := _label(data.display_name.to_upper(), 8, Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_label)
	var blurb := _label(AIRCRAFT_BLURB[index] if index < AIRCRAFT_BLURB.size() else "", 8, Color(0.8, 0.85, 0.8))
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(blurb)
	card.add_child(inner)
	if card.button_pressed:
		_select(path)
	return card


func _select(path: String) -> void:
	GameState.aircraft_path = path
	var data: AircraftData = load(path)
	_preview.texture = data.sprite
	if _rank_label:
		_rank_label.text = data.pilot_rank


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
