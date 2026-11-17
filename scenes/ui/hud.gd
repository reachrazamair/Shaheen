extends CanvasLayer
## Cockpit HUD: instrument panel (top-left), flight phase box (top-centre),
## instructor message box (top-right), plus a hidden debug readout (F1).
## The instructor messages double as a tutorial so friends can play without
## being told the controls.

@onready var panel: Control = $InstrumentPanel
@onready var phase_box: Control = $PhaseBox
@onready var messages: Control = $MessageBox
@onready var debug_label: Label = $DebugLabel
@onready var route_bar: Control = $RouteBar

## Seconds between repeated STALL callouts.
@export var stall_callout_cooldown_s := 4.0

var aircraft: Aircraft
var departure: BaseData
var destination: BaseData
var route_distance_m := 1.0
var has_flown := false
var _said := {}
var _stall_cooldown := 0.0
var _last_touchdown_fpm := 0.0


func setup(a: Aircraft, from_base: BaseData, to_base: BaseData, distance_m: float) -> void:
	aircraft = a
	departure = from_base
	destination = to_base
	route_distance_m = distance_m
	route_bar.to_name = to_base.short_name
	route_bar.total_m = distance_m
	panel.aircraft = a
	phase_box.aircraft = a
	a.lifted_off.connect(_on_lifted_off)
	a.touched_down.connect(_on_touched_down)
	messages.say("Welcome to %s, cadet. Today: fly to %s. Press E to start the engine." % [from_base.short_name.capitalize(), to_base.short_name.capitalize()])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		debug_label.visible = not debug_label.visible


func _process(delta: float) -> void:
	if aircraft == null:
		return
	var remaining := distance_to_destination()
	route_bar.remaining_m = remaining
	phase_box.phase = FlightPhase.compute(aircraft, has_flown, absf(remaining))
	_instructor(delta)
	if debug_label.visible:
		_update_debug()


## Metres to the destination runway threshold (negative once past it).
func distance_to_destination() -> float:
	return route_distance_m - aircraft.pos_m.x


## Comfortable approach speed: 1.3 x the stall speed with landing flaps.
func approach_speed_kt() -> int:
	var d := aircraft.data
	var bonus := d.flap_lift_bonus[d.flap_lift_bonus.size() - 1] if not d.flap_lift_bonus.is_empty() else 0.0
	return roundi(1.3 * d.stall_speed_kt / sqrt(1.0 + bonus))


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
			_once("cruise", "Good climb. %s is %.0f km ahead. Keep above %d kt or you will stall." % [
					destination.short_name.capitalize(), distance_to_destination() / 1000.0, roundi(a.data.stall_speed_kt)])
		var dist := distance_to_destination()
		var dest := destination.short_name.capitalize()
		if dist < 5000.0 and dist > 0.0:
			_once("descend", "%s ahead. Start your descent and slow down." % dest)
		if dist < 3000.0 and dist > 0.0:
			var gear := "gear down (G), " if a.data.retractable_gear and not a.gear_down else ""
			_once("configure", "Set up to land: %sflaps LDG (F), about %d kt." % [gear, approach_speed_kt()])
		if dist < 1200.0 and a.altitude_ft < 800.0:
			_once("cleared", "%s tower: cleared to land. Touch down gently." % dest)
		if dist < -destination.runway_length_m:
			_once("overshot", "You flew past the runway. Turn around is not possible yet: press R to retry.")
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
