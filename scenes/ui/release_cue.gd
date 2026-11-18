class_name ReleaseCue
extends Control
## Unguided-bomb release cue (Mirage V): a simple timing bar instead of a bomb
## sight. As the jet closes on the next target the marker slides right toward
## the green window (sized to the real hit window at this speed and height);
## in the window it flashes DROP!, past it it says LATE. A countdown in
## seconds is shown before that. Fixed on screen just right of the aircraft,
## clear of the ground so explosions stay visible.

var strike: StrikeMission

## Seconds before release when the cue appears / the bar's full length.
@export var show_from_s := 8.0
@export var bar_seconds := 6.0
@export var panel_color := Color(0.06, 0.07, 0.08, 0.82)
@export var frame_color := Color(0.45, 0.47, 0.5)
@export var ink_color := Color(1.0, 0.85, 0.45)
@export var drop_color := Color(0.45, 1.0, 0.45)
@export var late_color := Color(1.0, 0.35, 0.25)

var _font: Font
var _time := 0.0
var _cue := {}


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(delta: float) -> void:
	_time += delta
	_cue = {}
	var ok := strike != null and strike.aircraft != null and not strike.is_revealed
	if ok:
		var a := strike.aircraft
		ok = not a.data.bomb_guided and a.bombs_left > 0 and not a.on_ground and not a.crashed
	if ok:
		_cue = strike.next_release()
		ok = not _cue.is_empty() and _cue.seconds < show_from_s
	visible = ok
	if visible:
		queue_redraw()


func _draw() -> void:
	var s: float = _cue.seconds
	var win: float = _cue.window
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, panel_color)
	draw_rect(r, frame_color, false, 1.0)
	# Bar: left = bar_seconds to go, the green window near the right end.
	var bar := Rect2(6, size.y - 13, size.x - 12, 7)
	var to_x := func(sec: float) -> float: return bar.position.x + bar.size.x * (1.0 - (sec + 1.0) / (bar_seconds + 1.0))
	draw_rect(bar, Color(0.18, 0.19, 0.2))
	var g0: float = to_x.call(win)
	var g1: float = to_x.call(-win)
	draw_rect(Rect2(g0, bar.position.y, maxf(g1 - g0, 2.0), bar.size.y), Color(drop_color, 0.55))
	var mx := clampf(to_x.call(s), bar.position.x, bar.end.x - 1)
	var in_window := absf(s) <= win
	var late := s < -win
	var col := drop_color if in_window else (late_color if late else ink_color)
	draw_rect(Rect2(roundf(mx) - 1, bar.position.y - 3, 3, bar.size.y + 6), col)
	# Text.
	var blink := fmod(_time, 0.4) < 0.26
	var text := "DROP!" if in_window else ("LATE" if late else "DROP IN %.1f" % s)
	if in_window and not blink:
		text = ""
	draw_string(_font, Vector2(6, 10), "RELEASE CUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(ink_color, 0.7))
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(_font, Vector2(roundf((size.x - w) * 0.5), 27), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
