class_name AircraftData
extends Resource
## Every per-aircraft number lives here, so a new aircraft is just a new .tres.
## Units are SI (kg, N, m, m/s) unless the name says otherwise (kt, ft).
## Fields are added chunk by chunk as the flight model grows.

@export var display_name := "Aircraft"

@export_group("Mass and engine")
@export var mass_kg := 1100.0
## Static thrust at full throttle.
@export var max_thrust_n := 3000.0

@export_group("Drag")
## Air drag force = drag_coefficient * speed^2  (N per (m/s)^2).
## Sets top speed: thrust balances drag at sqrt(max_thrust / drag_coefficient).
@export var drag_coefficient := 0.55

@export_group("Ground handling")
## Rolling resistance as a fraction of weight (0.03 = 3% of weight).
@export var rolling_friction := 0.03
## Wheel-brake deceleration in g (0.4 = 0.4 g extra deceleration).
@export var brake_strength := 0.4

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
