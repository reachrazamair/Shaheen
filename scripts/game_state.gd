extends Node
## Autoload "GameState": small bits of state that live across scenes
## (the flight scene is reloaded on retry). Not saved to disk yet.

const RANK := "AVN CDT"   # Aviation Cadet
const MAX_NAME_LENGTH := 16

var pilot_name := ""


## "AVN CDT ALI" style call sign for the HUD and messages.
func cadet_title() -> String:
	var n := pilot_name.strip_edges().to_upper()
	return RANK + (" " + n if n != "" else "")


## Short form for radio calls, e.g. "Avn Cdt Ali".
func cadet_call() -> String:
	var n := pilot_name.strip_edges()
	return "Avn Cdt " + (n.capitalize() if n != "" else "Cadet")
