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
##
## Zoom: 1 normally. The flight sets zoom_goal below 1 to show more of the
## world (air-to-ground attack run); framing distances are screen px, so they
## stay the same on screen at any zoom, and the "low" framing (ground in view)
## then lasts up to a proportionally higher altitude.

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
## How quickly the zoom eases to zoom_goal (1/s).
@export var zoom_response := 1.5

## Set by the flight: zoom to ease to, and look-ahead multiplier (attack run
## keeps the plane nearer the middle so the ground behind it is in view too).
var zoom_goal := 1.0
var look_ahead_scale := 1.0
var _zoom := 1.0

var _look := 0.0
var _y := 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	position_smoothing_enabled = false
	process_priority = -5   # after the aircraft (-10), before the scenery (0)


func _process(delta: float) -> void:
	if target == null:
		return
	_zoom = lerpf(_zoom, zoom_goal, 1.0 - exp(-zoom_response * delta))
	zoom = Vector2(_zoom, _zoom)
	_look = lerpf(_look, _goal_look(), 1.0 - exp(-look_ahead_response * delta))
	_y = lerpf(_y, _goal_y(), 1.0 - exp(-vertical_response * delta))
	global_position = Vector2(target.global_position.x + _look, _y)


func snap() -> void:
	_zoom = zoom_goal
	zoom = Vector2(_zoom, _zoom)
	_look = _goal_look()
	_y = _goal_y()
	global_position = Vector2(target.global_position.x + _look, _y)
	reset_smoothing()


func _goal_look() -> float:
	return look_ahead_px * look_ahead_scale * clampf(target.speed_kt / look_ahead_full_speed_kt, 0.0, 1.0) / _zoom


func _goal_y() -> float:
	var half_h := get_viewport_rect().size.y * 0.5
	var s := smoothstep(blend_start_m / _zoom, blend_end_m / _zoom, target.pos_m.y)
	var plane_screen_y := lerpf(low_plane_screen_y, high_plane_screen_y, s)
	var ground_view_y := (half_h - ground_screen_y) / _zoom    # centre y that puts the ground at ground_screen_y
	return minf(ground_view_y, target.global_position.y - (plane_screen_y - half_h) / _zoom)
