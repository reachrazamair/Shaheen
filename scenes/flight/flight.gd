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
	var warnings := PackedStringArray()
	if a.stalled: warnings.append("** STALL **")
	if a.low_fuel: warnings.append("LOW FUEL")
	if a.engine_rpm == 0.0 and a.fuel_kg <= 0.0: warnings.append("OUT OF FUEL")
	if a.braking: warnings.append("AIRBRAKE" if a.airbrake_out else "BRAKE")

	var engine := "ON" if a.engine_on else "OFF"
	if a.engine_on and a.engine_rpm < 1.0: engine = "STARTING"
	elif not a.engine_on and a.engine_rpm > 0.0: engine = "STOPPING"
	var gear := "FIXED" if not a.data.retractable_gear else \
			("TRANSIT" if a.gear_in_transit else ("DOWN" if a.gear_down else "UP"))
	var flaps: String = Aircraft.FLAP_NAMES[a.flap_setting]
	if not is_equal_approx(a.flap_pos, float(a.flap_setting)): flaps += "..."

	var hint := ""
	if not a.engine_on and a.on_ground and a.speed_kt < 1.0 and a.fuel_kg > 0.0:
		hint = "   << press E to start the engine"

	debug_label.text = "%s   %s   %s%s\nSPD %3d kt   ALT %4d ft   VS %+5d fpm\nTHR %3d%%   PITCH %+3d   AOA %+3d   LIFT %.2fg\nENG %s   FLAPS %s   GEAR %s   FUEL %d%%\nDIST %d m   last touchdown %+d fpm\nUp/Down throttle  Left/Right pitch  E engine  F flaps  G gear  B brake  R restart" % [
		a.data.display_name, "GROUND" if a.on_ground else "AIRBORNE", "  ".join(warnings), hint,
		roundi(a.speed_kt), roundi(a.altitude_ft), roundi(a.vertical_speed_fpm),
		roundi(a.throttle * 100.0), roundi(rad_to_deg(a.pitch)), roundi(rad_to_deg(a.aoa)), a.lift_ratio,
		engine, flaps, gear, roundi(a.fuel_fraction * 100.0),
		roundi(a.pos_m.x), roundi(_last_touchdown_fpm),
	]
