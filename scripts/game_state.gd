extends Node
## Autoload "GameState": small bits of state that live across scenes
## (the flight scene is reloaded on retry). Not saved to disk yet.

const MAX_NAME_LENGTH := 16

## Aircraft the player can choose on the start screen (in unlock order).
const AIRCRAFT := [
	"res://data/aircraft/super_mushshak.tres",
	"res://data/aircraft/f16.tres",
	"res://data/aircraft/mirage5.tres",
]

## Night: the world canvas is multiplied by this colour (CanvasModulate).
const NIGHT_TINT := Color(0.2, 0.24, 0.4)

var pilot_name := ""
## Path of the chosen AircraftData.
var aircraft_path: String = AIRCRAFT[0]
## Time of day chosen on the start screen.
var night := false


## The chosen aircraft's data (rank, etc.).
func aircraft_data() -> AircraftData:
	return load(aircraft_path)


## Rank shown with the name: Aviation Cadet in the trainer, Squadron Leader
## in the F-16 (AircraftData.pilot_rank), e.g. "AVN CDT ALI" / "SQN LDR ALI".
func pilot_title() -> String:
	var n := pilot_name.strip_edges().to_upper()
	return aircraft_data().pilot_rank + (" " + n if n != "" else "")


## Short form for radio calls, e.g. "Avn Cdt Ali" / "Sqn Ldr Ali".
func pilot_call() -> String:
	var n := pilot_name.strip_edges()
	return aircraft_data().pilot_rank_call + (" " + n.capitalize() if n != "" else "")


## A light's colour boosted so it still shines at full brightness under the
## night tint (lights are drawn in the world canvas, which is darkened).
func glow(c: Color) -> Color:
	if not night:
		return c
	return Color(c.r / NIGHT_TINT.r, c.g / NIGHT_TINT.g, c.b / NIGHT_TINT.b, c.a)
