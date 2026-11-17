extends Camera2D
## Follows the aircraft with a speed-based look-ahead to the right.
## Vertical framing:
##  - Low (takeoff, approach, landing): the ground stays near the bottom of the
##    screen so the runway is always visible; the plane may rise up to just
##    below the cockpit panels.
##  - High (cruise): the plane sits a bit below the screen centre.
## The top of the screen is kept for the cockpit panels.

@export var target: Aircraft
## Max look-ahead (px) reached at look_ahead_full_speed_kt.
@export var look_ahead_px := 200.0
@export var look_ahead_full_speed_kt := 100.0
## Screen y of the ground line when flying low (360 = bottom edge).
@export var ground_screen_y := 320.0
## Highest the plane may sit on screen when low (just below the HUD panels).
@export var low_plane_screen_y := 140.0
## Where the plane sits on screen when high.
@export var high_plane_screen_y := 240.0
## Altitude band (m) over which framing blends from "low" to "high".
@export var blend_start_m := 55.0
@export var blend_end_m := 150.0


func _physics_process(_delta: float) -> void:
	if target:
		global_position = _goal()


func snap() -> void:
	global_position = _goal()
	reset_smoothing()


func _goal() -> Vector2:
	var half_h := get_viewport_rect().size.y * 0.5
	var p := target.global_position
	var f := clampf(target.speed_kt / look_ahead_full_speed_kt, 0.0, 1.0)
	var s := smoothstep(blend_start_m, blend_end_m, target.pos_m.y)
	var plane_screen_y := lerpf(low_plane_screen_y, high_plane_screen_y, s)
	var ground_view_y := half_h - ground_screen_y          # centre y that puts the ground at ground_screen_y
	var y := minf(ground_view_y, p.y - plane_screen_y + half_h)
	return Vector2(p.x + look_ahead_px * f, y)
