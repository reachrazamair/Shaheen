extends Control
## Top-centre flight phase box: dark panel with the current phase name and a
## tiny attitude diagram (horizon + plane silhouette tilted by pitch).

var aircraft: Aircraft
var phase := FlightPhase.TAKE_OFF

@export var box_color := Color(0.1, 0.11, 0.12)
@export var border_color := Color(0.45, 0.47, 0.5)
@export var text_color := Color(0.9, 0.92, 0.85)
@export var sky_color := Color(0.25, 0.4, 0.6)
@export var ground_color := Color(0.35, 0.28, 0.18)
@export var plane_color := Color(1.0, 1.0, 1.0)

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

	var w := _font.get_string_size(phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(_font, Vector2(roundf((size.x - w) * 0.5), 18), phase,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)

	# Attitude diagram.
	var d := Rect2(size.x * 0.5 - 30, 24, 60, 20)
	draw_rect(d, sky_color)
	draw_rect(Rect2(d.position.x, d.get_center().y, d.size.x, d.size.y * 0.5), ground_color)
	if aircraft == null:
		return
	var c := d.get_center()
	var pitch := aircraft.pitch
	var nose := Vector2.from_angle(-pitch)
	var up := Vector2.from_angle(-pitch - PI * 0.5)
	# Fuselage, tail fin and a wing stub.
	draw_line(c - nose * 9, c + nose * 9, plane_color, 1.0)
	draw_line(c - nose * 9, c - nose * 9 + up * 4, plane_color, 1.0)
	draw_line(c - nose * 2, c + nose * 3 + up * 1, plane_color, 1.0)
	draw_rect(d, border_color, false)
