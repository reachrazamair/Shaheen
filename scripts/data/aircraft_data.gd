class_name AircraftData
extends Resource
## Every per-aircraft number lives here, so a new aircraft is just a new .tres.
## Units are SI (kg, N, m, m/s) unless the name says otherwise (kt, deg, s).
## Fields are added chunk by chunk as the flight model grows.

@export var display_name := "Aircraft"

@export_group("Mass and engine")
## Constant for now (fuel weight effects come with the mission planner, Phase 4).
@export var mass_kg := 1100.0
## Thrust at full throttle when standing still. Raising thrust AND drag together
## keeps the top speed but makes speed changes punchier.
@export var max_thrust_n := 8400.0
## Propeller thrust fades linearly to zero at this airspeed (kt).
## Set to 0 for jets (thrust stays constant with speed).
@export var thrust_zero_speed_kt := 215.0
## Arcade knob: how many times faster speed builds and bleeds along the flight
## path. Doesn't change top speed, climb rate or stall speed, only how quickly
## the plane gets there (1.0 = physically honest inertia).
@export var speed_response := 1.4
## Time for the engine to spool up after E (and to wind down when shut off).
@export var engine_spool_time_s := 1.5
## Propeller aircraft draw a spinning/still propeller; jets don't.
@export var has_propeller := true

@export_group("Afterburner")
## Extra thrust at full afterburner (0 = no afterburner). Military (dry) thrust
## is max_thrust_n, reached at afterburner_threshold; throttle above that
## lights the afterburner.
@export var afterburner_thrust_n := 0.0
@export var afterburner_threshold := 0.85
## Fuel burn multiplier at full afterburner.
@export var afterburner_burn_multiplier := 3.0

@export_group("Fuel")
## Fuel quantity is compressed for gameplay (a flight lasts minutes, not hours).
@export var fuel_capacity_kg := 90.0
## Burn at full throttle; scales down toward idle_burn_fraction at idle.
@export var fuel_burn_full_kg_s := 0.25
@export var idle_burn_fraction := 0.15
## LOW FUEL warning below this fraction of capacity.
@export var low_fuel_fraction := 0.15

@export_group("Drag")
## Parasitic drag force = drag_coefficient * speed^2  (N per (m/s)^2).
@export var drag_coefficient := 0.7
## Extra drag from producing lift: adds induced_drag * cl^2 to the drag multiplier.
## Makes hard pulls and slow, nose-high flight bleed energy.
@export var induced_drag := 2.0
## Extra drag while the nose is rotating: adds pitch_rate_drag * |pitch rate in deg/s|
## to the drag multiplier. Yanking the nose up sharply costs a lot of speed;
## gentle, smooth pitch changes cost little.
@export var pitch_rate_drag := 0.35

@export_group("Lift and stall")
## Clean (no flaps) stall speed. Lift equals weight at this speed at the stall angle.
@export var stall_speed_kt := 55.0
## Angle of attack (nose vs flight path) where the wing stalls.
@export var stall_aoa_deg := 15.0
## Fraction of max lift produced with the nose exactly on the flight path (wing incidence/camber).
@export var zero_aoa_lift := 0.25
## Fraction of max lift left once fully stalled.
@export var post_stall_lift := 0.45
## How fast the nose drops on its own while stalled. Owner's choice: 0, i.e. the
## aircraft keeps its attitude and falls; the player must push the nose down
## (RIGHT) to recover. (Pulling up is blocked while stalled.)
@export var stall_nose_drop_deg_s := 0.0
## Once stalled, the stall lasts at least this long, so the nose drop is decisive
## and the warning doesn't flicker while the player is still pulling back.
@export var min_stall_time_s := 0.8

@export_group("Flaps")
## Per setting [UP, TO, LDG]: extra max lift (0.45 = +45%, lowers stall speed by ~17%).
@export var flap_lift_bonus := PackedFloat32Array([0.0, 0.2, 0.45])
## Per setting [UP, TO, LDG]: added to the parasitic drag multiplier.
@export var flap_drag := PackedFloat32Array([0.0, 0.25, 0.7])
## Seconds to move one flap step.
@export var flap_move_time_s := 1.2
## Flap setting at the start of a flight (0 UP, 1 TO, 2 LDG).
@export var default_flap_setting := 1

@export_group("Landing gear")
## False = fixed gear (e.g. Super Mushshak): always down, G does nothing.
@export var retractable_gear := false
## Added to the parasitic drag multiplier while extended (0 if built into the base drag).
@export var gear_drag := 0.0
@export var gear_transit_time_s := 3.0

@export_group("Air brake")
## B in the air: added to the parasitic drag multiplier.
@export var airbrake_drag := 1.2

@export_group("Pitch")
## Max nose rotation rate at full control authority.
@export var pitch_rate_deg_s := 25.0
## How quickly the pitch rate builds/settles (smoothing; higher = snappier).
@export var pitch_accel_deg_s2 := 150.0
## Below this speed the nose wheel stays on the ground.
@export var rotate_speed_kt := 60.0
## Holding nose-up on the takeoff roll starts lifting the nose from this
## fraction of rotate speed (fully free at rotate speed).
@export var rotate_start_fraction := 0.7
## Takeoff roll: once the nose wheel is off and speed >= rotate speed, the
## nose keeps coming up at this rate to the takeoff attitude (tail-strike
## limit - 2 deg), so the aircraft flies off by itself.
@export var auto_rotate_rate_deg_s := 4.0
## Landing roll: the nose comes down by itself at derotate_rate_deg_s unless
## the player holds nose-up; below this fraction of rotate speed it comes down
## whatever the stick says. (Nose down = weight on the wheels = brakes bite.)
@export var nose_down_fraction := 0.75
@export var derotate_rate_deg_s := 5.0
## Below rotate speed (and on the slow part of the landing roll) the tail
## doesn't have the airflow to lift the nose higher than this.
@export var max_ground_pitch_deg := 12.0
## Pitch at which the tail hits the runway = crash. No pitch limit otherwise:
## at or above rotate speed the player can over-rotate into a tail strike.
## Also checked just after lift-off: the tail sits sprite_main_wheel_x texture
## px behind the main wheels, so with the wheels only a few metres up a big
## pitch still drags the tail.
@export var tail_strike_pitch_deg := 15.0

@export_group("Ground handling")
## Rolling resistance as a fraction of the weight on the wheels.
@export var rolling_friction := 0.03
## Wheel-brake deceleration in g (0.9 = 0.9 g), scaled by weight on the wheels.
@export var brake_strength := 0.9

@export_group("Landing grading")
## Touchdown sink rate limits (ft/min). Up to perfect = PERFECT, then GOOD,
## FIRM, HARD; beyond hard_touchdown_fpm the gear collapses = CRASH.
@export var perfect_touchdown_fpm := 150.0
@export var good_touchdown_fpm := 300.0
@export var firm_touchdown_fpm := 500.0
@export var hard_touchdown_fpm := 800.0
## Bounce: a touchdown harder than bounce_from_fpm (but not a crash) makes the
## aircraft hop back into the air, like a real firm landing that "skips".
## Hop height grows from bounce_height_min_m just above bounce_from_fpm to
## bounce_height_max_m at hard_touchdown_fpm (gravity only; lift lets it float
## a little higher). Softer than bounce_from_fpm = no bounce at all.
@export var bounce_from_fpm := 500.0
@export var bounce_height_min_m := 0.3
@export var bounce_height_max_m := 1.2
## Touching down with the nose more than this far below the horizon = the nose
## wheel hits first: one grade lower (not a crash).
@export var max_nose_down_touchdown_deg := 2.0
## Nose more than this far down at touchdown = slammed onto the nose wheel = crash.
@export var nose_first_crash_deg := 5.0
## Running off the end of a runway (or off it onto grass) faster than this = crash;
## slower = overrun penalty.
@export var overrun_crash_speed_kt := 15.0

@export_group("Limits and gauges")
## Airspeed gauge top end (later: overspeed warning). Yellow arc from 85%.
@export var max_speed_kt := 160.0
## Vertical speed gauge range, +/- this many ft/min.
@export var gauge_vsi_max_fpm := 2000.0
## Thrust starts fading above this altitude...
@export var service_ceiling_m := 3000.0
## ...and is gone this many metres higher (soft ceiling).
@export var ceiling_fade_m := 1000.0

@export_group("Pilot G effects")
## Screen effects from G on the pilot (fighters). Blackout: high positive G
## (sharp pull-up) darkens the screen from the edges. Redout: strong negative G
## (sharp push-over) tints it red. Only above g_effect_min_speed_kt.
@export var g_effects := false
@export var g_effect_min_speed_kt := 250.0
@export var blackout_start_g := 5.0
@export var blackout_full_g := 9.0
@export var redout_start_g := -1.5
@export var redout_full_g := -4.0
## How fast the effect builds and fades (fraction of full per second).
@export var g_effect_onset := 0.8
@export var g_effect_recovery := 1.2

@export_group("Sound")
## Engine sound, made in code (scripts/sound_synth.gd): Piston = firing pulses
## and propeller buzz; Jet = turbine whine over a roar, plus afterburner rumble.
@export_enum("Piston", "Jet") var engine_sound := 0
## Engine note (playback pitch) at idle and at full power; the note follows
## engine RPM while it spools up or winds down.
@export var engine_pitch_idle := 0.6
@export var engine_pitch_full := 1.25
## Engine loudness at full power (dB).
@export var engine_volume_db := -6.0
## How much quieter the engine is at idle than at full power (dB).
@export var engine_idle_drop_db := 10.0
## Afterburner rumble at full afterburner (dB). Ignored without an afterburner.
@export var afterburner_volume_db := -3.0

@export_group("Weapons (air to ground)")
## Can fly the air-to-ground mission (owner: jets only).
@export var strike_capable := false
## Free-fall bombs carried on a strike mission (Space drops one).
@export var bomb_count := 2
## Where each bomb hangs, texture px: x = middle of the bomb, y = its top
## (pylon). Dropped from the last entry first.
@export var bomb_hardpoints := PackedVector2Array()
## Bomb size on the sprite, texture px (drawn at sprite_scale like the art).
@export var bomb_length_px := 64.0
@export var bomb_diameter_px := 12.0
## Air drag on a falling bomb: deceleration = bomb_drag * speed^2 (1/m).
@export var bomb_drag := 0.0002
## Released bombs are pushed down off the pylon at this speed (m/s).
@export var bomb_eject_ms := 2.0
## A target this close (metres, edge to impact) is destroyed. Arcade-generous.
@export var bomb_blast_radius_m := 18.0

@export_group("Pilot")
## Rank shown with the player's name (badge, result screen) and in radio calls.
@export var pilot_rank := "AVN CDT"
@export var pilot_rank_call := "Avn Cdt"

@export_group("Lights (night)")
## Texture px. Nav light on the near wingtip (green, starboard side faces the
## viewer) and the far one (red, partly visible), white tail light, flashing
## anti-collision beacon, and the landing light on the nose gear (gear down only).
@export var light_nav_near := Vector2.ZERO
@export var light_nav_far := Vector2.ZERO
@export var light_tail := Vector2.ZERO
@export var light_beacon := Vector2.ZERO
@export var light_landing := Vector2.ZERO

@export_group("Cockpit")
## Instrument panel look: Analog = grey panel with round dials (trainers),
## Glass = dark jet cockpit with green digital screens (fighters).
@export_enum("Analog", "Glass", "Dark analog") var cockpit_style := 0

@export_group("Look")
## Real-world size in metres; drives the placeholder shape and sprite scale.
@export var length_m := 7.0
@export var height_m := 2.6
## Side-view art, nose pointing right, split into layers that share one canvas:
## body (no gear blades), landing gear (slides up behind the body to retract)
## and propeller blades (shown while the engine runs).
## Built from the owner's art by tools/make_mushshak_from_art.py.
## When `sprite` is empty, a simple placeholder silhouette is drawn instead.
@export var sprite: Texture2D
@export var sprite_gear: Texture2D
@export var sprite_prop: Texture2D
## World px per texture px (textures are stored larger and drawn scaled down
## so they look smooth).
@export var sprite_scale := 0.25
## In texture px from the top-left:
## y where the wheel bottoms sit with the gear down (= the ground line).
@export var sprite_wheel_bottom_y := 105.0
## x of the main wheels: the aircraft's origin and ground pivot (0 = middle).
@export var sprite_main_wheel_x := 0.0
## How far the gear layer slides up when fully retracted.
@export var sprite_gear_travel := 26.0
@export var sprite_prop_center := Vector2(272, 57)
@export var sprite_prop_radius := 34.0
## Code-drawn gear, used when sprite_gear is empty (art shows the gear retracted).
## One entry per leg (main first): x, y where it leaves the fuselage, wheel diameter.
@export var sprite_gear_x := PackedFloat32Array()
@export var sprite_gear_top_y := PackedFloat32Array()
@export var sprite_gear_wheel_size := PackedFloat32Array()
## Engine nozzle (afterburner flame starts here, pointing back) and flame length.
@export var sprite_nozzle := Vector2.ZERO
@export var afterburner_flame_length := 60.0
## Flame height at the nozzle (texture px); it widens a little further back.
@export var afterburner_flame_width := 14.0
## Moving tailplane/elevator layer (cut from the body by the sprite tool),
## drawn rotating about its hinge with the pitch keys. Empty = no moving tail.
@export var sprite_elevator: Texture2D
@export var sprite_elevator_hinge := Vector2.ZERO
## Full deflection (degrees) at full stick; trailing edge up for nose-up.
@export var elevator_max_deg := 12.0
## How fast the surface follows the stick (full travel per 1/x seconds).
@export var elevator_speed := 6.0
## Wing trailing edge, where the flap hangs from (flap length 0 = don't draw).
@export var sprite_flap_hinge := Vector2(130, 40)
@export var sprite_flap_length := 18.0
@export var body_color := Color(0.95, 0.95, 0.95)

var _picture: Texture2D


## Still picture of the whole aircraft for menus: the body with its tailplane
## layer on top (the body alone has the tailplane cut out), cropped to the
## visible pixels. Built once and cached.
func picture() -> Texture2D:
	if _picture != null or sprite == null:
		return _picture if _picture != null else sprite
	var img := sprite.get_image()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	if sprite_elevator:
		var e := sprite_elevator.get_image()
		if e.is_compressed():
			e.decompress()
		e.clear_mipmaps()
		e.convert(Image.FORMAT_RGBA8)
		img.blend_rect(e, Rect2i(Vector2i.ZERO, e.get_size()), Vector2i.ZERO)
	img = img.get_region(img.get_used_rect())
	img.generate_mipmaps()
	_picture = ImageTexture.create_from_image(img)
	return _picture
@export var stripe_color := Color(0.82, 0.12, 0.12)
@export var trim_color := Color(0.25, 0.4, 0.8)
