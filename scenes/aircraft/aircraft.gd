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
## Crash severity (0..1) from which a crash is "big": explosion, shards blasted out.
const BIG_CRASH_SEVERITY := 0.6

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
## F steps the flaps one notch in this direction and reverses at the ends:
## TO -> UP (after takeoff) -> TO -> LDG (approach) -> TO -> UP ...
var flap_direction := -1
var flap_pos := 0.0                ## actual, moves toward flap_setting
var gear_down := true              ## target
var gear_pos := 1.0                ## actual: 1 down and locked, 0 up

## False once the flight is over (crash or result screen): input is ignored.
var controls_enabled := true
var crashed := false
## Pitch at the last touchdown, before the ground levels the nose.
var touchdown_pitch := 0.0

var _stall_timer := 0.0
var _prop_angle := 0.0
## Elevator/tailplane deflection, -1 (nose-down) .. 1 (nose-up), follows the stick.
var elevator := 0.0
## G felt by the pilot (along the seat axis, 1 = level flight), smoothed.
var g_load := 1.0
## 0..1 screen effects driven by g_load (see AircraftData "Pilot G effects").
var blackout := 0.0
var redout := 0.0
var _prev_vel := Vector2.ZERO
var _time := 0.0
## Wreckage shards after a crash: {poly (texture px around the shard centre), uvs, pos, vel, rot, spin, tint, resting}
var _fragments: Array = []
## Node transform at the previous and latest physics tick. Each rendered frame
## draws the aircraft between the two, so fast jets move smoothly even when the
## screen refreshes faster than the 60 Hz physics.
var _prev_px := Vector2.ZERO
var _prev_rot := 0.0
var _cur_px := Vector2.ZERO
var _cur_rot := 0.0

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
## 0..1: how far into the afterburner range the throttle is (0 if none / engine not up).
var afterburner: float:
	get:
		if data.afterburner_thrust_n <= 0.0 or engine_rpm < 0.95:
			return 0.0
		return clampf((throttle - data.afterburner_threshold) / (1.0 - data.afterburner_threshold), 0.0, 1.0)


func _ready() -> void:
	assert(data != null, "Aircraft needs an AircraftData resource")
	# Runs before the camera (-5) and scenery (0) each frame.
	process_priority = -10
	reset_state()
	queue_redraw()


## Swap in another aircraft's data (aircraft select) and reset.
func set_data(d: AircraftData) -> void:
	data = d
	reset_state()
	queue_redraw()


func place_at(x_m: float) -> void:
	reset_state()
	pos_m = Vector2(x_m, 0.0)
	_sync_node(true)


func reset_state() -> void:
	crashed = false
	controls_enabled = true
	_fragments.clear()
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
	flap_setting = data.default_flap_setting
	flap_pos = float(flap_setting)
	flap_direction = -1
	gear_down = true
	gear_pos = 1.0
	g_load = 1.0
	blackout = 0.0
	redout = 0.0
	_prev_vel = Vector2.ZERO
	elevator = 0.0
	_sync_node(true)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event.is_action_pressed("engine_toggle"):
		engine_on = not engine_on and fuel_kg > 0.0
	elif event.is_action_pressed("flaps_cycle"):
		if flap_setting + flap_direction < 0 or flap_setting + flap_direction >= FLAP_NAMES.size():
			flap_direction = -flap_direction
		flap_setting += flap_direction
	elif event.is_action_pressed("gear_toggle"):
		# Fixed gear can't move; retractable gear can't come up on the ground.
		if data.retractable_gear and not (on_ground and gear_down):
			gear_down = not gear_down


func _physics_process(delta: float) -> void:
	_time += delta
	if crashed:
		_update_fragments(delta)
		queue_redraw()
		return
	_stall_timer = maxf(0.0, _stall_timer - delta)
	_prop_angle = fmod(_prop_angle + engine_rpm * 30.0 * delta, TAU)
	_read_controls(delta)
	_update_systems(delta)
	_update_pitch(delta)
	_integrate(delta)
	_update_g(delta)
	_sync_node()
	queue_redraw()


func _read_controls(delta: float) -> void:
	if not controls_enabled:
		throttle = move_toward(throttle, 0.0, throttle_rate * delta)
		braking = on_ground
		return
	throttle += Input.get_axis("throttle_down", "throttle_up") * throttle_rate * delta
	throttle = clampf(throttle, 0.0, 1.0)
	braking = Input.is_action_pressed("brake")


func _update_systems(delta: float) -> void:
	# Engine spool and fuel.
	var spool := delta / maxf(data.engine_spool_time_s, 0.01)
	engine_rpm = move_toward(engine_rpm, 1.0 if engine_on else 0.0, spool)
	if engine_rpm > 0.0:
		var burn := data.fuel_burn_full_kg_s * lerpf(data.idle_burn_fraction, 1.0, minf(throttle, 1.0))
		burn *= lerpf(1.0, data.afterburner_burn_multiplier, afterburner)
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
	var stick := Input.get_axis("pitch_down", "pitch_up") if controls_enabled else 0.0
	elevator = move_toward(elevator, stick, data.elevator_speed * delta)
	var target_rate := stick \
			* deg_to_rad(data.pitch_rate_deg_s) * authority
	pitch_rate = move_toward(pitch_rate, target_rate, deg_to_rad(data.pitch_accel_deg_s2) * delta)
	if stalled:
		# The nose drops on its own; the player can push it down faster but not hold it up.
		pitch_rate = minf(pitch_rate, -deg_to_rad(data.stall_nose_drop_deg_s))
	pitch += pitch_rate * delta

	if on_ground:
		# The nose wheel can start to lift from rotate_start_fraction x rotate speed;
		# the allowed nose-up grows to the tail-strike limit at rotate speed.
		var start := rotate_ms * data.rotate_start_fraction
		var allow := clampf((speed - start) / maxf(rotate_ms - start, 0.1), 0.0, 1.0)
		var upper := deg_to_rad(data.max_ground_pitch_deg) * allow
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
			+ data.gear_drag * gear_pos + (data.airbrake_drag if airbrake_out else 0.0) \
			+ (0.0 if on_ground else data.pitch_rate_drag * absf(rad_to_deg(pitch_rate)))
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
		touchdown_pitch = pitch
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
	var t: float
	if data.afterburner_thrust_n > 0.0:
		# Dry thrust up to the afterburner detent, then afterburner on top.
		t = data.max_thrust_n * clampf(throttle / data.afterburner_threshold, 0.0, 1.0) \
				+ data.afterburner_thrust_n * afterburner
		t *= engine_rpm
	else:
		t = data.max_thrust_n * throttle * engine_rpm
	if data.thrust_zero_speed_kt > 0.0:
		t *= maxf(0.0, 1.0 - speed * WorldScale.MS_TO_KT / data.thrust_zero_speed_kt)
	# Soft ceiling: thin air takes the thrust away.
	t *= clampf(1.0 - (pos_m.y - data.service_ceiling_m) / data.ceiling_fade_m, 0.0, 1.0)
	return t


## Wreck the aircraft: the airframe shatters into many small irregular shards.
## Small crash (severity < BIG_CRASH_SEVERITY): the shards scatter a little and scrape along
## the ground. Big crash: an explosion flings them outward. Engine off,
## controls dead. The flight scene adds fire/smoke and the result screen.
## severity: 0..1 (from impact sink rate and speed).
func crash(severity := 0.5) -> void:
	var impact_vel := velocity_m
	var crash_pitch := pitch
	crashed = true
	controls_enabled = false
	blackout = 0.0
	redout = 0.0
	engine_on = false
	engine_rpm = 0.0
	throttle = 0.0
	velocity_m = Vector2.ZERO
	pos_m.y = 0.0
	on_ground = true
	stalled = false
	gear_down = false
	gear_pos = 0.0
	pitch = 0.0
	_sync_node()
	if data.sprite:
		_build_fragments(severity, impact_vel, crash_pitch)
	queue_redraw()


func _build_fragments(severity: float, impact_vel: Vector2, crash_pitch: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var img := data.sprite.get_image()
	if img.is_compressed():
		img.decompress()
	var tex_size := data.sprite.get_size()
	var sc := data.sprite_scale
	var used := Rect2(img.get_used_rect())
	var big := severity >= BIG_CRASH_SEVERITY
	# Shatter grid: a lattice with jittered inner points, so cells are irregular.
	# Shard size ~ shard_px on screen (smaller and more pieces for a big crash).
	var shard_px := 5.0 if big else 7.0
	var cols := maxi(3, roundi(used.size.x * sc / shard_px))
	var rows := maxi(2, roundi(used.size.y * sc / shard_px))
	var cw := used.size.x / cols
	var ch := used.size.y / rows
	var lattice: Array = []
	for r in rows + 1:
		var row := PackedVector2Array()
		for c in cols + 1:
			var v := used.position + Vector2(c * cw, r * ch)
			if c > 0 and c < cols:
				v.x += rng.randf_range(-0.38, 0.38) * cw
			if r > 0 and r < rows:
				v.y += rng.randf_range(-0.38, 0.38) * ch
			row.append(v)
		lattice.append(row)

	var origin := Vector2(-tex_size.x * 0.5 * sc, -data.sprite_wheel_bottom_y * sc)
	var forward := Vector2(impact_vel.x, 0.0) * WorldScale.PX_PER_M * (0.3 if big else 0.45)
	var blast_centre := used.get_center()
	_fragments.clear()
	for r in rows:
		for c in cols:
			var a: Vector2 = lattice[r][c]
			var b: Vector2 = lattice[r][c + 1]
			var cc: Vector2 = lattice[r + 1][c + 1]
			var d: Vector2 = lattice[r + 1][c]
			# Each cell becomes one chunk or two triangles split along a random diagonal.
			var shapes: Array = []
			var roll := rng.randf()
			if roll < 0.35:
				shapes = [[a, b, cc, d]]
			elif roll < 0.7:
				shapes = [[a, b, cc], [a, cc, d]]
			else:
				shapes = [[a, b, d], [b, cc, d]]
			for s in shapes:
				_add_shard(s, img, tex_size, origin, crash_pitch, forward, blast_centre, big, severity, rng)


## One shard: a small polygon of the texture. Skipped if it covers only empty pixels.
func _add_shard(pts: Array, img: Image, tex_size: Vector2, origin: Vector2, crash_pitch: float,
		forward: Vector2, blast_centre: Vector2, big: bool, severity: float, rng: RandomNumberGenerator) -> void:
	var centre := Vector2.ZERO
	for v in pts:
		centre += v
	centre /= pts.size()
	var solid := 0
	for v in pts + [centre]:
		var s: Vector2 = (v as Vector2).lerp(centre, 0.4)
		var px := Vector2i(clampi(int(s.x), 0, img.get_width() - 1), clampi(int(s.y), 0, img.get_height() - 1))
		if img.get_pixelv(px).a > 0.3:
			solid += 1
	if solid < 2:
		return
	var local := PackedVector2Array()
	var uvs := PackedVector2Array()
	for v in pts:
		local.append(v - centre)
		uvs.append(v / tex_size)
	var vel := forward
	var spin := 0.0
	if big:
		# Explosion: shards blast away from the middle of the airframe.
		var out := (centre - blast_centre).normalized()
		if out == Vector2.ZERO:
			out = Vector2.UP
		out = (out + Vector2(0, -0.8)).normalized().rotated(rng.randf_range(-0.6, 0.6))
		vel += out * rng.randf_range(20.0, 75.0) * (0.5 + 0.5 * severity)
		spin = rng.randf_range(-10.0, 10.0)
	else:
		# Breaking up on the ground: shards scatter a little and scrape along.
		vel *= rng.randf_range(0.55, 1.15)
		vel += Vector2(rng.randf_range(-18.0, 18.0), -rng.randf_range(0.0, 28.0))
		spin = rng.randf_range(-5.0, 5.0)
	var shade := rng.randf_range(0.55, 0.9)   # some pieces scorched darker
	_fragments.append({
		"poly": local,
		"uvs": uvs,
		"pos": (origin + centre * data.sprite_scale).rotated(-crash_pitch),
		"vel": vel,
		"rot": -crash_pitch,
		"spin": spin,
		"tint": Color(shade, shade * 0.97, shade * 0.95),
		"resting": false,
	})


## Pieces fly, then hit the ground and slide to a stop: no bounce.
func _update_fragments(delta: float) -> void:
	var g := 220.0   # px/s^2
	var sc := data.sprite_scale
	for f in _fragments:
		if f.resting:
			continue
		var grounded := false
		# Lowest point of the piece at its current angle.
		var bottom := -INF
		for v in f.poly:
			bottom = maxf(bottom, (v * sc).rotated(f.rot).y)
		if f.pos.y + bottom >= -0.01:
			grounded = true
		if grounded:
			f.pos.y = -bottom
			f.vel.y = 0.0
			f.spin = 0.0
			f.vel.x = move_toward(f.vel.x, 0.0, 260.0 * delta)
			f.pos.x += f.vel.x * delta
			if is_zero_approx(f.vel.x):
				f.resting = true
		else:
			f.vel.y += g * delta
			f.pos += f.vel * delta
			f.rot += f.spin * delta
			# Landed this tick: settle on the ground next tick.
			var new_bottom := -INF
			for v in f.poly:
				new_bottom = maxf(new_bottom, (v * sc).rotated(f.rot).y)
			if f.pos.y + new_bottom > 0.0:
				f.pos.y = -new_bottom


## Felt G = (acceleration + gravity) along the aircraft's "up" axis, in g.
func _update_g(delta: float) -> void:
	var felt := 1.0
	if not on_ground:
		var acc := (velocity_m - _prev_vel) / delta + Vector2(0.0, WorldScale.GRAVITY)
		felt = acc.dot(Vector2(-sin(pitch), cos(pitch))) / WorldScale.GRAVITY
	_prev_vel = velocity_m
	g_load = lerpf(g_load, felt, 1.0 - exp(-8.0 * delta))

	var black_target := 0.0
	var red_target := 0.0
	if data.g_effects and not crashed and speed_kt >= data.g_effect_min_speed_kt:
		black_target = clampf(inverse_lerp(data.blackout_start_g, data.blackout_full_g, g_load), 0.0, 1.0)
		red_target = clampf(inverse_lerp(data.redout_start_g, data.redout_full_g, g_load), 0.0, 1.0)
	blackout = move_toward(blackout, black_target,
			(data.g_effect_onset if black_target > blackout else data.g_effect_recovery) * delta)
	redout = move_toward(redout, red_target,
			(data.g_effect_onset if red_target > redout else data.g_effect_recovery) * delta)


## Called after each physics step (teleport = no smoothing from the old spot).
func _sync_node(teleport := false) -> void:
	_prev_px = _cur_px
	_prev_rot = _cur_rot
	_cur_px = Vector2(pos_m.x, -pos_m.y) * WorldScale.PX_PER_M
	_cur_rot = -pitch
	if teleport:
		_prev_px = _cur_px
		_prev_rot = _cur_rot
	position = _cur_px
	rotation = _cur_rot


func _process(_delta: float) -> void:
	if crashed:
		return
	var f := Engine.get_physics_interpolation_fraction()
	position = _prev_px.lerp(_cur_px, f)
	rotation = lerp_angle(_prev_rot, _cur_rot, f)


# --- Drawing ---
# With a sprite: sprite + code-drawn gear (behind the body), flaps and propeller.
# Without one: a simple placeholder silhouette.

func _draw() -> void:
	if data == null:
		return
	if crashed and not _fragments.is_empty():
		_draw_fragments()
	elif data.sprite:
		_draw_sprite_aircraft()
	else:
		_draw_placeholder(data.length_m * WorldScale.PX_PER_M, data.height_m * WorldScale.PX_PER_M)


func _draw_fragments() -> void:
	var sc := data.sprite_scale
	for f in _fragments:
		draw_set_transform(f.pos, f.rot, Vector2(sc, sc))
		draw_colored_polygon(f.poly, f.tint, f.uvs, data.sprite)
	draw_set_transform(Vector2.ZERO)


func _draw_sprite_aircraft() -> void:
	var sc := data.sprite_scale
	var size := data.sprite.get_size() * sc
	# Everything below is drawn in texture pixels; the transform scales it down
	# and puts the wheel bottoms (gear down) on the node origin.
	# On the ground with the gear (partly) up, the plane sits on its belly.
	var sink := (1.0 - gear_pos) * _gear_travel() * sc if on_ground else 0.0
	draw_set_transform(Vector2(-size.x * 0.5, -data.sprite_wheel_bottom_y * sc + sink), 0.0, Vector2(sc, sc))

	# Gear first, so it slides up and disappears behind the fuselage.
	if gear_pos > 0.05:
		if data.sprite_gear:
			draw_texture(data.sprite_gear, Vector2(0, -(1.0 - gear_pos) * data.sprite_gear_travel))
		else:
			_draw_code_gear()

	# Afterburner flame out of the nozzle (under the body so it starts inside the nozzle).
	var ab := afterburner
	if ab > 0.0:
		_draw_afterburner(ab)
	draw_texture(data.sprite, Vector2.ZERO)

	# Moving tailplane: rotates about its hinge, trailing edge up for nose-up.
	if data.sprite_elevator:
		var h := data.sprite_elevator_hinge
		var base := Vector2(-size.x * 0.5, -data.sprite_wheel_bottom_y * sc + sink)
		draw_set_transform(base + h * sc, deg_to_rad(data.elevator_max_deg) * elevator, Vector2(sc, sc))
		draw_texture(data.sprite_elevator, -h)
		draw_set_transform(base, 0.0, Vector2(sc, sc))

	# Flaps: a red panel hanging from the wing trailing edge (40 degrees at LDG).
	if flap_pos > 0.02 and data.sprite_flap_length > 0.0:
		var hinge := data.sprite_flap_hinge
		var ang := deg_to_rad(20.0 * flap_pos)
		var tip := hinge + Vector2(-cos(ang), sin(ang)) * data.sprite_flap_length
		draw_line(hinge, tip, Color(0.15, 0.15, 0.18), 10.0)
		draw_line(hinge, tip, data.stripe_color, 6.0)

	# Propeller: the art's blurred blades while running, a still blade when stopped.
	if data.has_propeller:
		var pc := data.sprite_prop_center
		if engine_rpm > 0.6 and data.sprite_prop:
			var flicker := 0.75 + 0.25 * sin(_prop_angle * 3.0)
			draw_texture(data.sprite_prop, Vector2.ZERO, Color(1, 1, 1, flicker))
		else:
			var span := data.sprite_prop_radius * absf(cos(_prop_angle))
			draw_rect(Rect2(pc.x - 2, pc.y - span, 4, span * 2), Color(0.2, 0.2, 0.22))
	draw_set_transform(Vector2.ZERO)


func _gear_travel() -> float:
	if data.sprite_gear:
		return data.sprite_gear_travel
	var top := 0.0
	for y in data.sprite_gear_top_y:
		top = maxf(top, y)
	return data.sprite_wheel_bottom_y - top


## Simple legs and wheels for aircraft whose art shows the gear retracted.
func _draw_code_gear() -> void:
	var leg_col := Color(0.42, 0.44, 0.46)
	for i in data.sprite_gear_x.size():
		var gx := data.sprite_gear_x[i]
		var top_y := data.sprite_gear_top_y[i]
		var r := data.sprite_gear_wheel_size[i] * 0.5
		var wy := lerpf(top_y - r, data.sprite_wheel_bottom_y - r, gear_pos)
		draw_rect(Rect2(gx - 2.5, top_y, 5, wy - top_y), leg_col)
		draw_rect(Rect2(gx - 1, top_y, 2, wy - top_y), Color(0.6, 0.62, 0.64))
		draw_circle(Vector2(gx, wy), r, Color(0.07, 0.07, 0.08))
		draw_circle(Vector2(gx, wy), r * 0.45, Color(0.6, 0.62, 0.66))


## Afterburner: a big flickering plume out of the nozzle. Red-orange outer
## flame, yellow middle, white-hot core, blue shock diamonds and a nozzle glow.
## Length grows with how far the throttle is into the afterburner range.
func _draw_afterburner(strength: float) -> void:
	var n := data.sprite_nozzle
	var flicker := 0.88 + 0.08 * sin(_time * 47.0) + 0.04 * sin(_time * 113.0)
	var length := data.afterburner_flame_length * (0.55 + 0.45 * strength) * flicker
	var h := data.afterburner_flame_width
	var wob := 1.5 * sin(_time * 71.0)
	var layers := [
		[1.25, 1.00, Color(0.95, 0.25, 0.08, 0.35)],   # red haze
		[1.00, 0.85, Color(1.0, 0.5, 0.1, 0.8)],       # orange
		[0.70, 0.62, Color(1.0, 0.82, 0.35, 0.9)],     # yellow
		[0.38, 0.35, Color(1.0, 0.98, 0.85, 1.0)],     # white-hot core
	]
	for l in layers:
		var hw: float = h * 0.5 * l[0]
		var fl: float = length * l[1]
		draw_colored_polygon(PackedVector2Array([
			n + Vector2(6, -hw), n + Vector2(-fl * 0.35, -hw * 1.1 + wob),
			n + Vector2(-fl, wob * 2.0),
			n + Vector2(-fl * 0.35, hw * 1.1 + wob), n + Vector2(6, hw),
		]), l[2])
	# Shock diamonds.
	var d_size := h * 0.22
	for k in 4:
		var d := n + Vector2(-length * (0.12 + 0.13 * k), 0)
		var s := d_size * (1.0 - 0.15 * k)
		draw_colored_polygon(PackedVector2Array([d + Vector2(s * 1.4, 0), d + Vector2(0, -s), d + Vector2(-s * 1.4, 0), d + Vector2(0, s)]),
				Color(0.65, 0.85, 1.0, 0.85))
	# Glow around the nozzle.
	draw_circle(n + Vector2(-2, 0), h * 0.75, Color(1.0, 0.6, 0.2, 0.25 * strength + 0.1))


func _draw_placeholder(l: float, h: float) -> void:
	var p := func(fx: float, fy: float) -> Vector2: return Vector2(fx * l, -fy * h)
	var dark := Color(0.15, 0.15, 0.18)
	if gear_pos > 0.05:
		for gx in [-0.05, 0.36]:
			draw_line(p.call(gx, 0.15), p.call(gx, 0.4), dark, 1.0)
			draw_rect(Rect2(p.call(gx, 0.0) + Vector2(-1.5, -3.0), Vector2(3, 3)), dark)
	draw_colored_polygon(PackedVector2Array([
		p.call(0.50, 0.55), p.call(0.42, 0.38), p.call(-0.20, 0.38),
		p.call(-0.50, 0.62), p.call(-0.50, 0.72), p.call(0.25, 0.80),
		p.call(0.45, 0.72),
	]), data.body_color)
	draw_colored_polygon(PackedVector2Array([
		p.call(-0.50, 0.70), p.call(-0.47, 1.05), p.call(-0.38, 1.05), p.call(-0.28, 0.74),
	]), data.body_color)
	draw_line(p.call(-0.48, 0.60), p.call(0.46, 0.50), data.stripe_color, 1.0)
