extends Control
## Small route progress bar under the phase box: destination name, distance
## remaining to its runway threshold, and a plane marker between the bases.

var to_name := ""
var total_m := 1.0
var remaining_m := 0.0

@export var box_color := Color(0.1, 0.11, 0.12)
@export var border_color := Color(0.45, 0.47, 0.5)
@export var text_color := Color(0.9, 0.92, 0.85)
@export var track_color := Color(0.3, 0.32, 0.34)
@export var done_color := Color(0.3, 0.95, 0.35)

var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, border_color)
	draw_rect(r.grow(-1), Color.BLACK)
	draw_rect(r.grow(-2), box_color)

	var text := "%s %.1f KM" % [to_name, maxf(remaining_m, 0.0) / 1000.0]
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(_font, Vector2(roundf((size.x - w) * 0.5), 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)

	var x0 := 8.0
	var x1 := size.x - 8.0
	var y := size.y - 6.0
	var p := clampf(1.0 - remaining_m / total_m, 0.0, 1.0)
	var px := roundf(lerpf(x0, x1, p))
	draw_rect(Rect2(x0, y, x1 - x0, 1), track_color)
	draw_rect(Rect2(x0, y, px - x0, 1), done_color)
	draw_rect(Rect2(x0 - 1, y - 1, 3, 3), text_color)        # departure
	draw_rect(Rect2(x1 - 1, y - 1, 3, 3), done_color)        # destination
	draw_rect(Rect2(px - 2, y - 2, 5, 2), Color.WHITE)       # plane marker
	draw_rect(Rect2(px - 2, y - 3, 1, 1), Color.WHITE)
