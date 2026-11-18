extends CanvasLayer
## Cockpit HUD: instructor message box (top-left, small so the plane stays
## visible), positional radar with the flight phase (top-centre), instrument
## panel (top-right; the plane flies on the left of the screen),
## plus a hidden debug readout (F1).
## The instructor messages double as a tutorial so friends can play without
## being told the controls.

@onready var panel: Control = $InstrumentPanel
@onready var radar: Control = $Radar
@onready var messages: Control = $MessageBox
@onready var debug_label: Label = $DebugLabel
@onready var cadet_badge: PanelContainer = $CadetBadge

## Seconds between repeated STALL callouts.
@export var stall_callout_cooldown_s := 4.0
## "Nose too high" warning: shouted when the nose is within this many degrees
## of the tail-strike pitch while the tail is still near the runway.
@export var tail_warning_margin_deg := 4.0
@export var tail_warning_cooldown_s := 3.0

var aircraft: Aircraft
var departure: BaseData
var destination: BaseData
var route_distance_m := 1.0
var has_flown := false
## Set by the flight when it ends (landed/crashed): tutorial prompts stop.
var flight_over := false
var _said := {}
var _stall_cooldown := 0.0
var _tail_cooldown := 0.0
var _last_touchdown_fpm := 0.0
var _prev_gear_down := true
var _prev_flap := 1


func setup(a: Aircraft, from_base: BaseData, to_base: BaseData, distance_m: float) -> void:
	aircraft = a
	departure = from_base
	destination = to_base
	route_distance_m = distance_m
	radar.to_name = to_base.short_name
	radar.route_m = distance_m
	radar.departure_runway_m = from_base.runway_length_m
	radar.destination_runway_m = to_base.runway_length_m
	cadet_badge.show_cadet()
	panel.aircraft = a
	var g_fx := preload("res://scenes/ui/g_effect.gd").new()
	g_fx.name = "GEffect"
	add_child(g_fx)
	g_fx.aircraft = a
	radar.aircraft = a
	_prev_gear_down = a.gear_down
	_prev_flap = a.flap_setting
	a.lifted_off.connect(_on_lifted_off)
	a.touched_down.connect(_on_touched_down)
	messages.say("%s! Target: %s. Why are you just SITTING there? E, start the d*mn engine!" % [
			GameState.pilot_call(), to_base.short_name.capitalize()])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		debug_label.visible = not debug_label.visible


func _process(delta: float) -> void:
	if aircraft == null:
		return
	var remaining := distance_to_destination()
	radar.remaining_m = remaining
	radar.phase = FlightPhase.compute(aircraft, has_flown, absf(remaining))
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
	if flight_over:
		return
	_stall_cooldown = maxf(0.0, _stall_cooldown - delta)
	if a.stalled and _stall_cooldown <= 0.0:
		_stall_cooldown = stall_callout_cooldown_s
		messages.say("STALL! STALL! Nose DOWN, RIGHT key, full power! NOW!", true)

	if a.fuel_kg <= 0.0 and a.engine_rpm <= 0.0:
		_once("no_fuel", "You ran it DRY?! Engine's dead! Hold your speed and glide. Careful!", true)
	elif a.low_fuel:
		_once("low_fuel", "Fuel is LOW! Did you even check it? Get it on the ground, FAST!")

	_tail_warning(delta)
	_react_to_controls()

	if not has_flown and a.on_ground:
		if a.engine_on and a.engine_rpm >= 1.0:
			if a.data.afterburner_thrust_n > 0.0:
				_once("engine", "Engine's up. UP, full throttle! Past the red mark, burner! Go, go, GO!")
			else:
				_once("engine", "Engine's running. What are you waiting for? UP, throttle! MOVE!")
		if a.speed_kt >= a.data.rotate_speed_kt:
			_once("rotate", "ROTATE! LEFT key, EASE the nose up! Don't yank it or you'll scrape the d*mn tail!")
	elif not a.on_ground:
		var gear_still_down := a.data.retractable_gear and a.gear_down
		if a.flap_setting != 0 and a.altitude_ft > 500.0 and not gear_still_down and not _approaching():
			_once("flaps_up", "500 feet and the flaps are still out?! F, flaps UP! Wake up!")
		if a.altitude_ft > 1000.0:
			_once("cruise", "Finally. %s is %.1f km. Under %d kt you stall, so WATCH your speed!" % [
					destination.short_name.capitalize(), distance_to_destination() / 1000.0, roundi(a.data.stall_speed_kt)])
		var dist := distance_to_destination()
		var dest := destination.short_name.capitalize()
		if dist < 2500.0 and dist > 0.0:
			_once("descend", "%s ahead! Descend, slow down. Don't you dare overshoot!" % dest)
		if dist < 1600.0 and dist > 0.0:
			_once("configure", _landing_checklist())
		if dist < 900.0 and a.altitude_ft < 600.0:
			_once("cleared", "%s tower: cleared to land. Gently! Easy, EASY!" % dest)
		if dist < -destination.runway_length_m:
			_once("overshot", "You FLEW PAST the runway?! Unbelievable. Press R. Again, d*mn it!")


## Warn before a tail strike: nose close to the strike pitch while the tail is
## still within reach of the runway (on the roll, at lift-off or in the flare).
func _tail_warning(delta: float) -> void:
	var a := aircraft
	_tail_cooldown = maxf(0.0, _tail_cooldown - delta)
	var strike := deg_to_rad(a.data.tail_strike_pitch_deg)
	var near_ground := a.pos_m.y < a.tail_arm_m() * (sin(strike + deg_to_rad(10.0)) - sin(strike))
	if _tail_cooldown <= 0.0 and near_ground and a.speed_kt > 20.0 and a.pitch_rate > 0.0 			and a.pitch > strike - deg_to_rad(tail_warning_margin_deg) and a.pitch < strike:
		_tail_cooldown = tail_warning_cooldown_s
		messages.say("NOSE TOO HIGH! You'll hit the tail! Ease OFF!", true)


func _approaching() -> bool:
	var dist := distance_to_destination()
	return dist < 2500.0 and dist > -destination.runway_length_m


## What is still missing before landing, e.g. "Set up to land: gear down (G), flaps LDG (F), about 61 kt."
func _landing_checklist() -> String:
	var a := aircraft
	var todo := PackedStringArray()
	if a.data.retractable_gear and not a.gear_down:
		todo.append("gear down (G)")
	if a.flap_setting != 2:
		todo.append("flaps LDG (F)")
	todo.append("%d kt" % approach_speed_kt())
	return "Configure NOW: %s. What the h*ll are you doing? Hurry!" % ", ".join(todo)


## Immediate feedback when the player moves the gear or the flaps.
func _react_to_controls() -> void:
	var a := aircraft
	var gear_changed := a.gear_down != _prev_gear_down
	var flaps_changed := a.flap_setting != _prev_flap
	_prev_gear_down = a.gear_down
	_prev_flap = a.flap_setting
	var dest := destination.short_name.capitalize()

	if gear_changed and a.data.retractable_gear and not a.on_ground:
		if not a.gear_down:
			if _approaching():
				messages.say("Gear UP on approach?! Are you f*cking mad? G, gear DOWN!", true)
			elif a.flap_setting != 0:
				messages.say("Gear up. Good. At 500 ft, flaps UP with F. Don't make me repeat it!", true)
			else:
				messages.say("Gear up. Climb to 1000 ft, head for %s. MOVE!" % dest, true)
		else:
			if _approaching():
				messages.say("Three green. %s" % ("Now flaps LDG, F! Quick!" if a.flap_setting != 2 						else "Hold %d kt. Steady!" % approach_speed_kt()), true)
			else:
				messages.say("Gear DOWN in the climb?! What the f*ck?! G, get it UP!", true)

	if flaps_changed:
		var setting: String = Aircraft.FLAP_NAMES[a.flap_setting]
		if a.on_ground and not has_flown:
			messages.say("Flaps %s. %s" % [setting, "Right, TO for takeoff. Now GO!" if a.flap_setting == 1 					else "WRONG! TO for takeoff, press F! Think!"], true)
		elif _approaching():
			match a.flap_setting:
				2: messages.say("Landing flaps. %s" % ("GEAR! G, gear down! Come ON!" if a.data.retractable_gear and not a.gear_down 						else "%d kt, aim for the numbers. Steady!" % approach_speed_kt()), true)
				1: messages.say("Flaps TO. Once more, F for LDG! Faster!", true)
				0: messages.say("Flaps UP on approach?! You want to land or not? F!", true)
		elif not a.on_ground:
			if a.flap_setting == 0:
				_said["flaps_up"] = true
				messages.say("Clean aircraft. 1000 ft, then %s. Don't drift!" % dest, true)
			else:
				messages.say("Flaps %s?! UP for the cruise, F! Pay ATTENTION!" % setting, true)


func _on_lifted_off() -> void:
	if has_flown:
		return
	has_flown = true
	if aircraft.data.retractable_gear:
		messages.say("Positive climb! GEAR UP! G! What are you waiting for?!")
	else:
		messages.say("Positive climb. Easy on the nose, build speed. Good, keep it there!")


func _on_touched_down(vertical_speed_ms: float) -> void:
	_last_touchdown_fpm = vertical_speed_ms * WorldScale.M_TO_FT * 60.0
	if has_flown and not flight_over:
		messages.say("%d ft/min. Let the nose down, then BRAKES! Hold B! Stop it on the runway!" % absi(roundi(_last_touchdown_fpm)), true)


func _update_debug() -> void:
	var a := aircraft
	debug_label.text = "PITCH %+d  AOA %+d  LIFT %.2fG  RPM %d%%\nFLAP POS %.2f  DIST %d M  LAST TD %+d FPM  %s" % [
		roundi(rad_to_deg(a.pitch)), roundi(rad_to_deg(a.aoa)), a.lift_ratio, roundi(a.engine_rpm * 100.0),
		a.flap_pos, roundi(a.pos_m.x), roundi(_last_touchdown_fpm), "AIRBRAKE" if a.airbrake_out else "",
	]
