extends Control
## Start screen, in sequential steps (owner): START -> name -> mission ->
## aircraft -> route (destination; ferry flights only) -> time of day -> FLY.
## Air to ground: only strike-capable aircraft (jets) can be picked, and there
## is no route step (targets and the landing base are random). One step on screen at a time,
## with BACK / NEXT (Enter = next, Esc = back). Choices live in GameState,
## so they are remembered when the player comes back from a flight.
## The rank comes from the aircraft ("AVN CDT" in the Super Mushshak, "SQN LDR"
## in the F-16), so it is shown from the aircraft step on.
## The first click/keypress here also unlocks browser audio on the web build.

const FLIGHT_SCENE := "res://scenes/flight/flight.tscn"

## Card text per aircraft (same order as GameState.AIRCRAFT).
const AIRCRAFT_BLURB := [
	"TRAINER",
	"STRIKE FIGHTER",
	"MULTI-ROLE",
	"MULTI-ROLE",
]

enum Step { START, NAME, MISSION, AIRCRAFT, ROUTE, TIME }
const STEP_TITLES := ["", "ENTER YOUR NAME", "CHOOSE YOUR MISSION", "CHOOSE YOUR AIRCRAFT", "CHOOSE YOUR ROUTE", "TIME OF DAY"]

## Text colour of a selected toggle button.
const SELECTED_COLOR := Color(1.0, 0.82, 0.35)
const INK := Color(0.08, 0.15, 0.2)

## Bottom-right aircraft picture: every aircraft is drawn this wide, with its
## right edge and its lowest pixel at these screen positions.
@export var preview_width := 150.0
@export var preview_right := 620.0
@export var preview_bottom := 312.0

var _step := Step.START
var _pages: Array[Control] = []
var _step_label: Label
var _nav: HBoxContainer
var _back: Button
var _next: Button
var _name_edit: LineEdit
var _preview: TextureRect
var _pilot_label: Label
## Aircraft card buttons, same order as GameState.AIRCRAFT.
var _cards: Array[Button] = []
## The second line on each card (role, or the bomb load on air to ground).
var _blurbs: Array[Label] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_name_edit.text = GameState.pilot_name
	_select_aircraft(GameState.aircraft_path)
	_show(Step.START)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _step != Step.START:
		_go_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and _step != Step.NAME and not _next.disabled:
		_go_next()
		get_viewport().set_input_as_handled()


func _build() -> void:
	# Background: a PAF airfield at golden hour (scenes/ui/menu_backdrop.gd),
	# with the selected aircraft on the runway in front of it.
	var backdrop: Control = preload("res://scenes/ui/menu_backdrop.gd").new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_preview)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	# Top-aligned so the title stays put from step to step.
	box.position = Vector2(14, 26)
	box.size = Vector2(612, 210)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(box)

	box.add_child(_label("PROJECT SHAHEEN", 32, Color(0.08, 0.2, 0.14)))
	_step_label = _label("", 16, INK)
	box.add_child(_step_label)

	_pages = [_page_start(), _page_name(), _page_mission(), _page_aircraft(), _page_route(), _page_time()]
	for p in _pages:
		box.add_child(p)

	_nav = HBoxContainer.new()
	_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav.add_theme_constant_override("separation", 120)
	_back = _button("BACK", Vector2(110, 26), 16)
	_back.pressed.connect(_go_back)
	_nav.add_child(_back)
	_next = _button("NEXT", Vector2(110, 26), 16)
	_next.pressed.connect(_go_next)
	_nav.add_child(_next)
	box.add_child(_nav)

	var keys := _label("UP/DOWN THROTTLE   LEFT/RIGHT PITCH   E ENGINE   F FLAPS   G GEAR   B BRAKE   T FUEL TRUCK   SPACE BOMB   R RESTART", 8, Color.WHITE)
	add_child(keys)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	keys.offset_top = -24
	keys.offset_bottom = -10


# --- Pages ---

func _page_start() -> Control:
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(0, 80)
	var start := _button("START", Vector2(160, 34), 16)
	start.pressed.connect(_go_next)
	c.add_child(start)
	return c


func _page_name() -> Control:
	var c := CenterContainer.new()
	_name_edit = LineEdit.new()
	_name_edit.max_length = GameState.MAX_NAME_LENGTH
	_name_edit.placeholder_text = "YOUR NAME"
	_name_edit.custom_minimum_size = Vector2(220, 26)
	_name_edit.add_theme_font_size_override("font_size", 16)
	_name_edit.text_changed.connect(func(_t: String) -> void: _update_nav())
	_name_edit.text_submitted.connect(func(_t: String) -> void:
		if not _next.disabled:
			_go_next())
	c.add_child(_name_edit)
	return c


func _page_mission() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	var options := [
		[GameState.Mission.FERRY, "FERRY FLIGHT", "FLY FROM BASE TO BASE AND LAND"],
		[GameState.Mission.STRIKE, "AIR TO GROUND", "BOMB THE TARGETS, THEN LAND AT THE BASE AHEAD"],
	]
	for o in options:
		var b := _toggle("", Vector2(280, 56), group, GameState.mission == o[0])
		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l1 := _label(o[1], 16, Color.WHITE)
		var l2 := _label(o[2], 8, Color(0.8, 0.85, 0.8))
		l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(l1)
		inner.add_child(l2)
		b.add_child(inner)
		_highlight(b, l1)
		var mission: GameState.Mission = o[0]
		b.toggled.connect(func(on: bool) -> void:
			if on:
				GameState.mission = mission)
		row.add_child(b)
	return row


## Air to ground: aircraft that can't carry bombs are greyed out, and if one of
## them is selected the first one that can is picked instead.
func _update_cards() -> void:
	var strike := GameState.mission == GameState.Mission.STRIKE
	var first_ok := -1
	var selected_ok := false
	for i in _cards.size():
		var data: AircraftData = load(GameState.AIRCRAFT[i])
		var ok := not strike or data.strike_capable
		_cards[i].disabled = not ok
		# Air to ground: the card says what it carries (AircraftData.weapon_menu_label).
		var role: String = AIRCRAFT_BLURB[i] if i < AIRCRAFT_BLURB.size() else ""
		if strike:
			role = data.weapon_menu_label if ok else "NO WEAPONS"
		_blurbs[i].text = role
		_cards[i].modulate = Color.WHITE if ok else Color(1, 1, 1, 0.35)
		if ok and first_ok < 0:
			first_ok = i
		if ok and GameState.AIRCRAFT[i] == GameState.aircraft_path:
			selected_ok = true
	if not selected_ok and first_ok >= 0:
		_cards[first_ok].button_pressed = true


func _page_aircraft() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in GameState.AIRCRAFT.size():
		var card := _aircraft_card(i, group)
		_cards.append(card)
		cards.add_child(card)
	v.add_child(cards)
	_pilot_label = _label("", 16, INK)
	v.add_child(_pilot_label)
	return v


func _page_route() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	var from: BaseData = load("res://data/bases/risalpur.tres")
	for path in GameState.DESTINATIONS:
		var base: BaseData = load(path)
		var b := _toggle("", Vector2(280, 56), group, GameState.destination_path == path)
		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l1 := _label("%s  >  %s" % [from.short_name, base.short_name], 16, Color.WHITE)
		var l2 := _label(base.display_name.to_upper(), 8, Color(0.8, 0.85, 0.8))
		l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(l1)
		inner.add_child(l2)
		b.add_child(inner)
		_highlight(b, l1)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				GameState.destination_path = path)
		row.add_child(b)
	return row


func _page_time() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	for night in [false, true]:
		var b := _toggle("NIGHT" if night else "DAY", Vector2(140, 40), group, GameState.night == night)
		b.add_theme_font_size_override("font_size", 16)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				GameState.night = night)
		row.add_child(b)
	return row


## A selectable card: aircraft picture, name and its role.
func _aircraft_card(index: int, group: ButtonGroup) -> Button:
	var path: String = GameState.AIRCRAFT[index]
	var data: AircraftData = load(path)
	var card := _toggle("", Vector2(140, 70), group, path == GameState.aircraft_path)
	card.toggled.connect(func(on: bool) -> void:
		if on:
			_select_aircraft(path))
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 4
	inner.offset_right = -4
	inner.offset_top = 3
	inner.offset_bottom = -3
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 1)
	var pic := TextureRect.new()
	pic.texture = data.picture()
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
	_blurbs.append(blurb)
	inner.add_child(blurb)
	card.add_child(inner)
	_highlight(card, name_label)
	return card


func _select_aircraft(path: String) -> void:
	GameState.aircraft_path = path
	_set_preview(GameState.aircraft_data())
	_update_pilot_label()


## Bottom-right picture of the chosen aircraft (body + tailplane, cropped to
## the visible art), scaled to the same width for every aircraft and standing
## on the same line, so same-length aircraft like the two F-16s match.
func _set_preview(data: AircraftData) -> void:
	var tex := data.picture()
	_preview.texture = tex
	var sz := tex.get_size()
	var h := preview_width * sz.y / maxf(sz.x, 1.0)
	_preview.size = Vector2(preview_width, h)
	_preview.position = Vector2(preview_right - preview_width, preview_bottom - h)


func _update_pilot_label() -> void:
	if _pilot_label:
		_pilot_label.text = GameState.pilot_title()


# --- Navigation ---

func _show(step: Step) -> void:
	_step = step
	for i in _pages.size():
		_pages[i].visible = i == step
	_step_label.text = STEP_TITLES[step]
	_step_label.visible = step != Step.START
	_nav.visible = step != Step.START
	_next.text = "FLY" if step == Step.TIME else "NEXT"
	if step == Step.AIRCRAFT:
		_update_cards()
	_update_pilot_label()
	_update_nav()
	if step == Step.NAME:
		_name_edit.grab_focus()
		_name_edit.caret_column = _name_edit.text.length()
	elif step == Step.START:
		(_pages[Step.START].get_child(0) as Button).grab_focus()
	else:
		_next.grab_focus()


func _update_nav() -> void:
	_next.disabled = _step == Step.NAME and _name_edit.text.strip_edges() == ""


func _go_next() -> void:
	if _step == Step.NAME:
		var n := _name_edit.text.strip_edges()
		if n == "":
			return
		GameState.pilot_name = n
	if _step == Step.TIME:
		get_tree().change_scene_to_file(FLIGHT_SCENE)
		return
	var next := (_step + 1) as Step
	if next == Step.ROUTE and GameState.mission == GameState.Mission.STRIKE:
		next = Step.TIME   # no route on a strike: targets and landing base are random
	_show(next)


func _go_back() -> void:
	if _step == Step.NAME:
		GameState.pilot_name = _name_edit.text.strip_edges()
	if _step > Step.START:
		var prev := (_step - 1) as Step
		if prev == Step.ROUTE and GameState.mission == GameState.Mission.STRIKE:
			prev = Step.AIRCRAFT
		_show(prev)


# --- Widgets ---

## The label inside a toggle card turns gold while the card is selected.
func _highlight(b: Button, label: Label) -> void:
	var paint := func(on: bool) -> void:
		label.add_theme_color_override("font_color", SELECTED_COLOR if on else Color.WHITE)
	paint.call(b.button_pressed)
	b.toggled.connect(paint)

func _toggle(text: String, min_size: Vector2, group: ButtonGroup, pressed: bool) -> Button:
	var b := _button(text, min_size, 8)
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = pressed
	b.add_theme_color_override("font_pressed_color", SELECTED_COLOR)
	b.add_theme_color_override("font_hover_pressed_color", SELECTED_COLOR)
	return b


func _button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	return b


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
