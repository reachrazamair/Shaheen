extends Control
## Top-left cockpit panel: grey metal plate with analog round gauges
## (airspeed, altimeter, vertical speed), throttle lever, fuel gauge,
## engine/gear/flap lights and a row of warning lights.
## Everything is drawn in code as placeholder pixel art at final size; gauge
## ranges come from the aircraft's data.
## Two looks, picked by AircraftData.cockpit_style:
##  - Analog (trainers): grey metal plate with round dials.
##  - Glass (fighters, F-16): dark panel with two green digital screens
##    (speed tape + Mach, altitude tape + vertical speed bar), G readout.

var aircraft: Aircraft

@export_group("Colours")
@export var plate_color := Color(0.55, 0.57, 0.6)
@export var plate_dark := Color(0.34, 0.36, 0.39)
@export var plate_light := Color(0.74, 0.76, 0.78)
@export var face_color := Color(0.08, 0.09, 0.1)
@export var marking_color := Color(0.9, 0.9, 0.86)
@export var needle_color := Color(1.0, 0.6, 0.15)
@export var label_color := Color(0.12, 0.13, 0.14)
@export var lamp_off := Color(0.22, 0.23, 0.24)
@export var lamp_green := Color(0.3, 0.95, 0.35)
@export var lamp_amber := Color(1.0, 0.72, 0.15)
@export var lamp_red := Color(1.0, 0.22, 0.18)
@export_subgroup("Glass cockpit")
@export var glass_plate := Color(0.17, 0.18, 0.2)
@export var glass_plate_light := Color(0.3, 0.31, 0.34)
@export var glass_plate_dark := Color(0.08, 0.08, 0.09)
@export var glass_label := Color(0.7, 0.72, 0.74)
@export var mfd_green := Color(0.35, 1.0, 0.45)
@export var mfd_dim := Color(0.12, 0.42, 0.18)
@export var mfd_bg := Color(0.02, 0.05, 0.03)

@export_group("Layout")
@export var gauge_radius := 25.0
@export var gauge_centres := PackedVector2Array([Vector2(33, 36), Vector2(92, 36), Vector2(151, 36)])
## Below this height with retractable gear still up and slow: GEAR warning.
@export var gear_warning_height_ft := 1000.0

var _font: Font
var _time := 0.0


func _ready() -> void:
	_font = get_theme_default_font()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if aircraft != null and aircraft.data.cockpit_style == 1:
		_draw_glass()
		return
	_draw_plate(Rect2(Vector2.ZERO, size))
	if aircraft == null:
		return
	_draw_airspeed(gauge_centres[0])
	_draw_altimeter(gauge_centres[1])
	_draw_vsi(gauge_centres[2])
	_draw_throttle(Vector2(190, 8))
	_draw_fuel(Vector2(211, 8))
	_draw_status(Vector2(226, 8))
	_draw_warnings(Vector2(6, size.y - 20))


# --- Plate ---

func _draw_plate(r: Rect2) -> void:
	draw_rect(r, plate_dark)
	draw_rect(r.grow(-1), plate_light)
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(3, 3)), plate_color)
	for c in [Vector2(4, 4), Vector2(r.size.x - 5, 4), Vector2(4, r.size.y - 5), Vector2(r.size.x - 5, r.size.y - 5)]:
		draw_rect(Rect2(c, Vector2(2, 2)), plate_dark)
		draw_rect(Rect2(c, Vector2(1, 1)), plate_light)


# --- Gauges ---

func _gauge_face(c: Vector2, label: String) -> void:
	draw_circle(c, gauge_radius + 2, plate_dark)
	draw_circle(c, gauge_radius + 1, Color(0.16, 0.16, 0.17))
	draw_circle(c, gauge_radius - 1, face_color)
	_text_centered(c + Vector2(0, gauge_radius + 10), label, label_color)


func _tick(c: Vector2, ang: float, r_in: float, r_out: float, col: Color, w := 1.0) -> void:
	var d := Vector2.from_angle(ang)
	draw_line(c + d * r_in, c + d * r_out, col, w)


func _needle(c: Vector2, ang: float, length: float, w := 1.0) -> void:
	draw_line(c, c + Vector2.from_angle(ang) * length, needle_color, w)
	draw_circle(c, 2, Color(0.3, 0.3, 0.3))


func _readout(c: Vector2, s: String, w := 26.0) -> void:
	var box := Rect2(c.x - w * 0.5, c.y + 6, w, 9)
	draw_rect(box, Color.BLACK)
	draw_rect(box, Color(0.3, 0.3, 0.3), false)
	_text_centered(Vector2(c.x, c.y + 13), s, marking_color)


## Airspeed: 0..max over a 270 degree sweep from bottom-left, with green/yellow arcs.
func _draw_airspeed(c: Vector2) -> void:
	var d := aircraft.data
	var to_ang := func(kt: float) -> float:
		return deg_to_rad(135.0 + 270.0 * clampf(kt / d.max_speed_kt, 0.0, 1.0))
	_gauge_face(c, "KNOTS")
	var r := gauge_radius - 3
	draw_arc(c, r, to_ang.call(d.stall_speed_kt), to_ang.call(d.max_speed_kt * 0.85), 24, lamp_green, 2.0)
	draw_arc(c, r, to_ang.call(d.max_speed_kt * 0.85), to_ang.call(d.max_speed_kt), 8, lamp_amber, 2.0)
	_tick(c, to_ang.call(d.max_speed_kt), r - 5, r + 1, lamp_red, 2.0)
	var kt := 0.0
	while kt <= d.max_speed_kt:
		_tick(c, to_ang.call(kt), r - (5 if int(kt) % 40 == 0 else 3), r - 1, marking_color)
		kt += 20.0
	_readout(c, str(roundi(aircraft.speed_kt)))
	_needle(c, to_ang.call(aircraft.speed_kt), r - 2)


## Altimeter: long needle = 1,000 ft per turn, short needle = 10,000 ft per turn.
func _draw_altimeter(c: Vector2) -> void:
	_gauge_face(c, "ALT FT")
	var r := gauge_radius - 3
	for i in 10:
		_tick(c, deg_to_rad(-90.0 + 36.0 * i), r - (5 if i == 0 else 3), r, marking_color)
	var alt := maxf(aircraft.altitude_ft, 0.0)
	_readout(c, str(roundi(alt / 10.0) * 10), 30.0)
	_needle(c, deg_to_rad(-90.0 + 360.0 * alt / 10000.0), r - 11, 2.0)
	_needle(c, deg_to_rad(-90.0 + 360.0 * fmod(alt, 1000.0) / 1000.0), r - 2)


## Vertical speed: zero at 9 o'clock, climb clockwise (up), descent anticlockwise.
func _draw_vsi(c: Vector2) -> void:
	var max_fpm := aircraft.data.gauge_vsi_max_fpm
	var to_ang := func(fpm: float) -> float:
		return deg_to_rad(180.0 + 160.0 * clampf(fpm / max_fpm, -1.0, 1.0))
	_gauge_face(c, "V/S")
	var r := gauge_radius - 3
	for i in range(-4, 5):
		_tick(c, to_ang.call(max_fpm * i / 4.0), r - (5 if i == 0 else 3), r, marking_color)
	_text_centered(c + Vector2(-9, -6), "UP", marking_color)
	var vs := aircraft.vertical_speed_fpm
	_readout(c, "%+d" % (roundi(vs / 10.0) * 10), 32.0)
	_needle(c, to_ang.call(vs), r - 2)


# --- Throttle and fuel ---

func _draw_throttle(p: Vector2) -> void:
	var h := 58.0
	draw_rect(Rect2(p.x, p.y, 8, h), plate_dark)
	draw_rect(Rect2(p.x + 3, p.y + 2, 2, h - 4), Color.BLACK)
	if aircraft.data.afterburner_thrust_n > 0.0:
		# Afterburner detent: everything above this mark lights the afterburner.
		var dy := p.y + (h - 6) * (1.0 - aircraft.data.afterburner_threshold) + 3
		draw_rect(Rect2(p.x - 4, dy, 16, 1), lamp_red)
	var hy := p.y + (h - 6) * (1.0 - aircraft.throttle)
	draw_rect(Rect2(p.x - 3, hy, 14, 6), Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(p.x - 2, hy + 1, 12, 1), Color(0.4, 0.4, 0.4))
	_text_centered(Vector2(p.x + 4, p.y + h + 10), "THR", _lc())
	_text_centered(Vector2(p.x + 4, p.y + h + 18), str(roundi(aircraft.throttle * 100.0)), _lc())


func _draw_fuel(p: Vector2) -> void:
	var h := 58.0
	var frac := clampf(aircraft.fuel_fraction, 0.0, 1.0)
	draw_rect(Rect2(p.x, p.y, 8, h), Color.BLACK)
	var col := lamp_amber if aircraft.low_fuel else lamp_green
	draw_rect(Rect2(p.x + 1, p.y + 1 + (h - 2) * (1.0 - frac), 6, (h - 2) * frac), col)
	for i in range(1, 4):
		draw_rect(Rect2(p.x, p.y + h * i / 4.0, 3, 1), plate_light)
	_text_centered(Vector2(p.x + 4, p.y + h + 10), "FUEL", _lc())


# --- Status lights ---

func _lamp(p: Vector2, col: Color, label: String) -> void:
	draw_rect(Rect2(p, Vector2(7, 6)), Color.BLACK)
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(5, 4)), col)
	_text(p + Vector2(10, 6), label, _lc())


func _draw_status(p: Vector2) -> void:
	var a := aircraft
	var eng := lamp_off
	if a.engine_on:
		eng = lamp_green if a.engine_rpm >= 1.0 else lamp_amber
	elif a.engine_rpm > 0.0:
		eng = lamp_amber
	_lamp(p, eng, "ENG")

	var gear := lamp_green
	if a.data.retractable_gear:
		gear = lamp_amber if a.gear_in_transit else (lamp_green if a.gear_down else lamp_off)
	_lamp(p + Vector2(0, 12), gear, "GEAR")

	_text(p + Vector2(0, 32), "FLAPS", label_color)
	for i in Aircraft.FLAP_NAMES.size():
		var on := a.flap_setting == i
		var moving := on and not is_equal_approx(a.flap_pos, float(i))
		var col := (lamp_amber if moving else lamp_green) if on else lamp_off
		_lamp(p + Vector2(0, 38 + i * 10), col, Aircraft.FLAP_NAMES[i])


# --- Warning lights ---

func _draw_warnings(p: Vector2) -> void:
	var a := aircraft
	var blink := fmod(_time, 0.5) < 0.3
	var gear_warn := a.data.retractable_gear and not a.on_ground and a.gear_pos < 1.0 \
			and a.altitude_ft < gear_warning_height_ft \
			and a.speed_kt < a.data.stall_speed_kt * 1.5 and a.vertical_speed_fpm < 0.0
	var fuel_text := "NO FUEL" if a.fuel_kg <= 0.0 else "FUEL"
	var items := [
		["STALL", a.stalled and blink, lamp_red],
		["GEAR", gear_warn and blink, lamp_red],
		[fuel_text, a.low_fuel, lamp_amber],
		["BRAKE", a.braking, lamp_amber],
	]
	if a.data.afterburner_thrust_n > 0.0:
		items.append(["A/B", a.afterburner > 0.0, Color(1.0, 0.55, 0.15)])
	var w := (size.x - 12.0 - 3.0 * (items.size() - 1)) / items.size()
	for i in items.size():
		var r := Rect2(p.x + i * (w + 3.0), p.y, w, 14)
		var lit: bool = items[i][1]
		draw_rect(r, Color.BLACK)
		draw_rect(r.grow(-1), items[i][2] if lit else lamp_off)
		_text_centered(Vector2(r.get_center().x, r.position.y + 10), items[i][0],
				Color.BLACK if lit else Color(0.42, 0.42, 0.42))


# --- Glass cockpit (fighters) ---

func _draw_glass() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, glass_plate_dark)
	draw_rect(r.grow(-1), glass_plate_light)
	draw_rect(Rect2(2, 2, size.x - 3, size.y - 3), glass_plate)
	# Two screens, then throttle, fuel and status on the right.
	var speed_mfd := Rect2(6, 6, 80, 82)
	var alt_mfd := Rect2(92, 6, 80, 82)
	_mfd_frame(speed_mfd)
	_mfd_frame(alt_mfd)
	_draw_speed_tape(speed_mfd.grow(-4))
	_draw_alt_tape(alt_mfd.grow(-4))
	_draw_throttle(Vector2(180, 8))
	_draw_fuel(Vector2(200, 8))
	_draw_glass_status(Vector2(218, 8))
	_draw_warnings(Vector2(6, size.y - 20))


## Screen bezel with the row of push buttons above and below (like an MFD).
func _mfd_frame(m: Rect2) -> void:
	draw_rect(m, glass_plate_dark)
	draw_rect(m.grow(-1), Color(0.24, 0.25, 0.27))
	for i in 5:
		var bx := m.position.x + 8 + i * (m.size.x - 16) / 4.0 - 3
		draw_rect(Rect2(bx, m.position.y - 0, 6, 2), Color(0.42, 0.43, 0.45))
		draw_rect(Rect2(bx, m.end.y - 2, 6, 2), Color(0.42, 0.43, 0.45))
	draw_rect(m.grow(-4), mfd_bg)


## A vertical tape: ticks scroll past a fixed box showing the current value.
## step = value between small ticks, label_every = small ticks per label.
func _tape(s: Rect2, value: float, units_per_px: float, step: float, label_every: int,
		fmt: Callable, box_text: String) -> void:
	var cy := s.get_center().y
	var x := s.position.x + 4
	var first := floorf((value - (s.size.y * 0.5) * units_per_px) / step) * step
	var v := first
	while v <= value + (s.size.y * 0.5) * units_per_px:
		var y := roundf(cy - (v - value) / units_per_px)
		if y > s.position.y + 1 and y < s.end.y - 1 and v >= 0.0:
			var major := is_zero_approx(fmod(roundf(v / step), float(label_every)))
			draw_rect(Rect2(x, y, 6 if major else 3, 1), mfd_green if major else mfd_dim)
			if major and absf(y - cy) > 7:
				_text(Vector2(x + 9, y + 3), fmt.call(v), mfd_dim.lightened(0.3))
		v += step
	# Current value box.
	var box := Rect2(s.position.x + 1, cy - 6, s.size.x - 14, 12)
	draw_rect(box, mfd_bg)
	draw_rect(box, mfd_green, false)
	draw_colored_polygon(PackedVector2Array([box.position + Vector2(box.size.x, 3), box.position + Vector2(box.size.x + 4, 6), box.position + Vector2(box.size.x, 9)]), mfd_green)
	_text(Vector2(box.position.x + 4, cy + 3), box_text, mfd_green)


func _draw_speed_tape(s: Rect2) -> void:
	var kt := aircraft.speed_kt
	_text(Vector2(s.position.x + 2, s.position.y + 7), "KTS", mfd_green)
	var tape := Rect2(s.position.x, s.position.y + 9, s.size.x, s.size.y - 20)
	_tape(tape, kt, 2.0, 10.0, 5, func(v: float) -> String: return str(roundi(v)), str(roundi(kt)))
	# Stall speed marker: red bar on the tape edge below stall speed.
	var cy := tape.get_center().y
	var stall_y := cy - (aircraft.data.stall_speed_kt - kt) / 2.0
	var top := clampf(stall_y, tape.position.y, tape.end.y)
	if top < tape.end.y:
		draw_rect(Rect2(tape.position.x + 1, top, 2, tape.end.y - top), lamp_red)
	var mach := kt / 661.5
	_text(Vector2(s.position.x + 2, s.end.y - 2), "M %.2f" % mach, mfd_green)
	var g := aircraft.g_load
	_text_right(Vector2(s.end.x - 2, s.position.y + 7), "G %.1f" % g, mfd_green)


func _draw_alt_tape(s: Rect2) -> void:
	var alt := maxf(aircraft.altitude_ft, 0.0)
	_text(Vector2(s.position.x + 2, s.position.y + 7), "ALT", mfd_green)
	var tape := Rect2(s.position.x, s.position.y + 9, s.size.x - 8, s.size.y - 20)
	_tape(tape, alt, 20.0, 100.0, 5, func(v: float) -> String: return str(roundi(v)), str(roundi(alt / 10.0) * 10))
	# Vertical speed bar on the right edge: grows up for climb, down for descent.
	var vs := aircraft.vertical_speed_fpm
	var bar_x := s.end.x - 4
	var cy := tape.get_center().y
	var half := tape.size.y * 0.5
	draw_rect(Rect2(bar_x, tape.position.y, 1, tape.size.y), mfd_dim)
	draw_rect(Rect2(bar_x - 2, cy, 5, 1), mfd_dim)
	var len_px := clampf(vs / aircraft.data.gauge_vsi_max_fpm, -1.0, 1.0) * half
	draw_rect(Rect2(bar_x - 1, minf(cy, cy - len_px), 3, absf(len_px)), mfd_green)
	_text(Vector2(s.position.x + 2, s.end.y - 2), "VS %+d" % (roundi(vs / 10.0) * 10), mfd_green)


func _draw_glass_status(p: Vector2) -> void:
	var a := aircraft
	var eng := lamp_off
	if a.engine_on:
		eng = lamp_green if a.engine_rpm >= 1.0 else lamp_amber
	elif a.engine_rpm > 0.0:
		eng = lamp_amber
	_lamp(p, eng, "ENG")
	_text(p + Vector2(10, 14), "%d%%" % roundi(a.engine_rpm * 100.0), glass_label)

	# Landing gear: three lights (nose, left, right) like a real jet.
	_text(p + Vector2(0, 26), "GEAR", glass_label)
	var gear_col := lamp_amber if a.gear_in_transit else (lamp_green if a.gear_down else lamp_off)
	for i in 3:
		var gp := p + Vector2(i * 9, 29) + (Vector2(0, -3) if i == 1 else Vector2.ZERO) + Vector2(0, 3)
		draw_rect(Rect2(gp, Vector2(7, 6)), Color.BLACK)
		draw_rect(Rect2(gp + Vector2(1, 1), Vector2(5, 4)), gear_col)

	_text(p + Vector2(0, 50), "FLAPS", glass_label)
	var flap: String = Aircraft.FLAP_NAMES[a.flap_setting]
	var moving := not is_equal_approx(a.flap_pos, float(a.flap_setting))
	var fr := Rect2(p + Vector2(0, 53), Vector2(26, 10))
	draw_rect(fr, mfd_bg)
	draw_rect(fr, glass_plate_light, false)
	_text_centered(Vector2(fr.get_center().x, fr.position.y + 8), flap, lamp_amber if moving else mfd_green)


# --- Text helpers ---

## Label colour for the current panel style (dark text on grey, light on black).
func _lc() -> Color:
	return glass_label if aircraft != null and aircraft.data.cockpit_style == 1 else label_color


func _text_right(baseline_right: Vector2, s: String, col: Color, font_size := 8) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, Vector2(roundf(baseline_right.x - w), baseline_right.y), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)



func _text(baseline_left: Vector2, s: String, col: Color, font_size := 8) -> void:
	draw_string(_font, baseline_left, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _text_centered(baseline_centre: Vector2, s: String, col: Color, font_size := 8) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, Vector2(roundf(baseline_centre.x - w * 0.5), baseline_centre.y), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
