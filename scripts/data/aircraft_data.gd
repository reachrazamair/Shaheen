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
@export var speed_response := 2.0
## Time for the engine to spool up after E (and to wind down when shut off).
@export var engine_spool_time_s := 1.5

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
@export var induced_drag := 0.6

@export_group("Lift and stall")
## Clean (no flaps) stall speed. Lift equals weight at this speed at the stall angle.
@export var stall_speed_kt := 55.0
## Angle of attack (nose vs flight path) where the wing stalls.
@export var stall_aoa_deg := 15.0
## Fraction of max lift produced with the nose exactly on the flight path (wing incidence/camber).
@export var zero_aoa_lift := 0.25
## Fraction of max lift left once fully stalled.
@export var post_stall_lift := 0.45
## How fast the nose drops on its own while stalled.
## (TODO: owner wants an option to turn this auto nose-drop on/off; see ROADMAP.)
@export var stall_nose_drop_deg_s := 25.0
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
@export var max_pitch_up_deg := 35.0
@export var max_pitch_down_deg := 30.0
## Below this speed the nose wheel stays on the ground.
@export var rotate_speed_kt := 60.0
## Max nose-up on the ground before the tail would strike.
@export var max_ground_pitch_deg := 12.0

@export_group("Ground handling")
## Rolling resistance as a fraction of the weight on the wheels.
@export var rolling_friction := 0.03
## Wheel-brake deceleration in g (0.9 = 0.9 g), scaled by weight on the wheels.
@export var brake_strength := 0.9

@export_group("Limits")
## Gauge top end (later: overspeed warning).
@export var max_speed_kt := 160.0
## Thrust starts fading above this altitude...
@export var service_ceiling_m := 3000.0
## ...and is gone this many metres higher (soft ceiling).
@export var ceiling_fade_m := 1000.0

@export_group("Look")
## Real-world size in metres; drives the placeholder shape and sprite scale.
@export var length_m := 7.0
@export var height_m := 2.6
## Optional finished sprite (nose pointing right, wheels touching the bottom edge).
## When empty, a placeholder silhouette is drawn instead.
@export var sprite: Texture2D
@export var body_color := Color(0.95, 0.95, 0.95)
@export var stripe_color := Color(0.82, 0.12, 0.12)
@export var trim_color := Color(0.25, 0.4, 0.8)
