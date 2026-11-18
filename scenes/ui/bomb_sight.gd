class_name BombSight
extends Control
## Strike mission bomb sight (bottom centre of the screen). In side view the
## impact point of a bomb is usually far off screen (it keeps the jet's speed
## while it falls), so this strip shows a zoomed stretch of ground centred on
## where a bomb released NOW would land: the cross in the middle is the
## impact point, targets slide in from the right as the jet flies on, and
## bombs already falling show where they will hit. Target under the cross =
## ON TARGET: press Space. Shown while airborne with bombs or bombs falling.

var strike: StrikeMission

## Metres of ground shown each side of the impact point.
@export var range_m := 900.0
@export var glass_color := Color(0.03, 0.07, 0.04, 0.88)
@export var frame_color := Color(0.25, 0.3, 0.26)
@export var ink_color := Color(0.45, 1.0, 0.45)
@export var target_color := Color(1.0, 0.45, 0.3)
@export var on_target_color := Color(1.0, 0.85, 0.3)

var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var a := strike.aircraft if strike else null
	var show := a != null and not a.crashed and not a.on_ground and (a.bombs_left > 0 or strike.bombs_in_air > 0)
	visible = show
	if show:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, frame_color)
	draw_rect(r.grow(-2), glass_color)
	var a := strike.aircraft
	var centre_x := strike.impact_x
	var ground_y := size.y - 9.0
	var to_x := func(m: float) -> float: return size.x * 0.5 + (m - centre_x) / range_m * (size.x * 0.5 - 6.0)
	draw_rect(Rect2(4, ground_y, size.x - 8, 1), Color(ink_color, 0.6))
	# Tick every 100 m so the speed of the ground is visible.
	var first := ceilf((centre_x - range_m) / 100.0) * 100.0
	var m := first
	while m <= centre_x + range_m:
		var tx: float = to_x.call(m)
		draw_rect(Rect2(roundf(tx), ground_y + 1, 1, 2 if int(m) % 500 != 0 else 4), Color(ink_color, 0.45))
		m += 100.0

	# Targets (clamped to the edges with an arrow when out of range).
	var on := strike.target_at(centre_x) != null and a.bombs_left > 0
	for t in strike.targets:
		var tx: float = to_x.call(t.x_m)
		if t.destroyed:
			if tx > 4 and tx < size.x - 4:
				draw_line(Vector2(tx - 3, ground_y - 5), Vector2(tx + 3, ground_y - 1), Color(ink_color, 0.35), 1.0)
				draw_line(Vector2(tx - 3, ground_y - 1), Vector2(tx + 3, ground_y - 5), Color(ink_color, 0.35), 1.0)
			continue
		var half: float = t.half_width_m / range_m * (size.x * 0.5 - 6.0)
		if tx < 6:
			draw_colored_polygon(PackedVector2Array([Vector2(5, ground_y - 4), Vector2(10, ground_y - 7), Vector2(10, ground_y - 1)]), target_color)
		elif tx > size.x - 6:
			draw_colored_polygon(PackedVector2Array([Vector2(size.x - 5, ground_y - 4), Vector2(size.x - 10, ground_y - 7), Vector2(size.x - 10, ground_y - 1)]), target_color)
		else:
			draw_rect(Rect2(tx - maxf(half, 2.0), ground_y - 6, maxf(half * 2.0, 4.0), 6), target_color)

	# Bombs already falling: where they will hit.
	for x in strike.falling_impacts():
		var bx: float = to_x.call(x)
		if bx > 4 and bx < size.x - 4:
			draw_rect(Rect2(bx - 1, ground_y - 12, 2, 8), Color(1, 1, 1, 0.85))

	# Impact cross in the middle (only while there are bombs to drop).
	if a.bombs_left > 0:
		var cx := roundf(size.x * 0.5)
		var col := on_target_color if on else ink_color
		draw_rect(Rect2(cx, 5, 1, ground_y - 3), Color(col, 0.5))
		draw_rect(Rect2(cx - 5, ground_y - 4, 11, 1), col)
		draw_rect(Rect2(cx - 1, ground_y - 6, 3, 5), col)
	var label := "ON TARGET - DROP!" if on else ("BOMB SIGHT  %d LEFT" % a.bombs_left if a.bombs_left > 0 else "BOMBS FALLING")
	draw_string(_font, Vector2(6, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, on_target_color if on else Color(ink_color, 0.8))
