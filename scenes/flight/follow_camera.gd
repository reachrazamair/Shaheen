extends Camera2D
## Follows the aircraft with a speed-based look-ahead to the right.
## limit_bottom keeps the ground near the bottom of the screen, leaving the
## top of the screen free for the cockpit panels (chunk 1.5).

@export var target: Aircraft
## Max look-ahead (px) reached at look_ahead_full_speed_kt.
@export var look_ahead_px := 140.0
@export var look_ahead_full_speed_kt := 100.0
## Keeps the plane this many px below the screen centre.
@export var vertical_offset_px := 60.0


func _physics_process(_delta: float) -> void:
	if target:
		global_position = _goal()


func snap() -> void:
	global_position = _goal()
	reset_smoothing()


func _goal() -> Vector2:
	var f := clampf(target.speed_kt / look_ahead_full_speed_kt, 0.0, 1.0)
	return target.global_position + Vector2(look_ahead_px * f, -vertical_offset_px)
