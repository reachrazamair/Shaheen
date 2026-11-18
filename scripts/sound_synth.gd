class_name SoundSynth
extends RefCounted
## Every game sound is made here in code (no audio files): short mono 16-bit
## AudioStreamWAV buffers, built once per session and cached. Loops are
## seamless (tones fit a whole number of cycles in the loop, noise loops are
## cross-faded end-to-start), so a player can vary pitch_scale and volume_db
## every frame to follow the engine and airspeed.
##
## The numbers here shape the raw sounds; how loud and how high they play in
## flight is tuned in AircraftData ("Sound") and aircraft_audio.gd.

const RATE := 22050

static var _cache := {}


## Piston engine + propeller (Super Mushshak). Firing pulses at 50 Hz with a
## propeller buzz on top; pitch_scale raises the RPM.
static func piston() -> AudioStreamWAV:
	return _cached("piston", func() -> AudioStreamWAV:
		var n := int(RATE * 0.5)
		var f0 := 50.0                  # 25 cycles in the loop
		var rng := _rng(11)
		var pop_amp := PackedFloat32Array()
		for k in 26:
			pop_amp.append(rng.randf_range(0.7, 1.0))
		var noise := _lowpass(_white(n, 12), 0.35)
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var ph := f0 * i / RATE
			var k := int(ph)
			var fr := ph - k
			var pop := exp(-7.0 * fr) * pop_amp[k] * (0.6 + 0.8 * noise[i])
			var body := 0.45 * sin(TAU * ph) + 0.25 * sin(TAU * 2.0 * ph)
			var buzz := 0.22 * _saw(3.0 * ph)     # three-blade propeller
			out[i] = tanh(1.6 * (0.7 * pop + body + buzz))
		return _wav(out, true))


## Jet turbine whine: two close tones that beat slightly. pitch_scale = spool.
static func jet_whine() -> AudioStreamWAV:
	return _cached("whine", func() -> AudioStreamWAV:
		var n := int(RATE * 0.5)
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var t := float(i) / RATE
			out[i] = 0.5 * sin(TAU * 1500.0 * t) + 0.3 * sin(TAU * 1730.0 * t) + 0.04 * sin(TAU * 3000.0 * t)
		return _wav(out, true))


## Jet roar / wind / tyre rumble: low-passed noise. pitch_scale brightens it.
static func roar() -> AudioStreamWAV:
	return _cached("roar", func() -> AudioStreamWAV:
		var n := RATE
		var x := _lowpass(_lowpass(_white(n + 2000, 21), 0.18), 0.25)
		return _wav(_crossfade_loop(_normalise(x), 2000), true))


## Afterburner: deep rumble with crackle (random pops in brown noise).
static func afterburner() -> AudioStreamWAV:
	return _cached("ab", func() -> AudioStreamWAV:
		var n := RATE
		var rng := _rng(31)
		var x := _lowpass(_white(n + 2000, 32), 0.06)
		var crackle := 0.0
		for i in x.size():
			if rng.randf() < 0.004:
				crackle = rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			crackle *= 0.93
			x[i] += crackle * 0.06
		return _wav(_crossfade_loop(_normalise(x), 2000), true))


## Stall warning horn: a harsh steady tone (square-ish, 900 Hz).
static func stall_horn() -> AudioStreamWAV:
	return _cached("horn", func() -> AudioStreamWAV:
		var n := int(RATE * 0.25)       # 225 cycles
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var ph := 900.0 * i / RATE
			out[i] = 0.6 * tanh(4.0 * sin(TAU * ph)) + 0.2 * sin(TAU * 2.0 * ph)
		return _wav(out, true))


## Gear warning: beep-beep (1 kHz, on 0.15 s, off 0.15 s).
static func gear_beep() -> AudioStreamWAV:
	return _cached("gearbeep", func() -> AudioStreamWAV:
		var n := int(RATE * 0.3)
		var on := int(RATE * 0.15)
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var env := clampf(minf(i, on - i) / 120.0, 0.0, 1.0) if i < on else 0.0
			out[i] = env * 0.7 * tanh(3.0 * sin(TAU * 1000.0 * i / RATE))
		return _wav(out, true))


## Gear motor / hydraulics: a buzzing hum while the gear moves.
static func gear_motor() -> AudioStreamWAV:
	return _cached("motor", func() -> AudioStreamWAV:
		var n := int(RATE * 0.5)
		var noise := _lowpass(_white(n, 41), 0.3)
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var ph := 120.0 * i / RATE
			out[i] = 0.4 * _saw(ph) + 0.2 * sin(TAU * 2.0 * ph) + 0.3 * noise[i]
		return _wav(out, true))


## Short thump: gear locking, touchdown. Falling low sine plus a click.
static func thump() -> AudioStreamWAV:
	return _cached("thump", func() -> AudioStreamWAV:
		var n := int(RATE * 0.25)
		var noise := _lowpass(_white(n, 51), 0.4)
		var out := PackedFloat32Array()
		out.resize(n)
		var ph := 0.0
		for i in n:
			var t := float(i) / RATE
			ph += lerpf(90.0, 40.0, t / 0.25) / RATE
			out[i] = exp(-18.0 * t) * sin(TAU * ph) + exp(-60.0 * t) * noise[i] * 0.8
		return _wav(_normalise(out), false))


## Tyre squeal on touchdown: a short falling chirp with rubbery noise.
static func squeal() -> AudioStreamWAV:
	return _cached("squeal", func() -> AudioStreamWAV:
		var n := int(RATE * 0.35)
		var noise := _white(n, 61)
		var out := PackedFloat32Array()
		out.resize(n)
		var ph := 0.0
		for i in n:
			var t := float(i) / RATE
			ph += lerpf(1100.0, 750.0, t / 0.35) / RATE
			var env := minf(t / 0.01, 1.0) * exp(-9.0 * t)
			out[i] = env * (0.6 * sin(TAU * ph) + 0.25 * sin(TAU * 2.0 * ph) + 0.2 * noise[i])
		return _wav(out, false))


## Crash: a long noisy blast with a deep rumble that dies away.
static func crash() -> AudioStreamWAV:
	return _cached("crash", func() -> AudioStreamWAV:
		var n := int(RATE * 1.8)
		var rng := _rng(71)
		var hi := _white(n, 72)
		var lo := _lowpass(_white(n, 73), 0.04)
		lo = _normalise(lo)
		var out := PackedFloat32Array()
		out.resize(n)
		var debris := 0.0
		for i in n:
			var t := float(i) / RATE
			if rng.randf() < 0.002 * exp(-2.0 * t):
				debris = rng.randf_range(0.4, 1.0)
			debris *= 0.995
			var env := minf(t / 0.005, 1.0)
			out[i] = env * (exp(-6.0 * t) * hi[i] * 0.7 + exp(-1.6 * t) * lo[i] + debris * hi[i] * 0.4)
		return _wav(_normalise(out), false))


# --- Building blocks ---

static func _cached(key: String, build: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _white(n: int, s: int) -> PackedFloat32Array:
	var r := _rng(s)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = r.randf_range(-1.0, 1.0)
	return a


## One-pole low-pass (k small = darker).
static func _lowpass(x: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := 0.0
	for i in x.size():
		y += k * (x[i] - y)
		x[i] = y
	return x


static func _normalise(x: PackedFloat32Array, peak := 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in x:
		m = maxf(m, absf(v))
	for i in x.size():
		x[i] *= peak / m
	return x


## Fades the last `fade` samples into the first ones and drops them, so the
## loop point is seamless.
static func _crossfade_loop(x: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := x.size() - fade
	for i in fade:
		var t := float(i) / fade
		x[i] = x[i] * t + x[n + i] * (1.0 - t)
	return x.slice(0, n)


static func _saw(ph: float) -> float:
	return 2.0 * (ph - floorf(ph)) - 1.0


static func _wav(x: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(x.size() * 2)
	for i in x.size():
		bytes.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = x.size()
	return w
