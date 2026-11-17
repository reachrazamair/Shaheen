extends Node
## Autoload "GameState": small bits of state that live across scenes
## (the flight scene is reloaded on retry). Not saved to disk yet.

const RANK := "AVN CDT"   # Aviation Cadet
const MAX_NAME_LENGTH := 16

## Aircraft the player can choose on the start screen (in unlock order).
const AIRCRAFT := [
	"res://data/aircraft/super_mushshak.tres",
	"res://data/aircraft/f16.tres",
]

var pilot_name := ""
## Path of the chosen AircraftData.
var aircraft_path: String = AIRCRAFT[0]


## "AVN CDT ALI" style call sign for the HUD and messages.
func cadet_title() -> String:
	var n := pilot_name.strip_edges().to_upper()
	return RANK + (" " + n if n != "" else "")


## Short form for radio calls, e.g. "Avn Cdt Ali".
func cadet_call() -> String:
	var n := pilot_name.strip_edges()
	return "Avn Cdt " + (n.capitalize() if n != "" else "Cadet")
