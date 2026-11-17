extends Node2D
## One flight: world + aircraft + camera + (for now) debug readout.

## Where the aircraft starts, in metres from the runway start.
@export var spawn_x_m := 60.0

@onready var aircraft: Aircraft = $Aircraft
@onready var camera: Camera2D = $Camera
@onready var debug_label: Label = $DebugUI/DebugLabel

var _last_touchdown_fpm := 0.0


func _ready() -> void:
	aircraft.place_at(spawn_x_m)
	camera.snap()
	aircraft.touched_down.connect(func(vy: float) -> void:
		_last_touchdown_fpm = vy * WorldScale.M_TO_FT * 60.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	# Temporary debug readout; replaced by the cockpit HUD in chunk 1.5.
	var a := aircraft
	var status := "GROUND" if a.on_ground else "AIRBORNE"
	if a.stalled:
		status += "   ** STALL **"
	if a.braking:
		status += "   BRAKE"
	debug_label.text = "%s   %s\nSPD %3d kt   ALT %4d ft   VS %+5d fpm\nTHR %3d%%   PITCH %+3d   AOA %+3d   LIFT %.2fg\nDIST %d m   last touchdown %+d fpm\nUp/Down throttle   Left/Right pitch   B brake   R restart" % [
		a.data.display_name, status,
		roundi(a.speed_kt), roundi(a.altitude_ft), roundi(a.vertical_speed_fpm),
		roundi(a.throttle * 100.0), roundi(rad_to_deg(a.pitch)), roundi(rad_to_deg(a.aoa)), a.lift_ratio,
		roundi(a.pos_m.x), roundi(_last_touchdown_fpm),
	]
