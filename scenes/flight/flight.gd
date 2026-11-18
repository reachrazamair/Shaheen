extends Node2D
## One flight: departure base -> destination base, aircraft, camera, scenery,
## HUD, and the landing judge (chunk 1.7).
## One shared world: the departure (Risalpur) and EVERY base in
## GameState.DESTINATIONS stand along the route at their route_distance_m, so
## the player can divert and land anywhere. The flight passes only if they
## land at the destination chosen on the start screen. The scenery theme
## blends from one base's look to the next as the plane flies.
##
## Flight states:
##   PREFLIGHT - on the departure runway, not yet airborne
##   FLYING    - airborne (also after a bounce)
##   ROLLOUT   - touched down on a runway, braking to a stop
##   STOPOVER  - stopped at a base BEFORE the destination: T calls the fuel
##               truck (engine off), then take off again for the destination
##   DONE      - result screen showing (landed, wrong base or crashed)
##
## Air-to-ground mission (GameState.Mission.STRIKE): only the departure and
## one landing base (random from DESTINATIONS) stand in the world; targets
## lie between them (StrikeMission). The landing base stays hidden (not
## drawn, not a runway, not on the radar) until the attack is over.

signal flight_finished(result: Dictionary)

enum State { PREFLIGHT, FLYING, ROLLOUT, STOPOVER, DONE }
const GRADES := ["PERFECT", "GOOD", "FIRM", "HARD"]
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CrashEffect := preload("res://scenes/world/crash_effect.gd")
const BaseScene := preload("res://scenes/world/base.tscn")
const FuelTruck := preload("res://scenes/world/fuel_truck.gd")

@export var departure: BaseData
## The base the player must land at (overridden by GameState.destination_path).
@export var destination: BaseData
## Distance to a base that has no route_distance_m of its own. Compressed so a trainer flight takes about
## a minute and a half (the real distance to Masroor, Karachi, is ~1,200 km).
@export var route_distance_m := 5000.0
## Sky gradient tint at night (top dark navy, faint glow at the horizon).
@export var night_sky_tint := Color(0.07, 0.09, 0.2)
## Night: the aircraft is multiplied by this on top of the night tint so it
## stays visible (1 = as dark as the scenery).
@export var night_aircraft_boost := Color(2.4, 2.1, 1.5)
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
@onready var landmarks: Node2D = $Landmarks

var state := State.PREFLIGHT
var flight_time_s := 0.0
var _airborne_once := false
var _landed_on := -1            ## index into _bases during rollout
## Every base in the world, by distance: [threshold x (m), BaseData, node].
## Index 0 is the departure.
var _bases: Array = []
var _truck: Node2D
## Air-to-ground mission, or null on a ferry flight.
var strike: StrikeMission
var _pause_menu: PauseMenu
## Fuel added by trucks at stopovers (kg) and where.
var _refuelled_kg := 0.0
var _refuelled_at: Array[String] = []
var _worst_touchdown_fpm := 0.0
var _overran := false
var _nose_wheel_first := false  ## a touchdown came down slightly nose-low: one grade lower


func _ready() -> void:
	if GameState.aircraft_path != "":
		aircraft.set_data(load(GameState.aircraft_path))
	if GameState.mission == GameState.Mission.STRIKE:
		strike = StrikeMission.new()
		strike.plan()
		destination = load(GameState.DESTINATIONS.pick_random())
		route_distance_m = strike.recovery_x_m
	else:
		if GameState.destination_path != "":
			destination = load(GameState.destination_path)
		if destination.route_distance_m > 0.0:
			route_distance_m = destination.route_distance_m
	_build_world()
	aircraft.place_at(spawn_x_m)
	if GameState.night:
		_setup_night()
	camera.snap()
	hud.strike = strike
	hud.setup(aircraft, departure, destination, route_distance_m)
	for b in _bases.slice(1):
		if b[1] != destination:
			hud.radar.other_bases.append([b[0], b[1].runway_length_m])
	aircraft.lifted_off.connect(_on_lifted_off)
	aircraft.touched_down.connect(_on_touched_down)
	aircraft.tail_struck.connect(_on_tail_struck)
	# Sound: added after the landing judge's connections, so a touchdown that
	# crashes is already marked crashed when the audio hears it.
	var audio := AircraftAudio.new()
	audio.aircraft = aircraft
	add_child(audio)
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.restart_pressed.connect(_retry)
	_pause_menu.menu_pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	if strike:
		add_child(strike)
		strike.setup(self, aircraft, aircraft, hud)
		strike.revealed.connect(_on_strike_revealed)
		_set_base_hidden(_bases.size() - 1, true)
	result_screen.retry_pressed.connect(_retry)
	result_screen.menu_pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	_update_theme()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_retry()
	elif event.is_action_pressed("refuel"):
		_request_refuel()


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

## Builds the shared world: departure at x = 0, then every base in
## GameState.DESTINATIONS at its route distance; ground colours and
## landmarks for all of them.
func _build_world() -> void:
	departure_base.data = departure
	_bases = [[0.0, departure, departure_base]]
	# [BaseData, threshold x m] for every other base in this world.
	var others: Array = []
	if strike:
		others.append([destination, route_distance_m])
	else:
		for path in GameState.DESTINATIONS:
			var b: BaseData = load(path)
			others.append([b, b.route_distance_m if b.route_distance_m > 0.0 else route_distance_m])
	var reused := false
	for o in others:
		var b: BaseData = o[0]
		var node: Node2D = destination_base
		if reused:
			node = BaseScene.instantiate()
			add_child(node)
			move_child(node, destination_base.get_index() + 1)
		reused = true
		node.data = b
		var x: float = o[1]
		node.position.x = x * WorldScale.PX_PER_M
		_bases.append([x, b, node])
	_bases.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var last: Array = _bases[_bases.size() - 1]
	ground.end_m = last[0] + last[1].runway_length_m + 3000.0
	# Ground colour: each base's colour holds around it and blends across the gap to the next.
	var xs := PackedFloat32Array()
	var grass := PackedColorArray()
	var tufts := PackedColorArray()
	for i in _bases.size() - 1:
		var end: float = _bases[i][0] + _bases[i][1].runway_length_m
		var gap: float = _bases[i + 1][0] - end
		xs.append(end + gap * 0.25)
		grass.append(_bases[i][1].ground_color)
		tufts.append(_bases[i][1].ground_tuft_color)
		xs.append(end + gap * 0.7)
		grass.append(_bases[i + 1][1].ground_color)
		tufts.append(_bases[i + 1][1].ground_tuft_color)
	ground.set_stops(xs, grass, tufts)
	_setup_landmarks()


## Background landmarks of every visible base.
func _setup_landmarks() -> void:
	var marks: Array = []
	for b in _bases:
		if b[2].visible:
			marks.append([b[1].landmarks, b[0]])
	landmarks.setup(marks)


## Strike mission: the landing base is hidden until the attack is over.
func _set_base_hidden(i: int, hidden: bool) -> void:
	_bases[i][2].visible = not hidden
	_setup_landmarks()


func _on_strike_revealed() -> void:
	_set_base_hidden(_bases.size() - 1, false)
	hud.radar.show_destination = true


## Index (into _bases) of the runway under a given x (m), or -1.
func runway_at(x_m: float) -> int:
	for i in _bases.size():
		if _bases[i][2].visible and x_m >= _bases[i][0] and x_m <= _bases[i][0] + _bases[i][1].runway_length_m:
			return i
	return -1


func _on_lifted_off() -> void:
	if state == State.DONE:
		return
	if state == State.STOPOVER:
		# Off again from the stopover: only the landing at the destination is graded.
		_worst_touchdown_fpm = 0.0
		_nose_wheel_first = false
		_overran = false
		hud.messages.say("Off again! Next stop %s. Clean it up and CLIMB!" % destination.short_name.capitalize(), true)
	elif state == State.ROLLOUT:
		hud.messages.say("You BOUNCED it, d*mn it! Hold the nose, settle it down! Gently!", true)
	_airborne_once = true
	state = State.FLYING


func _on_touched_down(vertical_speed_ms: float) -> void:
	if state != State.FLYING:
		return
	var d := aircraft.data
	var fpm := absf(vertical_speed_ms) * WorldScale.M_TO_FT * 60.0
	_worst_touchdown_fpm = maxf(_worst_touchdown_fpm, fpm)
	var where := runway_at(aircraft.pos_m.x)
	if where < 0:
		_crash("Touched down off the runway.", fpm)
	elif aircraft.gear_pos < 0.95:
		_crash("The gear was up: belly landing.", fpm)
	elif absf(rad_to_deg(aircraft.touchdown_pitch)) > 90.0:
		_crash("Hit the ground upside down.", fpm)
	elif rad_to_deg(aircraft.touchdown_pitch) > d.tail_strike_pitch_deg:
		_crash("Tail strike: the nose was far too high at touchdown.", fpm)
	elif rad_to_deg(aircraft.touchdown_pitch) < -d.nose_first_crash_deg:
		_crash("Slammed it onto the nose wheel: flare before touchdown.", fpm)
	elif fpm > d.hard_touchdown_fpm:
		_crash("Far too hard: %d ft/min. The gear collapsed." % roundi(fpm), fpm)
	else:
		if rad_to_deg(aircraft.touchdown_pitch) < -d.max_nose_down_touchdown_deg:
			_nose_wheel_first = true
			hud.messages.say("NOSE WHEEL FIRST?! Main wheels first, raise the nose before touchdown!", true)
		state = State.ROLLOUT
		_landed_on = where


func _on_tail_struck() -> void:
	if state == State.DONE:
		return
	var sink := maxf(-aircraft.velocity_m.y, 0.0) * WorldScale.M_TO_FT * 60.0
	_crash("Tail strike: you over-rotated. Too much nose-up near the ground.", sink)


## On the ground: overrun / off-runway checks, and the end of the rollout.
func _check_ground_roll() -> void:
	var x := aircraft.pos_m.x
	var on_runway := runway_at(x) >= 0
	if not on_runway and aircraft.speed_kt > aircraft.data.overrun_crash_speed_kt:
		_crash("Ran off the end of the runway.", _worst_touchdown_fpm if state == State.ROLLOUT else -1.0)
		return
	if not on_runway and state == State.ROLLOUT:
		_overran = true
	if state == State.ROLLOUT and aircraft.speed_kt < 1.0:
		if _is_stopover(_landed_on):
			_begin_stopover()
		else:
			_finish_landing()


# --- Refuelling stop ---

## A base between the departure and the destination: landing there is a
## stop (refuel with T, then take off again), not the end of the flight.
func _is_stopover(i: int) -> bool:
	return i > 0 and _bases[i][1] != destination and _bases[i][0] < route_distance_m


func _begin_stopover() -> void:
	state = State.STOPOVER
	hud.messages.say("Down at %s. Engine OFF with E, then T for the fuel truck. Then on to %s!" % [
			_bases[_landed_on][1].short_name.capitalize(), destination.short_name.capitalize()], true)


func _request_refuel() -> void:
	if state == State.DONE or _truck != null:
		return
	var a := aircraft
	if state != State.STOPOVER:
		if a.on_ground and _airborne_once and runway_at(a.pos_m.x) >= 0:
			hud.messages.say("Fuel truck? Stop the aircraft FIRST!", true)
		return
	if a.speed_kt > 1.0:
		hud.messages.say("Fuel truck? Stop the aircraft FIRST!", true)
	elif a.engine_on or a.engine_rpm > 0.01:
		hud.messages.say("Engine OFF first, E! You want to blow the truck up?!", true)
	elif a.fuel_kg >= a.data.fuel_capacity_kg - 0.5:
		hud.messages.say("Tanks are already FULL. Start up and GO!", true)
	else:
		_truck = FuelTruck.new()
		_truck.aircraft = a
		_truck.camera = camera
		add_child(_truck)
		move_child(_truck, aircraft.get_index())     # drawn behind the aircraft
		a.controls_enabled = false
		hud.messages.say("Fuel truck's coming. Sit still and don't touch ANYTHING!")
		_truck.fuelled.connect(_on_fuelled)
		_truck.hose_stowed.connect(_on_hose_stowed)
		_truck.finished.connect(_on_truck_gone)


func _on_fuelled() -> void:
	_refuelled_kg += _truck.added_kg
	var here: String = _bases[_landed_on][1].short_name.capitalize()
	if not _refuelled_at.has(here):
		_refuelled_at.append(here)
	hud.on_refuelled()
	hud.messages.say("Tanks FULL. Hose coming off. Hands OFF until it's clear!", true)


func _on_hose_stowed() -> void:
	if state == State.STOPOVER:
		aircraft.controls_enabled = true
		hud.messages.say("Hose is clear. E, start up, and get to %s. GO!" % destination.short_name.capitalize(), true)


func _on_truck_gone() -> void:
	_truck = null


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
	var landed_base: BaseData = _bases[_landed_on][1]
	if landed_base != destination:
		var here := landed_base.short_name.capitalize()
		var dest := destination.short_name.capitalize()
		result["grade"] = "WRONG BASE"
		result["title"] = "WRONG BASE"
		result["reasons"] = ["You landed %s %s. Your destination was %s." % [
				"back at" if _landed_on == 0 else "at", here, dest]]
		hud.messages.say("That's %s, %s! %s was the destination! Did you even READ the brief?!" % [here,
				GameState.pilot_call(), dest], true)
	else:
		var g := _grade_for(_worst_touchdown_fpm)
		var reasons: Array[String] = []
		if _nose_wheel_first:
			g = mini(g + 1, GRADES.size() - 1)
			reasons.append("Nose wheel touched first (one grade lower).")
		if _overran:
			g = mini(g + 1, GRADES.size() - 1)
			reasons.append("Rolled past the runway end (one grade lower).")
		result["grade"] = GRADES[g]
		result["title"] = GRADES[g] + " LANDING"
		reasons.push_front("Landed at %s." % destination.display_name)
		for b in _refuelled_at:
			reasons.append("Refuelled at %s." % b)
		result["reasons"] = reasons
		var praise := ["Perfect. Well done, %s. Don't let it go to your head.", "Good landing, %s. Not bad. Not bad at all.",
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
	var severity := clampf(sink / (3.0 * d.hard_touchdown_fpm)
			+ maxf(aircraft.speed_kt / d.stall_speed_kt - 1.0, 0.0) * 0.5, 0.0, 1.0)
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
	hud.messages.say("You CRASHED my sh*tting aircraft! %s R. Do it AGAIN!" % reason, true)
	_end(result)


func _base_result() -> Dictionary:
	return {
		"time_s": flight_time_s,
		"fuel_used_kg": aircraft.data.fuel_capacity_kg - aircraft.fuel_kg + _refuelled_kg,
		"fuel_capacity_kg": aircraft.data.fuel_capacity_kg,
	}


func _end(result: Dictionary) -> void:
	if strike:
		var reasons: Array = result.get("reasons", [])
		reasons.append("Targets destroyed: %d of %d." % [strike.targets_destroyed, strike.targets.size()])
		result["reasons"] = reasons
	state = State.DONE
	_pause_menu.enabled = false
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
	# Keep the aircraft readable: brighter than the dark world around it.
	aircraft.modulate = night_aircraft_boost


## Scenery theme at the plane: the nearest base's look, blending across the
## gap between one base's runway end and the next base's threshold.
func _update_theme() -> void:
	var x := aircraft.pos_m.x
	var a: BaseData = _bases[0][1]
	var b: BaseData = a
	var t := 0.0
	for i in _bases.size() - 1:
		var end: float = _bases[i][0] + _bases[i][1].runway_length_m
		if x < _bases[i + 1][0] or i == _bases.size() - 2:
			a = _bases[i][1]
			b = _bases[i + 1][1]
			t = smoothstep(0.15, 0.85, (x - end) / maxf(_bases[i + 1][0] - end, 1.0))
			break
	sky.modulate = night_sky_tint if GameState.night else a.sky_tint.lerp(b.sky_tint, t)
	mountains.color = a.mountain_color.lerp(b.mountain_color, t)
	mountains.height_scale = lerpf(a.mountain_height, b.mountain_height, t)
	hills.color = a.hill_color.lerp(b.hill_color, t)
	trees.color = a.tree_color.lerp(b.tree_color, t)
