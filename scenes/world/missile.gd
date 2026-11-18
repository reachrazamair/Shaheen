class_name Missile
extends Bomb
## Air-to-ground missile (AGM-88 HARM on the F-16D). After release it drops
## clear of the jet for drop_s, then its rocket motor lights (flame out of the
## back, smoke trail) and burns for burn_s, accelerating to speed_ms. It steers
## (turn rate limited) at a point above its target while far away, so it
## climbs a little first, then dives onto the target: a missile-like path.
## guide_x (from Bomb) = the target's x; it goes off when it reaches the ground.

var drop_s := 0.35
var burn_s := 8.0
var speed_ms := 420.0
var accel := 140.0
var turn_deg_s := 35.0
var loft := 0.25
var loft_max_m := 250.0
## Smoke trail: how many points are kept and how often one is added.
@export var trail_points := 40
@export var trail_step_s := 0.04

var _t := 0.0
var _trail := PackedVector2Array()   # world px
var _trail_timer := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < drop_s or is_nan(guide_x):
		# Falling clear of the pylon (or no target: flies on like a dumb rocket).
		vel_m = step(vel_m, drag, delta)
		if _t >= drop_s:
			vel_m += vel_m.normalized() * accel * delta * (1.0 if _t < drop_s + burn_s else 0.0)
	else:
		var dist := guide_x - pos_m.x
		var aim := Vector2(guide_x, clampf(dist * loft, 0.0, loft_max_m))
		var want := (aim - pos_m).angle()
		var heading := vel_m.angle()
		heading = rotate_toward(heading, want, deg_to_rad(turn_deg_s) * delta)
		var speed := vel_m.length()
		if _t < drop_s + burn_s:
			speed = minf(speed + accel * delta, speed_ms)
		vel_m = Vector2.from_angle(heading) * speed
	pos_m += vel_m * delta
	if motor_on():
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = trail_step_s
			_trail.append(Vector2(pos_m.x, -pos_m.y) * WorldScale.PX_PER_M)
			if _trail.size() > trail_points:
				_trail.remove_at(0)
	if pos_m.y <= 0.0:
		impacted.emit(pos_m.x)
		queue_free()
		return
	_sync()
	queue_redraw()


func motor_on() -> bool:
	return _t >= drop_s and _t < drop_s + burn_s


func _draw() -> void:
	# Smoke trail (world points to local), fading toward the old end.
	var n := _trail.size()
	for i in range(1, n):
		var a := to_local(_trail[i - 1])
		var b := to_local(_trail[i])
		var f := float(i) / n
		draw_line(a, b, Color(0.85, 0.85, 0.82, 0.5 * f), 1.0 + 2.0 * (1.0 - f))
	super._draw()
	if motor_on() and texture:
		# Rocket flame out of the nozzle (the tail is at -x).
		var sz := texture.get_size() * draw_scale
		var tail := Vector2(-sz.x * 0.5, 0)
		var flick := 0.8 + 0.2 * sin(_t * 60.0) + 0.1 * sin(_t * 137.0)
		var l := sz.y * 1.6 * flick
		var h := sz.y * 0.22
		draw_colored_polygon(PackedVector2Array([tail + Vector2(0, -h), tail + Vector2(-l, 0), tail + Vector2(0, h)]),
				GameState.glow(Color(1.0, 0.55, 0.15, 0.85)))
		draw_colored_polygon(PackedVector2Array([tail + Vector2(0, -h * 0.5), tail + Vector2(-l * 0.55, 0), tail + Vector2(0, h * 0.5)]),
				GameState.glow(Color(1.0, 0.95, 0.7, 1.0)))
