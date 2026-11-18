class_name AircraftAudio
extends Node
## All the sounds of the player's aircraft, made in code by SoundSynth.
## Looping sounds (engine, wind, tyre rumble, warnings, gear motor) play all
## the time they're needed and follow the aircraft's state every frame via
## volume and pitch; one-shots (touchdown, gear clunk, crash) fire on events.
## The flight scene adds this node and sets `aircraft`.
##
## Per-aircraft engine numbers live in AircraftData ("Sound"); the mix of
## everything else is tuned here.

@export var aircraft: Aircraft

@export_group("Mix (dB)")
## Added to every sound of the aircraft (a mix trim; players set their own
## level with the Master / Engine / Effects sliders in the pause menu).
@export var master_volume_db := 0.0
## Rushing air at the aircraft's max speed (grows with speed squared).
@export var wind_volume_db := -12.0
## Tyre rumble on the ground at rumble_full_speed_kt.
@export var rumble_volume_db := -10.0
@export var rumble_full_speed_kt := 90.0
## Jet roar under the turbine whine, relative to engine_volume_db.
@export var jet_roar_offset_db := -2.0
@export var stall_horn_volume_db := -12.0
@export var gear_warning_volume_db := -14.0
@export var gear_motor_volume_db := -16.0
@export var gear_clunk_volume_db := -8.0
## Touchdown thump at the hardest legal touchdown (softer landings are quieter).
@export var touchdown_volume_db := -2.0
@export var squeal_volume_db := -10.0
@export var crash_volume_db := 0.0

@export_group("Feel")
## How quickly volumes and pitches follow the aircraft (higher = snappier).
@export var smoothing := 10.0

var _engine: AudioStreamPlayer
var _roar: AudioStreamPlayer
var _ab: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _rumble: AudioStreamPlayer
var _horn: AudioStreamPlayer
var _beep: AudioStreamPlayer
var _motor: AudioStreamPlayer
var _thump: AudioStreamPlayer
var _squeal: AudioStreamPlayer
var _crash: AudioStreamPlayer
var _clunk: AudioStreamPlayer
var _loops: Array[AudioStreamPlayer] = []
## Current linear volume per loop player (smoothed toward the target).
var _vol := {}
var _was_in_transit := false
var _wrecked := false


func _ready() -> void:
	assert(aircraft != null, "AircraftAudio needs the aircraft")
	var jet := aircraft.data.engine_sound == 1
	_engine = _loop(SoundSynth.jet_whine() if jet else SoundSynth.piston(), &"Engine")
	_roar = _loop(SoundSynth.roar(), &"Engine") if jet else null
	_ab = _loop(SoundSynth.afterburner(), &"Engine") if aircraft.data.afterburner_thrust_n > 0.0 else null
	_wind = _loop(SoundSynth.roar())
	_rumble = _loop(SoundSynth.roar())
	_horn = _loop(SoundSynth.stall_horn())
	_beep = _loop(SoundSynth.gear_beep())
	_motor = _loop(SoundSynth.gear_motor()) if aircraft.data.retractable_gear else null
	_thump = _one_shot(SoundSynth.thump())
	_clunk = _one_shot(SoundSynth.thump())
	_squeal = _one_shot(SoundSynth.squeal())
	_crash = _one_shot(SoundSynth.crash())
	aircraft.touched_down.connect(_on_touched_down)
	aircraft.wrecked.connect(_on_wrecked)
	_was_in_transit = aircraft.gear_in_transit


func _process(delta: float) -> void:
	if _wrecked:
		return
	var a := aircraft
	var d := a.data
	var k := 1.0 - exp(-smoothing * delta)

	# Engine: the note follows power, and drops away as the RPM winds down.
	var dry := clampf(a.throttle / d.afterburner_threshold, 0.0, 1.0) if d.afterburner_thrust_n > 0.0 else a.throttle
	var power := dry * a.engine_rpm
	var rpm_fade := smoothstep(0.0, 0.3, a.engine_rpm)
	var pitch := lerpf(d.engine_pitch_idle, d.engine_pitch_full, power) * lerpf(0.35, 1.0, a.engine_rpm)
	var eng_db := d.engine_volume_db - d.engine_idle_drop_db * (1.0 - power)
	_drive(_engine, rpm_fade * db_to_linear(eng_db), pitch, k)
	if _roar:
		_drive(_roar, rpm_fade * db_to_linear(eng_db + jet_roar_offset_db), lerpf(0.5, 1.1, power), k)
	if _ab:
		var ab := a.afterburner
		_drive(_ab, ab * db_to_linear(d.afterburner_volume_db), 0.85 + 0.25 * ab, k)

	# Air rushing past: grows with speed squared, more with the air brake out.
	var s := clampf(a.speed_kt / maxf(d.max_speed_kt, 1.0), 0.0, 1.3)
	var wind := s * s * (1.6 if a.airbrake_out else 1.0)
	_drive(_wind, wind * db_to_linear(wind_volume_db), 0.6 + 0.9 * s, k)

	# Tyres rolling on the runway.
	var roll := clampf(a.speed_kt / rumble_full_speed_kt, 0.0, 1.0) if a.on_ground else 0.0
	_drive(_rumble, roll * db_to_linear(rumble_volume_db), 0.25 + 0.35 * roll, k)

	# Warnings snap on and off (no fade).
	_drive(_horn, db_to_linear(stall_horn_volume_db) if a.stalled else 0.0, 1.0, 1.0)
	_drive(_beep, db_to_linear(gear_warning_volume_db) if a.gear_warning else 0.0, 1.0, 1.0)

	# Gear motor while it moves; a clunk when it locks up or down.
	if _motor:
		var moving := a.gear_in_transit
		_drive(_motor, db_to_linear(gear_motor_volume_db) if moving else 0.0, 1.0 if a.gear_down else 1.15, k)
		if _was_in_transit and not moving:
			_play(_clunk, gear_clunk_volume_db, 1.6)
		_was_in_transit = moving


func _on_touched_down(vertical_speed_ms: float) -> void:
	if aircraft.crashed:
		return   # the crash sound covers it
	var fpm := absf(vertical_speed_ms) * WorldScale.M_TO_FT * 60.0
	var hard := clampf(fpm / maxf(aircraft.data.hard_touchdown_fpm, 1.0), 0.0, 1.0)
	_play(_thump, touchdown_volume_db + linear_to_db(lerpf(0.25, 1.0, hard)), lerpf(1.2, 0.85, hard))
	var fast := clampf(aircraft.speed_kt / maxf(aircraft.data.stall_speed_kt, 1.0), 0.3, 1.2)
	_play(_squeal, squeal_volume_db + linear_to_db(fast), randf_range(0.95, 1.05))


func _on_wrecked(severity: float) -> void:
	_wrecked = true
	for p in _loops:
		p.stop()
	_play(_crash, crash_volume_db + linear_to_db(lerpf(0.5, 1.0, severity)), lerpf(1.15, 0.8, severity))


# --- Helpers ---

## Engine sounds go to the "Engine" bus, everything else to "Effects".
func _loop(stream: AudioStream, bus := &"Effects") -> AudioStreamPlayer:
	var p := _one_shot(stream)
	p.bus = bus
	_loops.append(p)
	_vol[p] = 0.0
	return p


func _one_shot(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"Effects"
	add_child(p)
	return p


## Moves a loop toward a linear volume and a pitch; stops it when silent.
func _drive(p: AudioStreamPlayer, target: float, pitch: float, k: float) -> void:
	var v: float = lerpf(_vol[p], target, k)
	if v < 0.002 and target < 0.002:
		v = 0.0
	_vol[p] = v
	if v <= 0.0:
		if p.playing:
			p.stop()
		return
	p.volume_db = linear_to_db(v) + master_volume_db
	if p.playing:
		p.pitch_scale = clampf(lerpf(p.pitch_scale, pitch, k), 0.05, 4.0)
	else:
		p.pitch_scale = clampf(pitch, 0.05, 4.0)
		p.play()


func _play(p: AudioStreamPlayer, db: float, pitch: float) -> void:
	p.volume_db = db + master_volume_db
	p.pitch_scale = pitch
	p.play()
