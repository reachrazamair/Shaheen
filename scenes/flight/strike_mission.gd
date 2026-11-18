class_name StrikeMission
extends Node2D
## Air-to-ground mission (GameState.Mission.STRIKE), added by the flight scene.
## Take off from the departure base; 2-3 ground targets stand at random spots
## a few km out; the jet carries data.bomb_count free-fall bombs (Space drops
## one). The landing base (random real base) stands beyond the targets but is
## hidden until the attack is over: every target destroyed, every bomb gone
## off, or the plane past the last target. Then it "appears" and the flight
## lands there as usual (landing judge in flight.gd).
## Draws the aiming marker (where a bomb dropped now would hit) itself.

signal revealed

@export_group("Layout (metres from the departure threshold)")
## First target this far out.
@export var area_start_m := 4500.0
## Gap between targets (random in this range).
@export var spacing_min_m := 700.0
@export var spacing_max_m := 1300.0
@export var target_count_min := 2
@export var target_count_max := 3
## Landing base threshold this far beyond the last target.
@export var recovery_gap_m := 3000.0
## The attack counts as over once the plane is this far past the last target.
@export var pass_margin_m := 300.0

@export_group("Aiming marker")
@export var show_impact_marker := true
@export var marker_color := Color(0.45, 1.0, 0.45)
@export var marker_on_target_color := Color(1.0, 0.3, 0.2)

@export_group("Instructor")
## "Targets ahead" call at this distance from the first live target.
@export var targets_ahead_call_m := 3000.0

var aircraft: Aircraft
var hud: CanvasLayer
var targets: Array[GroundTarget] = []
var target_x_m := PackedFloat32Array()
var recovery_x_m := 0.0
var is_revealed := false
var bombs_in_air := 0
var _kinds: Array = []
var _rng := RandomNumberGenerator.new()
var _said := {}
## Where a bomb released now would land (m), and whether the marker is shown.
var impact_x := 0.0
var _marker_visible := false
## Bombs still falling (plain Array: a bomb is freed when it goes off).
var _falling: Array = []
var _boom: AudioStreamPlayer
var _release: AudioStreamPlayer


var targets_destroyed: int:
	get:
		var n := 0
		for t in targets:
			if t.destroyed:
				n += 1
		return n


## Random layout for this mission (call before the world is built).
func plan() -> void:
	_rng.randomize()
	var n := _rng.randi_range(target_count_min, target_count_max)
	var kinds := GroundTarget.KINDS.duplicate()
	kinds.shuffle()
	var x := area_start_m + _rng.randf_range(0.0, 500.0)
	for i in n:
		target_x_m.append(x)
		_kinds.append(kinds[i % kinds.size()])
		x += _rng.randf_range(spacing_min_m, spacing_max_m)
	recovery_x_m = target_x_m[n - 1] + recovery_gap_m


## Places the targets in the world (as children of `world`, drawn behind
## `draw_before`) and hooks up the aircraft.
func setup(world: Node2D, draw_before: Node, a: Aircraft, h: CanvasLayer) -> void:
	aircraft = a
	hud = h
	for i in target_x_m.size():
		var t := GroundTarget.new()
		t.kind = _kinds[i]
		t.x_m = target_x_m[i]
		world.add_child(t)
		world.move_child(t, draw_before.get_index())
		targets.append(t)
	a.bombs_left = a.data.bomb_count
	a.bomb_released.connect(_on_bomb_released.bind(world, draw_before))
	_boom = _player(SoundSynth.crash())
	_release = _player(SoundSynth.thump())
	z_index = 1


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"Effects"
	add_child(p)
	return p


## Metres to the next target still standing ahead (or the nearest one), INF if none.
func distance_to_next_target() -> float:
	var best := INF
	for t in targets:
		if not t.destroyed and t.x_m > aircraft.pos_m.x - 50.0:
			best = minf(best, t.x_m - aircraft.pos_m.x)
	return best


func _physics_process(_delta: float) -> void:
	if aircraft == null:
		return
	var a := aircraft
	if not is_revealed and not a.crashed:
		var d := distance_to_next_target()
		if not a.on_ground and d < targets_ahead_call_m:
			_once("ahead", "Targets %.1f km! Watch the BOMB SIGHT: target under the cross, SPACE! Steady!" % (d / 1000.0))
		var all_hit := targets_destroyed == targets.size()
		var dry := a.bombs_left == 0 and bombs_in_air == 0
		var past := a.pos_m.x > target_x_m[target_x_m.size() - 1] + pass_margin_m
		if all_hit or dry or past:
			_reveal()
	# Aiming marker: where a bomb released now would land.
	_marker_visible = show_impact_marker and a.bombs_left > 0 and not a.on_ground and not a.crashed
	if _marker_visible:
		var hp := a.data.bomb_hardpoints[mini(a.bombs_left - 1, a.data.bomb_hardpoints.size() - 1)]
		var pos := a.hardpoint_m(hp + Vector2(0.0, a.data.bomb_diameter_px * 0.5))
		var down := Vector2(sin(a.pitch), -cos(a.pitch)) * a.data.bomb_eject_ms
		impact_x = Bomb.predict_impact_x(pos, a.velocity_m + down, a.data.bomb_drag)
	queue_redraw()


func _draw() -> void:
	if not _marker_visible:
		return
	var on := target_at(impact_x) != null
	var col := GameState.glow(marker_on_target_color if on else marker_color)
	var p := Vector2(impact_x * WorldScale.PX_PER_M, -1.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)]),
			Color(col, 0.35))
	draw_polyline(PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0), p + Vector2(0, -7)]),
			col, 1.5)
	for k in 6:
		draw_rect(Rect2(p.x - 0.5, p.y - 12 - k * 6, 1, 3), Color(col, 0.8 - k * 0.12))


## The live target a bomb hitting x would destroy, or null.
func target_at(x: float) -> GroundTarget:
	var r := aircraft.data.bomb_blast_radius_m
	for t in targets:
		if not t.destroyed and absf(x - t.x_m) <= r + t.half_width_m:
			return t
	return null


func _on_bomb_released(pos: Vector2, vel: Vector2, world: Node2D, draw_before: Node) -> void:
	var d := aircraft.data
	var b := Bomb.new()
	b.pos_m = pos
	b.vel_m = vel
	b.drag = d.bomb_drag
	b.length_px = d.bomb_length_px * d.sprite_scale
	b.diameter_px = d.bomb_diameter_px * d.sprite_scale
	b.impacted.connect(_on_impact)
	world.add_child(b)
	world.move_child(b, draw_before.get_index())
	_falling.append(b)
	bombs_in_air += 1
	_release.pitch_scale = 1.6
	_release.volume_db = -10.0
	_release.play()
	if not _said.has("first_drop"):
		_said["first_drop"] = true
		hud.messages.say("Bomb away! Watch it fall...", true)


## Predicted impact x (m) of every bomb still falling.
func falling_impacts() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for b in _falling:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			out.append(Bomb.predict_impact_x(b.pos_m, b.vel_m, b.drag))
	return out


func _on_impact(x: float) -> void:
	bombs_in_air -= 1
	var still: Array = []
	for b in _falling:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			still.append(b)
	_falling = still
	var fx := Node2D.new()
	fx.set_script(preload("res://scenes/world/crash_effect.gd"))
	fx.severity = 0.85
	fx.position = Vector2(x * WorldScale.PX_PER_M, 0.0)
	get_parent().add_child(fx)
	_boom.volume_db = -4.0
	_boom.play()
	if aircraft.crashed:
		return
	var hit := target_at(x)
	if hit:
		hit.destroy()
		var left := targets.size() - targets_destroyed
		if left == 0:
			hud.messages.say("ALL TARGETS DESTROYED! Sh*t hot, %s! Now don't crash on the way home!" % GameState.pilot_call(), true)
		else:
			hud.messages.say("TARGET DESTROYED! %d to go. Next one under the cross!" % left, true)
	else:
		var miss := INF
		for t in targets:
			if not t.destroyed:
				miss = minf(miss, absf(x - t.x_m) - t.half_width_m)
		if miss < INF:
			hud.messages.say("MISSED by %d m! Target UNDER the cross, then drop, d*mn it!" % roundi(maxf(miss, 1.0)), true)


func _reveal() -> void:
	is_revealed = true
	revealed.emit()
	var dest: String = hud.destination.short_name.capitalize()
	var km := maxf(recovery_x_m - aircraft.pos_m.x, 0.0) / 1000.0
	var hits := targets_destroyed
	var lead := "Attack over, %d of %d hit." % [hits, targets.size()] if hits < targets.size() else "Job done."
	# Short message so the bomb-hit call before it can still be read.
	await get_tree().create_timer(2.5 if hits > 0 else 0.5).timeout
	if is_instance_valid(hud) and not hud.flight_over:
		hud.messages.say("%s Land at %s, %.1f km ahead. Gear, flaps, GO!" % [lead, dest, km], true)


func _once(key: String, text: String) -> void:
	if not _said.has(key):
		_said[key] = true
		hud.messages.say(text, true)
