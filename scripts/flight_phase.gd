class_name FlightPhase
extends RefCounted
## Works out the flight phase shown in the top-centre box from the aircraft
## state. Kept separate from the HUD so landing/grading code can reuse it.

const TAKE_OFF := "TAKE OFF"
const CLIMB := "CLIMB"
const CRUISE := "CRUISE"
const DESCENT := "DESCENT"
const APPROACH := "APPROACH"
## Air-to-ground target run (set by the HUD, not computed here).
const ATTACK := "ATTACK"
const LANDED := "LANDED"
const CRASHED := "CRASHED"

## Still "TAKE OFF" until this height after lift-off.
const TAKEOFF_HEIGHT_FT := 300.0
## Vertical speed beyond which we call it a climb or descent.
const CLIMB_FPM := 300.0
## Within this distance of the destination runway (and not climbing) = approach.
const APPROACH_DISTANCE_M := 2500.0


## distance_to_destination_m: INF until destinations exist (chunk 1.6).
## near_departure: still close to the departure runway (TAKE OFF is only shown
## there; climbing from low level later on is just CLIMB).
static func compute(a: Aircraft, has_flown: bool, distance_to_destination_m := INF, near_departure := true) -> String:
	if a.crashed:
		return CRASHED
	if a.on_ground:
		return LANDED if has_flown else TAKE_OFF
	var vs := a.vertical_speed_fpm
	if distance_to_destination_m < APPROACH_DISTANCE_M and vs < CLIMB_FPM:
		return APPROACH
	if near_departure and a.altitude_ft < TAKEOFF_HEIGHT_FT and vs > 0.0:
		return TAKE_OFF
	if vs > CLIMB_FPM:
		return CLIMB
	if vs < -CLIMB_FPM:
		return DESCENT
	return CRUISE
