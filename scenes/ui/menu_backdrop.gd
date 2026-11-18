extends Control
## Start-screen background: a PAF airfield at golden hour.
##  - Static (drawn once): warm sky, low sun with glow, layered mountains and
##    hills, tree line, control tower, hardened shelters with parked JF-17 and
##    F-16, a K-8 on the apron, runway with edge lights, grass.
##  - Animated (redrawn each frame, cheap): drifting clouds, a waving Pakistan
##    flag, and every few seconds a three-ship formation (Mirage lead, two
##    F-16s) crossing the top of the screen trailing contrails.
## Layout is in the 640x360 base resolution; the ground line is GROUND_Y.

const GROUND_Y := 318.0

@export var formation_period_s := 9.0
@export var formation_speed := 150.0

var _static: Control
var _parked: Control
var _anim: Control
var _time := 0.0
var _clouds: Array = []   # [position, scale, speed]

var _tex_jf17: Texture2D = preload("res://assets/sprites/jf17_front_body.png")
var _tex_f16_front: Texture2D = preload("res://assets/sprites/f16_front_body.png")
var _tex_k8: Texture2D = preload("res://assets/sprites/k8_front_body.png")
var _tex_f16: Texture2D = preload("res://assets/sprites/f16_body.png")
var _tex_mirage: Texture2D = preload("res://assets/sprites/mirage5_body.png")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static = _layer(_draw_static)
	_parked = _layer(_draw_parked)
	_anim = _layer(_draw_anim)
	_parked.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for i in 6:
		# One open lane of sky above the title, so clouds never pass behind the
		# UI (the start screen's steps fill the space under the title).
		var lane_y := 13.0
		_clouds.append([Vector2(rng.randf_range(0, 640), lane_y + rng.randf_range(-2, 2)), rng.randf_range(0.45, 0.65), rng.randf_range(4, 9)])


func _layer(callback: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	c.draw.connect(callback)
	return c


func _process(delta: float) -> void:
	_time += delta
	for c in _clouds:
		c[0].x -= c[2] * delta
		if c[0].x < -70:
			c[0].x = 710
	_anim.queue_redraw()


# --- Static scene ---

func _draw_static() -> void:
	var s := _static
	# Sky: deep blue at the top to warm gold at the horizon.
	var bands := 48
	for i in bands:
		var f := float(i) / bands
		var col := Color(0.2, 0.38, 0.68).lerp(Color(0.55, 0.7, 0.88), clampf(f * 1.6, 0.0, 1.0))
		if f > 0.55:
			col = col.lerp(Color(1.0, 0.8, 0.58), (f - 0.55) / 0.45)
		s.draw_rect(Rect2(0, floorf(f * GROUND_Y), 640, ceilf(GROUND_Y / bands) + 1), col)
	# Low sun with glow.
	var sun := Vector2(560, 262)
	for k in 5:
		s.draw_circle(sun, 70.0 - k * 12.0, Color(1.0, 0.85, 0.55, 0.1 + k * 0.04))
	s.draw_circle(sun, 16, Color(1.0, 0.95, 0.8))
	# Far mountains, then nearer hills.
	s.draw_colored_polygon(_ridge(300.0, 62.0, [[3, 0.4, 1.0], [7, 1.9, 0.45], [13, 0.7, 0.2]]), Color(0.6, 0.6, 0.72))
	s.draw_colored_polygon(_ridge(306.0, 30.0, [[5, 2.2, 1.0], [11, 0.3, 0.4]]), Color(0.52, 0.56, 0.5))
	# Tree line.
	var x := -4.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	while x < 650:
		var r := rng.randf_range(3.5, 7.0)
		s.draw_circle(Vector2(x, GROUND_Y - r * 0.8), r, Color(0.27, 0.38, 0.22).lerp(Color(0.36, 0.46, 0.26), rng.randf()))
		x += r * rng.randf_range(1.0, 1.8)
	# Control tower.
	var tx := 26.0
	s.draw_rect(Rect2(tx - 3, GROUND_Y - 58, 6, 58), Color(0.86, 0.82, 0.72))
	s.draw_rect(Rect2(tx - 10, GROUND_Y - 70, 20, 12), Color(0.86, 0.82, 0.72))
	s.draw_rect(Rect2(tx - 8, GROUND_Y - 68, 16, 7), Color(0.45, 0.7, 0.78))
	s.draw_rect(Rect2(tx - 12, GROUND_Y - 72, 24, 3), Color(0.4, 0.38, 0.36))
	s.draw_rect(Rect2(tx - 0.5, GROUND_Y - 82, 1, 10), Color(0.3, 0.3, 0.32))
	s.draw_rect(Rect2(tx - 1, GROUND_Y - 83, 2, 2), Color(1, 0.25, 0.2))
	# Flag pole (the flag itself waves on the animated layer).
	s.draw_rect(Rect2(52, GROUND_Y - 60, 1, 60), Color(0.75, 0.75, 0.78))
	# Hardened aircraft shelters (aircraft drawn on the parked layer).
	for cx in [96.0, 156.0]:
		_shelter(s, cx)
	# Runway with markings and edge lights, then grass.
	s.draw_rect(Rect2(0, GROUND_Y, 640, 5), Color(0.33, 0.33, 0.36))
	for dx in range(220, 640, 34):
		s.draw_rect(Rect2(dx, GROUND_Y + 2, 16, 1), Color(0.9, 0.9, 0.86))
	for lx in range(214, 640, 24):
		s.draw_rect(Rect2(lx, GROUND_Y - 2, 1, 2), Color(0.25, 0.25, 0.25))
		s.draw_rect(Rect2(lx, GROUND_Y - 3, 1, 1), Color(1.0, 0.85, 0.35))
	s.draw_rect(Rect2(0, GROUND_Y + 5, 640, 360 - GROUND_Y - 5), Color(0.42, 0.6, 0.3))


func _ridge(base_y: float, amp: float, waves: Array) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, GROUND_Y)])
	for i in 81:
		var x := 640.0 * i / 80.0
		var h := 0.0
		for w in waves:
			h += sin(x / 640.0 * TAU * w[0] + w[1]) * w[2]
		pts.append(Vector2(x, base_y - (h * 0.4 + 0.6) * amp))
	pts.append(Vector2(640, GROUND_Y))
	return pts


func _shelter(s: Control, cx: float) -> void:
	var w := 54.0
	var h := 28.0
	s.draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.5 - 8, GROUND_Y), Vector2(cx - w * 0.5, GROUND_Y - h * 0.7), Vector2(cx - w * 0.5, GROUND_Y)]), Color(0.44, 0.52, 0.32))
	s.draw_colored_polygon(PackedVector2Array([Vector2(cx + w * 0.5, GROUND_Y), Vector2(cx + w * 0.5, GROUND_Y - h * 0.7), Vector2(cx + w * 0.5 + 8, GROUND_Y)]), Color(0.44, 0.52, 0.32))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		outer.append(Vector2(cx - cos(a) * w * 0.5, GROUND_Y - sin(a) * h))
		inner.append(Vector2(cx - cos(a) * (w * 0.5 - 4), GROUND_Y - sin(a) * (h - 4)))
	s.draw_colored_polygon(outer, Color(0.68, 0.66, 0.6))
	s.draw_polyline(outer, Color(0.3, 0.3, 0.32), 1.0)
	s.draw_colored_polygon(inner, Color(0.17, 0.17, 0.19))


# --- Parked aircraft (smooth filtering) ---

func _draw_parked() -> void:
	_front(_tex_jf17, 96.0, 0.24, Color(0.75, 0.75, 0.78))
	_front(_tex_f16_front, 156.0, 0.24, Color(0.75, 0.75, 0.78))
	_front(_tex_k8, 205.0, 0.24, Color.WHITE)


func _front(tex: Texture2D, cx: float, sc: float, tint: Color) -> void:
	var size := tex.get_size() * sc
	_parked.draw_rect(Rect2(cx - size.x * 0.35, GROUND_Y - 1, size.x * 0.7, 1), Color(0, 0, 0, 0.25))
	_parked.draw_texture_rect(tex, Rect2(cx - size.x * 0.5, GROUND_Y - size.y, size.x, size.y), false, tint)


# --- Animated layer ---

func _draw_anim() -> void:
	var a := _anim
	# Clouds.
	for c in _clouds:
		var p: Vector2 = c[0]
		var k: float = c[1]
		for j in 4:
			a.draw_circle(p + Vector2(j * 11.0 * k, -sin(j * 1.3 + 0.5) * 4.0 * k), (8.0 + (j % 2) * 3.0) * k, Color(1, 1, 1, 0.75))
		a.draw_rect(Rect2(p.x - 6 * k, p.y, 46 * k, 4 * k), Color(1, 1, 1, 0.75))
	# Pakistan flag waving at the top of the pole.
	_flag(a, Vector2(53, GROUND_Y - 60))
	# Formation flypast across the top of the screen.
	var t := fmod(_time, formation_period_s)
	var lead_x := -60.0 + t * formation_speed
	if lead_x < 760.0:
		var jets := [[_tex_mirage, Vector2(lead_x, 2)], [_tex_f16, Vector2(lead_x - 30, 7)], [_tex_f16, Vector2(lead_x - 60, 12)]]
		for j in jets:
			_jet(a, j[0], j[1])


func _flag(a: Control, top: Vector2) -> void:
	var w := 24
	var h := 16.0
	for col in w:
		var wave := sin(_time * 5.0 - col * 0.45) * (col / float(w)) * 2.0
		var x := top.x + col
		var color := Color.WHITE if col < 6 else Color(0.0, 0.36, 0.2)
		a.draw_rect(Rect2(x, top.y + wave, 1, h), color)
	# Crescent and star (rough, at this size), riding the wave.
	var cx := top.x + 15.0
	var wy := sin(_time * 5.0 - 15 * 0.45) * (15.0 / w) * 2.0
	var c := Vector2(cx, top.y + h * 0.5 + wy)
	a.draw_circle(c, 4.5, Color.WHITE)
	a.draw_circle(c + Vector2(1.6, -1.2), 4.0, Color(0.0, 0.36, 0.2))
	a.draw_circle(c + Vector2(3.2, -2.6), 1.2, Color.WHITE)


func _jet(a: Control, tex: Texture2D, nose_pos: Vector2) -> void:
	var sc := 0.07
	var size := tex.get_size() * sc
	var tail := nose_pos - Vector2(size.x, 0)
	# Contrail: a fading white line streaming back from the tail.
	var trail_y := tail.y + size.y * 0.5
	for k in 10:
		var x0 := tail.x - k * 14.0
		a.draw_rect(Rect2(x0 - 14, trail_y - 1, 14, 2), Color(1, 1, 1, 0.55 * (1.0 - k / 10.0)))
	a.draw_texture_rect(tex, Rect2(tail.x, nose_pos.y, size.x, size.y), false)
