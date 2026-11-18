extends Control
## Top-centre positional radar: a side-view map of the whole route on an amber
## screen. Shows both bases (runway, tower, hangar), the ground, and the plane
## as a blip at its real distance and altitude, with a sweep line. Under the
## screen: the flight phase, the distance left to the destination runway, and
## a row of progress segments.
## Replaces the old phase box (attitude diagram) and route bar.

var aircraft: Aircraft
var phase := FlightPhase.TAKE_OFF
var to_name := ""
var route_m := 1.0                 ## departure threshold -> destination threshold
var departure_runway_m := 1000.0
var destination_runway_m := 1000.0
var remaining_m := 0.0
## Other bases along the route (diversions): [[threshold x m, runway length m], ...].
## Drawn dimmer; the map always runs from the departure to the farthest base.
var other_bases: Array = []
## Strike mission: the landing base is off the map until it appears.
var show_destination := true
## Strike mission (targets as blips, bombs left), or null.
var strike: StrikeMission
@export var target_color := Color(1.0, 0.42, 0.28)

@export_group("Colours")
@export var bezel_color := Color(0.42, 0.33, 0.24)
@export var bezel_light := Color(0.62, 0.5, 0.36)
@export var bezel_dark := Color(0.22, 0.16, 0.11)
@export var screen_color := Color(0.36, 0.24, 0.15)
@export var grid_color := Color(0.5, 0.36, 0.23)
@export var ink_color := Color(1.0, 0.82, 0.55)
@export var blip_color := Color(1.0, 1.0, 0.85)
@export var strip_color := Color(0.12, 0.1, 0.08)
@export var segment_on := Color(1.0, 0.72, 0.25)
@export var segment_off := Color(0.3, 0.24, 0.18)

@export_group("Scale")
## Map margin before the departure and after the destination runway (m).
@export var margin_m := 500.0
## Altitude ranges the screen steps through (ft); the smallest that fits is used.
@export var altitude_ranges_ft := PackedFloat32Array([1000, 2000, 5000, 10000, 20000])
## Seconds for one sweep across the screen.
@export var sweep_time_s := 2.5
@export var segments := 10

var _font: Font
var _time := 0.0
var _range_ft := 1000.0


func _ready() -> void:
	_font = get_theme_default_font()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _screen_rect() -> Rect2:
	return Rect2(5, 5, size.x - 14, 46)


func _draw() -> void:
	_draw_bezel()
	var sr := _screen_rect()
	draw_rect(sr.grow(1), bezel_dark)
	draw_rect(sr, screen_color)
	if aircraft == null:
		return

	# Map: x across the route, y = altitude (ground near the bottom of the screen).
	var x0 := -margin_m
	var x1 := route_m + destination_runway_m + margin_m
	for b in other_bases:
		x1 = maxf(x1, b[0] + b[1] + margin_m)
	var ground_y := sr.end.y - 6.0
	var to_x := func(m: float) -> float: return roundf(lerpf(sr.position.x + 2, sr.end.x - 2, (m - x0) / (x1 - x0)))

	# Vertical grid every kilometre, faint horizontal lines at quarter ranges.
	var km := 0.0
	while km <= x1:
		draw_rect(Rect2(to_x.call(km), sr.position.y, 1, sr.size.y), grid_color)
		km += 1000.0
	for q in range(1, 4):
		var gy := roundf(lerpf(ground_y, sr.position.y + 9, q / 4.0))
		for gx in range(int(sr.position.x) + 1, int(sr.end.x), 4):
			draw_rect(Rect2(gx, gy, 2, 1), grid_color)

	# Ground and the two bases.
	draw_rect(Rect2(sr.position.x, ground_y, sr.size.x, 1), ink_color.darkened(0.25))
	_draw_base(to_x.call(0.0), to_x.call(departure_runway_m), ground_y)
	for b in other_bases:
		_draw_base(to_x.call(b[0]), to_x.call(b[0] + b[1]), ground_y, 0.45)
	if show_destination:
		_draw_base(to_x.call(route_m), to_x.call(route_m + destination_runway_m), ground_y)
		# Marker over the destination.
		var dx: float = to_x.call(route_m + destination_runway_m * 0.5)
		draw_colored_polygon(PackedVector2Array([Vector2(dx - 2, sr.position.y + 2), Vector2(dx + 3, sr.position.y + 2),
				Vector2(dx + 0.5, sr.position.y + 5)]), segment_on)
	if strike:
		# Targets: a bright block while standing, a dim x once destroyed.
		for t in strike.targets:
			var tx: float = to_x.call(t.x_m)
			if t.destroyed:
				draw_rect(Rect2(tx - 1, ground_y - 3, 1, 1), ink_color.darkened(0.4))
				draw_rect(Rect2(tx + 1, ground_y - 3, 1, 1), ink_color.darkened(0.4))
				draw_rect(Rect2(tx, ground_y - 2, 1, 1), ink_color.darkened(0.4))
			else:
				draw_rect(Rect2(tx - 1, ground_y - 3, 3, 3), target_color)
		# Bombs left: small bomb icons in the top-right corner.
		for i in aircraft.bombs_left:
			var bx := sr.end.x - 10 - i * 9
			draw_rect(Rect2(bx, sr.position.y + 3, 6, 2), ink_color)
			draw_rect(Rect2(bx - 1, sr.position.y + 2, 1, 4), ink_color)

	# Altitude range (steps up as the plane climbs).
	var alt := maxf(aircraft.altitude_ft, 0.0)
	_range_ft = altitude_ranges_ft[altitude_ranges_ft.size() - 1]
	for r in altitude_ranges_ft:
		if alt * 1.15 <= r:
			_range_ft = r
			break
	_text(Vector2(sr.position.x + 2, sr.position.y + 7), "%dK FT" % roundi(_range_ft / 1000.0) if _range_ft >= 1000.0 else "%d FT" % _range_ft, ink_color.darkened(0.2))

	# Sweep line with a fading trail.
	var sweep := fmod(_time / sweep_time_s, 1.0)
	var sx := lerpf(sr.position.x, sr.end.x - 1, sweep)
	for k in 6:
		var tx := sx - k * 2
		if tx >= sr.position.x:
			draw_rect(Rect2(tx, sr.position.y, 1, sr.size.y), Color(ink_color, 0.35 - k * 0.05))

	# Plane blip: brighter just after the sweep passes over it.
	var px: float = to_x.call(clampf(aircraft.pos_m.x, x0, x1))
	var py := roundf(lerpf(ground_y - 2, sr.position.y + 2, clampf(alt / _range_ft, 0.0, 1.0)))
	var since := fmod((sx - px) / (sr.size.x) + 1.0, 1.0)
	var col := blip_color if since < 0.5 else blip_color.darkened(0.25)
	# Tiny side-view plane: fuselage, tail, wing.
	draw_rect(Rect2(px - 3, py, 7, 1), col)
	draw_rect(Rect2(px - 3, py - 2, 1, 2), col)
	draw_rect(Rect2(px, py + 1, 2, 1), col)
	draw_rect(Rect2(px + 4, py, 1, 1), col)
	# Drop line to the ground so height is easy to judge.
	for dy in range(int(py) + 3, int(ground_y), 2):
		draw_rect(Rect2(px, dy, 1, 1), Color(ink_color, 0.5))

	_draw_strip()


## Runway strip, control tower and hangar for one base.
## dim: 0 = full brightness, more = fainter (bases that aren't the destination).
func _draw_base(rx0: float, rx1: float, ground_y: float, dim := 0.0) -> void:
	var ink := ink_color.lerp(screen_color, dim)
	draw_rect(Rect2(rx0, ground_y - 1, maxf(rx1 - rx0, 2.0), 2), ink)
	# Tower: stick with a cab on top.
	draw_rect(Rect2(rx0 + 1, ground_y - 8, 1, 7), ink)
	draw_rect(Rect2(rx0, ground_y - 10, 3, 2), ink)
	# Hangar: a little arched block behind the runway start.
	draw_rect(Rect2(rx0 - 7, ground_y - 3, 5, 3), ink.darkened(0.15))
	draw_rect(Rect2(rx0 - 6, ground_y - 4, 3, 1), ink.darkened(0.15))


## Bottom strip: phase on the left, distance to go on the right, progress segments.
func _draw_strip() -> void:
	var r := Rect2(4, 54, size.x - 12, size.y - 58)
	draw_rect(r, bezel_dark)
	draw_rect(r.grow(-1), strip_color)
	_text(Vector2(r.position.x + 3, r.position.y + 9), phase, ink_color)
	var to_target := strike != null and not show_destination
	var dist := ("TGT %.1f KM" if to_target else "%.1f KM") % (maxf(remaining_m, 0.0) / 1000.0)
	var w := _font.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_text(Vector2(r.end.x - 3 - w, r.position.y + 9), dist, ink_color.darkened(0.15))
	var progress := clampf(aircraft.pos_m.x / route_m if to_target else 1.0 - remaining_m / route_m, 0.0, 1.0)
	var sw := (r.size.x - 6 - (segments - 1)) / segments
	for i in segments:
		var lit := progress * segments > i
		draw_rect(Rect2(roundf(r.position.x + 3 + i * (sw + 1)), r.position.y + 13, floorf(sw), 4), segment_on if lit else segment_off)


## Bronze frame with rivets down the right side (like an old radar set).
func _draw_bezel() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, bezel_dark)
	draw_rect(r.grow(-1), bezel_light)
	draw_rect(Rect2(2, 2, size.x - 3, size.y - 3), bezel_color)
	for i in 6:
		var c := Vector2(size.x - 5, 6 + i * (size.y - 12) / 5.0)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), bezel_dark)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(1, 1)), bezel_light)


func _text(baseline_left: Vector2, s: String, col: Color) -> void:
	draw_string(_font, baseline_left, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
