extends Camera2D
## Follows the aircraft with a speed-based look-ahead to the right.
## Vertical framing:
##  - Low (takeoff, approach, landing): the ground stays near the bottom of the
##    screen so the runway is always visible; the plane may rise up to just
##    below the cockpit panels.
##  - High (cruise): the plane sits a bit below the screen centre.
## The top of the screen is kept for the cockpit panels.
##
## Runs every rendered frame (after the aircraft has placed itself between
## physics ticks), with its own smoothing: horizontally the camera is locked to
## the plane (no lag, so fast jets don't judder or drift), the look-ahead and
## the vertical position ease in.

@export var target: Aircraft
## Max look-ahead (px) reached at look_ahead_full_speed_kt.
@export var look_ahead_px := 200.0
@export var look_ahead_full_speed_kt := 100.0
## Screen y of the ground line when flying low (360 = bottom edge).
@export var ground_screen_y := 320.0
## Highest the plane may sit on screen when low (just below the HUD panels).
@export var low_plane_screen_y := 155.0
## Where the plane sits on screen when high.
@export var high_plane_screen_y := 240.0
## Altitude band (m) over which framing blends from "low" to "high".
@export var blend_start_m := 40.0
@export var blend_end_m := 130.0
## How quickly the look-ahead and the vertical framing catch up (1/s).
@export var look_ahead_response := 2.0
@export var vertical_response := 6.0

var _look := 0.0
var _y := 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	position_smoothing_enabled = false
	process_priority = -5   # after the aircraft (-10), before the scenery (0)


func _process(delta: float) -> void:
	if target == null:
		return
	_look = lerpf(_look, _goal_look(), 1.0 - exp(-look_ahead_response * delta))
	_y = lerpf(_y, _goal_y(), 1.0 - exp(-vertical_response * delta))
	global_position = Vector2(target.global_position.x + _look, _y)


func snap() -> void:
	_look = _goal_look()
	_y = _goal_y()
	global_position = Vector2(target.global_position.x + _look, _y)
	reset_smoothing()


func _goal_look() -> float:
	return look_ahead_px * clampf(target.speed_kt / look_ahead_full_speed_kt, 0.0, 1.0)


func _goal_y() -> float:
	var half_h := get_viewport_rect().size.y * 0.5
	var s := smoothstep(blend_start_m, blend_end_m, target.pos_m.y)
	var plane_screen_y := lerpf(low_plane_screen_y, high_plane_screen_y, s)
	var ground_view_y := half_h - ground_screen_y          # centre y that puts the ground at ground_screen_y
	return minf(ground_view_y, target.global_position.y - plane_screen_y + half_h)
