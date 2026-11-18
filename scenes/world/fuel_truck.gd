extends Node2D
## Fuel bowser for a refuelling stop at a base along the route (flight.gd
## spawns it when the player presses T, stopped with the engine off).
## Drives in from the right, parks just ahead of the aircraft's nose, runs its
## hose to the aircraft, fills the tank, reels the hose back in and drives off
## to the left behind the aircraft. Drawn behind the aircraft (on its far side).
## Placeholder pixel art drawn in code, facing left (cab on the left).
## Node origin = centre of the truck on the ground; y = 0 is the ground line.

signal fuelled           ## tank full, hose coming back in
signal hose_stowed       ## hose reeled in, truck driving off: the aircraft may start up
signal finished          ## drove off screen (node frees itself)

enum Phase { ARRIVE, CONNECT, FUEL, DISCONNECT, LEAVE }

## Set by flight.gd before adding the node.
var aircraft: Aircraft
var camera: Camera2D

@export var truck_scale := 1.4
@export var drive_speed_px_s := 90.0
@export var accel_px_s2 := 70.0
## Gap between the aircraft's nose and the truck's cab (px).
@export var park_gap_px := 14.0
@export var hose_time_s := 1.0
## Seconds to fill the tank, however empty it is.
@export var fuel_time_s := 4.0
@export var cab_color := Color(0.42, 0.45, 0.3)
@export var tank_color := Color(0.82, 0.83, 0.8)
@export var band_color := Color(0.75, 0.15, 0.12)

var phase := Phase.ARRIVE
## Fuel added (kg), for the result screen.
var added_kg := 0.0

var _speed := 0.0
var _park_x := 0.0
var _hose := 0.0          ## 0 = reeled in, 1 = connected
var _fuel_rate := 0.0
var _time := 0.0
var _wheel_angle := 0.0


func _ready() -> void:
	var nose_px := aircraft.position.x + (aircraft.data.sprite.get_size().x - aircraft.data.sprite_main_wheel_x) * aircraft.data.sprite_scale
	_park_x = nose_px + park_gap_px + 20.0 * truck_scale
	# Start just off the right edge of the screen (or at the parking spot if that is further).
	var right := camera.get_screen_center_position().x + get_viewport_rect().size.x * 0.5 + 40.0 * truck_scale
	position = Vector2(maxf(right, _park_x + 40.0), 0.0)


func _process(delta: float) -> void:
	_time += delta
	match phase:
		Phase.ARRIVE:
			var left := position.x - _park_x
			# Slow down for the parking spot.
			var target := minf(drive_speed_px_s, sqrt(2.0 * accel_px_s2 * maxf(left, 0.0)))
			_speed = move_toward(_speed, target, accel_px_s2 * 2.0 * delta)
			_drive(-maxf(_speed, 4.0) * delta)
			if position.x <= _park_x:
				position.x = _park_x
				_speed = 0.0
				phase = Phase.CONNECT
		Phase.CONNECT:
			_hose = minf(1.0, _hose + delta / hose_time_s)
			if _hose >= 1.0:
				_fuel_rate = maxf(aircraft.data.fuel_capacity_kg - aircraft.fuel_kg, 0.0) / fuel_time_s
				phase = Phase.FUEL
		Phase.FUEL:
			var add := minf(_fuel_rate * delta, aircraft.data.fuel_capacity_kg - aircraft.fuel_kg)
			aircraft.fuel_kg += add
			added_kg += add
			if aircraft.fuel_kg >= aircraft.data.fuel_capacity_kg - 0.01:
				aircraft.fuel_kg = aircraft.data.fuel_capacity_kg
				phase = Phase.DISCONNECT
				fuelled.emit()
		Phase.DISCONNECT:
			_hose = maxf(0.0, _hose - delta / hose_time_s)
			if _hose <= 0.0:
				phase = Phase.LEAVE
				hose_stowed.emit()
		Phase.LEAVE:
			_speed = move_toward(_speed, drive_speed_px_s, accel_px_s2 * delta)
			_drive(-_speed * delta)
			var left_edge := camera.get_screen_center_position().x - get_viewport_rect().size.x * 0.5
			if position.x < left_edge - 40.0 * truck_scale:
				finished.emit()
				queue_free()
	queue_redraw()


func _drive(dx: float) -> void:
	position.x += dx
	_wheel_angle += dx / (3.5 * truck_scale)


func _night() -> bool:
	return GameState.night


func _lamp(c: Color) -> Color:
	return GameState.glow(c)


func _draw() -> void:
	_draw_hose()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(truck_scale, truck_scale))
	var dark := Color(0.16, 0.16, 0.17)
	# Chassis.
	draw_rect(Rect2(-20, -6, 40, 3), dark)
	# Tank: a long capsule with a red band, a placard and a ladder.
	var tank := PackedVector2Array()
	for k in 9:
		var a := PI * 0.5 + PI * k / 8.0
		tank.append(Vector2(-6 + cos(a) * 4.5, -10.5 + sin(a) * 4.5))
	for k in 9:
		var a := -PI * 0.5 + PI * k / 8.0
		tank.append(Vector2(15.5 + cos(a) * 4.5, -10.5 + sin(a) * 4.5))
	draw_colored_polygon(tank, tank_color)
	draw_rect(Rect2(-8, -12, 26, 2), band_color)
	draw_rect(Rect2(-6, -15, 22, 1), tank_color.lightened(0.25))
	draw_rect(Rect2(-6, -6.5, 22, 0.5), tank_color.darkened(0.3))
	draw_rect(Rect2(17.5, -14, 1, 8), dark)                    # rear ladder
	# Flammable placard (orange diamond) on the tank side.
	draw_colored_polygon(PackedVector2Array([Vector2(6, -11), Vector2(8, -9), Vector2(6, -7), Vector2(4, -9)]), Color(0.95, 0.5, 0.1))
	# Hose cabinet with the reel.
	draw_rect(Rect2(-9, -9, 4, 4), dark.lightened(0.15))
	draw_circle(Vector2(-7, -7), 1.2, dark)
	# Cab.
	draw_colored_polygon(PackedVector2Array([Vector2(-21, -4), Vector2(-21, -11), Vector2(-19, -15),
			Vector2(-11, -15), Vector2(-11, -4)]), cab_color)
	var glass := _lamp(Color(0.9, 0.85, 0.6)) if _night() else Color(0.5, 0.7, 0.8)
	draw_colored_polygon(PackedVector2Array([Vector2(-20.5, -11), Vector2(-18.7, -14), Vector2(-16, -14),
			Vector2(-16, -11)]), glass)                                # windscreen
	draw_rect(Rect2(-15, -14, 3, 3), glass)                           # side window
	draw_rect(Rect2(-11.5, -15, 0.5, 11), dark)                       # cab / body gap
	draw_rect(Rect2(-21, -5, 3, 1), dark)                             # bumper
	# Lights: headlight, tail light, amber beacon flashing on the cab roof.
	draw_rect(Rect2(-21, -7, 1, 1.5), _lamp(Color(1.0, 0.95, 0.7)) if _night() else Color(0.9, 0.9, 0.8))
	draw_rect(Rect2(19.5, -7, 1, 1.5), _lamp(Color(1.0, 0.15, 0.1)) if _night() else Color(0.7, 0.1, 0.1))
	var beacon_on := fmod(_time, 0.6) < 0.3
	draw_rect(Rect2(-16, -16.5, 2, 1.5), _lamp(Color(1.0, 0.65, 0.1)) if beacon_on else Color(0.55, 0.35, 0.1))
	if beacon_on and _night():
		draw_circle(Vector2(-15, -16), 3.0, _lamp(Color(1.0, 0.6, 0.1, 0.25)))
	# Wheels (front, two rear) with a turning hub mark.
	for wx in [-15.0, 8.0, 14.0]:
		draw_circle(Vector2(wx, -3), 3.0, Color(0.08, 0.08, 0.09))
		draw_circle(Vector2(wx, -3), 1.3, Color(0.55, 0.56, 0.58))
		var spoke := Vector2(cos(_wheel_angle), sin(_wheel_angle)) * 1.2
		draw_line(Vector2(wx, -3) - spoke, Vector2(wx, -3) + spoke, Color(0.25, 0.25, 0.27), 0.5)
	draw_set_transform(Vector2.ZERO)
	if _night():
		# Headlight beam on the ground ahead.
		draw_colored_polygon(PackedVector2Array([Vector2(-21 * truck_scale, -8), Vector2(-60 * truck_scale, -1),
				Vector2(-60 * truck_scale, 0), Vector2(-21 * truck_scale, -6)]), _lamp(Color(1.0, 0.95, 0.7, 0.18)))


## Hose from the cabinet to the aircraft's refuelling point near the main
## wheels, sagging to the ground; it unrolls and reels back in (_hose 0..1).
func _draw_hose() -> void:
	if _hose <= 0.0 or aircraft == null:
		return
	var start := Vector2(-7, -7) * truck_scale
	var target := aircraft.position + Vector2(4, -5) - position
	var mid := Vector2((start.x + target.x) * 0.5, -0.5)
	var pts := PackedVector2Array()
	var n := 24
	for k in n + 1:
		var t := float(k) / n * _hose
		pts.append(start.lerp(mid, t).lerp(mid.lerp(target, t), t))
	draw_polyline(pts, Color(0.1, 0.1, 0.1), 1.5)
	if _hose >= 1.0:
		draw_circle(target, 1.5, Color(0.6, 0.6, 0.62))              # nozzle coupling
