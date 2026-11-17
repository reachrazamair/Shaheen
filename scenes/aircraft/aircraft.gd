class_name Aircraft
extends Node2D
## The player's aircraft.
## Physics runs in metres: pos_m.x = distance along the route, pos_m.y = altitude.
## The node's pixel position is derived from pos_m every physics tick.
## Node origin = the point where the wheels touch the ground; the nose points +x.
##
## Chunk 1.2: ground roll only (throttle, drag, rolling friction, wheel brakes).
## Lift, pitch and stall come in chunk 1.3; engine, flaps, gear, fuel in 1.4.

@export var data: AircraftData

@export_group("Controls")
## Throttle lever travel per second while W/S is held (0.6 = idle to full in ~1.7 s).
@export var throttle_rate := 0.6

var throttle := 0.0                ## 0..1
var velocity_m := Vector2.ZERO     ## m/s; x forward, y up
var pos_m := Vector2.ZERO          ## m; x along route, y altitude
var on_ground := true
var braking := false

var speed_kt: float:
	get: return velocity_m.length() * WorldScale.MS_TO_KT


func _ready() -> void:
	assert(data != null, "Aircraft needs an AircraftData resource")
	_sync_position()
	queue_redraw()


func place_at(x_m: float) -> void:
	pos_m = Vector2(x_m, 0.0)
	velocity_m = Vector2.ZERO
	_sync_position()


func _physics_process(delta: float) -> void:
	_read_controls(delta)
	if on_ground:
		_simulate_ground(delta)
	pos_m += velocity_m * delta
	_sync_position()


func _read_controls(delta: float) -> void:
	if Input.is_action_pressed("throttle_up"):
		throttle += throttle_rate * delta
	if Input.is_action_pressed("throttle_down"):
		throttle -= throttle_rate * delta
	throttle = clampf(throttle, 0.0, 1.0)
	braking = Input.is_action_pressed("brake")


func _simulate_ground(delta: float) -> void:
	var v := velocity_m.x
	var thrust := data.max_thrust_n * throttle
	var drag := data.drag_coefficient * v * v
	v += (thrust - drag) / data.mass_kg * delta

	# Friction and brakes only ever slow the plane down; they never push it backwards.
	var resist_g := data.rolling_friction
	if braking:
		resist_g += data.brake_strength
	var dv := resist_g * WorldScale.GRAVITY * delta
	v = 0.0 if v <= dv else v - dv

	velocity_m = Vector2(v, 0.0)
	pos_m.y = 0.0


func _sync_position() -> void:
	position = Vector2(pos_m.x, -pos_m.y) * WorldScale.PX_PER_M


# --- Placeholder drawing (replaced by data.sprite when real art exists) ---

func _draw() -> void:
	if data == null:
		return
	var l := data.length_m * WorldScale.PX_PER_M
	var h := data.height_m * WorldScale.PX_PER_M
	if data.sprite:
		var size := data.sprite.get_size()
		var s := l / size.x
		draw_set_transform(Vector2(-l * 0.5, -size.y * s), 0.0, Vector2(s, s))
		draw_texture(data.sprite, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
		return
	_draw_placeholder(l, h)


func _draw_placeholder(l: float, h: float) -> void:
	var p := func(fx: float, fy: float) -> Vector2: return Vector2(fx * l, -fy * h)
	var dark := Color(0.15, 0.15, 0.18)

	# Landing gear: legs + wheels (main gear behind centre, nose gear forward).
	for gx in [-0.05, 0.36]:
		draw_line(p.call(gx, 0.15), p.call(gx, 0.4), dark, 1.0)
		draw_rect(Rect2(p.call(gx, 0.0) + Vector2(-1.5, -3.0), Vector2(3, 3)), dark)

	# Fuselage.
	draw_colored_polygon(PackedVector2Array([
		p.call(0.50, 0.55), p.call(0.42, 0.38), p.call(-0.20, 0.38),
		p.call(-0.50, 0.62), p.call(-0.50, 0.72), p.call(0.25, 0.80),
		p.call(0.45, 0.72),
	]), data.body_color)
	# Livery stripes along the fuselage.
	draw_line(p.call(-0.48, 0.60), p.call(0.46, 0.50), data.stripe_color, 1.0)
	draw_line(p.call(-0.46, 0.55), p.call(0.44, 0.45), data.trim_color, 1.0)
	# Tail fin with a red leading band.
	draw_colored_polygon(PackedVector2Array([
		p.call(-0.50, 0.70), p.call(-0.47, 1.05), p.call(-0.38, 1.05),
		p.call(-0.28, 0.74),
	]), data.body_color)
	draw_line(p.call(-0.47, 1.0), p.call(-0.49, 0.72), data.stripe_color, 2.0)
	# Canopy and high wing.
	draw_colored_polygon(PackedVector2Array([
		p.call(0.02, 0.78), p.call(0.30, 0.79), p.call(0.20, 0.97), p.call(0.04, 0.97),
	]), Color(0.55, 0.78, 0.92))
	draw_rect(Rect2(p.call(-0.12, 1.02), Vector2(0.42 * l, 2)), data.stripe_color)
	# Propeller blur.
	draw_line(p.call(0.52, 0.85), p.call(0.52, 0.25), Color(0.4, 0.4, 0.45, 0.8), 1.0)
