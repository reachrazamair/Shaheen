extends Control
## Top-right radio/instructor box: placeholder pixel portrait of a PAF
## instructor plus short typewriter messages. Messages queue up; urgent ones
## (e.g. STALL) interrupt.

@export var plate_color := Color(0.55, 0.57, 0.6)
@export var plate_dark := Color(0.34, 0.36, 0.39)
@export var plate_light := Color(0.74, 0.76, 0.78)
## Characters revealed per second.
@export var type_speed := 50.0
## Each message stays at least this long before the next queued one shows.
@export var min_display_s := 2.5

@onready var _label: Label = $Text

var _queue: Array[String] = []
var _shown_for := 999.0
var _time := 0.0


func say(text: String, urgent := false) -> void:
	if urgent:
		_queue.clear()
		_show(text)
	elif _label.text == text or _queue.has(text):
		return
	else:
		_queue.append(text)


func _show(text: String) -> void:
	_label.text = text
	_label.visible_characters = 0
	_shown_for = 0.0


func _process(delta: float) -> void:
	_time += delta
	_shown_for += delta
	if _label.visible_characters >= 0:
		_label.visible_characters = mini(_label.get_total_character_count(), int(_shown_for * type_speed))
	if not _queue.is_empty() and _shown_for >= min_display_s:
		_show(_queue.pop_front())
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, plate_dark)
	draw_rect(r.grow(-1), plate_light)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(3, 3)), plate_color)
	draw_rect(Rect2(46, 4, size.x - 50, size.y - 16), Color(0.82, 0.84, 0.8))
	_draw_portrait(Vector2(5, 5))
	# Decorative radio lights; the first blinks while a message is typing.
	var typing := _label.visible_characters < _label.get_total_character_count()
	for i in 8:
		var on := (i == 0 and typing and fmod(_time, 0.3) < 0.15) or i == 7
		var col := Color(0.3, 0.95, 0.35) if on else Color(0.24, 0.25, 0.26)
		draw_rect(Rect2(48 + i * 10, size.y - 9, 6, 4), Color.BLACK)
		draw_rect(Rect2(49 + i * 10, size.y - 8, 4, 2), col)


## Placeholder instructor portrait (36x44): peaked cap, moustache, PAF blue-grey uniform.
func _draw_portrait(o: Vector2) -> void:
	var px := func(x: int, y: int, w: int, h: int, c: Color) -> void:
		draw_rect(Rect2(o + Vector2(x, y), Vector2(w, h)), c)
	var skin := Color(0.82, 0.62, 0.47)
	var skin_dark := Color(0.68, 0.48, 0.36)
	var uniform := Color(0.36, 0.45, 0.58)
	var cap := Color(0.2, 0.25, 0.35)
	px.call(0, 0, 38, 46, Color.BLACK)
	px.call(1, 1, 36, 44, Color(0.6, 0.72, 0.8))         # background
	px.call(4, 34, 30, 11, uniform)                      # shoulders
	px.call(15, 34, 8, 6, Color(0.92, 0.92, 0.9))        # shirt collar
	px.call(18, 35, 2, 6, Color(0.15, 0.18, 0.28))       # tie
	px.call(6, 37, 6, 2, Color(0.85, 0.75, 0.3))         # rank braid
	px.call(26, 37, 6, 2, Color(0.85, 0.75, 0.3))
	px.call(15, 30, 8, 5, skin_dark)                     # neck
	px.call(11, 13, 16, 19, skin)                        # face
	px.call(10, 18, 1, 6, skin_dark)                     # ears
	px.call(27, 18, 1, 6, skin_dark)
	px.call(8, 6, 22, 7, cap)                            # cap crown
	px.call(9, 12, 21, 3, Color(0.08, 0.08, 0.1))        # visor
	px.call(17, 7, 4, 3, Color(0.9, 0.78, 0.3))          # cap badge
	px.call(14, 18, 3, 2, Color(0.1, 0.1, 0.1))          # eyes
	px.call(22, 18, 3, 2, Color(0.1, 0.1, 0.1))
	px.call(13, 16, 5, 1, Color(0.2, 0.15, 0.1))         # eyebrows
	px.call(21, 16, 5, 1, Color(0.2, 0.15, 0.1))
	px.call(18, 21, 2, 4, skin_dark)                     # nose
	px.call(14, 26, 10, 2, Color(0.15, 0.1, 0.08))       # moustache
	px.call(16, 29, 6, 1, Color(0.55, 0.3, 0.28))        # mouth
