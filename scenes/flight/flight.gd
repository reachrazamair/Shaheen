extends Node2D
## One flight: departure base -> destination base, aircraft, camera, scenery,
## HUD, and the landing judge (chunk 1.7).
## Bases and the route distance are data; the scenery theme blends from the
## departure base's look to the destination's as the plane flies.
##
## Flight states:
##   PREFLIGHT - on the departure runway, not yet airborne
##   FLYING    - airborne (also after a bounce)
##   ROLLOUT   - touched down on a runway, braking to a stop
##   DONE      - result screen showing (landed, wrong base or crashed)

signal flight_finished(result: Dictionary)

enum State { PREFLIGHT, FLYING, ROLLOUT, DONE }
const GRADES := ["PERFECT", "GOOD", "FIRM", "HARD"]
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CrashEffect := preload("res://scenes/world/crash_effect.gd")

@export var departure: BaseData
@export var destination: BaseData
## Distance between the two runway thresholds. Compressed so a trainer flight
## takes about a minute and a half (real Risalpur-Peshawar is ~45 km).
@export var route_distance_m := 5000.0
## Sky gradient tint at night (top dark navy, faint glow at the horizon).
@export var night_sky_tint := Color(0.07, 0.09, 0.2)
## Where the aircraft starts, in metres from the departure runway threshold.
@export var spawn_x_m := 60.0
## Seconds between the end of the flight and the result screen.
@export var result_delay_s := 1.2

@onready var aircraft: Aircraft = $Aircraft
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var result_screen: CanvasLayer = $ResultScreen
@onready var ground: Node2D = $Ground
@onready var departure_base: Node2D = $DepartureBase
@onready var destination_base: Node2D = $DestinationBase
@onready var sky: CanvasItem = $Sky/Gradient
@onready var mountains: Node2D = $Mountains
@onready var hills: Node2D = $Hills
@onready var trees: Node2D = $Trees

var state := State.PREFLIGHT
var flight_time_s := 0.0
var _airborne_once := false
var _landed_on := ""            ## "departure" / "destination" during rollout
var _worst_touchdown_fpm := 0.0
var _overran := false


func _ready() -> void:
	if GameState.aircraft_path != "":
		aircraft.set_data(load(GameState.aircraft_path))
	departure_base.data = departure
	destination_base.data = destination
	destination_base.position.x = route_distance_m * WorldScale.PX_PER_M
	ground.end_m = route_distance_m + destination.runway_length_m + 3000.0
	aircraft.place_at(spawn_x_m)
	if GameState.night:
		_setup_night()
	camera.snap()
	hud.setup(aircraft, departure, destination, route_distance_m)
	aircraft.lifted_off.connect(_on_lifted_off)
	aircraft.touched_down.connect(_on_touched_down)
	result_screen.retry_pressed.connect(_retry)
	result_screen.menu_pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	_update_theme()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_retry()


func _retry() -> void:
	get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	_update_theme()


func _physics_process(delta: float) -> void:
	if state == State.DONE:
		return
	if _airborne_once:
		flight_time_s += delta
	if aircraft.on_ground:
		_check_ground_roll()


# --- Landing judge ---

## Runway under a given x (m): "departure", "destination" or "".
func runway_at(x_m: float) -> String:
	if x_m >= 0.0 and x_m <= departure.runway_length_m:
		return "departure"
	if x_m >= route_distance_m and x_m <= route_distance_m + destination.runway_length_m:
		return "destination"
	return ""


func _on_lifted_off() -> void:
	if state == State.DONE:
		return
	if state == State.ROLLOUT:
		hud.messages.say("You BOUNCED it! Hold the nose, settle it down! Aram se!", true)
	_airborne_once = true
	state = State.FLYING


func _on_touched_down(vertical_speed_ms: float) -> void:
	if state != State.FLYING:
		return
	var d := aircraft.data
	var fpm := absf(vertical_speed_ms) * WorldScale.M_TO_FT * 60.0
	_worst_touchdown_fpm = maxf(_worst_touchdown_fpm, fpm)
	var where := runway_at(aircraft.pos_m.x)
	if where == "":
		_crash("Touched down off the runway.", fpm)
	elif aircraft.gear_pos < 0.95:
		_crash("The gear was up: belly landing.", fpm)
	elif absf(rad_to_deg(aircraft.touchdown_pitch)) > 90.0:
		_crash("Hit the ground upside down.", fpm)
	elif rad_to_deg(aircraft.touchdown_pitch) > d.max_ground_pitch_deg + 3.0:
		_crash("Tail strike: the nose was far too high at touchdown.", fpm)
	elif rad_to_deg(aircraft.touchdown_pitch) < -d.max_nose_down_touchdown_deg:
		_crash("Nose-first landing: flare before touchdown.", fpm)
	elif fpm > d.hard_touchdown_fpm:
		_crash("Far too hard: %d ft/min. The gear collapsed." % roundi(fpm), fpm)
	else:
		state = State.ROLLOUT
		_landed_on = where


## On the ground: overrun / off-runway checks, and the end of the rollout.
func _check_ground_roll() -> void:
	var x := aircraft.pos_m.x
	var on_runway := runway_at(x) != ""
	if not on_runway and aircraft.speed_kt > aircraft.data.overrun_crash_speed_kt:
		_crash("Ran off the end of the runway.", _worst_touchdown_fpm if state == State.ROLLOUT else -1.0)
		return
	if not on_runway and state == State.ROLLOUT:
		_overran = true
	if state == State.ROLLOUT and aircraft.speed_kt < 1.0:
		_finish_landing()


func _grade_for(fpm: float) -> int:
	var d := aircraft.data
	var limits := [d.perfect_touchdown_fpm, d.good_touchdown_fpm, d.firm_touchdown_fpm]
	for i in limits.size():
		if fpm <= limits[i]:
			return i
	return 3


func _finish_landing() -> void:
	var result := _base_result()
	result["touchdown_fpm"] = _worst_touchdown_fpm
	if _landed_on == "departure":
		result["grade"] = "WRONG BASE"
		result["title"] = "WRONG BASE"
		result["reasons"] = ["You landed back at %s. Your destination was %s." % [
				departure.short_name.capitalize(), destination.short_name.capitalize()]]
		hud.messages.say("That's %s, %s! %s was the destination! Did you even READ the brief?!" % [departure.short_name.capitalize(),
				GameState.pilot_call(), destination.short_name.capitalize()], true)
	else:
		var g := _grade_for(_worst_touchdown_fpm)
		var reasons: Array[String] = []
		if _overran:
			g = mini(g + 1, GRADES.size() - 1)
			reasons.append("Rolled past the runway end (one grade lower).")
		result["grade"] = GRADES[g]
		result["title"] = GRADES[g] + " LANDING"
		reasons.push_front("Landed at %s." % destination.display_name)
		result["reasons"] = reasons
		var praise := ["Perfect. Shabash, %s. Don't let it go to your head.", "Good landing, %s. Not bad. Not bad at all.",
				"Firm, %s. FLARE more next time! Again!", "HARD landing, %s! You want to break my aircraft?!"]
		hud.messages.say(praise[g] % GameState.pilot_call(), true)
	_end(result)


func _crash(reason: String, fpm := -1.0) -> void:
	if state == State.DONE:
		return
	# Severity (0..1) from sink rate and ground speed: >= Aircraft.BIG_CRASH_SEVERITY is a big crash
	# (explosion, shards blasted out), below that the wreck shatters and scrapes along.
	var d := aircraft.data
	var sink := maxf(fpm, 0.0)
	var severity := clampf(sink / (2.0 * d.hard_touchdown_fpm) + aircraft.speed_kt / (4.0 * d.stall_speed_kt), 0.0, 1.0)
	aircraft.crash(severity)
	var fx := Node2D.new()
	fx.set_script(CrashEffect)
	fx.severity = severity
	fx.position = aircraft.position
	add_child(fx)
	var result := _base_result()
	result["grade"] = "CRASH"
	result["title"] = "CRASH"
	result["reasons"] = [reason]
	if fpm >= 0.0:
		result["touchdown_fpm"] = fpm
	hud.messages.say("You CRASHED it! %s R, phir se karo!" % reason, true)
	_end(result)


func _base_result() -> Dictionary:
	return {
		"time_s": flight_time_s,
		"fuel_used_kg": aircraft.data.fuel_capacity_kg - aircraft.fuel_kg,
		"fuel_capacity_kg": aircraft.data.fuel_capacity_kg,
	}


func _end(result: Dictionary) -> void:
	state = State.DONE
	aircraft.controls_enabled = false
	hud.flight_over = true
	flight_finished.emit(result)
	await get_tree().create_timer(result_delay_s).timeout
	result_screen.show_result(result)


# --- Scenery ---

## Night flight: the world canvas is darkened (lights use GameState.glow to
## stay bright), dark sky with stars, aircraft lights on.
func _setup_night() -> void:
	var tint := CanvasModulate.new()
	tint.color = GameState.NIGHT_TINT
	add_child(tint)
	var stars := preload("res://scenes/world/stars.gd").new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Sky.add_child(stars)
	aircraft.night_lights = true


func _update_theme() -> void:
	var t := smoothstep(0.15, 0.85, aircraft.pos_m.x / route_distance_m)
	sky.modulate = night_sky_tint if GameState.night else departure.sky_tint.lerp(destination.sky_tint, t)
	mountains.color = departure.mountain_color.lerp(destination.mountain_color, t)
	mountains.height_scale = lerpf(departure.mountain_height, destination.mountain_height, t)
	hills.color = departure.hill_color.lerp(destination.hill_color, t)
	trees.color = departure.tree_color.lerp(destination.tree_color, t)
