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


## Placeholder instructor portrait (38x46): black flying helmet with the
## sun visor down over the eyes, green flight suit with PAF flag patch,
## oxygen mask hanging loose. Animated: the mouth moves while a message types.
func _draw_portrait(o: Vector2) -> void:
	var px := func(x: int, y: int, w: int, h: int, c: Color) -> void:
		draw_rect(Rect2(o + Vector2(x, y), Vector2(w, h)), c)
	var skin := Color(0.82, 0.62, 0.47)
	var skin_dark := Color(0.66, 0.47, 0.35)
	var suit := Color(0.36, 0.45, 0.26)
	var suit_dark := Color(0.26, 0.33, 0.18)
	var shell := Color(0.1, 0.1, 0.11)
	var shell_hi := Color(0.27, 0.28, 0.3)
	var shell_dark := Color(0.04, 0.04, 0.05)
	var visor := Color(0.07, 0.06, 0.1)
	var visor_hi := Color(0.55, 0.42, 0.25)
	var dark := Color(0.12, 0.1, 0.09)
	var typing := _label.visible_characters < _label.get_total_character_count()
	var mouth_open := typing and fmod(_time, 0.22) < 0.11

	px.call(0, 0, 38, 46, Color.BLACK)
	px.call(1, 1, 36, 44, Color(0.6, 0.72, 0.8))       # sky background
	# Flight suit: shoulders, collar, zip, name tag, flag patch.
	px.call(3, 35, 32, 10, suit)
	px.call(3, 43, 32, 2, suit_dark)
	px.call(12, 33, 5, 4, suit_dark)
	px.call(21, 33, 5, 4, suit_dark)
	px.call(18, 36, 1, 9, Color(0.75, 0.75, 0.72))     # zip
	px.call(23, 38, 7, 3, Color(0.2, 0.17, 0.12))      # name tag
	px.call(24, 39, 5, 1, Color(0.85, 0.8, 0.6))
	px.call(6, 37, 2, 4, Color.WHITE)                  # Pakistan flag patch
	px.call(8, 37, 4, 4, Color(0.0, 0.4, 0.2))
	px.call(10, 38, 1, 1, Color.WHITE)
	# Neck and face.
	px.call(15, 30, 8, 5, skin_dark)
	px.call(11, 14, 16, 18, skin)
	# Black helmet shell with ear cups and a highlight along the top.
	px.call(9, 3, 20, 2, shell)
	px.call(7, 5, 24, 10, shell)
	px.call(7, 15, 5, 12, shell)
	px.call(26, 15, 5, 12, shell)
	px.call(7, 24, 5, 3, shell_dark)
	px.call(26, 24, 5, 3, shell_dark)
	px.call(11, 4, 9, 1, shell_hi)                     # shine on the dome
	px.call(9, 5, 3, 1, shell_hi)
	px.call(9, 8, 20, 1, shell_dark)                   # visor housing
	# Sun visor DOWN: dark mirrored glass over the eyes, with a warm reflection.
	px.call(9, 9, 20, 11, visor)
	px.call(10, 20, 18, 1, visor)
	px.call(11, 10, 6, 1, visor_hi)
	px.call(11, 11, 3, 1, visor_hi)
	px.call(23, 17, 4, 1, Color(0.3, 0.32, 0.4))
	px.call(9, 9, 1, 11, shell_hi)                     # visor rim
	px.call(28, 9, 1, 11, shell_hi)
	# Oxygen mask hanging from the right side, with its hose.
	px.call(27, 26, 4, 5, Color(0.4, 0.42, 0.4))
	px.call(28, 31, 1, 5, dark)
	# Nose tip under the visor, moustache, mouth (talks).
	px.call(18, 21, 2, 3, skin_dark)
	px.call(14, 25, 11, 2, dark)                      # moustache
	if mouth_open:
		px.call(16, 27, 7, 3, Color(0.3, 0.1, 0.1))
	else:
		px.call(16, 28, 7, 1, Color(0.55, 0.3, 0.28))
