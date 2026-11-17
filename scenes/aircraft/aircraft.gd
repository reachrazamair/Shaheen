class_name Aircraft
extends Node2D
## The player's aircraft: a small custom 2D flight model (no RigidBody).
## Physics runs in metres: pos_m.x = distance along the route, pos_m.y = altitude.
## The node's pixel position/rotation are derived from the state every physics tick.
## Node origin = the point where the wheels touch the ground; the nose points +x.
##
## Forces each tick: thrust (along the nose), lift (perpendicular to the flight
## path), drag (against the flight path), gravity, and on the ground: normal
## force, rolling friction and brakes.
##
## Lift model: lift = weight * (speed / stall_speed)^2 * cl * (1 + flap bonus),
## where cl is the fraction of max lift for the current angle of attack
## (aoa = nose vs flight path). cl rises with aoa up to 1.0 at stall_aoa, then
## collapses (stall). Faster means more lift at the same pitch, so it climbs.
##
## Systems (chunk 1.4): engine start/stop with spool-up, fuel burn, flaps
## (UP/TO/LDG), landing gear (fixed or retractable), air brake (B in the air).
## Crash and landing grading come in chunk 1.7.

signal touched_down(vertical_speed_ms: float)
signal lifted_off

const FLAP_NAMES := ["UP", "TO", "LDG"]

@export var data: AircraftData

@export_group("Controls")
## Throttle lever travel per second while the key is held (1.6 = idle to full in ~0.6 s).
@export var throttle_rate := 1.6
## Start the flight with the engine already running (handy for testing).
@export var start_with_engine_on := false

# Flight state
var throttle := 0.0                ## 0..1 lever position
var velocity_m := Vector2.ZERO     ## m/s; x forward, y up
var pos_m := Vector2.ZERO          ## m; x along route, y altitude
var pitch := 0.0                   ## rad, nose up positive
var pitch_rate := 0.0              ## rad/s, current (smoothed)
var aoa := 0.0                     ## rad, angle of attack
var on_ground := true
var braking := false
var stalled := false
var lift_ratio := 0.0              ## lift / weight, for debugging and tuning

# Systems state
var engine_on := false             ## switch position
var engine_rpm := 0.0              ## 0..1, spools toward 1 when on, 0 when off
var fuel_kg := 0.0
var flap_setting := 0              ## target: 0 UP, 1 TO, 2 LDG
var flap_pos := 0.0                ## actual, moves toward flap_setting
var gear_down := true              ## target
var gear_pos := 1.0                ## actual: 1 down and locked, 0 up

var _stall_timer := 0.0

var speed_kt: float:
	get: return velocity_m.length() * WorldScale.MS_TO_KT
var altitude_ft: float:
	get: return pos_m.y * WorldScale.M_TO_FT
var vertical_speed_fpm: float:
	get: return velocity_m.y * WorldScale.M_TO_FT * 60.0
var fuel_fraction: float:
	get: return fuel_kg / data.fuel_capacity_kg
var low_fuel: bool:
	get: return fuel_fraction < data.low_fuel_fraction
var gear_in_transit: bool:
	get: return gear_pos > 0.0 and gear_pos < 1.0
var airbrake_out: bool:
	get: return braking and not on_ground


func _ready() -> void:
	assert(data != null, "Aircraft needs an AircraftData resource")
	reset_state()
	queue_redraw()


func place_at(x_m: float) -> void:
	reset_state()
	pos_m = Vector2(x_m, 0.0)
	_sync_node()


func reset_state() -> void:
	pos_m = Vector2.ZERO
	velocity_m = Vector2.ZERO
	pitch = 0.0
	pitch_rate = 0.0
	throttle = 0.0
	on_ground = true
	stalled = false
	fuel_kg = data.fuel_capacity_kg
	engine_on = start_with_engine_on
	engine_rpm = 1.0 if start_with_engine_on else 0.0
	flap_setting = 0
	flap_pos = 0.0
	gear_down = true
	gear_pos = 1.0
	_sync_node()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("engine_toggle"):
		engine_on = not engine_on and fuel_kg > 0.0
	elif event.is_action_pressed("flaps_cycle"):
		flap_setting = (flap_setting + 1) % FLAP_NAMES.size()
	elif event.is_action_pressed("gear_toggle"):
		# Fixed gear can't move; retractable gear can't come up on the ground.
		if data.retractable_gear and not (on_ground and gear_down):
			gear_down = not gear_down


func _physics_process(delta: float) -> void:
	_stall_timer = maxf(0.0, _stall_timer - delta)
	_read_controls(delta)
	_update_systems(delta)
	_update_pitch(delta)
	_integrate(delta)
	_sync_node()
	queue_redraw()


func _read_controls(delta: float) -> void:
	throttle += Input.get_axis("throttle_down", "throttle_up") * throttle_rate * delta
	throttle = clampf(throttle, 0.0, 1.0)
	braking = Input.is_action_pressed("brake")


func _update_systems(delta: float) -> void:
	# Engine spool and fuel.
	var spool := delta / maxf(data.engine_spool_time_s, 0.01)
	engine_rpm = move_toward(engine_rpm, 1.0 if engine_on else 0.0, spool)
	if engine_rpm > 0.0:
		var burn := data.fuel_burn_full_kg_s * lerpf(data.idle_burn_fraction, 1.0, throttle)
		fuel_kg = maxf(0.0, fuel_kg - burn * engine_rpm * delta)
		if fuel_kg <= 0.0:
			engine_on = false   # flamed out: glide from here

	# Flaps move one step per flap_move_time_s.
	flap_pos = move_toward(flap_pos, float(flap_setting), delta / maxf(data.flap_move_time_s, 0.01))

	# Gear.
	if not data.retractable_gear:
		gear_down = true
		gear_pos = 1.0
	else:
		gear_pos = move_toward(gear_pos, 1.0 if gear_down else 0.0, delta / maxf(data.gear_transit_time_s, 0.01))


func _update_pitch(delta: float) -> void:
	var speed := velocity_m.length()
	var rotate_ms := data.rotate_speed_kt / WorldScale.MS_TO_KT
	# Controls are weak at low speed and fully effective from rotate speed upward.
	var authority := clampf(speed / rotate_ms, 0.25, 1.0)
	var target_rate := Input.get_axis("pitch_down", "pitch_up") \
			* deg_to_rad(data.pitch_rate_deg_s) * authority
	pitch_rate = move_toward(pitch_rate, target_rate, deg_to_rad(data.pitch_accel_deg_s2) * delta)
	if stalled:
		# The nose drops on its own; the player can push it down faster but not hold it up.
		pitch_rate = minf(pitch_rate, -deg_to_rad(data.stall_nose_drop_deg_s))
	pitch += pitch_rate * delta

	if on_ground:
		# Nose wheel stays down below rotate speed; above it the nose may rise to the tail-strike limit.
		var upper := deg_to_rad(data.max_ground_pitch_deg) if speed >= rotate_ms else 0.0
		if pitch > upper:
			pitch = maxf(upper, pitch - deg_to_rad(data.pitch_rate_deg_s) * delta)
		if pitch < 0.0:
			pitch = 0.0
			pitch_rate = maxf(pitch_rate, 0.0)
	else:
		pitch = clampf(pitch, -deg_to_rad(data.max_pitch_down_deg), deg_to_rad(data.max_pitch_up_deg))


func _integrate(delta: float) -> void:
	var g := WorldScale.GRAVITY
	var weight := data.mass_kg * g
	var speed := velocity_m.length()
	var nose := Vector2(cos(pitch), sin(pitch))
	var path := velocity_m / speed if speed > 0.5 else nose

	aoa = wrapf(pitch - atan2(path.y, path.x), -PI, PI)
	var cl := _lift_fraction(aoa) * (1.0 + _flap_value(data.flap_lift_bonus))
	var vs := data.stall_speed_kt / WorldScale.MS_TO_KT
	var lift_mag := weight * (speed / vs) * (speed / vs) * cl
	lift_ratio = lift_mag / weight

	var drag_mult := 1.0 + data.induced_drag * cl * cl + _flap_value(data.flap_drag) \
			+ data.gear_drag * gear_pos + (data.airbrake_drag if airbrake_out else 0.0)
	var lift := Vector2(-path.y, path.x) * lift_mag
	var drag := -path * data.drag_coefficient * speed * speed * drag_mult
	var thrust := nose * _thrust(speed)
	var force := lift + drag + thrust + Vector2(0.0, -weight)
	# Arcade speed response: amplify only the along-path part of the net force.
	# Equilibria (top speed, steady climb) are unchanged; speed just gets there faster.
	force += path * force.dot(path) * (data.speed_response - 1.0)

	if on_ground:
		if force.y > 0.0:
			on_ground = false
			lifted_off.emit()
		else:
			# Ground pushes back; friction and brakes scale with weight on the wheels.
			var normal := -force.y
			force.y = 0.0
			var v := velocity_m.x + force.x / data.mass_kg * delta
			var resist := data.rolling_friction + (data.brake_strength if braking else 0.0)
			var dv := resist * normal / data.mass_kg * delta
			v = 0.0 if v <= dv else v - dv
			velocity_m = Vector2(v, 0.0)
			pos_m.x += v * delta
			pos_m.y = 0.0
			return

	velocity_m += force / data.mass_kg * delta
	pos_m += velocity_m * delta

	if pos_m.y <= 0.0:
		# Touchdown. (Crash, gear-up landing and grading: chunk 1.7.)
		var vy := velocity_m.y
		pos_m.y = 0.0
		velocity_m.y = 0.0
		on_ground = true
		stalled = false
		if pitch < 0.0:
			pitch = 0.0
		touched_down.emit(vy)


## Fraction of max lift for a given angle of attack; also updates the stall state.
func _lift_fraction(a: float) -> float:
	var stall_a := deg_to_rad(data.stall_aoa_deg)
	if on_ground:
		stalled = false
	elif a > stall_a:
		if not stalled:
			_stall_timer = data.min_stall_time_s
		stalled = true
	elif stalled and _stall_timer <= 0.0 and a < stall_a - deg_to_rad(3.0):
		stalled = false   # recovers only after the minimum stall time and some hysteresis

	if a <= stall_a:
		var cl := data.zero_aoa_lift + (1.0 - data.zero_aoa_lift) * a / stall_a
		return maxf(cl, -0.6)
	# Past the stall angle lift collapses over ~5 degrees.
	var t := clampf((a - stall_a) / deg_to_rad(5.0), 0.0, 1.0)
	return lerpf(1.0, data.post_stall_lift, t)


## Interpolates a per-flap-setting array at the current (moving) flap position.
func _flap_value(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var i := clampi(floori(flap_pos), 0, values.size() - 1)
	var j := mini(i + 1, values.size() - 1)
	return lerpf(values[i], values[j], flap_pos - i)


func _thrust(speed: float) -> float:
	var t := data.max_thrust_n * throttle * engine_rpm
	if data.thrust_zero_speed_kt > 0.0:
		t *= maxf(0.0, 1.0 - speed * WorldScale.MS_TO_KT / data.thrust_zero_speed_kt)
	# Soft ceiling: thin air takes the thrust away.
	t *= clampf(1.0 - (pos_m.y - data.service_ceiling_m) / data.ceiling_fade_m, 0.0, 1.0)
	return t


func _sync_node() -> void:
	position = Vector2(pos_m.x, -pos_m.y) * WorldScale.PX_PER_M
	rotation = -pitch


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

	# Landing gear: legs + wheels, retracting up into the fuselage with gear_pos.
	if gear_pos > 0.05:
		var drop := lerpf(0.4, 0.0, gear_pos)   # wheels rise as the gear comes up
		for gx in [-0.05, 0.36]:
			draw_line(p.call(gx, 0.15 + drop), p.call(gx, 0.4), dark, 1.0)
			draw_rect(Rect2(p.call(gx, drop) + Vector2(-1.5, -3.0), Vector2(3, 3)), dark)

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
	# Canopy and high wing, with flaps hanging down from the wing's trailing edge.
	draw_colored_polygon(PackedVector2Array([
		p.call(0.02, 0.78), p.call(0.30, 0.79), p.call(0.20, 0.97), p.call(0.04, 0.97),
	]), Color(0.55, 0.78, 0.92))
	draw_rect(Rect2(p.call(-0.12, 1.02), Vector2(0.42 * l, 2)), data.stripe_color)
	if flap_pos > 0.05:
		draw_line(p.call(-0.12, 0.98), p.call(-0.12 - 0.06 * flap_pos, 0.98 - 0.12 * flap_pos), data.stripe_color, 1.0)
	# Propeller: blurred disc when running, a still blade when stopped.
	if engine_rpm > 0.3:
		draw_line(p.call(0.52, 0.85), p.call(0.52, 0.25), Color(0.4, 0.4, 0.45, 0.4 + 0.4 * engine_rpm), 1.0)
	else:
		draw_line(p.call(0.52, 0.70), p.call(0.52, 0.40), dark, 1.0)
