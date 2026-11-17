extends Node2D
## Crash effect, drawn in code. Set `severity` (0..1) before adding it.
##  - Small crash (< Aircraft.BIG_CRASH_SEVERITY): a dust cloud kicked up along the
##    ground, a shower of sparks and a thin smoke trail. No fireball.
##  - Big crash: a white flash, a rolling fireball made of several blobs,
##    sparks and burning bits thrown out, then a thick smoke column.

@export var fireball_time_s := 1.1
@export var smoke_puffs := 16

var severity := 0.5
var _t := 0.0
var _sparks: Array = []    # [velocity, size, life]
var _blobs: Array = []     # fireball blobs: [offset, radius, delay]
var _rng := RandomNumberGenerator.new()


## Fire and sparks stay bright at night.
func _g(c: Color) -> Color:
	return GameState.glow(c)


func _big() -> bool:
	return severity >= Aircraft.BIG_CRASH_SEVERITY


func _ready() -> void:
	_rng.randomize()
	var n := 40 if _big() else 18
	for i in n:
		var ang := _rng.randf_range(-PI * 0.95, -PI * 0.05)   # upward half
		var speed := _rng.randf_range(40, 170) if _big() else _rng.randf_range(20, 80)
		var v := Vector2.from_angle(ang) * speed
		if not _big():
			v.y *= 0.5          # scraping: sparks stay low and spray forward
			v.x = absf(v.x) * 0.8 + 20
		_sparks.append([v, _rng.randf_range(0.7, 1.6), _rng.randf_range(0.5, 1.3)])
	if _big():
		for i in 7:
			_blobs.append([Vector2(_rng.randf_range(-16, 16), _rng.randf_range(-14, 2)),
					_rng.randf_range(9, 17), _rng.randf_range(0.0, 0.25)])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _big():
		_draw_explosion()
	else:
		_draw_dust()
	_draw_sparks()
	_draw_smoke()


func _draw_explosion() -> void:
	# Flash.
	if _t < 0.12:
		draw_circle(Vector2(0, -6), 34, _g(Color(1, 1, 0.9, 0.85 * (1.0 - _t / 0.12))))
	# Fireball: blobs swell, rise a little, go from yellow to orange to dark red.
	for b in _blobs:
		var t: float = (_t - b[2]) / fireball_time_s
		if t < 0.0 or t > 1.0:
			continue
		var pos: Vector2 = b[0] + Vector2(0, -6 - 18 * t)
		var r: float = b[1] * (0.4 + 0.9 * sqrt(t))
		var a := 1.0 - t * t
		draw_circle(pos, r, _g(Color(0.75, 0.2, 0.05, a * 0.8)))
		draw_circle(pos, r * 0.75, _g(Color(1.0, 0.5, 0.1, a * 0.9)))
		if t < 0.6:
			draw_circle(pos, r * 0.45, _g(Color(1.0, 0.9, 0.5, a)))
	# Burning ground fire after the fireball.
	if _t > 0.4:
		for k in 5:
			var flick := 0.6 + 0.4 * sin(_t * 13.0 + k * 2.1)
			var x := -14.0 + k * 7.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 0), Vector2(x + 4, 0),
					Vector2(x + sin(_t * 9.0 + k) * 2.0, -9.0 * flick - 3.0)]), _g(Color(1.0, 0.55, 0.1, 0.85)))


func _draw_dust() -> void:
	# Brown dust kicked up along the ground, spreading forward and fading.
	var t := clampf(_t / 1.8, 0.0, 1.0)
	for k in 9:
		var x := -10.0 + k * 9.0 * (0.3 + t)
		var r := (5.0 + k % 3 * 2.0) * (0.5 + t)
		draw_circle(Vector2(x, -r * 0.5), r, Color(0.55, 0.47, 0.36, 0.55 * (1.0 - t)))


func _draw_sparks() -> void:
	for s in _sparks:
		var life: float = s[2]
		if _t > life:
			continue
		var v: Vector2 = s[0]
		var p := v * _t + Vector2(0, 0.5 * 200.0 * _t * _t)
		if p.y > 0.0:
			continue
		var f := _t / life
		var col := _g(Color(1.0, 0.9 - 0.5 * f, 0.4 - 0.3 * f, 1.0 - f))
		draw_line(p, p - v.normalized() * (2.0 + s[1] * 2.0), col, s[1])


func _draw_smoke() -> void:
	if _t < 0.3:
		return
	# Thick black column for a big crash, thin grey wisp for a small one.
	var thick := _big()
	var count := smoke_puffs if thick else 7
	for i in count:
		var age := fmod(_t * (0.5 if thick else 0.7) + float(i) / count, 1.0)
		var pos := Vector2(4 + age * 30 + sin(i * 1.7) * 4, -6 - age * (100.0 if thick else 50.0))
		var shade := 0.14 if thick else 0.45
		var col := Color(shade, shade, shade + 0.02, (0.75 if thick else 0.35) * (1.0 - age))
		draw_circle(pos.round(), (5 + age * 12) if thick else (3 + age * 6), col)
