extends CanvasLayer
## Cockpit HUD: instrument panel (top-left), flight phase box (top-centre),
## instructor message box (top-right), plus a hidden debug readout (F1).
## The instructor messages double as a tutorial so friends can play without
## being told the controls.

@onready var panel: Control = $InstrumentPanel
@onready var phase_box: Control = $PhaseBox
@onready var messages: Control = $MessageBox
@onready var debug_label: Label = $DebugLabel

## Seconds between repeated STALL callouts.
@export var stall_callout_cooldown_s := 4.0

var aircraft: Aircraft
var has_flown := false
var _said := {}
var _stall_cooldown := 0.0
var _last_touchdown_fpm := 0.0


func setup(a: Aircraft) -> void:
	aircraft = a
	panel.aircraft = a
	phase_box.aircraft = a
	a.lifted_off.connect(_on_lifted_off)
	a.touched_down.connect(_on_touched_down)
	messages.say("Welcome, cadet. Press E to start the engine.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		debug_label.visible = not debug_label.visible


func _process(delta: float) -> void:
	if aircraft == null:
		return
	phase_box.phase = FlightPhase.compute(aircraft, has_flown)
	_instructor(delta)
	if debug_label.visible:
		_update_debug()


func _once(key: String, text: String, urgent := false) -> void:
	if not _said.has(key):
		_said[key] = true
		messages.say(text, urgent)


func _instructor(delta: float) -> void:
	var a := aircraft
	_stall_cooldown = maxf(0.0, _stall_cooldown - delta)
	if a.stalled and _stall_cooldown <= 0.0:
		_stall_cooldown = stall_callout_cooldown_s
		messages.say("STALL! Nose down with RIGHT and add power!", true)

	if a.fuel_kg <= 0.0 and a.engine_rpm <= 0.0:
		_once("no_fuel", "Engine out, no fuel! Keep your speed up and glide down.", true)
	elif a.low_fuel:
		_once("low_fuel", "Fuel is low. Land soon.")

	if not has_flown and a.on_ground:
		if a.engine_on and a.engine_rpm >= 1.0:
			_once("engine", "Engine running. Hold UP to open the throttle and start your takeoff roll.")
		if a.speed_kt >= a.data.rotate_speed_kt:
			_once("rotate", "Rotate! Press LEFT to lift the nose.")
	elif not a.on_ground:
		if a.flap_setting != 0 and a.altitude_ft > 500.0:
			_once("flaps_up", "Clean up: press F until the flaps read UP.")
		if a.altitude_ft > 1000.0:
			_once("cruise", "Good climb. Watch your speed: below %d kt you will stall." % roundi(a.data.stall_speed_kt))
	elif has_flown and a.speed_kt < 1.0:
		_once("stopped", "Nicely done. Press R to fly again.")


func _on_lifted_off() -> void:
	if has_flown:
		return
	has_flown = true
	if aircraft.data.retractable_gear:
		messages.say("Positive climb. Gear up! Press G.")
	else:
		messages.say("Positive climb. Ease the nose up gently and build speed.")


func _on_touched_down(vertical_speed_ms: float) -> void:
	_last_touchdown_fpm = vertical_speed_ms * WorldScale.M_TO_FT * 60.0
	if has_flown:
		_said.erase("stopped")
		messages.say("Touchdown at %d ft/min. Hold B to brake." % absi(roundi(_last_touchdown_fpm)), true)


func _update_debug() -> void:
	var a := aircraft
	debug_label.text = "PITCH %+d  AOA %+d  LIFT %.2fG  RPM %d%%\nFLAP POS %.2f  DIST %d M  LAST TD %+d FPM  %s" % [
		roundi(rad_to_deg(a.pitch)), roundi(rad_to_deg(a.aoa)), a.lift_ratio, roundi(a.engine_rpm * 100.0),
		a.flap_pos, roundi(a.pos_m.x), roundi(_last_touchdown_fpm), "AIRBRAKE" if a.airbrake_out else "",
	]
